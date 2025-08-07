%==============================================================================
% BOOKMARKMANAGER.M
%==============================================================================
% Manager class for position bookmark storage and retrieval.
%
% This manager handles the storage, retrieval, and management of position
% bookmarks within the Foilview application. It provides a unified interface
% for adding, removing, and accessing bookmarked positions with associated
% metadata including metrics and labels.
%
% Key Features:
%   - Position bookmark storage with X, Y, Z coordinates
%   - Metric association with each bookmark
%   - Label-based bookmark identification
%   - Automatic metadata logging to files
%   - Duplicate label handling (replace existing)
%   - Index-based bookmark access and removal
%   - Maximum metric tracking and bookmarking
%
% Bookmark Structure:
%   - Labels: Human-readable identifiers for positions
%   - XPositions: X-axis coordinates in micrometers
%   - YPositions: Y-axis coordinates in micrometers
%   - ZPositions: Z-axis coordinates in micrometers
%   - Metrics: Associated metric data (type, value, etc.)
%
% Dependencies:
%   - MetadataService: Metadata logging and file management
%   - FoilviewUtils: Utility functions for error handling
%   - Main application: Access to controller and metadata configuration
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   manager = BookmarkManager();
%   manager.add('Focus Point', 100, 200, 50, metricStruct);
%   bookmark = manager.get(1);  % Get first bookmark
%
%==============================================================================

