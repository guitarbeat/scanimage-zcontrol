classdef FoilviewController < handle

    properties (Constant, Access = public)
        STEP_SIZES = [0.1, 0.5, 1, 5, 10, 50]
        DEFAULT_STEP_SIZE = 1.0
        MIN_STEP_SIZE = 0.01
        MAX_STEP_SIZE = 1000

        DEFAULT_AUTO_STEP = 10
        DEFAULT_AUTO_STEPS = 10
        DEFAULT_AUTO_DELAY = 0.5
        MIN_AUTO_STEPS = 1
        MAX_AUTO_STEPS = 1000
        MIN_AUTO_DELAY = 0.1
        MAX_AUTO_DELAY = 10.0

        POSITION_REFRESH_PERIOD = 0.5
        METRIC_REFRESH_PERIOD = 1.0
        MOVEMENT_WAIT_TIME = 0.2
        STATUS_RESET_DELAY = 5

        METRIC_TYPES = {'Std Dev', 'Mean', 'Max'}
        DEFAULT_METRIC = 'Std Dev'

        POSITION_TOLERANCE = 0.01

        % Label validation constants
        MIN_LABEL_LENGTH = 1
        MAX_LABEL_LENGTH = 50
        LABEL_INVALID_CHARS = '<>:"/\|?*'

        TEXT = struct(...
            'Ready', 'Ready', ...
            'Simulation', 'Simulation Mode', ...
            'Initializing', 'Initializing...', ...
            'Connected', 'Connected', ...
            'NotRunning', 'ScanImage not running', ...
            'WindowNotFound', 'Motor Controls window not found', ...
            'MissingElements', 'Missing UI elements in Motor Controls', ...
            'LostConnection', 'Lost connection', ...
            'MovementError', 'Movement error', ...
            'InvalidPosition', 'Invalid position', ...
            'AutoStepError', 'Auto-step error')
    end

    properties (Access = public)
        CurrentPosition (1,1) double = 0
        CurrentXPosition (1,1) double = 0
        CurrentYPosition (1,1) double = 0

        IsAutoRunning (1,1) logical = false
        CurrentStep (1,1) double = 0
        TotalSteps (1,1) double = 0
        AutoDirection (1,1) double = 1
        RecordMetrics (1,1) logical = false
        AutoStepMetrics = struct('Positions', [], 'Values', struct())

        CurrentMetric (1,1) double = 0
        AllMetrics struct = struct()
        CurrentMetricType char = 'Focus Score'

        SimulationMode (1,1) logical = true
        StatusMessage char = ''

        BookmarkManager
    end

    properties (Access = private)
        ScanImageManager
        StageControlService
        MetricCalculationService
        AutoTimer

        StatusUpdateCallback
        PositionUpdateCallback
        MetricUpdateCallback
        AutoStepCompleteCallback
    end

    events
        StatusChanged
        PositionChanged
        MetricChanged
        AutoStepComplete
    end

    methods (Access = public)
        function obj = FoilviewController()
            % Initialize the controller
            obj.ScanImageManager = ScanImageManager();
            obj.StageControlService = StageControlService(obj.ScanImageManager);
            obj.MetricCalculationService = MetricCalculationService(obj.ScanImageManager);
            obj.BookmarkManager = BookmarkManager();
            obj.CurrentMetricType = obj.DEFAULT_METRIC;

            % Set up event listeners
            addlistener(obj.StageControlService, 'PositionChanged', @obj.onStagePositionChanged);
            addlistener(obj.MetricCalculationService, 'MetricCalculated', @obj.onMetricCalculated);

            obj.connectToScanImage();
        end

        function setFoilviewApp(obj, foilviewApp)
            % Set reference to the main foilview app for metadata logging
            if ~isempty(obj.BookmarkManager)
                obj.BookmarkManager.setFoilviewApp(foilviewApp);
            end
        end

        function delete(obj)
            obj.cleanup();
        end
    end

    methods (Access = public)
        function connectToScanImage(obj)
            % Establishes connection to ScanImage and initializes motor controls.
            [success, message] = obj.ScanImageManager.connect();
            obj.SimulationMode = ~success;
            obj.StatusMessage = message;
            obj.notifyStatusChanged();

            if success
                % Successfully connected - initialize positions via service
                obj.StageControlService.initializePositions();
                obj.syncPositionsFromService();
                obj.notifyPositionChanged();
            end
        end

        function moveStage(obj, microns)
            % Move Z stage - now delegates to StageControlService
            success = obj.StageControlService.moveStage('Z', microns);
            if success
                obj.syncPositionsFromService();
            end
        end

        function moveStageX(obj, microns)
            % Move X stage - now delegates to StageControlService
            success = obj.StageControlService.moveStage('X', microns);
            if success
                obj.syncPositionsFromService();
            end
        end

        function moveStageY(obj, microns)
            % Move Y stage - now delegates to StageControlService
            success = obj.StageControlService.moveStage('Y', microns);
            if success
                obj.syncPositionsFromService();
            end
        end

        function setPosition(obj, position)
            % Set Z position - now delegates to StageControlService
            success = obj.StageControlService.setAbsolutePosition('Z', position);
            if success
                obj.syncPositionsFromService();
            end
        end

        function setXYZPosition(obj, xPos, yPos, zPos)
            % Set X, Y, and Z positions simultaneously - now delegates to StageControlService
            success = obj.StageControlService.setXYZPosition(xPos, yPos, zPos);
            if success
                obj.syncPositionsFromService();
            end
        end

        function success = resetPosition(obj)
            % Reset Z position - now delegates to StageControlService
            success = obj.StageControlService.resetPosition('Z');
            if success
                obj.syncPositionsFromService();
            end
        end

        function refreshPosition(obj)
            % Refresh positions - now delegates to StageControlService
            success = obj.StageControlService.refreshPositions();
            if success
                obj.syncPositionsFromService();
            end
        end

        function updateMetric(obj)
            % Update metrics - now delegates to MetricCalculationService
            FoilviewUtils.safeExecute(@() doUpdateMetric(), 'updateMetric');

            function doUpdateMetric()
                % Get current position for metric calculation
                currentPos = [obj.CurrentXPosition, obj.CurrentYPosition, obj.CurrentPosition];

                % Calculate all metrics using the service
                obj.AllMetrics = obj.MetricCalculationService.calculateAllMetrics(currentPos);

                % Get the current selected metric value
                obj.CurrentMetric = obj.MetricCalculationService.getCurrentMetric();

                obj.notifyMetricChanged();

                % If recording metrics during auto-stepping
                if obj.IsAutoRunning && obj.RecordMetrics
                    obj.recordCurrentMetric();
                end
            end
        end

        function setMetricType(obj, metricType)
            % Set metric type - now delegates to MetricCalculationService
            if obj.MetricCalculationService.setMetricType(metricType)
                obj.CurrentMetricType = metricType;
                obj.updateMetric();
            end
        end

        function startAutoStepping(obj, stepSize, numSteps, delay, direction, recordMetrics)
            % Start auto-stepping using ScanControlService for parameter validation
            obj.isValidTimerState();

            if obj.IsAutoRunning
                return;
            end

            % Create and validate parameters using service
            params = ScanControlService.createAutoStepParams(stepSize, numSteps, delay, direction, recordMetrics);
            if ~params.isValid
                error('Invalid auto-step parameters: %s', params.errorMessage);
            end

            % Clear any existing timer first
            if ~isempty(obj.AutoTimer) && isvalid(obj.AutoTimer)
                FoilviewUtils.safeStopTimer(obj.AutoTimer);
                obj.AutoTimer = [];
            end

            obj.IsAutoRunning = true;
            obj.CurrentStep = 0;
            obj.TotalSteps = params.numSteps;
            obj.AutoDirection = params.direction;
            obj.RecordMetrics = params.recordMetrics;

            % Initialize metrics collection using service
            if obj.RecordMetrics
                obj.AutoStepMetrics = ScanControlService.initializeMetricsCollection();
            end

            try
                obj.AutoTimer = FoilviewUtils.createTimer('fixedRate', params.delay, ...
                    @(~,~) obj.executeAutoStep(params.stepSize));

                start(obj.AutoTimer);
                obj.notifyStatusChanged();

                fprintf('Auto-stepping started: %d steps of %.1f μm\n', params.numSteps, params.stepSize);
            catch ME
                fprintf('ERROR: Failed to start auto-stepping: %s\n', ME.message);
                % Clean up on failure
                obj.IsAutoRunning = false;
                if ~isempty(obj.AutoTimer) && isvalid(obj.AutoTimer)
                    FoilviewUtils.safeStopTimer(obj.AutoTimer);
                    obj.AutoTimer = [];
                end
                rethrow(ME);
            end
        end

        function stopAutoStepping(obj)
            % Validate timer state first
            obj.isValidTimerState();

            FoilviewUtils.safeExecute(@() doStop(), 'stopAutoStepping');

            function doStop()
                if ~isempty(obj.AutoTimer) && isvalid(obj.AutoTimer)
                    FoilviewUtils.safeStopTimer(obj.AutoTimer);
                end

                obj.AutoTimer = [];
                obj.IsAutoRunning = false;

                obj.notifyStatusChanged();

                % Generate completion summary using ScanControlService
                if obj.RecordMetrics && ~isempty(obj.AutoStepMetrics.Positions)
                    params = struct('stepSize', 0, 'numSteps', obj.TotalSteps, 'direction', obj.AutoDirection);
                    summary = ScanControlService.summarizeAutoStepSession(obj.AutoStepMetrics, params);
                    fprintf('Auto-stepping completed: %d steps, %.1f μm total distance, %.1f sec duration\n', ...
                        summary.TotalSteps, summary.TotalDistance, summary.Duration);
                else
                    fprintf('Auto-stepping completed at position %.1f μm\n', obj.CurrentPosition);
                end

                % Notify completion
                obj.notifyAutoStepComplete();
            end
        end

        function markCurrentPosition(obj, label)
            if isempty(strtrim(label))
                error('Label cannot be empty');
            end

            metricStruct = struct('Type', obj.CurrentMetricType, 'Value', obj.CurrentMetric);
            obj.BookmarkManager.add(label, obj.CurrentXPosition, obj.CurrentYPosition, obj.CurrentPosition, metricStruct);

            fprintf('Position marked: "%s" at X:%.1f, Y:%.1f, Z:%.1f μm (Metric: %.2f)\n', ...
                label, obj.CurrentXPosition, obj.CurrentYPosition, obj.CurrentPosition, obj.CurrentMetric);
        end

        function goToMarkedPosition(obj, index)
            bookmark = obj.BookmarkManager.get(index);
            if ~isempty(bookmark) && ~obj.IsAutoRunning
                obj.setXYZPosition(bookmark.X, bookmark.Y, bookmark.Z);
                fprintf('Moved to bookmark "%s": X:%.1f, Y:%.1f, Z:%.1f μm\n', bookmark.Label, bookmark.X, bookmark.Y, bookmark.Z);
            end
        end

        function deleteMarkedPosition(obj, index)
            bookmark = obj.BookmarkManager.get(index);
            if ~isempty(bookmark)
                obj.BookmarkManager.remove(index);
                fprintf('Deleted bookmark: "%s"\n', bookmark.Label);
            end
        end

        function metrics = getAutoStepMetrics(obj)
            % Return the collected auto step metrics
            if obj.RecordMetrics && ~isempty(obj.AutoStepMetrics.Positions)
                % Return a copy of the metrics
                metrics = obj.AutoStepMetrics;
            else
                metrics = struct('Positions', [], 'Values', struct());
            end
        end

        % ===== UI INTERACTION METHODS (consolidated from foilview_logic) =====

        function success = startAutoSteppingWithValidation(obj, app, autoControls, plotManager)
            % Start the auto-stepping sequence with comprehensive validation
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
                if obj.IsAutoRunning
                    uialert(app.UIFigure, 'Auto-stepping is already running', 'Operation in Progress');
                    return;
                end

                % Clear previous plot data if recording metrics
                if recordMetrics
                    plotManager.clearMetricsPlot(app.MetricsPlotControls.Axes);
                end

                % Start auto stepping in controller
                obj.startAutoStepping(stepSize, numSteps, delay, direction, recordMetrics);
                success = true;
            end
        end

        function success = markCurrentPositionWithValidation(obj, uiFigure, label, updateCallback)
            % Enhanced position marking with validation and error handling
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

                obj.markCurrentPosition(label);
                updateCallback();  % Update bookmarks list
                success = true;
            end
        end

        function success = goToMarkedPositionWithValidation(obj, index)
            % Enhanced position navigation with safety checks
            success = FoilviewUtils.safeExecuteWithReturn(@() doGoToPosition(), ...
                'goToMarkedPositionWithValidation', false);

            function success = doGoToPosition()
                success = false;

                if ~obj.BookmarkManager.isValidIndex(index)
                    fprintf('Invalid bookmark index: %d\n', index);
                    return;
                end

                if obj.IsAutoRunning
                    fprintf('Cannot navigate to bookmark while auto-stepping is running\n');
                    return;
                end

                obj.goToMarkedPosition(index);
                success = true;
            end
        end

        function success = deleteMarkedPositionWithValidation(obj, index, updateCallback)
            % Enhanced bookmark deletion with validation
            success = FoilviewUtils.safeExecuteWithReturn(@() doDeletePosition(), ...
                'deleteMarkedPositionWithValidation', false);

            function success = doDeletePosition()
                success = false;

                if ~obj.BookmarkManager.isValidIndex(index)
                    fprintf('Invalid bookmark index: %d\n', index);
                    return;
                end

                obj.deleteMarkedPosition(index);
                updateCallback();  % Update bookmarks list
                success = true;
            end
        end

        function success = moveStageManual(obj, stepSize, direction)
            % Enhanced manual stage movement with validation
            success = FoilviewUtils.safeExecuteWithReturn(@() doMoveStage(), ...
                'moveStageManual', false);

            function success = doMoveStage()
                success = false;

                if ~isnumeric(direction) || ~ismember(direction, [-1, 1])
                    fprintf('Invalid direction: must be 1 (up) or -1 (down)\n');
                    return;
                end

                if ~isnumeric(stepSize) || stepSize <= 0
                    fprintf('Invalid step size: must be a positive number\n');
                    return;
                end

                fprintf('FoilviewController: Attempting to move stage %.1f μm in direction %d\n', stepSize, direction);
                obj.moveStage(direction * stepSize);
                success = true;
            end
        end

        function success = recoverFromMotorError(obj)
            % Attempt to recover from motor error state
            success = FoilviewUtils.safeExecuteWithReturn(@() doRecover(), 'recoverFromMotorError', false);

            function success = doRecover()
                success = false;

                if obj.SimulationMode
                    success = true;
                    return;
                end

                try
                    % Find motor controls window
                    motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                    if isempty(motorFig)
                        return;
                    end

                    % Check for error state on Z axis
                    if obj.ScanImageManager.checkMotorErrorState(motorFig, 'Z')
                        fprintf('FoilviewController: Motor error detected, attempting recovery...\n');
                        obj.ScanImageManager.clearMotorError(motorFig, 'Z');
                        pause(1.0); % Give more time for recovery

                        % Check if recovery was successful
                        if ~obj.ScanImageManager.checkMotorErrorState(motorFig, 'Z')
                            fprintf('FoilviewController: Motor error recovery successful\n');
                            success = true;
                        else
                            fprintf('FoilviewController: Motor error recovery failed\n');
                        end
                    else
                        fprintf('FoilviewController: No motor error detected\n');
                        success = true;
                    end

                catch ME
                    fprintf('FoilviewController: Error during motor recovery: %s\n', ME.message);
                end
            end
        end

        function success = refreshConnection(obj)
            % Enhanced connection refresh with return value
            success = FoilviewUtils.safeExecuteWithReturn(@() doRefresh(), ...
                'refreshConnection', false);

            function success = doRefresh()
                obj.connectToScanImage();
                success = true;
            end
        end

        function success = setMetricTypeWithValidation(obj, metricType)
            % Enhanced metric type setting with validation
            success = FoilviewUtils.safeExecuteWithReturn(@() doSetMetricType(), ...
                'setMetricTypeWithValidation', false);

            function success = doSetMetricType()
                success = false;

                if ~ischar(metricType) && ~isstring(metricType)
                    fprintf('Metric type must be a string\n');
                    return;
                end

                if ~ismember(metricType, obj.METRIC_TYPES)
                    fprintf('Invalid metric type: %s\n', metricType);
                    return;
                end

                obj.setMetricType(metricType);
                success = true;
            end
        end

        function syncStepSizes(obj, manualControls, autoControls, sourceValue, isFromManual)
            % Enhanced step size synchronization with validation - now uses shared step size
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
            % Enhanced direction setting with validation and visual feedback using utilities
            FoilviewUtils.safeExecute(@() doSetDirection(), 'setAutoDirectionWithValidation');

            function doSetDirection()
                if ~isnumeric(direction) || ~ismember(direction, [-1, 1])
                    fprintf('Invalid direction: must be 1 (up) or -1 (down)\n');
                    return;
                end

                obj.AutoDirection = direction;

                % Update toggle switch value
                if isfield(autoControls, 'DirectionSwitch') && ~isempty(autoControls.DirectionSwitch)
                    if obj.AutoDirection == 1  % Up
                        autoControls.DirectionSwitch.Value = 'Up';
                    else  % Down
                        autoControls.DirectionSwitch.Value = 'Down';
                    end
                end

                % Update direction button styling
                if obj.AutoDirection == 1  % Up
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
            % Change step size up or down, returns new index and value
            newIndex = currentIndex + change;

            % Clamp index within bounds
            newIndex = max(1, min(newIndex, length(obj.STEP_SIZES)));

            newStepSize = obj.STEP_SIZES(newIndex);
        end

        function cleanup(obj)
            % Clean up all resources - PUBLIC method for external access
            if ~isempty(obj.AutoTimer) && isvalid(obj.AutoTimer)
                FoilviewUtils.safeStopTimer(obj.AutoTimer);
                obj.AutoTimer = [];
            end

            if ~isempty(obj.ScanImageManager) && isvalid(obj.ScanImageManager)
                obj.ScanImageManager.cleanup();
            end
        end
    end

    methods (Access = private)
        function executeAutoStep(obj, stepSize)
            FoilviewUtils.safeExecute(@() doExecuteStep(), 'executeAutoStep');

            function doExecuteStep()
                % Check if controller is still valid and auto running
                if ~obj.IsAutoRunning
                    return;
                end

                obj.CurrentStep = obj.CurrentStep + 1;
                % Apply direction at execution time
                actualStep = stepSize * obj.AutoDirection;

                % Notify UI that status has changed (step count updated)
                obj.notifyStatusChanged();

                try
                    obj.moveStage(actualStep);
                    fprintf('Auto-step %d/%d: moved %.2f μm (direction %d)\n', obj.CurrentStep, obj.TotalSteps, actualStep, obj.AutoDirection);
                catch ME
                    fprintf('ERROR: Failed to execute step %d/%d: %s\n', obj.CurrentStep, obj.TotalSteps, ME.message);
                    % Stop auto-stepping on movement error
                    obj.stopAutoStepping();
                    return;
                end

                if obj.CurrentStep >= obj.TotalSteps
                    obj.stopAutoStepping();
                end
            end
        end



        function recordCurrentMetric(obj)
            % Record current metric for auto-stepping using ScanControlService
            if obj.RecordMetrics
                % Use service to record metric step
                obj.AutoStepMetrics = ScanControlService.recordMetricStep(...
                    obj.AutoStepMetrics, obj.CurrentPosition, obj.AllMetrics);
            end
        end

        % === HELPER METHODS FOR STAGE CONTROL SERVICE INTEGRATION ===

        function syncPositionsFromService(obj)
            % Sync controller position properties from StageControlService
            positions = obj.StageControlService.getCurrentPositions();
            obj.CurrentXPosition = positions.x;
            obj.CurrentYPosition = positions.y;
            obj.CurrentPosition = positions.z;
        end

        function onStagePositionChanged(obj, ~, ~)
            % Handle position changes from StageControlService
            obj.syncPositionsFromService();
            obj.notifyPositionChanged();
        end

        function onMetricCalculated(obj, ~, eventData)
            % Handle metric calculation events from MetricCalculationService
            if ~isempty(eventData) && isfield(eventData, 'metrics')
                obj.AllMetrics = eventData.metrics;
                obj.CurrentMetric = obj.MetricCalculationService.getCurrentMetric();
                obj.notifyMetricChanged();
            end
        end

        % === NOTIFICATION METHODS ===

        function notifyStatusChanged(obj)
            notify(obj, 'StatusChanged');
        end

        function notifyPositionChanged(obj)
            notify(obj, 'PositionChanged');
        end

        function notifyMetricChanged(obj)
            notify(obj, 'MetricChanged');
        end

        function notifyAutoStepComplete(obj)
            notify(obj, 'AutoStepComplete');
        end

        % === VALIDATION METHODS (updated to use services) ===

        function valid = validateMovement(obj, microns)
            % Validate movement parameters - now delegates to service
            [valid, ~] = obj.StageControlService.validateStageMovementParameters('Z', microns);
        end

        function valid = validatePosition(obj, position)
            % Validate absolute position - now delegates to service
            [valid, ~] = obj.StageControlService.validateAbsolutePosition(position);
        end

        function [valid, errorMsg] = validateAutoStepParameters(~, autoControls)
            % Validate auto-step parameters from UI controls
            try
                stepSize = autoControls.SharedStepSize.CurrentValue;
                numSteps = autoControls.StepsField.Field.Value;
                delay = autoControls.DelayField.Field.Value;

                % Use ScanControlService for validation
                [valid, errorMsg] = ScanControlService.validateAutoStepParameters(stepSize, numSteps, delay);

            catch ME
                valid = false;
                errorMsg = sprintf('Error validating parameters: %s', ME.message);
            end
        end

        % === TIMER STATE VALIDATION ===

        function isValidTimerState(obj)
            % Validate timer state for debugging
            if ~isempty(obj.AutoTimer) && ~isvalid(obj.AutoTimer)
                FoilviewUtils.warn('FoilviewController', 'Invalid timer detected, cleaning up');
                obj.AutoTimer = [];
            end
        end

        function timerState = getTimerState(obj)
            % Public method to get timer state for debugging
            timerState = struct();
            timerState.hasTimer = ~isempty(obj.AutoTimer);
            timerState.isValid = timerState.hasTimer && isvalid(obj.AutoTimer);
            timerState.isRunning = obj.IsAutoRunning;

            if timerState.isValid
                timerState.running = strcmp(obj.AutoTimer.Running, 'on');
                timerState.period = obj.AutoTimer.Period;
            end
        end

    end
end
