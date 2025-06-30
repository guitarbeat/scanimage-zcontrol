classdef foilview_logic < handle
    % foilview_logic - Enhanced business logic for foilview
    %
    % This class manages core application logic including auto-stepping,
    % bookmark management, parameter validation, and user input handling.
    % Enhanced with comprehensive validation and error handling.
    
    properties (Constant, Access = private)
        % Validation constants - use centralized utilities where possible
        MIN_LABEL_LENGTH = 1
        MAX_LABEL_LENGTH = 50
        LABEL_INVALID_CHARS = '<>:"/\|?*'  % Characters not allowed in labels
    end
    
    methods (Static)
        function success = startAutoStepping(app, controller, autoControls, plotManager)
            % Start the auto-stepping sequence with comprehensive validation
            success = foilview_utils.safeExecuteWithReturn(@() doStartAutoStepping(), ...
                'startAutoStepping', false);
            
            function success = doStartAutoStepping()
                success = false;
                
                % Validate parameters first
                [valid, errorMsg] = foilview_logic.validateAutoStepParameters(autoControls);
                if ~valid
                    uialert(app.UIFigure, errorMsg, 'Invalid Parameters');
                    return;
                end
                
                % Get parameters from UI
                stepSize = autoControls.StepField.Value;
                numSteps = autoControls.StepsField.Value;
                delay = autoControls.DelayField.Value;
                direction = controller.AutoDirection;
                recordMetrics = true;  % Always record metrics for plotting
                
                % Additional safety checks
                if controller.IsAutoRunning
                    uialert(app.UIFigure, 'Auto-stepping is already running', 'Operation in Progress');
                    return;
                end
                
                % Clear previous plot data if recording metrics
                if recordMetrics
                    plotManager.clearMetricsPlot(app.MetricsPlotControls.Axes);
                end
                
                % Start auto stepping in controller
                controller.startAutoStepping(stepSize, numSteps, delay, direction, recordMetrics);
                success = true;
            end
        end
        
        function stopAutoStepping(controller)
            % Stop the auto-stepping sequence safely
            foilview_utils.safeExecute(@() controller.stopAutoStepping(), 'stopAutoStepping');
        end
        
        function [valid, errorMsg] = validateAutoStepParameters(autoControls)
            % Enhanced parameter validation with detailed error messages
            valid = true;
            errorMsg = '';
            
            stepSize = autoControls.StepField.Value;
            numSteps = autoControls.StepsField.Value;
            delay = autoControls.DelayField.Value;
            
            % Validate step size using utility
            if ~foilview_utils.validateNumericRange(stepSize, foilview_controller.MIN_STEP_SIZE, foilview_controller.MAX_STEP_SIZE, 'Step size')
                valid = false;
                errorMsg = sprintf('Step size must be between %.3f and %.1f μm', ...
                    foilview_controller.MIN_STEP_SIZE, foilview_controller.MAX_STEP_SIZE);
                return;
            end
            
            % Validate number of steps using utility
            if ~foilview_utils.validateInteger(numSteps, foilview_controller.MIN_AUTO_STEPS, foilview_controller.MAX_AUTO_STEPS, 'Number of steps')
                valid = false;
                errorMsg = sprintf('Number of steps must be between %d and %d', ...
                    foilview_controller.MIN_AUTO_STEPS, foilview_controller.MAX_AUTO_STEPS);
                return;
            end
            
            % Validate delay using utility
            if ~foilview_utils.validateNumericRange(delay, foilview_controller.MIN_AUTO_DELAY, foilview_controller.MAX_AUTO_DELAY, 'Delay')
                valid = false;
                errorMsg = sprintf('Delay must be between %.1f and %.1f seconds', ...
                    foilview_controller.MIN_AUTO_DELAY, foilview_controller.MAX_AUTO_DELAY);
                return;
            end
        end
        
        function success = markCurrentPosition(uiFigure, controller, label, updateCallback)
            % Enhanced position marking with validation and error handling
            success = foilview_utils.safeExecuteWithReturn(@() doMarkPosition(), ...
                'markCurrentPosition', false);
            
            function success = doMarkPosition()
                success = false;
                
                % Validate label using centralized validation
                [valid, errorMsg] = foilview_utils.validateStringInput(label, ...
                    foilview_logic.MIN_LABEL_LENGTH, foilview_logic.MAX_LABEL_LENGTH, ...
                    foilview_logic.LABEL_INVALID_CHARS, 'Label');
                if ~valid
                    uialert(uiFigure, errorMsg, 'Invalid Label');
                    return;
                end
                
                controller.markCurrentPosition(label);
                updateCallback();  % Update bookmarks list
                success = true;
            end
        end
        
        function [valid, errorMsg] = validateLabel(label)
            % Use centralized string validation
            [valid, errorMsg] = foilview_utils.validateStringInput(label, ...
                foilview_logic.MIN_LABEL_LENGTH, foilview_logic.MAX_LABEL_LENGTH, ...
                foilview_logic.LABEL_INVALID_CHARS, 'Label');
        end
        
        function success = goToMarkedPosition(controller, index)
            % Enhanced position navigation with safety checks
            success = foilview_utils.safeExecuteWithReturn(@() doGoToPosition(), ...
                'goToMarkedPosition', false);
            
            function success = doGoToPosition()
                success = false;
                
                if ~foilview_logic.isValidBookmarkIndex(controller, index)
                    fprintf('Invalid bookmark index: %d\n', index);
                    return;
                end
                
                if controller.IsAutoRunning
                    fprintf('Cannot navigate to bookmark while auto-stepping is running\n');
                    return;
                end
                
                controller.goToMarkedPosition(index);
                success = true;
            end
        end
        
        function success = deleteMarkedPosition(controller, index, updateCallback)
            % Enhanced bookmark deletion with validation
            success = foilview_utils.safeExecuteWithReturn(@() doDeletePosition(), ...
                'deleteMarkedPosition', false);
            
            function success = doDeletePosition()
                success = false;
                
                if ~foilview_logic.isValidBookmarkIndex(controller, index)
                    fprintf('Invalid bookmark index: %d\n', index);
                    return;
                end
                
                controller.deleteMarkedPosition(index);
                updateCallback();  % Update bookmarks list
                success = true;
            end
        end
        
        function valid = isValidBookmarkIndex(controller, index)
            % Enhanced bookmark index validation using utilities
            if ~isnumeric(index) || ~isscalar(index) || index < 1 || mod(index, 1) ~= 0
                valid = false;
                return;
            end
            
            valid = index <= length(controller.MarkedPositions.Labels);
        end
        
        function success = moveStageManual(controller, manualControls, direction)
            % Enhanced manual stage movement with validation
            success = foilview_utils.safeExecuteWithReturn(@() doMoveStage(), ...
                'moveStageManual', false);
            
            function success = doMoveStage()
                success = false;
                
                if ~isnumeric(direction) || ~ismember(direction, [-1, 1])
                    fprintf('Invalid direction: must be 1 (up) or -1 (down)\n');
                    return;
                end
                
                % Get step size from editable field
                stepSize = manualControls.StepSizeField.Value;
                
                % Validate step size
                if ~isnumeric(stepSize) || stepSize <= 0
                    fprintf('Invalid step size: must be a positive number\n');
                    return;
                end
                
                controller.moveStage(direction * stepSize);
                success = true;
            end
        end
        
        function success = resetPosition(controller)
            % Enhanced position reset with return value
            success = foilview_utils.safeExecuteWithReturn(@() controller.resetPosition(), ...
                'resetPosition', false);
        end
        
        function success = refreshConnection(controller)
            % Enhanced connection refresh with return value
            success = foilview_utils.safeExecuteWithReturn(@() doRefresh(), ...
                'refreshConnection', false);
            
            function success = doRefresh()
                controller.connectToScanImage();
                success = true;
            end
        end
        
        function success = setMetricType(controller, metricType)
            % Enhanced metric type setting with validation
            success = foilview_utils.safeExecuteWithReturn(@() doSetMetricType(), ...
                'setMetricType', false);
            
            function success = doSetMetricType()
                success = false;
                
                if ~ischar(metricType) && ~isstring(metricType)
                    fprintf('Metric type must be a string\n');
                    return;
                end
                
                if ~ismember(metricType, controller.METRIC_TYPES)
                    fprintf('Invalid metric type: %s\n', metricType);
                    return;
                end
                
                controller.setMetricType(metricType);
                success = true;
            end
        end
        
        function success = updateMetric(controller)
            % Enhanced metric update with error handling
            success = foilview_utils.safeExecuteWithReturn(@() controller.updateMetric(), ...
                'updateMetric', false);
        end
        
        function syncStepSizes(manualControls, autoControls, sourceValue, isFromManual)
            % Enhanced step size synchronization with validation
            foilview_utils.safeExecute(@() doSync(), 'syncStepSizes');
            
            function doSync()
                if isFromManual
                    % Manual step size changed (via editable field), update auto field
                    if isnumeric(sourceValue)
                        % Direct numeric value from editable field
                        stepValue = sourceValue;
                    else
                        % String value from dropdown (legacy support)
                        stepValue = foilview_utils.extractStepSizeFromString(sourceValue);
                    end
                    
                    if ~isnan(stepValue) && stepValue > 0
                        autoControls.StepField.Value = stepValue;
                    end
                else
                    % Auto field changed, update manual controls to match exactly
                    newStepSize = sourceValue;
                    if isnumeric(newStepSize) && newStepSize > 0
                        % Update manual field to match exactly (no rounding to predefined values)
                        manualControls.StepSizeField.Value = newStepSize;
                    end
                end
            end
        end
        
        function setAutoDirection(controller, autoControls, direction)
            % Enhanced direction setting with validation and visual feedback using utilities
            foilview_utils.safeExecute(@() doSetDirection(), 'setAutoDirection');
            
            function doSetDirection()
                if ~isnumeric(direction) || ~ismember(direction, [-1, 1])
                    fprintf('Invalid direction: must be 1 (up) or -1 (down)\n');
                    return;
                end
                
                controller.AutoDirection = direction;
                
                % Update direction button styling using modern styling system
                if controller.AutoDirection == 1  % Up
                    foilview_styling.styleButton(autoControls.DirectionButton, 'success', 'base');
                else  % Down
                    foilview_styling.styleButton(autoControls.DirectionButton, 'warning', 'base');
                end
            end
        end
    end
end 