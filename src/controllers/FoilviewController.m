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
        
        MIN_POSITION = -10000
        MAX_POSITION = 10000
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
            obj.BookmarkManager = BookmarkManager();
            obj.CurrentMetricType = obj.DEFAULT_METRIC;
            obj.connectToScanImage();
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
                % Successfully connected
                obj.initializePositionsFromManager();
                obj.notifyPositionChanged();
            end
        end
        
        function moveStage(obj, microns)
            % Validate input using centralized utilities
            if ~obj.validateMovement(microns)
                return;
            end
            
            FoilviewUtils.safeExecute(@() doMoveStage(), 'moveStage');
            
            function doMoveStage()
                newPos = obj.ScanImageManager.moveStage('Z', microns);
                obj.CurrentPosition = newPos;
                fprintf('Z Stage moved %.1f μm to position %.1f μm\n', ...
                    microns, obj.CurrentPosition);
                obj.notifyPositionChanged();
            end
        end
        
        function moveStageX(obj, microns)
            % Move X stage by specified amount
            if ~obj.validateMovement(microns)
                return;
            end
            
            FoilviewUtils.safeExecute(@() doMoveStageX(), 'moveStageX');
            
            function doMoveStageX()
                newPos = obj.ScanImageManager.moveStage('X', microns);
                obj.CurrentXPosition = newPos;
                fprintf('X Stage moved %.1f μm to position %.1f μm\n', ...
                    microns, obj.CurrentXPosition);
                obj.notifyPositionChanged();
            end
        end
        
        function moveStageY(obj, microns)
            % Move Y stage by specified amount
            if ~obj.validateMovement(microns)
                return;
            end
            
            FoilviewUtils.safeExecute(@() doMoveStageY(), 'moveStageY');
            
            function doMoveStageY()
                newPos = obj.ScanImageManager.moveStage('Y', microns);
                obj.CurrentYPosition = newPos;
                fprintf('Y Stage moved %.1f μm to position %.1f μm\n', ...
                    microns, obj.CurrentYPosition);
                obj.notifyPositionChanged();
            end
        end
        
        function setPosition(obj, position)
            % Validate input using centralized utilities
            if ~obj.validatePosition(position)
                return;
            end
            
            FoilviewUtils.safeExecute(@() doSetPosition(), 'setPosition');
            
            function doSetPosition()
                if obj.SimulationMode
                    obj.CurrentPosition = position;
                    obj.notifyPositionChanged();
                else
                    % Calculate delta
                    delta = position - obj.CurrentPosition;
                    
                    if abs(delta) > obj.POSITION_TOLERANCE
                        obj.moveStage(delta);
                        % moveStage already calls notifyPositionChanged
                    else
                        obj.notifyPositionChanged(); % Notify if already at position
                    end
                end
            end
        end
        
        function setXYZPosition(obj, xPos, yPos, zPos)
            % Set X, Y, and Z positions simultaneously
            FoilviewUtils.safeExecute(@() doSetXYZPosition(), 'setXYZPosition');
            
            function doSetXYZPosition()
                % Move stages if needed
                if abs(xPos - obj.CurrentXPosition) > obj.POSITION_TOLERANCE
                    obj.moveStageX(xPos - obj.CurrentXPosition);
                end
                if abs(yPos - obj.CurrentYPosition) > obj.POSITION_TOLERANCE
                    obj.moveStageY(yPos - obj.CurrentYPosition);
                end
                if abs(zPos - obj.CurrentPosition) > obj.POSITION_TOLERANCE
                    obj.moveStage(zPos - obj.CurrentPosition);
                end

                % Final position update and notification
                obj.refreshPosition(); % Get final state from manager
                fprintf('Position set to X:%.1f, Y:%.1f, Z:%.1f μm\n', ...
                       obj.CurrentXPosition, obj.CurrentYPosition, obj.CurrentPosition);
            end
        end
        
        function success = resetPosition(obj)
            success = FoilviewUtils.safeExecuteWithReturn(@() doResetPosition(), 'resetPosition', false);
            
            function success = doResetPosition()
                oldPosition = obj.CurrentPosition;
                obj.CurrentPosition = 0;
                obj.notifyPositionChanged();
                fprintf('Position reset to 0 μm (was %.1f μm)\n', oldPosition);
                success = true;
            end
        end
        
        function refreshPosition(obj)
            if obj.shouldRefreshPosition()
                FoilviewUtils.safeExecute(@() doRefreshPosition(), 'refreshPosition');
            end
            
            function doRefreshPosition()
                positions = obj.ScanImageManager.getPositions();
                
                xChanged = abs(positions.x - obj.CurrentXPosition) > obj.POSITION_TOLERANCE;
                yChanged = abs(positions.y - obj.CurrentYPosition) > obj.POSITION_TOLERANCE;
                zChanged = abs(positions.z - obj.CurrentPosition) > obj.POSITION_TOLERANCE;
                
                obj.CurrentXPosition = positions.x;
                obj.CurrentYPosition = positions.y;
                obj.CurrentPosition = positions.z;
                
                if zChanged || xChanged || yChanged
                    obj.notifyPositionChanged();
                end
            end
        end
        
        function updateMetric(obj)
            FoilviewUtils.safeExecute(@() doUpdateMetric(), 'updateMetric');
            
            function doUpdateMetric()
                % Preallocate AllMetrics structure
                obj.AllMetrics = struct();
                for i = 1:length(obj.METRIC_TYPES)
                    metricType = obj.METRIC_TYPES{i};
                    fieldName = strrep(metricType, ' ', '_');
                    obj.AllMetrics.(fieldName) = NaN;
                end
                
                if obj.SimulationMode
                    % Simulate metric values based on position
                    for i = 1:length(obj.METRIC_TYPES)
                        metricType = obj.METRIC_TYPES{i};
                        % Convert to valid field name
                        fieldName = strrep(metricType, ' ', '_');
                        
                        % Generate different simulated metrics
                        switch metricType
                            case 'Std Dev'
                                % Simulate focus-like behavior: peak at certain positions
                                obj.AllMetrics.(fieldName) = 50 - abs(mod(obj.CurrentPosition, 100) - 50);
                            case 'Mean'
                                obj.AllMetrics.(fieldName) = 100 - mod(abs(obj.CurrentPosition), 100);
                            case 'Max'
                                obj.AllMetrics.(fieldName) = 200 - mod(abs(obj.CurrentPosition), 150);
                        end
                    end
                else
                    % Get real image data from ScanImage
                    pixelData = obj.ScanImageManager.getImageData();
                    if ~isempty(pixelData)
                        % Calculate all metrics
                        for i = 1:length(obj.METRIC_TYPES)
                            metricType = obj.METRIC_TYPES{i};
                            fieldName = strrep(metricType, ' ', '_');
                            obj.AllMetrics.(fieldName) = obj.calculateMetric(pixelData, metricType);
                        end
                    else
                        % If no pixel data, set all metrics to NaN
                        obj.setAllMetricsToNaN();
                    end
                end
                
                % Set the current selected metric
                fieldName = strrep(obj.CurrentMetricType, ' ', '_');
                if isfield(obj.AllMetrics, fieldName)
                    obj.CurrentMetric = obj.AllMetrics.(fieldName);
                else
                    obj.CurrentMetric = NaN;
                end
                
                obj.notifyMetricChanged();
                
                % If recording metrics during auto-stepping
                if obj.IsAutoRunning && obj.RecordMetrics
                    obj.recordCurrentMetric();
                end
            end
        end
        
        function setMetricType(obj, metricType)
            if ismember(metricType, obj.METRIC_TYPES)
                obj.CurrentMetricType = metricType;
                obj.updateMetric();
            end
        end
        
        function startAutoStepping(obj, stepSize, numSteps, delay, direction, recordMetrics)
            if obj.IsAutoRunning
                return;
            end
            
            obj.IsAutoRunning = true;
            obj.CurrentStep = 0;
            obj.TotalSteps = numSteps;
            obj.AutoDirection = direction;
            obj.RecordMetrics = recordMetrics;
            
            % Reset metrics collection if enabled
            if obj.RecordMetrics
                obj.AutoStepMetrics = struct('Positions', [], 'Values', struct());
            end
            
            obj.AutoTimer = FoilviewUtils.createTimer('fixedRate', delay, ...
                @(~,~) obj.executeAutoStep(stepSize));
            
            start(obj.AutoTimer);
            obj.notifyStatusChanged();
            
            fprintf('Auto-stepping started: %d steps of %.1f μm\n', numSteps, stepSize);
        end
        
        function stopAutoStepping(obj)
            FoilviewUtils.safeExecute(@() doStop(), 'stopAutoStepping');
            
            function doStop()
                FoilviewUtils.safeStopTimer(obj.AutoTimer);
                obj.AutoTimer = [];
                obj.IsAutoRunning = false;
                obj.notifyStatusChanged();
                
                fprintf('Auto-stepping completed at position %.1f μm\n', obj.CurrentPosition);
                
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
                stepSize = autoControls.StepField.Value;
                numSteps = autoControls.StepsField.Value;
                delay = autoControls.DelayField.Value;
                direction = obj.AutoDirection;
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
            % recoverFromMotorError - Attempt to recover from motor error state
            success = FoilviewUtils.safeExecuteWithReturn(@() doRecover(), 'recoverFromMotorError', false);
            
            function success = doRecover()
                success = false;
                
                if obj.SimulationMode
                    fprintf('FoilviewController: No motor error recovery needed in simulation mode\n');
                    success = true;
                    return;
                end
                
                try
                    % Find motor controls window
                    motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                    if isempty(motorFig)
                        fprintf('FoilviewController: Motor Controls window not found for error recovery\n');
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
            % Enhanced step size synchronization with validation
            FoilviewUtils.safeExecute(@() doSync(), 'syncStepSizes');
            
            function doSync()
                if isFromManual
                    % Manual dropdown changed, update auto field
                    stepValue = FoilviewUtils.extractStepSizeFromString(sourceValue);
                    if ~isnan(stepValue) && stepValue > 0
                        autoControls.StepField.Value = stepValue;
                    end
                else
                    % Auto field changed, update manual dropdown
                    newStepSize = sourceValue;
                    if isnumeric(newStepSize) && newStepSize > 0
                        [~, idx] = min(abs(obj.STEP_SIZES - newStepSize));
                        targetValue = FoilviewUtils.formatPosition(obj.STEP_SIZES(idx));
                        if ismember(targetValue, manualControls.StepSizeDropdown.Items)
                            manualControls.StepSizeDropdown.Value = targetValue;
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
    end
    

    methods (Access = private)
        function initializePositionsFromManager(obj)
            % Read initial X, Y, and Z positions from the manager.
            if ~obj.SimulationMode
                positions = obj.ScanImageManager.getPositions();
                obj.CurrentPosition = positions.z;
                obj.CurrentXPosition = positions.x;
                obj.CurrentYPosition = positions.y;
            end
        end

        function setSimulationMode(obj, isSimulation, message)
            obj.SimulationMode = isSimulation;
            obj.StatusMessage = message;
            obj.notifyStatusChanged();
        end
        
        function should = shouldRefreshPosition(obj)
            should = ~obj.SimulationMode && ~obj.IsAutoRunning;
        end
        
        function executeAutoStep(obj, stepSize)
            FoilviewUtils.safeExecute(@() doExecuteStep(), 'executeAutoStep');
            
            function doExecuteStep()
                % Check if controller is still valid and auto running
                if ~obj.IsAutoRunning
                    return;
                end
                
                obj.CurrentStep = obj.CurrentStep + 1;
                % Apply direction at execution time
                obj.moveStage(stepSize * obj.AutoDirection);
                
                if obj.CurrentStep >= obj.TotalSteps
                    obj.stopAutoStepping();
                end
            end
        end
        
        function value = calculateMetric(~, pixelData, metricType)
            if isempty(pixelData)
                value = NaN;
                return;
            end
            
            % Convert to double for calculations
            pixelData = double(pixelData);
            
            % Calculate the requested metric
            switch metricType
                case 'Std Dev'
                    value = std(pixelData(:));
                case 'Mean'
                    value = mean(pixelData(:));
                case 'Max'
                    value = max(pixelData(:));
                otherwise
                    value = std(pixelData(:));  % Default to Std Dev for focus
            end
        end
        
        function setAllMetricsToNaN(obj)
            % Helper method to set all metrics to NaN - eliminates duplication
            for i = 1:length(obj.METRIC_TYPES)
                metricType = obj.METRIC_TYPES{i};
                fieldName = strrep(metricType, ' ', '_');
                obj.AllMetrics.(fieldName) = NaN;
            end
        end
        
        function recordCurrentMetric(obj)
            % Add current position to the auto step metrics
            obj.AutoStepMetrics.Positions(end+1) = obj.CurrentPosition;
            
            % Record all metrics
            for i = 1:length(obj.METRIC_TYPES)
                metricType = obj.METRIC_TYPES{i};
                fieldName = strrep(metricType, ' ', '_');
                if ~isfield(obj.AutoStepMetrics.Values, fieldName)
                    obj.AutoStepMetrics.Values.(fieldName) = [];
                end
                obj.AutoStepMetrics.Values.(fieldName)(end+1) = obj.AllMetrics.(fieldName);
                
                % Check if this is a new maximum for this metric
                currentValue = obj.AllMetrics.(fieldName);
                if ~isnan(currentValue)
                    % Get existing values for this metric
                    values = obj.AutoStepMetrics.Values.(fieldName);
                    values = values(~isnan(values));  % Remove any NaN values
                    
                    % If this is the first value or a new maximum
                    if isempty(values) || currentValue >= max(values) % Use >= to handle first value
                        % Create a bookmark for this maximum
                        obj.BookmarkManager.updateMax(metricType, currentValue, ...
                            obj.CurrentXPosition, obj.CurrentYPosition, obj.CurrentPosition);
                        
                        fprintf('Updated max %s bookmark at X:%.1f, Y:%.1f, Z:%.1f μm\n', ...
                            metricType, obj.CurrentXPosition, obj.CurrentYPosition, obj.CurrentPosition);
                    end
                end
            end
        end
        
        function cleanupInternal(obj)
            % Stop auto-stepping
            if obj.IsAutoRunning
                obj.stopAutoStepping();
            end
            
            % Clean up any timers using centralized utility
            FoilviewUtils.safeStopTimer(obj.AutoTimer);
            obj.AutoTimer = [];
        end
        

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
        
        function success = validateMovement(obj, microns)
            success = true;
            if obj.SimulationMode
                if microns == 0
                    fprintf('Movement is zero\n');
                    success = false;
                end
            else
                if abs(microns) > obj.MAX_STEP_SIZE
                    fprintf('Movement exceeds maximum step size of %.1f μm\n', obj.MAX_STEP_SIZE);
                    success = false;
                end
            end
        end
        
        function success = validatePosition(obj, position)
            % Use centralized validation utilities
            success = FoilviewUtils.validateNumericRange(position, obj.MIN_POSITION, obj.MAX_POSITION, 'Position');
        end
        
        function handleMovementError(obj, e, microns)
            obj.SimulationMode = true;
            obj.setSimulationMode(true, ['Error: ' e.message]);
            fprintf('Movement error: %.1f μm\n', microns);
        end
        
        % ===== VALIDATION METHODS (consolidated from foilview_logic) =====
        
        function [valid, errorMsg] = validateAutoStepParameters(obj, autoControls)
            % Enhanced parameter validation with detailed error messages
            valid = true;
            errorMsg = '';
            
            stepSize = autoControls.StepField.Value;
            numSteps = autoControls.StepsField.Value;
            delay = autoControls.DelayField.Value;
            
            % Validate step size using utility
            if ~FoilviewUtils.validateNumericRange(stepSize, obj.MIN_STEP_SIZE, obj.MAX_STEP_SIZE, 'Step size')
                valid = false;
                errorMsg = sprintf('Step size must be between %.3f and %.1f μm', ...
                    obj.MIN_STEP_SIZE, obj.MAX_STEP_SIZE);
                return;
            end
            
            % Validate number of steps using utility
            if ~FoilviewUtils.validateInteger(numSteps, obj.MIN_AUTO_STEPS, obj.MAX_AUTO_STEPS, 'Number of steps')
                valid = false;
                errorMsg = sprintf('Number of steps must be between %d and %d', ...
                    obj.MIN_AUTO_STEPS, obj.MAX_AUTO_STEPS);
                return;
            end
            
            % Validate delay using utility
            if ~FoilviewUtils.validateNumericRange(delay, obj.MIN_AUTO_DELAY, obj.MAX_AUTO_DELAY, 'Delay')
                valid = false;
                errorMsg = sprintf('Delay must be between %.1f and %.1f seconds', ...
                    obj.MIN_AUTO_DELAY, obj.MAX_AUTO_DELAY);
                return;
            end
        end
        
        function [valid, errorMsg] = validateLabel(obj, label)
            % Use centralized string validation
            [valid, errorMsg] = FoilviewUtils.validateStringInput(label, ...
                obj.MIN_LABEL_LENGTH, obj.MAX_LABEL_LENGTH, ...
                obj.LABEL_INVALID_CHARS, 'Label');
        end
    end
    
    methods (Access = public)
        function cleanup(obj)
            % Public wrapper to clean up controller resources
            obj.cleanupInternal();
        end
    end
end 

