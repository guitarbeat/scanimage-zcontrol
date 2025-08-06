classdef UIOrchestrator < handle
    %UIORCHESTRATOR Handles UI coordination and updates for Foilview
    %   Extracted from FoilviewController for better separation of concerns
    %   Manages UI state updates, validation, and user interaction flows
    
    properties (Access = private)
        Logger
    end
    
    properties (Constant)
        % UI validation constants
        MIN_LABEL_LENGTH = 1
        MAX_LABEL_LENGTH = 50
        LABEL_INVALID_CHARS = '<>:"/\|?*'
        
        STEP_SIZES = [0.1, 0.5, 1, 5, 10, 50]
        METRIC_TYPES = {'Std Dev', 'Mean', 'Max'}
    end
    
    methods
        function obj = UIOrchestrator()
            obj.Logger = LoggingService('UIOrchestrator', 'SuppressInitMessage', true);
        end
        
        function success = startAutoSteppingWithValidation(obj, controller, app, autoControls, plotManager)
            %STARTAUTOSTEPPINGWITHVALIDATION Start auto-stepping with UI validation
            success = FoilviewUtils.safeExecuteWithReturn(@() doStartAutoStepping(), ...
                'startAutoSteppingWithValidation', false);

            function success = doStartAutoStepping()
                success = false;

                % Validate parameters first
                [valid, errorMsg] = obj.validateAutoStepParameters(autoControls);
                if ~valid
                    uialert(app.UIFigure, errorMsg, 'Invalid Parameters');
                    return;
                end

                % Get parameters from UI
                stepSize = autoControls.SharedStepSize.CurrentValue;
                numSteps = autoControls.StepsField.Field.Value;
                delay = autoControls.DelayField.Field.Value;

                % Get direction from toggle switch
                if strcmp(autoControls.DirectionSwitch.Value, 'Up')
                    direction = 1;
                else
                    direction = -1;
                end

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
        
        function success = markCurrentPositionWithValidation(obj, controller, uiFigure, label, updateCallback)
            %MARKCURRENTPOSITIONWITHVALIDATION Enhanced position marking with validation
            success = FoilviewUtils.safeExecuteWithReturn(@() doMarkPosition(), ...
                'markCurrentPositionWithValidation', false);

            function success = doMarkPosition()
                success = false;

                % Validate label using centralized validation
                [valid, errorMsg] = FoilviewUtils.validateStringInput(label, ...
                    obj.MIN_LABEL_LENGTH, obj.MAX_LABEL_LENGTH, ...
                    obj.LABEL_INVALID_CHARS, 'Label');
                if ~valid
                    uialert(uiFigure, errorMsg, 'Invalid Label');
                    return;
                end

                controller.markCurrentPosition(label);
                updateCallback();  % Update bookmarks list
                success = true;
            end
        end
        
        function success = goToMarkedPositionWithValidation(obj, controller, index)
            %GOTOMARKEDPOSITIONWITHVALIDATION Enhanced position navigation with safety checks
            success = FoilviewUtils.safeExecuteWithReturn(@() doGoToPosition(), ...
                'goToMarkedPositionWithValidation', false);

            function success = doGoToPosition()
                success = false;

                if ~controller.BookmarkManager.isValidIndex(index)
                    obj.Logger.warning('Invalid bookmark index: %d', index);
                    return;
                end

                if controller.IsAutoRunning
                    obj.Logger.warning('Cannot navigate to bookmark while auto-stepping is running');
                    return;
                end

                controller.goToMarkedPosition(index);
                success = true;
            end
        end
        
        function success = deleteMarkedPositionWithValidation(obj, controller, index, updateCallback)
            %DELETEMARKEDPOSITIONWITHVALIDATION Enhanced bookmark deletion with validation
            success = FoilviewUtils.safeExecuteWithReturn(@() doDeletePosition(), ...
                'deleteMarkedPositionWithValidation', false);

            function success = doDeletePosition()
                success = false;

                if ~controller.BookmarkManager.isValidIndex(index)
                    obj.Logger.warning('Invalid bookmark index: %d', index);
                    return;
                end

                controller.deleteMarkedPosition(index);
                updateCallback();  % Update bookmarks list
                success = true;
            end
        end
        
        function success = moveStageManual(obj, controller, stepSize, direction)
            %MOVESTAGEMANUAL Enhanced manual stage movement with validation
            success = FoilviewUtils.safeExecuteWithReturn(@() doMoveStage(), ...
                'moveStageManual', false);

            function success = doMoveStage()
                success = false;

                if ~isnumeric(direction) || ~ismember(direction, [-1, 1])
                    obj.Logger.warning('Invalid direction: must be 1 (up) or -1 (down)');
                    return;
                end

                if ~isnumeric(stepSize) || stepSize <= 0
                    obj.Logger.warning('Invalid step size: must be a positive number');
                    return;
                end

                obj.Logger.debug('Attempting to move stage %.1f μm in direction %d', stepSize, direction);
                controller.moveStage(direction * stepSize);
                success = true;
            end
        end
        
        function success = setMetricTypeWithValidation(obj, controller, metricType)
            %SETMETRICTYPEWITHVALIDATION Enhanced metric type setting with validation
            success = FoilviewUtils.safeExecuteWithReturn(@() doSetMetricType(), ...
                'setMetricTypeWithValidation', false);

            function success = doSetMetricType()
                success = false;

                if ~ischar(metricType) && ~isstring(metricType)
                    obj.Logger.warning('Metric type must be a string');
                    return;
                end

                if ~ismember(metricType, obj.METRIC_TYPES)
                    obj.Logger.warning('Invalid metric type: %s', metricType);
                    return;
                end

                controller.setMetricType(metricType);
                success = true;
            end
        end
        
        function syncStepSizes(obj, manualControls, autoControls, sourceValue, isFromManual)
            %SYNCSTEPSIZES Enhanced step size synchronization with validation
            FoilviewUtils.safeExecute(@() doSync(), 'syncStepSizes');

            function doSync()
                if isFromManual
                    % Manual dropdown changed, update shared step size
                    stepValue = FoilviewUtils.extractStepSizeFromString(sourceValue);
                    if ~isnan(stepValue) && stepValue > 0
                        % Update shared step size control
                        [~, idx] = min(abs(obj.STEP_SIZES - stepValue));
                        autoControls.SharedStepSize.CurrentValue = stepValue;
                        autoControls.SharedStepSize.CurrentStepIndex = idx;
                        autoControls.SharedStepSize.StepSizeDisplay.Text = sprintf('%.1f', stepValue);
                    end
                else
                    % Shared step size changed, update manual dropdown
                    newStepSize = sourceValue;
                    if isnumeric(newStepSize) && newStepSize > 0
                        [~, idx] = min(abs(obj.STEP_SIZES - newStepSize));
                        targetValue = FoilviewUtils.formatPosition(obj.STEP_SIZES(idx));
                        if ismember(targetValue, manualControls.SharedStepSize.StepSizeDropdown.Items)
                            manualControls.SharedStepSize.StepSizeDropdown.Value = targetValue;
                        end
                    end
                end
            end
        end
        
        function setAutoDirectionWithValidation(obj, autoControls, direction)
            %SETAUTODIRECTIONWITHVALIDATION Enhanced direction setting with validation
            FoilviewUtils.safeExecute(@() doSetDirection(), 'setAutoDirectionWithValidation');

            function doSetDirection()
                if ~isnumeric(direction) || ~ismember(direction, [-1, 1])
                    obj.Logger.warning('Invalid direction: must be 1 (up) or -1 (down)');
                    return;
                end

                % Update toggle switch value
                if isfield(autoControls, 'DirectionSwitch') && ~isempty(autoControls.DirectionSwitch)
                    if direction == 1  % Up
                        autoControls.DirectionSwitch.Value = 'Up';
                    else  % Down
                        autoControls.DirectionSwitch.Value = 'Down';
                    end
                end

                % Update direction button styling
                if direction == 1  % Up
                    autoControls.DirectionButton.BackgroundColor = [0.2 0.7 0.3];  % success color
                    autoControls.DirectionButton.FontColor = [1 1 1];  % white text
                    autoControls.DirectionButton.Text = '▲ UP';
                    autoControls.DirectionButton.FontSize = 10;
                    autoControls.DirectionButton.FontWeight = 'bold';
                else  % Down
                    autoControls.DirectionButton.BackgroundColor = [0.9 0.6 0.2];  % warning color
                    autoControls.DirectionButton.FontColor = [1 1 1];  % white text
                    autoControls.DirectionButton.Text = '▼ DOWN';
                    autoControls.DirectionButton.FontSize = 10;
                    autoControls.DirectionButton.FontWeight = 'bold';
                end
            end
        end
        
        function [newIndex, newStepSize] = changeStepSize(obj, currentIndex, change)
            %CHANGESTEPSIZE Change step size up or down, returns new index and value
            newIndex = currentIndex + change;

            % Clamp index within bounds
            newIndex = max(1, min(newIndex, length(obj.STEP_SIZES)));

            newStepSize = obj.STEP_SIZES(newIndex);
        end
    end
    
    methods (Access = private)
        function [valid, errorMsg] = validateAutoStepParameters(obj, autoControls)
            %VALIDATEAUTOSTEPPARAMETERS Validate auto-stepping parameters from UI
            valid = true;
            errorMsg = '';
            
            try
                % Validate step size
                stepSize = autoControls.SharedStepSize.CurrentValue;
                if ~isnumeric(stepSize) || stepSize <= 0
                    valid = false;
                    errorMsg = 'Step size must be a positive number';
                    return;
                end
                
                % Validate number of steps
                numSteps = autoControls.StepsField.Field.Value;
                if ~isnumeric(numSteps) || numSteps < 1 || numSteps > 1000
                    valid = false;
                    errorMsg = 'Number of steps must be between 1 and 1000';
                    return;
                end
                
                % Validate delay
                delay = autoControls.DelayField.Field.Value;
                if ~isnumeric(delay) || delay < 0.1 || delay > 10.0
                    valid = false;
                    errorMsg = 'Delay must be between 0.1 and 10.0 seconds';
                    return;
                end
                
            catch ME
                valid = false;
                errorMsg = sprintf('Parameter validation error: %s', ME.message);
            end
        end
    end
end