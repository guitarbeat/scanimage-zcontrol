classdef ZScanner < handle
    % ZScanner - Handles automated Z-scanning.
    %
    % Refactored to eliminate code duplication and improve parameter management.
    % Uses controller.params for configuration and standardizes error handling.

    properties (Access = private)
        controller      % Handle to the main controller
        
        % Z-scan properties
        isScanning = false  % Scanning state flag
        scanTimer       % Timer for scanning
        scanRange       % Range for scanning
        scanDirection   % Direction of scanning
        scanStartZ      % Starting Z position
        scanEndZ        % Ending Z position
        scanCurrentZ    % Current Z position
        
        % Adaptive scan properties  
        consecutiveDecreases = 0  % Consecutive brightness decreases
        maxConsecutiveDecreases = 3  % Maximum consecutive decreases
        lastBrightness = 0   % Last measured brightness
    end

    methods
        function obj = ZScanner(controller)
            obj.controller = controller;
        end

        function start(obj, stepSize, pauseTime)
            % Start Z-scanning with specified parameters
            try
                % Update parameters
                if nargin > 1 && ~isempty(stepSize)
                    obj.controller.params.stepSize = stepSize;
                end
                if nargin > 2 && ~isempty(pauseTime)
                    obj.controller.params.scanPauseTime = pauseTime;
                end
                
                % Start scanning if not already scanning
                if ~obj.isScanning
                    obj.initializeScan();
                end
            catch ME
                obj.handleError(ME, 'start Z-scan');
            end
        end

        function stop(obj)
            % Stop Z-scanning
            if obj.isScanning
                stop(obj.scanTimer);
                delete(obj.scanTimer);
                obj.isScanning = false;
                obj.controller.updateStatus('Scan stopped. Ready to move to max brightness.');
            end
        end

        function scanStep(obj)
            % Execute one step of the Z scan between Z limits
            if obj.isScanning
                try
                    % Move to next position
                    obj.scanCurrentZ = obj.scanCurrentZ + obj.controller.params.stepSize * obj.scanDirection;
                    
                    % Check if we've reached the end
                    if (obj.scanDirection > 0 && obj.scanCurrentZ >= obj.scanEndZ) || ...
                       (obj.scanDirection < 0 && obj.scanCurrentZ <= obj.scanEndZ)
                        obj.stop();
                        obj.controller.updateStatus('Scan completed. Ready to move to max brightness.');
                        return;
                    end
                    
                    % Move to the new position
                    obj.controller.absoluteMove(obj.scanCurrentZ);
                    
                    % Mark brightness data on plot
                    obj.controller.updatePlot();
                    
                    % Update status
                    obj.controller.updateStatus(sprintf('Scanning: Z=%.2f, Step=%.2f', ...
                        obj.scanCurrentZ, obj.controller.params.stepSize));
                catch ME
                    obj.handleError(ME, 'scan step');
                    obj.stop();
                end
            end
        end

        function moveZ(obj, direction, stepSize)
            % Move Z stage (unified method for up/down movement)
            % direction: 1 for up (decrease Z), -1 for down (increase Z)
            try
                % If stepSize is not provided, use the current parameter value
                if nargin < 3
                    stepSize = obj.controller.params.stepSize;
                end
                
                % Update step size in ScanImage
                obj.controller.setStepSize(stepSize);
                
                % Call the appropriate button in ScanImage
                if direction > 0
                    obj.controller.pressZdec(); % Up (decrease Z)
                    dirText = 'up';
                else
                    obj.controller.pressZinc(); % Down (increase Z)
                    dirText = 'down';
                end
                
                % Update current Z position display
                currentZ = obj.controller.getZ();
                obj.controller.updateStatus(sprintf('Moved Z %s by %d to %.2f', dirText, stepSize, currentZ));
                obj.controller.updateCurrentZDisplay();
            catch ME
                obj.handleError(ME, sprintf('move Z %s', dirText));
            end
        end
        
        function moveZUp(obj, stepSize)
            % Move Z stage up (decrease Z in ScanImage) - wrapper for backward compatibility
            obj.moveZ(1, stepSize);
        end
        
        function moveZDown(obj, stepSize)
            % Move Z stage down (increase Z in ScanImage) - wrapper for backward compatibility
            obj.moveZ(-1, stepSize);
        end

        function val = getZLimit(obj, which)
            % Get Z min or max limit from motor controls
            if strcmpi(which, 'min')
                val = str2double(get(obj.controller.findByTag('pbMinLim'), 'UserData'));
                if isnan(val)
                    val = -Inf;
                end
            else
                val = str2double(get(obj.controller.findByTag('pbMaxLim'), 'UserData'));
                if isnan(val)
                    val = Inf;
                end
            end
        end
        
        function setZLimit(obj, isMin, zValue)
            % Set Z limit (unified method for min/max limits)
            try
                % Get limit value from GUI if not provided
                if nargin < 3 || isempty(zValue)
                    % Try to get value from controller's GUI
                    if isfield(obj.controller, 'gui') && ~isempty(obj.controller.gui) && isvalid(obj.controller.gui)
                        if isMin
                            fieldName = 'hMinZEdit';
                            limitType = 'Min';
                        else
                            fieldName = 'hMaxZEdit';
                            limitType = 'Max';
                        end
                        
                        if isfield(obj.controller.gui, fieldName)
                            zValue = obj.controller.gui.(fieldName).Value;
                        else
                            obj.controller.updateStatus(sprintf('Cannot set %s Z limit: no value provided', limitType));
                            return;
                        end
                    else
                        obj.controller.updateStatus(sprintf('Cannot set %s Z limit: no GUI available', limitType));
                        return;
                    end
                end
                
                % Move to target position
                obj.controller.absoluteMove(zValue);
                pause(0.2);
                
                % Press the appropriate Set Limit button
                if isMin
                    obj.controller.pressSetLimMin();
                    limitType = 'Min';
                else
                    obj.controller.pressSetLimMax();
                    limitType = 'Max';
                end
                
                obj.controller.updateStatus(sprintf('Set %s Z limit to %.2f', limitType, zValue));
            catch ME
                if isMin
                    limitType = 'Min';
                else
                    limitType = 'Max';
                end
                obj.handleError(ME, sprintf('set %s Z limit', limitType));
            end
        end
        
        function setMinZLimit(obj, minZ)
            % Set minimum Z limit - wrapper for backward compatibility
            obj.setZLimit(true, minZ);
        end
        
        function setMaxZLimit(obj, maxZ)
            % Set maximum Z limit - wrapper for backward compatibility
            obj.setZLimit(false, maxZ);
        end

        function toggleZScan(obj, state, stepSize, pauseTime, metricType)
            % Toggle Z-scan state
            try
                if state
                    % Get parameters from GUI if not provided
                    if nargin < 3 || isempty(stepSize)
                        stepSize = obj.getParameterFromGui('hStepSizeSlider', obj.controller.params.stepSize);
                    end
                    if nargin < 4 || isempty(pauseTime)
                        pauseTime = obj.getParameterFromGui('hPauseTimeEdit', obj.controller.params.scanPauseTime);
                    end
                    if nargin < 5
                        metricType = obj.getParameterFromGui('hMetricDropDown', 1);
                    end
                    
                    % Update step size value display in GUI
                    obj.updateGuiValue('hStepSizeValue', stepSize, 'Text', @num2str);
                    
                    % Start scanner
                    obj.start(stepSize, pauseTime);
                    obj.controller.updateStatus('Z-Scan started');
                else
                    obj.stop();
                    obj.controller.updateStatus('Z-Scan stopped');
                end
            catch ME
                if state
                    obj.handleError(ME, 'start Z-scan');
                else
                    obj.handleError(ME, 'stop Z-scan');
                end
            end
        end

        function updateStepSizeImmediate(obj, value)
            % Update step size in all relevant places
            try
                % Round the value
                value = round(value);
                
                % Update in parameters object
                obj.controller.params.stepSize = value;
                
                % Update step size in ScanImage
                obj.controller.setStepSize(value);
                
                % Update step size value in GUI
                obj.updateGuiValue('hStepSizeValue', value, 'Text', @num2str);
            catch ME
                obj.handleError(ME, 'update step size');
            end
        end
    end

    methods (Access = private)
        function handleError(obj, ME, operation)
            % Standardized error handling
            errorMsg = sprintf('Error during %s: %s', operation, ME.message);
            
            if obj.controller.verbosity > 0
                warning(errorMsg);
            end
            
            obj.controller.updateStatus(errorMsg);
            
            if obj.controller.verbosity > 1
                disp(getReport(ME));
            end
        end
        
        function value = getParameterFromGui(obj, fieldName, defaultValue)
            % Get parameter value from GUI with fallback
            value = defaultValue;
            
            try
                if isfield(obj.controller, 'gui') && ~isempty(obj.controller.gui) && ...
                   isvalid(obj.controller.gui) && isfield(obj.controller.gui, fieldName)
                    
                    % Handle different property types
                    if isprop(obj.controller.gui.(fieldName), 'Value')
                        guiValue = obj.controller.gui.(fieldName).Value;
                        
                        % For sliders, round the value
                        if strcmp(fieldName, 'hStepSizeSlider')
                            guiValue = max(1, round(guiValue));
                        end
                        
                        value = guiValue;
                    end
                end
            catch
                % Use default if any error occurs
            end
        end
        
        function updateGuiValue(obj, fieldName, value, property, transformFunc)
            % Update GUI component value with optional transformation
            try
                if isfield(obj.controller, 'gui') && ~isempty(obj.controller.gui) && ...
                   isvalid(obj.controller.gui) && isfield(obj.controller.gui, fieldName)
                   
                    if nargin >= 5 && ~isempty(transformFunc)
                        value = transformFunc(value);
                    end
                    
                    obj.controller.gui.(fieldName).(property) = value;
                end
            catch
                % Silently ignore GUI update failures
            end
        end
        
        function initializeScan(obj)
            % Initialize and start scanning between Z limits
            currentZ = obj.controller.getZ();
            
            % Get Z limits from motor controls or GUI
            minZ = max(obj.getParameterFromGui('hMinZEdit', -25), obj.getZLimit('min'));
            maxZ = min(obj.getParameterFromGui('hMaxZEdit', 25), obj.getZLimit('max'));
            
            % Ensure valid start position
            if currentZ < minZ
                obj.scanStartZ = minZ;
            elseif currentZ > maxZ
                obj.scanStartZ = maxZ;
            else
                obj.scanStartZ = currentZ;
            end
            
            obj.scanEndZ = maxZ;
            obj.scanCurrentZ = obj.scanStartZ;
            obj.scanDirection = sign(obj.scanEndZ - obj.scanStartZ);
            
            % Reset adaptive scan properties
            obj.lastBrightness = 0;
            obj.consecutiveDecreases = 0;
            
            % Move to start position
            obj.controller.absoluteMove(obj.scanStartZ);
            pause(obj.controller.params.scanPauseTime);
            
            % Start the scan timer
            obj.isScanning = true;
            obj.scanTimer = timer('Period', obj.controller.params.scanPauseTime, ...
                'ExecutionMode', 'fixedRate', ...
                'TimerFcn', @(~,~) obj.scanStep());
            start(obj.scanTimer);
            
            obj.controller.updateStatus(sprintf('Scanning from Z=%.2f to Z=%.2f', ...
                obj.scanStartZ, obj.scanEndZ));
        end
    end
end 