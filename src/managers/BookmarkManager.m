classdef BookmarkManager < handle
    properties (Access = public)
        MarkedPositions = struct('Labels', {{}}, 'XPositions', [], 'YPositions', [], 'ZPositions', [], 'Metrics', {{}})
    end

    methods (Access = public)
        function obj = BookmarkManager()
            % Constructor
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
    end
end 