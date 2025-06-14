classdef CoreUtils
    % CoreUtils - Utility functions shared across core components
    %
    % This class provides common utility functions to reduce code duplication
    % across multiple core classes.
    
    methods(Static)
        function isValid = isGuiValid(obj)
            % Checks if a GUI component is valid and accessible
            % Returns true if the GUI exists, is not empty, and is a valid object
            try
                isValid = isfield(obj, 'gui') && ...
                         ~isempty(obj.gui) && ...
                         isvalid(obj.gui);
            catch
                isValid = false;
            end
        end
        
        function handleError(controller, ME, prefix)
            % Handle and display error information
            % 
            % Parameters:
            %   controller - Object that may have a GUI to update
            %   ME - The MException object
            %   prefix - Optional prefix for the error message
            
            if nargin < 3
                prefix = 'Error';
            end
            
            % Build error message
            errMsg = sprintf('%s: %s', prefix, ME.message);
            
            % Only display errors in console with verbosity > 1
            verbosity = 0;
            try
                if isfield(controller, 'verbosity')
                    verbosity = controller.verbosity;
                end
            catch
                % If we can't get verbosity, default to minimal output
            end
            
            if verbosity > 1
                disp(getReport(ME));
            end
            
            % Update GUI status if available
            if core.CoreUtils.isGuiValid(controller) && ismethod(controller.gui, 'updateStatus')
                try
                    controller.gui.updateStatus(errMsg, 'error');
                catch
                    % Silently ignore errors when updating GUI
                end
            end
        end
        
        function updateStatus(controller, message, varargin)
            % Update status text in the GUI
            % Only display console message with verbosity > 1
            verbosity = 0;
            try
                if isfield(controller, 'verbosity')
                    verbosity = controller.verbosity;
                end
            catch
                % If we can't get verbosity, default to minimal output
            end
            
            % Only update GUI if it's initialized
            if core.CoreUtils.isGuiValid(controller) && ismethod(controller.gui, 'updateStatus')
                try
                    % Forward any optional parameters to GUI's updateStatus method
                    controller.gui.updateStatus(message, varargin{:});
                catch
                    % Silently ignore errors when updating GUI
                end
            end
        end
        
        function cleanupTimer(timerObj)
            % Safely clean up a timer object
            % 
            % Parameters:
            %   timerObj - Timer object to clean up
            
            try
                if ~isempty(timerObj) && isvalid(timerObj)
                    if strcmp(timerObj.Running, 'on')
                        stop(timerObj);
                    end
                    delete(timerObj);
                end
            catch ME
                warning('Error cleaning up timer: %s', ME.message);
            end
        end
        
        function hasFeature = hasAppDesignerFeature(featureName)
            % Check if a specific App Designer feature is available
            % 
            % Parameters:
            %   featureName - Name of the feature to check (e.g., 'RangeSlider')
            %
            % Returns:
            %   hasFeature - True if the feature is available
            
            % Check MATLAB version first
            hasFeature = false;
            
            switch lower(featureName)
                case 'rangeslider'
                    % RangeSlider was introduced in R2020b (9.9)
                    hasFeature = ~verLessThan('matlab', '9.9');
                case 'statebutton'
                    % StateButton was introduced in R2019b (9.7)
                    hasFeature = ~verLessThan('matlab', '9.7');
                case 'buttongroup'
                    % ButtonGroup was introduced in R2019a (9.6)
                    hasFeature = ~verLessThan('matlab', '9.6');
                case 'treeview'
                    % TreeView was introduced in R2020a (9.8)
                    hasFeature = ~verLessThan('matlab', '9.8');
                otherwise
                    % Default to checking MATLAB version
                    hasFeature = ~verLessThan('matlab', '9.6'); % R2019a or newer
            end
            
            % Additional check - try to create the component
            if hasFeature
                try
                    % Create a temporary figure for testing
                    f = uifigure('Visible', 'off');
                    
                    % Try to create the component
                    switch lower(featureName)
                        case 'rangeslider'
                            uislider(f, 'Range', 'on');
                        case 'statebutton'
                            uibutton(f, 'state');
                        case 'buttongroup'
                            uibuttongroup(f);
                        case 'treeview'
                            uitree(f);
                    end
                    
                    % If we got here, the component exists
                    delete(f);
                catch
                    % Component creation failed
                    hasFeature = false;
                    
                    % Clean up
                    if exist('f', 'var') && isvalid(f)
                        delete(f);
                    end
                end
            end
        end
        
        function value = validateParameter(value, defaultValue, validationFcn)
            % Validate a parameter value with a validation function
            % 
            % Parameters:
            %   value - Value to validate
            %   defaultValue - Default value to use if validation fails
            %   validationFcn - Function handle for validation
            %
            % Returns:
            %   value - Validated value or default
            
            try
                % Check if the validation function passes
                if isempty(value) || ~validationFcn(value)
                    value = defaultValue;
                end
            catch
                % If any error occurs during validation, use default
                value = defaultValue;
            end
        end
        
        function validateNumericRange(value, minValue, maxValue, name)
            % Validate that a numeric value is within a range
            %
            % Parameters:
            %   value - Value to validate
            %   minValue - Minimum allowed value
            %   maxValue - Maximum allowed value
            %   name - Name of the parameter (for error messages)
            %
            % Throws an error if validation fails
            
            if nargin < 4
                name = 'Parameter';
            end
            
            if ~isnumeric(value) || ~isscalar(value)
                error('%s must be a numeric scalar', name);
            end
            
            if value < minValue || value > maxValue
                error('%s must be between %g and %g', name, minValue, maxValue);
            end
        end
        
        function result = tryMethod(obj, methodName, defaultResult, varargin)
            % Try to call a method on an object, returning a default if it fails
            %
            % Parameters:
            %   obj - Object to call method on
            %   methodName - Name of method to call
            %   defaultResult - Default result if method call fails
            %   varargin - Arguments to pass to the method
            %
            % Returns:
            %   result - Result of method call or default
            
            result = defaultResult;
            
            try
                if isempty(obj)
                    return;
                end
                
                if ~isvalid(obj)
                    return;
                end
                
                if ~ismethod(obj, methodName)
                    return;
                end
                
                % Call the method
                if nargin > 3
                    result = obj.(methodName)(varargin{:});
                else
                    result = obj.(methodName)();
                end
            catch
                % Return default result on any error
                result = defaultResult;
            end
        end
        
        function logging(verbosity, minLevel, formatStr, varargin)
            % Log a message with the given verbosity level
            %
            % Parameters:
            %   verbosity - Current verbosity level
            %   minLevel - Minimum level required to display this message
            %   formatStr - Format string for the message
            %   varargin - Arguments for the format string
            
            if verbosity >= minLevel
                % Format the timestamp
                timestamp = datestr(now, 'HH:MM:SS.FFF');
                
                % Create the message with timestamp prefix
                fullMsg = sprintf('[%s] %s', timestamp, sprintf(formatStr, varargin{:}));
                
                % Display the message
                disp(fullMsg);
            end
        end
        
        function obj = safeDelete(obj)
            % Safely delete an object and set it to empty
            %
            % Parameters:
            %   obj - Object to delete
            %
            % Returns:
            %   obj - Empty array after deletion
            
            try
                if ~isempty(obj) && isvalid(obj)
                    delete(obj);
                end
            catch
                % Silently ignore errors
            end
            
            obj = [];
        end
    end
end 