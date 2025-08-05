%==============================================================================
% FILEPATHUTILS.M
%==============================================================================
% File and path manipulation utility class for Foilview.
%
% This class provides static methods for ensuring absolute paths, checking
% and creating directories, generating safe filenames, and handling file
% extensions and uniqueness. It is used throughout the application for
% robust file and path operations.
%
% Key Features:
%   - Absolute/relative path handling
%   - Directory existence checks and creation
%   - Filesystem-safe filename generation
%   - Unique file path generation with timestamps
%   - Relative path calculation
%
% Dependencies:
%   - MATLAB: File I/O and path utilities
%   - FoilviewUtils: Error handling
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   FilePathUtils.ensureFullPath('data/file.txt');
%   FilePathUtils.makeSafeFilename('my:file?.txt');
%
%==============================================================================

classdef FilePathUtils < handle
    % FilePathUtils - File and path manipulation utilities
    
    methods (Static)
        function fullPath = ensureFullPath(path, basePath)
            % Ensure path is absolute, using basePath if relative
            if nargin < 2
                basePath = pwd;
            end
            
            if isAbsolutePath(path)
                fullPath = path;
            else
                fullPath = fullfile(basePath, path);
            end
        end
        
        function isAbs = isAbsolutePath(path)
            % Check if path is absolute
            if ispc
                isAbs = length(path) >= 2 && path(2) == ':';
            else
                isAbs = ~isempty(path) && path(1) == '/';
            end
        end
        
        function success = ensureDirectoryExists(dirPath)
            % Create directory if it doesn't exist
            success = false;
            try
                if ~exist(dirPath, 'dir')
                    mkdir(dirPath);
                end
                success = true;
            catch ME
                FoilviewUtils.logException('FilePathUtils', ME);
            end
        end
        
        function safeName = makeSafeFilename(filename, maxLength)
            % Create filesystem-safe filename
            if nargin < 2
                maxLength = 255;
            end
            
            % Remove invalid characters
            invalidChars = '<>:"/\|?*';
            safeName = filename;
            for i = 1:length(invalidChars)
                safeName = strrep(safeName, invalidChars(i), '_');
            end
            
            % Truncate if too long
            if length(safeName) > maxLength
                [~, name, ext] = fileparts(safeName);
                maxNameLength = maxLength - length(ext);
                if maxNameLength > 0
                    safeName = [name(1:maxNameLength) ext];
                else
                    safeName = name(1:maxLength);
                end
            end
        end
        
        function uniquePath = makeUniqueFilePath(basePath, extension)
            % Generate unique file path with timestamp
            if nargin < 2
                extension = '.mat';
            end
            
            timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
            filename = sprintf('%s_%s%s', basePath, timestamp, extension);
            
            counter = 1;
            uniquePath = filename;
            while exist(uniquePath, 'file')
                uniquePath = sprintf('%s_%s_%d%s', basePath, timestamp, counter, extension);
                counter = counter + 1;
            end
        end
        
        function relativePath = getRelativePath(fullPath, basePath)
            % Get relative path from base path
            if nargin < 2
                basePath = pwd;
            end
            
            try
                relativePath = relativepath(fullPath, basePath);
            catch
                % Fallback if relativepath is not available
                relativePath = fullPath;
            end
        end
    end
end