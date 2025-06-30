classdef foilview_utils < handle
    % foilview_utils - Utility functions to eliminate code duplication
    %
    % This class consolidates common functionality used across the foilview
    % application to eliminate code duplication and improve maintainability.
    
    properties (Constant, Access = public)
        % Centralized constants to eliminate duplication
        
        % Error handling configuration
        ERROR_PREFIX = 'Error in %s: %s\n'
        
        % Common UI component field names for validation
        BUTTON_FIELDS = {'UpButton', 'DownButton', 'DirectionButton', 'StartStopButton', 'ZeroButton', ...
                         'MarkButton', 'GoToButton', 'DeleteButton', 'RefreshButton', ...
                         'ClearButton', 'ExportButton', 'ExpandButton'}
        
        FIELD_FIELDS = {'StepField', 'StepsField', 'DelayField', 'MarkField'}
        
        DROPDOWN_FIELDS = {'StepSizeDropdown', 'TypeDropdown'}
        
        % Performance constants
        DEFAULT_UPDATE_THROTTLE = 0.05  % 50ms minimum between updates
        DEFAULT_PLOT_THROTTLE = 0.1     % 100ms minimum between plot updates
        DEFAULT_MAX_DATA_POINTS = 1000
        
        % Validation constants
        POSITION_PRECISION_THRESHOLD = 0.1  % When to use high precision formatting
    end
    
    methods (Static)
        %% Enhanced Error Handling Utilities
        function logError(context, error)
            % Centralized error logging with consistent formatting
            if ischar(error)
                fprintf(foilview_utils.ERROR_PREFIX, context, error);
            elseif isstruct(error) && isfield(error, 'message')
                fprintf(foilview_utils.ERROR_PREFIX, context, error.message);
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
                    foilview_utils.logError(context, e);
                end
            end
        end
        
        function success = safeExecuteWithReturn(func, context, defaultReturn)
            % Execute function with error handling and return value
            if nargin < 3, defaultReturn = []; end
            try
                success = func();
            catch e
                foilview_utils.logError(context, e);
                success = defaultReturn;
            end
        end
        
        %% Enhanced UI Styling Utilities
        % NOTE: Button styling moved to foilview_styling.styleButton()
        % This maintains backward compatibility for existing code.
        
        function setControlEnabled(control, enabled, fieldName)
            % Safely enable/disable a control with validation
            if nargin < 3, fieldName = ''; end
            
            if ~isempty(fieldName)
                if ~isfield(control, fieldName) || ~foilview_utils.validateUIComponent(control.(fieldName))
                    return;
                end
                control.(fieldName).Enable = foilview_utils.getEnableState(enabled);
            else
                if foilview_utils.validateUIComponent(control)
                    control.Enable = foilview_utils.getEnableState(enabled);
                end
            end
        end
        
        function setControlsEnabled(controlStruct, enabled, fieldNames)
            % Enable/disable multiple controls efficiently
            if nargin < 3
                fieldNames = foilview_utils.getAllControlFields();
            end
            
            for i = 1:length(fieldNames)
                foilview_utils.setControlEnabled(controlStruct, enabled, fieldNames{i});
            end
        end
        
        function fields = getAllControlFields()
            % Get all common control field names
            fields = [foilview_utils.BUTTON_FIELDS, ...
                     foilview_utils.FIELD_FIELDS, ...
                     foilview_utils.DROPDOWN_FIELDS];
        end
        
        %% Enhanced Position Formatting Utilities
        function str = formatPosition(position, highPrecision)
            % Centralized position formatting with automatic precision detection
            if nargin < 2
                highPrecision = abs(position) < foilview_utils.POSITION_PRECISION_THRESHOLD;
            end
            
            if highPrecision && abs(position) < foilview_utils.POSITION_PRECISION_THRESHOLD
                str = sprintf('%.2f μm', position);
            else
                str = sprintf('%.1f μm', position);
            end
        end
        
        function items = formatStepSizeItems(stepSizes)
            % Format step sizes for dropdown items
            items = arrayfun(@(x) foilview_utils.formatPosition(x), stepSizes, 'UniformOutput', false);
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
        
        %% Enhanced Timer Utilities
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
                    foilview_utils.safeStopTimer(timerObj);
                end
            catch
                % Ignore errors if timerfindall is not available
            end
        end
        
        %% Enhanced UI Validation Utilities
        function valid = validateUIComponent(component)
            % Centralized UI component validation
            valid = ~isempty(component) && isvalid(component);
        end
        
        function valid = validateMultipleComponents(varargin)
            % Validate multiple UI components at once
            valid = true;
            for i = 1:nargin
                if ~foilview_utils.validateUIComponent(varargin{i})
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
                   ~foilview_utils.validateUIComponent(controlStruct.(requiredFields{i}))
                    valid = false;
                    break;
                end
            end
        end
        
        function enableState = getEnableState(enabled)
            % Convert boolean to MATLAB enable state
            enableState = matlab.lang.OnOffSwitchState(enabled);
        end
        
        %% Enhanced Plot Utilities
        function configureAxes(axes, titleText, xlabelText, ylabelText)
            % Centralized axis configuration with optional labels
            if ~foilview_utils.validateUIComponent(axes)
                return;
            end
            
            set(axes, 'Box', 'on', 'TickDir', 'out', ...
                'LineWidth', 1.5);  % Use standard line width
            
            if nargin >= 3 && ~isempty(xlabelText)
                xlabel(axes, xlabelText, 'FontSize', foilview_styling.FONT_SIZE_MEDIUM);
            else
                xlabel(axes, 'Z Position (μm)', 'FontSize', foilview_styling.FONT_SIZE_MEDIUM);
            end
            
            if nargin >= 4 && ~isempty(ylabelText)
                ylabel(axes, ylabelText, 'FontSize', foilview_styling.FONT_SIZE_MEDIUM);
            else
                ylabel(axes, 'Normalized Metric Value', 'FontSize', foilview_styling.FONT_SIZE_MEDIUM);
            end
            
            if nargin >= 2 && ~isempty(titleText)
                foilview_utils.setPlotTitle(axes, titleText);
            end
        end
        
        function setPlotTitle(axes, titleText, showRange, minPos, maxPos)
            % Centralized plot title setting
            if ~foilview_utils.validateUIComponent(axes)
                return;
            end
            
            if nargin > 3 && showRange && ~isempty(minPos) && ~isempty(maxPos)
                fullTitle = sprintf('%s (%s)', titleText, foilview_utils.formatPositionRange(minPos, maxPos));
            else
                fullTitle = titleText;
            end
            
            title(axes, fullTitle, 'FontSize', foilview_styling.FONT_SIZE_MEDIUM, ...
                'FontWeight', foilview_styling.FONT_WEIGHT_BOLD);
        end
        
        function legendObj = createLegend(axes, location)
            % Centralized legend creation
            if nargin < 2, location = 'northeast'; end
            legendObj = legend(axes, 'Location', location, 'Interpreter', 'none', ...
                           'FontSize', foilview_styling.FONT_SIZE_SMALL, 'Box', 'on');
        end
        
        %% Enhanced Validation Utilities
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
            valid = foilview_utils.validateNumericRange(value, minVal, maxVal, name);
            
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
        
        %% Enhanced String Utilities
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
                foilview_utils.truncateString(label, maxLabelLength), ...
                xPos, yPos, zPos, ...
                metricValue, ...
                metricType);
        end
        
        %% Enhanced Performance Utilities
        function shouldUpdate = shouldThrottleUpdate(lastUpdateTime, interval)
            % Check if enough time has passed for throttled updates
            if nargin < 2, interval = foilview_utils.DEFAULT_UPDATE_THROTTLE; end
            currentTime = now * 24 * 3600;  % Convert to seconds
            shouldUpdate = (currentTime - lastUpdateTime) >= interval;
        end
        
        function limitedData = limitDataForPerformance(data, maxPoints)
            % Limit data points for performance
            if nargin < 2, maxPoints = foilview_utils.DEFAULT_MAX_DATA_POINTS; end
            
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
            if nargin < 3, maxPoints = foilview_utils.DEFAULT_MAX_DATA_POINTS; end
            
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
        
        %% UI Update Utilities
        function success = batchUIUpdate(updateFunctions, suppressErrors)
            % Perform multiple UI updates efficiently
            if nargin < 2, suppressErrors = true; end
            success = true;
            
            try
                % Temporarily disable graphics updates
                drawnow('limitrate');
                
                % Execute all update functions
                for i = 1:length(updateFunctions)
                    if ~foilview_utils.safeExecute(updateFunctions{i}, ...
                            sprintf('batchUpdate function %d', i), suppressErrors)
                        success = false;
                    end
                end
                
                % Force graphics update
                drawnow;
                
            catch e
                foilview_utils.logError('batchUIUpdate', e);
                success = false;
            end
        end
        
        %% Configuration Utilities
        function config = getDefaultUIConfig()
            % Get default UI configuration to eliminate duplication
            config = struct(...
                'FontSize', foilview_styling.FONT_SIZE_NORMAL, ...
                'FontWeight', foilview_styling.FONT_WEIGHT_NORMAL, ...
                'LineWidth', 1.5, ...
                'MarkerSize', foilview_styling.MARKER_SIZE, ...
                'UpdateThrottle', foilview_utils.DEFAULT_UPDATE_THROTTLE, ...
                'PlotThrottle', foilview_utils.DEFAULT_PLOT_THROTTLE, ...
                'MaxDataPoints', foilview_utils.DEFAULT_MAX_DATA_POINTS);
        end
    end
end 