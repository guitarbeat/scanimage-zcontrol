classdef foilview_controller < handle
    % foilview_controller - Core Z-stage positioning and metrics functionality
    % 
    % This class provides comprehensive control over microscope Z-stage positioning,
    % integrating with ScanImage software for hardware control and real-time
    % focus metrics calculation. Supports both manual positioning and automated
    % scanning sequences with data collection.
    %
    % Key Features:
    %   - ScanImage Motor Controls integration with automatic fallback to simulation
    %   - Real-time position tracking and metrics calculation  
    %   - Automated stepping sequences with configurable parameters
    %   - Position bookmarking system for saving important locations
    %   - Event-driven architecture for loose coupling with UI components
    %
    % Usage:
    %   controller = foilview_controller();           % Create controller
    %   controller.moveStage(10);                     % Move 10 μm up
    %   controller.startAutoStepping(2, 20, 0.5, 1, true);  % Auto scan
    %   controller.markCurrentPosition('Focus');      % Save position
    %
    % Events:
    %   StatusChanged    - Fired when connection status changes
    %   PositionChanged  - Fired when stage position updates
    %   MetricChanged    - Fired when focus metrics are recalculated
    %   AutoStepComplete - Fired when automated sequence finishes
    %
    % See also: foilview, foilview_ui, foilview_plot, foilview_logic, foilview_updater
    
    %% Configuration Constants
    properties (Constant, Access = public)
        % Step Size Configuration (microns)
        STEP_SIZES = [0.1, 0.5, 1, 5, 10, 50]
        DEFAULT_STEP_SIZE = 1.0
        MIN_STEP_SIZE = 0.01
        MAX_STEP_SIZE = 1000
        
        % Auto Step Configuration
        DEFAULT_AUTO_STEP = 10      % Default step size (μm)
        DEFAULT_AUTO_STEPS = 10     % Default number of steps
        DEFAULT_AUTO_DELAY = 0.5    % Default delay between steps (seconds)
        MIN_AUTO_STEPS = 1
        MAX_AUTO_STEPS = 1000
        MIN_AUTO_DELAY = 0.1
        MAX_AUTO_DELAY = 10.0
        
        % Timer Configuration (seconds)
        POSITION_REFRESH_PERIOD = 0.5   % Position reading frequency
        METRIC_REFRESH_PERIOD = 1.0     % Metric calculation frequency
        MOVEMENT_WAIT_TIME = 0.2        % Post-movement settling time
        STATUS_RESET_DELAY = 5          % Status message auto-reset time
        
        % Metric Configuration
        METRIC_TYPES = {'Std Dev', 'Mean', 'Max'}
        DEFAULT_METRIC = 'Std Dev'      % Best performer for focus detection
        
        % Position Limits (microns)
        MIN_POSITION = -10000
        MAX_POSITION = 10000
        POSITION_TOLERANCE = 0.01       % Minimum movement threshold
        
        % Status Messages
        TEXT = struct(...
            'Ready', 'Ready', ...
            'Simulation', 'Simulation Mode', ...
            'Initializing', 'Initializing...', ...
            'Connected', 'Connected', ...
            'NotRunning', 'ScanImage not running - Start ScanImage first', ...
            'WindowNotFound', 'Motor Controls window not found - Open Motor Controls in ScanImage', ...
            'MissingElements', 'Missing UI elements in Motor Controls - Check ScanImage version compatibility', ...
            'LostConnection', 'Lost connection', ...
            'MovementError', 'Movement error', ...
            'InvalidPosition', 'Invalid position', ...
            'AutoStepError', 'Auto-step error', ...
            'WorkspaceError', 'Cannot access base workspace - Ensure ScanImage is initialized', ...
            'ScanImageInvalid', 'hSI variable exists but is not a valid ScanImage object', ...
            'VersionIncompatible', 'ScanImage version may be incompatible - Some features may not work')
    end
    
    %% Public Properties
    properties (Access = public)
        % Position State
        CurrentPosition (1,1) double = 0        % Current Z position in microns
        CurrentXPosition (1,1) double = 0       % Current X position in microns
        CurrentYPosition (1,1) double = 0       % Current Y position in microns
        MarkedPositions = struct('Labels', {{}}, 'XPositions', [], 'YPositions', [], 'ZPositions', [], 'Metrics', {{}})  % Saved position bookmarks
        
        % Auto Step State
        IsAutoRunning (1,1) logical = false     % True when automated sequence is active
        CurrentStep (1,1) double = 0            % Current step number in sequence
        TotalSteps (1,1) double = 0             % Total steps in current sequence
        AutoDirection (1,1) double = 1          % 1 for up, -1 for down movement
        RecordMetrics (1,1) logical = false     % Whether to collect metrics during auto-stepping
        AutoStepMetrics = struct('Positions', [], 'Values', struct())  % Collected metrics data
        
        % Metric State
        CurrentMetric (1,1) double = 0          % Current value of selected metric
        AllMetrics struct = struct()            % All calculated metrics for current position
        CurrentMetricType char = 'Focus Score'  % Currently selected metric type
        
        % ScanImage Integration
        SimulationMode (1,1) logical = true     % True when running without ScanImage hardware
        StatusMessage char = ''                 % Current status for display
    end
    
    %% Private Properties
    properties (Access = private)
        % ScanImage handles
        hSI                         % ScanImage handle
        motorFig                    % Motor Controls figure handle
        etZPos                      % Z position field
        etXPos                      % X position field
        etYPos                      % Y position field
        Zstep                       % Z step field
        Xstep                       % X step field
        Ystep                       % Y step field
        Zdec                        % Z decrease button
        Zinc                        % Z increase button
        Xdec                        % X decrease button
        Xinc                        % X increase button
        Ydec                        % Y decrease button
        Yinc                        % Y increase button
        
        % Timers
        AutoTimer
        
        % Callbacks
        StatusUpdateCallback
        PositionUpdateCallback
        MetricUpdateCallback
        AutoStepCompleteCallback
    end
    
    %% Events
    events
        StatusChanged
        PositionChanged
        MetricChanged
        AutoStepComplete
    end
    
    %% Constructor and Destructor
    methods (Access = public)
        function obj = foilview_controller()
            % Initialize the controller
            obj.CurrentMetricType = obj.DEFAULT_METRIC;
            obj.connectToScanImage();
        end
        
        function delete(obj)
            obj.cleanup();
        end
    end
    
    %% Public Interface Methods
    methods (Access = public)
        function connectToScanImage(obj)
            % Check if ScanImage is running with enhanced workspace validation
            try
                % * Use safe method to get ScanImage handle
                [success, hSI_handle] = obj.safeGetScanImageHandle();
                if ~success
                    % Error message already set by safeGetScanImageHandle
                    return;
                end
                
                % Store validated handle
                obj.hSI = hSI_handle;
                
                % Find motor controls window
                obj.motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                if isempty(obj.motorFig)
                    obj.setSimulationMode(true, obj.TEXT.WindowNotFound);
                    return;
                end
                
                % Find motor UI elements
                obj.etZPos = findall(obj.motorFig, 'Tag', 'etZPos');
                obj.etXPos = findall(obj.motorFig, 'Tag', 'etXPos');
                obj.etYPos = findall(obj.motorFig, 'Tag', 'etYPos');
                obj.Zstep = findall(obj.motorFig, 'Tag', 'Zstep');
                obj.Xstep = findall(obj.motorFig, 'Tag', 'Xstep');
                obj.Ystep = findall(obj.motorFig, 'Tag', 'Ystep');
                obj.Zdec = findall(obj.motorFig, 'Tag', 'Zdec');
                obj.Zinc = findall(obj.motorFig, 'Tag', 'Zinc');
                obj.Xdec = findall(obj.motorFig, 'Tag', 'Xdec');
                obj.Xinc = findall(obj.motorFig, 'Tag', 'Xinc');
                obj.Ydec = findall(obj.motorFig, 'Tag', 'Ydec');
                obj.Yinc = findall(obj.motorFig, 'Tag', 'Yinc');
                
                % Check that at least Z controls are available (X/Y are optional)
                if any(cellfun(@isempty, {obj.etZPos, obj.Zstep, obj.Zdec, obj.Zinc}))
                    obj.setSimulationMode(true, obj.TEXT.MissingElements);
                    return;
                end
                
                % Successfully connected
                obj.setSimulationMode(false, obj.TEXT.Connected);
                
                % ! Initialize positions with better error handling
                obj.CurrentPosition = str2double(obj.etZPos.String);
                if isnan(obj.CurrentPosition)
                    % ! Warn about position reading failure instead of silent default
                    warning('foilview:PositionRead', ...
                        'Could not read Z position from Motor Controls, defaulting to 0');
                    obj.CurrentPosition = 0;
                end
                
                % Initialize X position if available
                if ~isempty(obj.etXPos)
                    obj.CurrentXPosition = str2double(obj.etXPos.String);
                    if isnan(obj.CurrentXPosition)
                        warning('foilview:PositionRead', ...
                            'Could not read X position from Motor Controls, defaulting to 0');
                        obj.CurrentXPosition = 0;
                    end
                end
                
                % Initialize Y position if available
                if ~isempty(obj.etYPos)
                    obj.CurrentYPosition = str2double(obj.etYPos.String);
                    if isnan(obj.CurrentYPosition)
                        warning('foilview:PositionRead', ...
                            'Could not read Y position from Motor Controls, defaulting to 0');
                        obj.CurrentYPosition = 0;
                    end
                end
                
                obj.notifyPositionChanged();
                
            catch ex
                % ! Provide specific troubleshooting guidance based on error type
                errorMsg = obj.generateTroubleshootingMessage(ex);
                obj.setSimulationMode(true, errorMsg);
                foilview_utils.logError('connectToScanImage', ex);
            end
        end
        
        function moveStage(obj, microns)
            % Validate input using centralized utilities
            if ~obj.validateMovement(microns)
                return;
            end
            
            success = foilview_utils.safeExecute(@() doMoveStage(), 'moveStage');
            
            function doMoveStage()
                if obj.SimulationMode
                    obj.CurrentPosition = obj.CurrentPosition + microns;
                else
                    % Set step size
                    obj.Zstep.String = num2str(abs(microns));
                    
                    % Simulate pressing Enter in the step field to apply the value
                    if isfield(obj.Zstep, 'Callback') && ~isempty(obj.Zstep.Callback)
                        obj.Zstep.Callback(obj.Zstep, []);
                    end
                    
                    % Press button
                    if microns > 0
                        obj.Zinc.Callback(obj.Zinc, []);
                    else
                        obj.Zdec.Callback(obj.Zdec, []);
                    end
                    
                    % Read position with timeout
                    pause(obj.MOVEMENT_WAIT_TIME);
                    zPos = str2double(obj.etZPos.String);
                    if ~isnan(zPos)
                        obj.CurrentPosition = zPos;
                    else
                        obj.CurrentPosition = obj.CurrentPosition + microns;
                    end
                end
                
                obj.notifyPositionChanged();
                fprintf('Stage moved %.1f μm to position %.1f μm\n', microns, obj.CurrentPosition);
            end
        end
        
        function moveStageX(obj, microns)
            % Move X stage by specified amount
            if ~obj.validateMovement(microns)
                return;
            end
            
            success = foilview_utils.safeExecute(@() doMoveStageX(), 'moveStageX');
            
            function doMoveStageX()
                if obj.SimulationMode || isempty(obj.etXPos)
                    obj.CurrentXPosition = obj.CurrentXPosition + microns;
                else
                    % Set step size
                    if ~isempty(obj.Xstep)
                        obj.Xstep.String = num2str(abs(microns));
                        
                        % Simulate pressing Enter in the step field to apply the value
                        if isfield(obj.Xstep, 'Callback') && ~isempty(obj.Xstep.Callback)
                            obj.Xstep.Callback(obj.Xstep, []);
                        end
                    end
                    
                    % Press button
                    if microns > 0 && ~isempty(obj.Xinc)
                        obj.Xinc.Callback(obj.Xinc, []);
                    elseif microns < 0 && ~isempty(obj.Xdec)
                        obj.Xdec.Callback(obj.Xdec, []);
                    end
                    
                    % Read position with timeout
                    pause(obj.MOVEMENT_WAIT_TIME);
                    xPos = str2double(obj.etXPos.String);
                    if ~isnan(xPos)
                        obj.CurrentXPosition = xPos;
                    else
                        obj.CurrentXPosition = obj.CurrentXPosition + microns;
                    end
                end
                
                obj.notifyPositionChanged();
                fprintf('X Stage moved %.1f μm to position %.1f μm\n', microns, obj.CurrentXPosition);
            end
        end
        
        function moveStageY(obj, microns)
            % Move Y stage by specified amount
            if ~obj.validateMovement(microns)
                return;
            end
            
            success = foilview_utils.safeExecute(@() doMoveStageY(), 'moveStageY');
            
            function doMoveStageY()
                if obj.SimulationMode || isempty(obj.etYPos)
                    obj.CurrentYPosition = obj.CurrentYPosition + microns;
                else
                    % Set step size
                    if ~isempty(obj.Ystep)
                        obj.Ystep.String = num2str(abs(microns));
                        
                        % Simulate pressing Enter in the step field to apply the value
                        if isfield(obj.Ystep, 'Callback') && ~isempty(obj.Ystep.Callback)
                            obj.Ystep.Callback(obj.Ystep, []);
                        end
                    end
                    
                    % Press button
                    if microns > 0 && ~isempty(obj.Yinc)
                        obj.Yinc.Callback(obj.Yinc, []);
                    elseif microns < 0 && ~isempty(obj.Ydec)
                        obj.Ydec.Callback(obj.Ydec, []);
                    end
                    
                    % Read position with timeout
                    pause(obj.MOVEMENT_WAIT_TIME);
                    yPos = str2double(obj.etYPos.String);
                    if ~isnan(yPos)
                        obj.CurrentYPosition = yPos;
                    else
                        obj.CurrentYPosition = obj.CurrentYPosition + microns;
                    end
                end
                
                obj.notifyPositionChanged();
                fprintf('Y Stage moved %.1f μm to position %.1f μm\n', microns, obj.CurrentYPosition);
            end
        end
        
        function setPosition(obj, position)
            % Validate input using centralized utilities
            if ~obj.validatePosition(position)
                return;
            end
            
            success = foilview_utils.safeExecute(@() doSetPosition(), 'setPosition');
            
            function doSetPosition()
                if obj.SimulationMode
                    obj.CurrentPosition = position;
                else
                    % Calculate delta
                    delta = position - obj.CurrentPosition;
                    
                    if abs(delta) > obj.POSITION_TOLERANCE
                        obj.moveStage(delta);
                        return; % moveStage already calls notifyPositionChanged
                    end
                end
                
                obj.notifyPositionChanged();
            end
        end
        
        function setXYZPosition(obj, xPos, yPos, zPos)
            % Set X, Y, and Z positions simultaneously
            success = foilview_utils.safeExecute(@() doSetXYZPosition(), 'setXYZPosition');
            
            function doSetXYZPosition()
                if obj.SimulationMode
                    obj.CurrentXPosition = xPos;
                    obj.CurrentYPosition = yPos;
                    obj.CurrentPosition = zPos;
                else
                    % Calculate deltas
                    deltaX = xPos - obj.CurrentXPosition;
                    deltaY = yPos - obj.CurrentYPosition;
                    deltaZ = zPos - obj.CurrentPosition;
                    
                    % Move stages if needed
                    if abs(deltaX) > obj.POSITION_TOLERANCE
                        obj.moveStageX(deltaX);
                    end
                    if abs(deltaY) > obj.POSITION_TOLERANCE
                        obj.moveStageY(deltaY);
                    end
                    if abs(deltaZ) > obj.POSITION_TOLERANCE
                        obj.moveStage(deltaZ);
                        return; % moveStage already calls notifyPositionChanged
                    end
                end
                
                obj.notifyPositionChanged();
                fprintf('Position set to X:%.1f, Y:%.1f, Z:%.1f μm\n', ...
                       obj.CurrentXPosition, obj.CurrentYPosition, obj.CurrentPosition);
            end
        end
        
        function success = resetPosition(obj)
            success = foilview_utils.safeExecuteWithReturn(@() doResetPosition(), 'resetPosition', false);
            
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
                foilview_utils.safeExecute(@() doRefreshPosition(), 'refreshPosition');
            end
            
            function doRefreshPosition()
                positionChanged = false;
                
                % Refresh Z position
                if ~isempty(obj.etZPos)
                    zPos = str2double(obj.etZPos.String);
                    if ~isnan(zPos) && zPos ~= obj.CurrentPosition
                        obj.CurrentPosition = zPos;
                        positionChanged = true;
                    end
                end
                
                % Refresh X position if available
                if ~isempty(obj.etXPos)
                    xPos = str2double(obj.etXPos.String);
                    if ~isnan(xPos) && xPos ~= obj.CurrentXPosition
                        obj.CurrentXPosition = xPos;
                        positionChanged = true;
                    end
                end
                
                % Refresh Y position if available
                if ~isempty(obj.etYPos)
                    yPos = str2double(obj.etYPos.String);
                    if ~isnan(yPos) && yPos ~= obj.CurrentYPosition
                        obj.CurrentYPosition = yPos;
                        positionChanged = true;
                    end
                end
                
                if positionChanged
                    obj.notifyPositionChanged();
                end
            end
        end
        
        function updateMetric(obj)
            foilview_utils.safeExecute(@() doUpdateMetric(), 'updateMetric');
            
            function doUpdateMetric()
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
                    pixelData = obj.getImageData();
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
            
            obj.AutoTimer = foilview_utils.createTimer('fixedRate', delay, ...
                @(~,~) obj.executeAutoStep(stepSize));
            
            start(obj.AutoTimer);
            obj.notifyStatusChanged();
            
            fprintf('Auto-stepping started: %d steps of %.1f μm\n', numSteps, stepSize);
        end
        
        function stopAutoStepping(obj)
            foilview_utils.safeExecute(@() doStop(), 'stopAutoStepping');
            
            function doStop()
                foilview_utils.safeStopTimer(obj.AutoTimer);
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
            
            % Remove existing bookmark with same label
            existingIdx = strcmp(obj.MarkedPositions.Labels, label);
            if any(existingIdx)
                obj.MarkedPositions.Labels(existingIdx) = [];
                obj.MarkedPositions.XPositions(existingIdx) = [];
                obj.MarkedPositions.YPositions(existingIdx) = [];
                obj.MarkedPositions.ZPositions(existingIdx) = [];
                obj.MarkedPositions.Metrics(existingIdx) = [];
            end
            
            % Add new bookmark with current XYZ positions and metric
            obj.MarkedPositions.Labels{end+1} = label;
            obj.MarkedPositions.XPositions(end+1) = obj.CurrentXPosition;
            obj.MarkedPositions.YPositions(end+1) = obj.CurrentYPosition;
            obj.MarkedPositions.ZPositions(end+1) = obj.CurrentPosition;
            obj.MarkedPositions.Metrics{end+1} = struct(...
                'Type', obj.CurrentMetricType, ...
                'Value', obj.CurrentMetric);
            
            fprintf('Position marked: "%s" at X:%.1f, Y:%.1f, Z:%.1f μm (Metric: %.2f)\n', ...
                label, obj.CurrentXPosition, obj.CurrentYPosition, obj.CurrentPosition, obj.CurrentMetric);
        end
        
        function goToMarkedPosition(obj, index)
            if obj.isValidBookmarkIndex(index) && ~obj.IsAutoRunning
                xPos = obj.MarkedPositions.XPositions(index);
                yPos = obj.MarkedPositions.YPositions(index);
                zPos = obj.MarkedPositions.ZPositions(index);
                label = obj.MarkedPositions.Labels{index};
                
                obj.setXYZPosition(xPos, yPos, zPos);
                fprintf('Moved to bookmark "%s": X:%.1f, Y:%.1f, Z:%.1f μm\n', label, xPos, yPos, zPos);
            end
        end
        
        function deleteMarkedPosition(obj, index)
            if obj.isValidBookmarkIndex(index)
                label = obj.MarkedPositions.Labels{index};
                obj.MarkedPositions.Labels(index) = [];
                obj.MarkedPositions.XPositions(index) = [];
                obj.MarkedPositions.YPositions(index) = [];
                obj.MarkedPositions.ZPositions(index) = [];
                obj.MarkedPositions.Metrics(index) = [];
                
                fprintf('Deleted bookmark: "%s"\n', label);
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
    end
    
    %% Private Methods
    methods (Access = private)
        function setSimulationMode(obj, isSimulation, message)
            obj.SimulationMode = isSimulation;
            obj.StatusMessage = message;
            obj.notifyStatusChanged();
        end
        
        function [success, hSI_handle] = safeGetScanImageHandle(obj)
            % * Safely retrieve ScanImage handle with comprehensive validation
            % This method addresses the critical base workspace dependency issue
            success = false;
            hSI_handle = [];
            
            try
                % ! Check if we can access base workspace at all
                try
                    testVar = evalin('base', '1');
                catch ME
                    % Cannot access base workspace - might be called from function scope
                    obj.setSimulationMode(true, obj.TEXT.WorkspaceError);
                    foilview_utils.logError('safeGetScanImageHandle', ...
                        ['Base workspace inaccessible: ' ME.message]);
                    return;
                end
                
                % Check if hSI variable exists in base workspace
                if ~evalin('base', 'exist(''hSI'', ''var'')')
                    obj.setSimulationMode(true, obj.TEXT.NotRunning);
                    return;
                end
                
                % Get the hSI handle
                hSI_handle = evalin('base', 'hSI');
                
                % ! Validate that hSI is actually a ScanImage object
                if isempty(hSI_handle)
                    obj.setSimulationMode(true, obj.TEXT.NotRunning);
                    return;
                end
                
                if ~isobject(hSI_handle)
                    obj.setSimulationMode(true, obj.TEXT.ScanImageInvalid);
                    return;
                end
                
                % * Validate ScanImage compatibility
                [isCompatible, versionInfo] = obj.validateScanImageVersion(hSI_handle);
                if ~isCompatible
                    % ! Still allow connection but warn user
                    warning('foilview:VersionCheck', ...
                        'ScanImage version compatibility issue: %s', versionInfo);
                    % Set simulation mode with warning but continue
                    obj.setSimulationMode(false, obj.TEXT.VersionIncompatible);
                else
                    success = true;
                end
                
                success = true;
                
            catch ME
                obj.setSimulationMode(true, ['Workspace Error: ' ME.message]);
                foilview_utils.logError('safeGetScanImageHandle', ME);
            end
        end
        
        function [isCompatible, versionInfo] = validateScanImageVersion(obj, hSI_handle)
            % * Validate ScanImage version compatibility
            % Returns true if compatible, false with warning message if not
            isCompatible = true;
            versionInfo = 'Unknown version';
            
            try
                % Check if version property exists
                if isprop(hSI_handle, 'version')
                    versionInfo = hSI_handle.version;
                    % ! Basic version check - could be enhanced with specific version logic
                    if ischar(versionInfo) && ~isempty(versionInfo)
                        % Log version for debugging
                        fprintf('ScanImage version detected: %s\n', versionInfo);
                        % For now, consider all versions compatible but log
                        isCompatible = true;
                    else
                        versionInfo = 'Version property exists but is empty';
                        isCompatible = false;
                    end
                elseif isprop(hSI_handle, 'VERSION_STR')
                    % Alternative version property name
                    versionInfo = hSI_handle.VERSION_STR;
                    fprintf('ScanImage version detected (VERSION_STR): %s\n', versionInfo);
                    isCompatible = true;
                else
                    % No version property found - older ScanImage
                    versionInfo = 'No version property found - may be older ScanImage version';
                    isCompatible = false;
                end
                
                % ! Additional compatibility checks could be added here
                % For example: checking for required properties/methods
                requiredProperties = {'hMotors'};
                for i = 1:length(requiredProperties)
                    if ~isprop(hSI_handle, requiredProperties{i})
                        versionInfo = sprintf('Missing required property: %s', requiredProperties{i});
                        isCompatible = false;
                        break;
                    end
                end
                
            catch ME
                versionInfo = sprintf('Error checking version: %s', ME.message);
                isCompatible = false;
            end
        end
        
        function errorMsg = generateTroubleshootingMessage(obj, exception)
            % * Generate specific troubleshooting messages based on error type
            % Provides users with actionable guidance instead of generic errors
            
            errorMsg = ['Connection Error: ' exception.message];
            
            % ! Provide specific guidance based on error patterns
            if contains(exception.message, 'Undefined variable')
                errorMsg = sprintf('%s\n\nTroubleshooting:\n1. Start ScanImage first\n2. Ensure ScanImage completed initialization\n3. Check that hSI variable exists in workspace', ...
                    errorMsg);
            elseif contains(exception.message, 'Reference to non-existent field')
                errorMsg = sprintf('%s\n\nTroubleshooting:\n1. Check ScanImage version compatibility\n2. Try restarting ScanImage\n3. Verify Motor Controls are enabled', ...
                    errorMsg);
            elseif contains(exception.message, 'Invalid figure handle')
                errorMsg = sprintf('%s\n\nTroubleshooting:\n1. Open Motor Controls window in ScanImage\n2. Ensure Motor Controls are not minimized\n3. Try closing and reopening Motor Controls', ...
                    errorMsg);
            elseif contains(exception.message, 'Tag')
                errorMsg = sprintf('%s\n\nTroubleshooting:\n1. Check ScanImage version - UI tags may have changed\n2. Try restarting ScanImage\n3. Verify Motor Controls window is fully loaded', ...
                    errorMsg);
            else
                % Generic troubleshooting for unknown errors
                errorMsg = sprintf('%s\n\nGeneral Troubleshooting:\n1. Restart ScanImage\n2. Ensure Motor Controls window is open\n3. Check MATLAB command window for additional error details', ...
                    errorMsg);
            end
        end
        
        function should = shouldRefreshPosition(obj)
            should = ~obj.SimulationMode && ...
                     ~obj.IsAutoRunning && ...
                     foilview_utils.validateUIComponent(obj.etZPos);
        end
        
        function handleConnectionLoss(obj)
            obj.SimulationMode = true;
            obj.setSimulationMode(true, obj.TEXT.LostConnection);
        end
        
        function executeAutoStep(obj, stepSize)
            foilview_utils.safeExecute(@() doExecuteStep(), 'executeAutoStep');
            
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
        
        function pixelData = getImageData(obj)
            pixelData = [];
            foilview_utils.safeExecute(@() doGetImageData(), 'getImageData', true);  % Suppress errors
            
            function doGetImageData()
                if ~isempty(obj.hSI) && isprop(obj.hSI, 'hDisplay')
                    % Try to get ROI data array
                    roiData = obj.hSI.hDisplay.getRoiDataArray();
                    if ~isempty(roiData) && isprop(roiData(1), 'imageData') && ~isempty(roiData(1).imageData)
                        pixelData = roiData(1).imageData{1}{1};
                    end
                    
                    % If that fails, try buffer method
                    if isempty(pixelData) && isprop(obj.hSI.hDisplay, 'stripeDataBuffer')
                        buffer = obj.hSI.hDisplay.stripeDataBuffer;
                        if ~isempty(buffer) && iscell(buffer) && ~isempty(buffer{1})
                            pixelData = buffer{1}.roiData{1}.imageData{1}{1};
                        end
                    end
                end
            end
        end
        
        function value = calculateMetric(obj, pixelData, metricType)
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
                    if isempty(values) || currentValue == max(values)
                        % Create a bookmark for this maximum
                        obj.createMaxBookmark(metricType, currentValue);
                    end
                end
            end
        end
        
        function createMaxBookmark(obj, metricType, value)
            % Create a bookmark for a maximum value
            % Format: "Max [Metric Type] (value)"
            label = sprintf('Max %s (%.1f)', metricType, value);
            
            % Remove any existing bookmark with the same metric type
            existingIdx = cellfun(@(x) startsWith(x, ['Max ' metricType]), obj.MarkedPositions.Labels);
            if any(existingIdx)
                obj.MarkedPositions.Labels(existingIdx) = [];
                obj.MarkedPositions.XPositions(existingIdx) = [];
                obj.MarkedPositions.YPositions(existingIdx) = [];
                obj.MarkedPositions.ZPositions(existingIdx) = [];
                obj.MarkedPositions.Metrics(existingIdx) = [];
            end
            
            % Add new bookmark with current XYZ positions
            obj.MarkedPositions.Labels{end+1} = label;
            obj.MarkedPositions.XPositions(end+1) = obj.CurrentXPosition;
            obj.MarkedPositions.YPositions(end+1) = obj.CurrentYPosition;
            obj.MarkedPositions.ZPositions(end+1) = obj.CurrentPosition;
            obj.MarkedPositions.Metrics{end+1} = struct(...
                'Type', metricType, ...
                'Value', value);
            
            % Log the bookmark creation
            fprintf('Created bookmark for maximum %s: %.1f at X:%.1f, Y:%.1f, Z:%.1f μm\n', ...
                metricType, value, obj.CurrentXPosition, obj.CurrentYPosition, obj.CurrentPosition);
        end
        
        function valid = isValidBookmarkIndex(obj, index)
            valid = index >= 1 && index <= length(obj.MarkedPositions.Labels);
        end
        
        function cleanup(obj)
            % Stop auto-stepping
            if obj.IsAutoRunning
                obj.stopAutoStepping();
            end
            
            % Clean up any timers using centralized utility
            foilview_utils.safeStopTimer(obj.AutoTimer);
            obj.AutoTimer = [];
        end
        
        % Event notification methods
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
            success = foilview_utils.validateNumericRange(position, obj.MIN_POSITION, obj.MAX_POSITION, 'Position');
        end
        
        function handleMovementError(obj, e, microns)
            % ! Enhanced movement error handling with troubleshooting guidance
            obj.SimulationMode = true;
            
            % Generate specific error message with troubleshooting steps
            errorMsg = sprintf('Movement Error (%.1f μm): %s\n\nTroubleshooting:\n1. Check motor connections\n2. Verify ScanImage is not busy\n3. Ensure stage limits are not exceeded\n4. Try smaller step sizes', ...
                microns, e.message);
            
            obj.setSimulationMode(true, errorMsg);
            foilview_utils.logError('handleMovementError', e);
            
            % ! Also log to console for debugging
            warning('foilview:MovementError', 'Movement error: %.1f μm - %s', microns, e.message);
        end
    end
end 