classdef BookmarkManager < handle
    properties (Access = public)
        MarkedPositions = struct('Labels', {{}}, 'XPositions', [], 'YPositions', [], 'ZPositions', [], 'Metrics', {{}})
    end
    
    properties (Access = private)
        FoilviewApp
    end

    methods (Access = public)
        function obj = BookmarkManager()
            % Constructor
        end
        
        function setFoilviewApp(obj, foilviewApp)
            % Set reference to the main foilview app for metadata logging
            obj.FoilviewApp = foilviewApp;
        end

        function add(obj, label, xPos, yPos, zPos, metricStruct)
            % Unified helper to add a bookmark, replacing any with the same label.
            existingIdx = strcmp(obj.MarkedPositions.Labels, label);
            if any(existingIdx)
                obj.remove(existingIdx);
            end

            % Initialize structure arrays if empty
            if isempty(obj.MarkedPositions.Labels)
                obj.MarkedPositions.Labels = {};
                obj.MarkedPositions.XPositions = [];
                obj.MarkedPositions.YPositions = [];
                obj.MarkedPositions.ZPositions = [];
                obj.MarkedPositions.Metrics = {};
            end

            % Append new bookmark
            obj.MarkedPositions.Labels{end+1} = label;
            obj.MarkedPositions.XPositions(end+1) = xPos;
            obj.MarkedPositions.YPositions(end+1) = yPos;
            obj.MarkedPositions.ZPositions(end+1) = zPos;
            obj.MarkedPositions.Metrics{end+1} = metricStruct;
            
            % Save bookmark to metadata using MetadataService
            if ~isempty(obj.FoilviewApp) && isvalid(obj.FoilviewApp)
                try
                    % Get metadata file path from workspace instead of app property
                    metadataFile = obj.getMetadataFile();
                    if ~isempty(metadataFile)
                        MetadataService.saveBookmarkMetadata(label, xPos, yPos, zPos, metricStruct, ...
                            metadataFile, obj.FoilviewApp.Controller);
                    end
                catch ME
                    FoilviewUtils.logException('BookmarkManager.add', ME);
                end
            end
        end

        function remove(obj, index)
            if obj.isValidIndex(index)
                obj.MarkedPositions.Labels(index) = [];
                obj.MarkedPositions.XPositions(index) = [];
                obj.MarkedPositions.YPositions(index) = [];
                obj.MarkedPositions.ZPositions(index) = [];
                obj.MarkedPositions.Metrics(index) = [];
            end
        end

        function bookmark = get(obj, index)
            bookmark = [];
            if obj.isValidIndex(index)
                bookmark = struct(...
                    'Label', obj.MarkedPositions.Labels{index}, ...
                    'X', obj.MarkedPositions.XPositions(index), ...
                    'Y', obj.MarkedPositions.YPositions(index), ...
                    'Z', obj.MarkedPositions.ZPositions(index), ...
                    'Metric', obj.MarkedPositions.Metrics{index} ...
                );
            end
        end

        function updateMax(obj, metricType, value, xPos, yPos, zPos)
            label = sprintf('Max %s (%.1f)', metricType, value);
            
            % Remove any existing bookmark with the same metric type prefix
            existingIdx = find(cellfun(@(x) startsWith(x, ['Max ' metricType]), obj.MarkedPositions.Labels));
            if ~isempty(existingIdx)
                obj.remove(existingIdx);
            end

            metricStruct = struct('Type', metricType, 'Value', value);
            obj.add(label, xPos, yPos, zPos, metricStruct);
        end
        
        function labels = getLabels(obj)
            labels = obj.MarkedPositions.Labels;
        end

        function valid = isValidIndex(obj, index)
            valid = isnumeric(index) && isscalar(index) && index >= 1 && index <= length(obj.MarkedPositions.Labels);
        end
        
        function metadataFile = getMetadataFile(~)
            % Get the metadata file path from workspace
            try
                metadataFile = evalin('base', 'metadataFilePath');
                if ~ischar(metadataFile) || isempty(metadataFile)
                    metadataFile = '';
                end
            catch
                metadataFile = '';
            end
        end

        function loadBookmarksFromMetadata(obj, metadataFile)
            % loadBookmarksFromMetadata - Loads bookmarks from a metadata file and updates MarkedPositions
            % Assumes metadata file is CSV with bookmark fields
            try
                if nargin < 2 || isempty(metadataFile)
                    metadataFile = obj.getMetadataFile();
                end
                if isempty(metadataFile) || ~exist(metadataFile, 'file')
                    FoilviewUtils.warn('BookmarkManager', 'Metadata file not found: %s', metadataFile);
                    return;
                end
                % Use FilePathUtils to ensure full path
                metadataFile = FilePathUtils.ensureFullPath(metadataFile);
                % Read file as text
                fid = fopen(metadataFile, 'r');
                if fid == -1
                    FoilviewUtils.warn('BookmarkManager', 'Could not open metadata file: %s', metadataFile);
                    return;
                end
                lines = {};
                tline = fgetl(fid);
                while ischar(tline)
                    lines{end+1} = tline; %#ok<AGROW>
                    tline = fgetl(fid);
                end
                fclose(fid);
                % Parse lines for bookmarks
                labels = {};
                xPos = [];
                yPos = [];
                zPos = [];
                metrics = {};
                for i = 1:length(lines)
                    line = lines{i};
                    tokens = strsplit(line, ',');
                    % Expecting at least 18 columns (see ScanImageManager writeMetadataToFile)
                    if numel(tokens) >= 18
                        bookmarkLabel = strtrim(tokens{16});
                        bookmarkMetricType = strtrim(tokens{17});
                        bookmarkMetricValue = strtrim(tokens{18});
                        if ~isempty(bookmarkLabel)
                            % Parse positions (columns 15, 14, 13: z, x, y)
                            try
                                z = str2double(tokens{14});
                                x = str2double(tokens{15});
                                y = str2double(tokens{16});
                            catch
                                z = NaN; x = NaN; y = NaN;
                            end
                            % Parse metric value
                            metricVal = str2double(bookmarkMetricValue);
                            if isnan(metricVal)
                                metricVal = bookmarkMetricValue;
                            end
                            metricStruct = struct('Type', bookmarkMetricType, 'Value', metricVal);
                            labels{end+1} = bookmarkLabel;
                            xPos(end+1) = x;
                            yPos(end+1) = y;
                            zPos(end+1) = z;
                            metrics{end+1} = metricStruct;
                        end
                    end
                end
                % Update MarkedPositions
                obj.MarkedPositions.Labels = labels;
                obj.MarkedPositions.XPositions = xPos;
                obj.MarkedPositions.YPositions = yPos;
                obj.MarkedPositions.ZPositions = zPos;
                obj.MarkedPositions.Metrics = metrics;
                % Note: This method doesn't have a logger property, so we'll use FoilviewUtils
                FoilviewUtils.info('BookmarkManager', 'Loaded %d bookmarks from metadata', numel(labels));
            catch ME
                FoilviewUtils.logException('BookmarkManager', ME, 'loadBookmarksFromMetadata failed');
            end
        end
    end
end 