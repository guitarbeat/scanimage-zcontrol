classdef NumericUtils < handle
    % NumericUtils - Numeric computation and validation utilities
    
    methods (Static)
        function result = safeDiv(numerator, denominator, defaultValue)
            % Safe division with default value for division by zero
            if nargin < 3
                defaultValue = NaN;
            end
            
            if denominator == 0
                result = defaultValue;
            else
                result = numerator / denominator;
            end
        end
        
        function normalized = normalizeToFirst(data)
            % Normalize data array to first non-zero value
            normalized = data;
            if ~isempty(data)
                firstNonZero = data(find(data ~= 0, 1, 'first'));
                if ~isempty(firstNonZero) && firstNonZero ~= 0
                    normalized = data / firstNonZero;
                end
            end
        end
        
        function limited = limitRange(value, minVal, maxVal)
            % Limit value to specified range
            limited = max(minVal, min(maxVal, value));
        end
        
        function rounded = roundToPrecision(value, precision)
            % Round value to specified precision
            if nargin < 2
                precision = 0.1;
            end
            rounded = round(value / precision) * precision;
        end
        
        function [minVal, maxVal] = getDataRange(data, padding)
            % Get data range with optional padding
            if nargin < 2
                padding = 0.05; % 5% padding
            end
            
            if isempty(data)
                minVal = 0;
                maxVal = 1;
                return;
            end
            
            validData = data(~isnan(data) & ~isinf(data));
            if isempty(validData)
                minVal = 0;
                maxVal = 1;
                return;
            end
            
            minVal = min(validData);
            maxVal = max(validData);
            
            if minVal == maxVal
                minVal = minVal - 1;
                maxVal = maxVal + 1;
            else
                range = maxVal - minVal;
                paddingAmount = range * padding;
                minVal = minVal - paddingAmount;
                maxVal = maxVal + paddingAmount;
            end
        end
        
        function interpolated = interpolateGaps(data, positions)
            % Interpolate NaN gaps in data
            interpolated = data;
            if nargin < 2
                positions = 1:length(data);
            end
            
            validIdx = ~isnan(data);
            if sum(validIdx) >= 2
                interpolated(~validIdx) = interp1(positions(validIdx), ...
                    data(validIdx), positions(~validIdx), 'linear', 'extrap');
            end
        end
        
        function smoothed = smoothData(data, windowSize)
            % Smooth data using moving average
            if nargin < 2
                windowSize = 5;
            end
            
            if length(data) < windowSize
                smoothed = data;
                return;
            end
            
            try
                smoothed = movmean(data, windowSize);
            catch
                % Fallback for older MATLAB versions
                smoothed = NumericUtils.movingAverage(data, windowSize);
            end
        end
        
        function averaged = movingAverage(data, windowSize)
            % Manual moving average implementation
            averaged = data;
            halfWindow = floor(windowSize / 2);
            
            for i = 1:length(data)
                startIdx = max(1, i - halfWindow);
                endIdx = min(length(data), i + halfWindow);
                averaged(i) = mean(data(startIdx:endIdx));
            end
        end
        
        function metric = calculateMetric(pixelData, metricType)
            % Calculate various metrics from pixel data
            if isempty(pixelData)
                metric = NaN;
                return;
            end
            
            switch metricType
                case 'Std Dev'
                    metric = std(pixelData(:));
                case 'Mean'
                    metric = mean(pixelData(:));
                case 'Max'
                    metric = max(pixelData(:));
                case 'Min'
                    metric = min(pixelData(:));
                case 'Variance'
                    metric = var(pixelData(:));
                case 'Range'
                    metric = max(pixelData(:)) - min(pixelData(:));
                otherwise
                    metric = std(pixelData(:)); % Default to std dev
            end
        end
    end
end