classdef FoilviewUtils < handle
    
    properties (Constant, Access = public)
        ERROR_PREFIX = 'Error in %s: %s\n'
        
        UI_STYLE = struct(...
            'FONT_SIZE_SMALL', 9, ...
            'FONT_SIZE_NORMAL', 10, ...
            'FONT_SIZE_MEDIUM', 11, ...
            'FONT_SIZE_LARGE', 12, ...
            'FONT_SIZE_XLARGE', 14, ...
            'FONT_WEIGHT_NORMAL', 'normal', ...
            'FONT_WEIGHT_BOLD', 'bold', ...
            'LINE_WIDTH', 1.5, ...
            'MARKER_SIZE', 4)
        
        BUTTON_FIELDS = {'UpButton', 'DownButton', 'DirectionButton', 'StartStopButton', 'ZeroButton', ...
                         'MarkButton', 'GoToButton', 'DeleteButton', 'RefreshButton', ...
                         'ClearButton', 'ExportButton', 'ExpandButton'}
        
        FIELD_FIELDS = {'StepField', 'StepsField', 'DelayField', 'MarkField'}
        
        DROPDOWN_FIELDS = {'StepSizeDropdown', 'TypeDropdown'}
        
        SWITCH_FIELDS = {'DirectionSwitch'}
        
        DEFAULT_UPDATE_THROTTLE = 0.05
        DEFAULT_PLOT_THROTTLE = 0.1
        DEFAULT_MAX_DATA_POINTS = 1000
        
        POSITION_PRECISION_THRESHOLD = 0.1
    end
    
    methods (Static)
    
        function logError(context, error)
            % Centralized error logging with consistent formatting
            if ischar(error)
                fprintf(FoilviewUtils.ERROR_PREFIX, context, error);
            elseif isstruct(error) && isfield(error, 'message')
                fprintf(FoilviewUtils.ERROR_PREFIX, context, error.message);
            else
                fprintf('Error in %s: Unknown error\n', context);
            end
        end
        
        function success = safeExecute(func, context, suppressErrors)
            % Execute function with standardized error handling
            if nargin < 3, suppressErrors = false; end
            success = false;
            try
                func();
                success = true;
            catch e
                if ~suppressErrors
                    FoilviewUtils.logError(context, e);
                end
            end
        end
        
        function output = safeExecuteWithReturn(func, functionName, defaultValue)
            % Safely execute a function and return a value, with error handling
            try
                output = func();
            catch ME
                fprintf('Error in %s: %s\n', functionName, ME.message);
                output = defaultValue;
            end
        end
        
        
        
        function setControlEnabled(control, enabled, fieldName)
            % Safely enable/disable a control with validation
            if nargin < 3, fieldName = ''; end
            
            if ~isempty(fieldName)
                if ~isfield(control, fieldName) || ~FoilviewUtils.validateUIComponent(control.(fieldName))
                    return;
                end
                control.(fieldName).Enable = FoilviewUtils.getEnableState(enabled);
            else
                if FoilviewUtils.validateUIComponent(control)
                    control.Enable = FoilviewUtils.getEnableState(enabled);
                end
            end
        end
        
        function setControlsEnabled(controlStruct, enabled, fieldNames)
            % Enable/disable multiple controls efficiently
            if nargin < 3
                fieldNames = FoilviewUtils.getAllControlFields();
            end
            
            for i = 1:length(fieldNames)
                FoilviewUtils.setControlEnabled(controlStruct, enabled, fieldNames{i});
            end
        end
        
        function fields = getAllControlFields()
            % Get all common control field names
            fields = [FoilviewUtils.BUTTON_FIELDS, ...
                     FoilviewUtils.FIELD_FIELDS, ...
                     FoilviewUtils.DROPDOWN_FIELDS, ...
                     FoilviewUtils.SWITCH_FIELDS];
        end
        
    
        function str = formatPosition(position, highPrecision)
            % Centralized position formatting with automatic precision detection
            if nargin < 2
                highPrecision = abs(position) < FoilviewUtils.POSITION_PRECISION_THRESHOLD;
            end
            
            if highPrecision && abs(position) < FoilviewUtils.POSITION_PRECISION_THRESHOLD
                str = sprintf('%.2f μm', position);
            else
                str = sprintf('%.1f μm', position);
            end
        end
        
        function items = formatStepSizeItems(stepSizes)
            % Format step sizes for dropdown items
            items = arrayfun(@(x) FoilviewUtils.formatPosition(x), stepSizes, 'UniformOutput', false);
        end
        
        function str = formatPositionRange(minPos, maxPos)
            % Format position range for plot titles
            str = sprintf('%.1f - %.1f μm', minPos, maxPos);
        end
        
        function str = formatMetricValue(value)
            % Format metric values consistently
            if isnan(value)
                str = 'N/A';
            elseif value == 0
                str = '0.00';
            elseif abs(value) < 0.01
                str = sprintf('%.4f', value);
            elseif abs(value) < 1
                str = sprintf('%.3f', value);
            else
                str = sprintf('%.2f', value);
            end
        end
        
    
        function timerObj = createTimer(mode, period, callback)
            % Centralized timer creation with validation
            if ~ischar(mode) || ~isnumeric(period) || period <= 0
                error('Invalid timer parameters');
            end
            
            % Create timer object using proper constructor
            timerObj = timer();
            timerObj.ExecutionMode = mode;
            timerObj.Period = period;
            timerObj.TimerFcn = callback;
        end
        
        function safeStopTimer(timerObj)
            % Safe timer stopping with validation
            if ~isempty(timerObj) && isvalid(timerObj)
                try
                    stop(timerObj);
                    delete(timerObj);
                catch
                    % Ignore errors during cleanup
                end
            end
        end
        
        function cleanupAllTimers()
            % Clean up all timers - useful for shutdown
            try
                allTimers = timerfindall();
                for timerObj = allTimers'
                    FoilviewUtils.safeStopTimer(timerObj);
                end
            catch
                % Ignore errors if timerfindall is not available
            end
        end
        
    
        function valid = validateUIComponent(component)
            % Centralized UI component validation
            valid = ~isempty(component) && isvalid(component);
        end
        
        function valid = validateMultipleComponents(varargin)
            % Validate multiple UI components at once
            valid = true;
            for i = 1:nargin
                if ~FoilviewUtils.validateUIComponent(varargin{i})
                    valid = false;
                    break;
                end
            end
        end
        
        function valid = validateControlStruct(controlStruct, requiredFields)
            % Validate that a control structure has required fields
            valid = true;
            if nargin < 2, return; end
            
            for i = 1:length(requiredFields)
                if ~isfield(controlStruct, requiredFields{i}) || ...
                   ~FoilviewUtils.validateUIComponent(controlStruct.(requiredFields{i}))
                    valid = false;
                    break;
                end
            end
        end
        
        function enableState = getEnableState(enabled)
            % Convert boolean to MATLAB enable state
            enableState = matlab.lang.OnOffSwitchState(enabled);
        end
        
    
        function configureAxes(axes, titleText, xlabelText, ylabelText)
            % Centralized axis configuration with optional labels
            if ~FoilviewUtils.validateUIComponent(axes)
                return;
            end
            
            set(axes, 'Box', 'on', 'TickDir', 'out', ...
                'LineWidth', FoilviewUtils.UI_STYLE.LINE_WIDTH);
            
            if nargin >= 3 && ~isempty(xlabelText)
                xlabel(axes, xlabelText, 'FontSize', FoilviewUtils.UI_STYLE.FONT_SIZE_NORMAL);
            else
                xlabel(axes, 'Z Position (μm)', 'FontSize', FoilviewUtils.UI_STYLE.FONT_SIZE_NORMAL);
            end
            
            if nargin >= 4 && ~isempty(ylabelText)
                ylabel(axes, ylabelText, 'FontSize', FoilviewUtils.UI_STYLE.FONT_SIZE_NORMAL);
            else
                ylabel(axes, 'Normalized Metric Value', 'FontSize', FoilviewUtils.UI_STYLE.FONT_SIZE_NORMAL);
            end
            
            if nargin >= 2 && ~isempty(titleText)
                FoilviewUtils.setPlotTitle(axes, titleText);
            end
        end
        
        function setPlotTitle(axes, titleText, showRange, minPos, maxPos)
            % Centralized plot title setting
            if ~FoilviewUtils.validateUIComponent(axes)
                return;
            end
            
            if nargin > 3 && showRange && ~isempty(minPos) && ~isempty(maxPos)
                fullTitle = sprintf('%s (%s)', titleText, FoilviewUtils.formatPositionRange(minPos, maxPos));
            else
                fullTitle = titleText;
            end
            
            title(axes, fullTitle, 'FontSize', FoilviewUtils.UI_STYLE.FONT_SIZE_MEDIUM, ...
                'FontWeight', FoilviewUtils.UI_STYLE.FONT_WEIGHT_BOLD);
        end
        
        function legendObj = createLegend(axes, location)
            % Centralized legend creation
            if nargin < 2, location = 'northeast'; end
            legendObj = legend(axes, 'Location', location, 'Interpreter', 'none', ...
                           'FontSize', FoilviewUtils.UI_STYLE.FONT_SIZE_SMALL, 'Box', 'on');
        end
        
    
        function valid = validateNumericRange(value, minVal, maxVal, name)
            % Centralized numeric range validation
            valid = true;
            
            if ~isnumeric(value) || ~isscalar(value)
                if nargin >= 4
                    fprintf('%s must be a numeric scalar\n', name);
                end
                valid = false;
                return;
            end
            
            if value < minVal
                if nargin >= 4
                    fprintf('%s must be at least %.3f\n', name, minVal);
                end
                valid = false;
                return;
            end
            
            if value > maxVal
                if nargin >= 4
                    fprintf('%s must not exceed %.3f\n', name, maxVal);
                end
                valid = false;
                return;
            end
        end
        
        function valid = validateInteger(value, minVal, maxVal, name)
            % Centralized integer validation
            valid = FoilviewUtils.validateNumericRange(value, minVal, maxVal, name);
            
            if valid && mod(value, 1) ~= 0
                if nargin >= 4
                    fprintf('%s must be a whole number\n', name);
                end
                valid = false;
            end
        end
        
        function [valid, errorMsg] = validateStringInput(str, minLength, maxLength, invalidChars, name)
            % Comprehensive string validation
            valid = true;
            errorMsg = '';
            
            if nargin < 5, name = 'Input'; end
            if nargin < 4, invalidChars = ''; end
            if nargin < 3, maxLength = inf; end
            if nargin < 2, minLength = 1; end
            
            % Check for empty or whitespace-only strings
            if isempty(strtrim(str))
                valid = false;
                errorMsg = sprintf('%s cannot be empty', name);
                return;
            end
            
            % Check length
            if length(str) < minLength
                valid = false;
                errorMsg = sprintf('%s must be at least %d character(s)', name, minLength);
                return;
            end
            
            if length(str) > maxLength
                valid = false;
                errorMsg = sprintf('%s must not exceed %d characters', name, maxLength);
                return;
            end
            
            % Check for invalid characters
            if ~isempty(invalidChars) && any(ismember(str, invalidChars))
                valid = false;
                errorMsg = sprintf('%s contains invalid characters: %s', name, invalidChars);
                return;
            end
        end
        
    
        function result = extractStepSizeFromString(str)
            % Extract numeric step size from formatted string
            result = str2double(extractBefore(str, ' μm'));
        end
        
        function truncated = truncateString(str, maxLength)
            % Truncate string with ellipsis
            if length(str) <= maxLength
                truncated = str;
            else
                truncated = [str(1:maxLength-3) '...'];
            end
        end
        
        function formatted = formatBookmarkItem(label, xPos, yPos, zPos, metricValue, metricType, maxLabelLength)
            % Format bookmark list items consistently with XYZ coordinates
            if nargin < 7, maxLabelLength = 12; end
            
            formatted = sprintf('%-*s X:%.1f Y:%.1f Z:%.1f   %.1f %s', ...
                maxLabelLength, ...
                FoilviewUtils.truncateString(label, maxLabelLength), ...
                xPos, yPos, zPos, ...
                metricValue, ...
                metricType);
        end
        
    
        function shouldUpdate = shouldThrottleUpdate(lastUpdateTime, interval)
            % Check if enough time has passed for throttled updates
            if nargin < 2, interval = FoilviewUtils.DEFAULT_UPDATE_THROTTLE; end
            currentTime = posixtime(datetime('now'));  % Convert to seconds
            shouldUpdate = (currentTime - lastUpdateTime) >= interval;
        end
        
        function limitedData = limitDataForPerformance(data, maxPoints)
            % Limit data points for performance
            if nargin < 2, maxPoints = FoilviewUtils.DEFAULT_MAX_DATA_POINTS; end
            
            if length(data) <= maxPoints
                limitedData = data;
            else
                % Keep evenly spaced points
                indices = round(linspace(1, length(data), maxPoints));
                limitedData = data(indices);
            end
        end
        
        function [limitedPositions, limitedValues] = limitMetricsData(positions, valuesStruct, maxPoints)
            % Limit both positions and metrics data consistently
            if nargin < 3, maxPoints = FoilviewUtils.DEFAULT_MAX_DATA_POINTS; end
            
            if length(positions) <= maxPoints
                limitedPositions = positions;
                limitedValues = valuesStruct;
            else
                % Keep evenly spaced points
                indices = round(linspace(1, length(positions), maxPoints));
                limitedPositions = positions(indices);
                
                limitedValues = struct();
                fieldNames = fieldnames(valuesStruct);
                for i = 1:length(fieldNames)
                    limitedValues.(fieldNames{i}) = valuesStruct.(fieldNames{i})(indices);
                end
            end
        end
        
    
        function success = batchUIUpdate(updateFunctions, suppressErrors)
            % Perform multiple UI updates efficiently
            if nargin < 2, suppressErrors = true; end
            success = true;
            
            try
                % Temporarily disable graphics updates
                drawnow limitrate;
                
                % Execute all update functions
                for i = 1:length(updateFunctions)
                    if ~FoilviewUtils.safeExecute(updateFunctions{i}, ...
                            sprintf('batchUpdate function %d', i), suppressErrors)
                        success = false;
                    end
                end
                
                % Force graphics update
                drawnow;
                
            catch e
                FoilviewUtils.logError('batchUIUpdate', e);
                success = false;
            end
        end
        
    
        function config = getDefaultUIConfig()
            % Get default UI configuration to eliminate duplication
            config = struct(...
                'FontSize', FoilviewUtils.UI_STYLE.FONT_SIZE_NORMAL, ...
                'FontWeight', FoilviewUtils.UI_STYLE.FONT_WEIGHT_NORMAL, ...
                'LineWidth', FoilviewUtils.UI_STYLE.LINE_WIDTH, ...
                'MarkerSize', FoilviewUtils.UI_STYLE.MARKER_SIZE, ...
                'UpdateThrottle', FoilviewUtils.DEFAULT_UPDATE_THROTTLE, ...
                'PlotThrottle', FoilviewUtils.DEFAULT_PLOT_THROTTLE, ...
                'MaxDataPoints', FoilviewUtils.DEFAULT_MAX_DATA_POINTS);
        end
    end
end 
