classdef ZStageController < handle
    % ZStageController - Core Z-stage positioning and metrics functionality
    % Handles ScanImage integration, position control, and metric calculations
    
    %% Constants
    properties (Constant, Access = public)
        % Step Size Options
        STEP_SIZES = [0.1, 0.5, 1, 5, 10, 50]
        DEFAULT_STEP_SIZE = 1.0
        
        % Auto Step Defaults
        DEFAULT_AUTO_STEP = 10
        DEFAULT_AUTO_STEPS = 10
        DEFAULT_AUTO_DELAY = 0.5
        
        % Timer Configuration
        POSITION_REFRESH_PERIOD = 0.5
        METRIC_REFRESH_PERIOD = 1.0
        MOVEMENT_WAIT_TIME = 0.2
        STATUS_RESET_DELAY = 5
        
        % Metric Options
        METRIC_TYPES = {'Mean', 'Median', 'Std Dev', 'Max', 'Focus Score'}
        DEFAULT_METRIC = 'Focus Score'
        
        % Status Messages
        TEXT = struct(...
            'Ready', 'Ready', ...
            'Simulation', 'Simulation Mode', ...
            'Initializing', 'ScanImage: Initializing...', ...
            'Connected', 'Connected to ScanImage', ...
            'NotRunning', 'ScanImage not running', ...
            'WindowNotFound', 'Motor Controls window not found', ...
            'MissingElements', 'Missing UI elements in Motor Controls', ...
            'LostConnection', 'Lost connection')
    end
    
    %% Public Properties
    properties (Access = public)
        % Position State
        CurrentPosition (1,1) double = 0
        MarkedPositions = struct('Labels', {{}}, 'Positions', [], 'Metrics', {{}})
        
        % Auto Step State
        IsAutoRunning (1,1) logical = false
        CurrentStep (1,1) double = 0
        TotalSteps (1,1) double = 0
        AutoDirection (1,1) double = 1  % 1 for up, -1 for down
        RecordMetrics (1,1) logical = false
        AutoStepMetrics = struct('Positions', [], 'Values', struct())
        
        % Metric State
        CurrentMetric (1,1) double = 0
        AllMetrics struct = struct()
        CurrentMetricType char = 'Focus Score'
        
        % ScanImage Integration
        SimulationMode (1,1) logical = true
        StatusMessage char = ''
    end
    
    %% Private Properties
    properties (Access = private)
        % ScanImage handles
        hSI                         % ScanImage handle
        motorFig                    % Motor Controls figure handle
        etZPos                      % Z position field
        Zstep                       % Z step field
        Zdec                        % Z decrease button
        Zinc                        % Z increase button
        
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
        function obj = ZStageController()
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
            % Check if ScanImage is running
            try
                % Check if hSI exists
                if ~evalin('base', 'exist(''hSI'', ''var'') && isobject(hSI)')
                    obj.setSimulationMode(true, obj.TEXT.NotRunning);
                    return;
                end
                
                % Get ScanImage handle
                obj.hSI = evalin('base', 'hSI');
                
                % Find motor controls window
                obj.motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                if isempty(obj.motorFig)
                    obj.setSimulationMode(true, obj.TEXT.WindowNotFound);
                    return;
                end
                
                % Find motor UI elements
                obj.etZPos = findall(obj.motorFig, 'Tag', 'etZPos');
                obj.Zstep = findall(obj.motorFig, 'Tag', 'Zstep');
                obj.Zdec = findall(obj.motorFig, 'Tag', 'Zdec');
                obj.Zinc = findall(obj.motorFig, 'Tag', 'Zinc');
                
                if any(cellfun(@isempty, {obj.etZPos, obj.Zstep, obj.Zdec, obj.Zinc}))
                    obj.setSimulationMode(true, obj.TEXT.MissingElements);
                    return;
                end
                
                % Successfully connected
                obj.setSimulationMode(false, obj.TEXT.Connected);
                
                % Initialize position
                obj.CurrentPosition = str2double(obj.etZPos.String);
                if isnan(obj.CurrentPosition)
                    obj.CurrentPosition = 0;
                end
                
                obj.notifyPositionChanged();
                
            catch ex
                obj.setSimulationMode(true, ['Error: ' ex.message]);
            end
        end
        
        function moveStage(obj, microns)
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
                
                % Read position
                pause(0.1);
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
        
        function setPosition(obj, position)
            if obj.SimulationMode
                obj.CurrentPosition = position;
            else
                % Calculate delta
                delta = position - obj.CurrentPosition;
                
                if abs(delta) > 0.01
                    obj.moveStage(delta);
                    return; % moveStage already calls notifyPositionChanged
                end
            end
            
            obj.notifyPositionChanged();
        end
        
        function resetPosition(obj)
            oldPosition = obj.CurrentPosition;
            obj.CurrentPosition = 0;
            obj.notifyPositionChanged();
            fprintf('Position reset to 0 μm (was %.1f μm)\n', oldPosition);
        end
        
        function refreshPosition(obj)
            if obj.shouldRefreshPosition()
                try
                    zPos = str2double(obj.etZPos.String);
                    if ~isnan(zPos) && zPos ~= obj.CurrentPosition
                        obj.CurrentPosition = zPos;
                        obj.notifyPositionChanged();
                    end
                catch
                    obj.handleConnectionLoss();
                end
            end
        end
        
        function updateMetric(obj)
            if obj.SimulationMode
                % Simulate metric values based on position
                for i = 1:length(obj.METRIC_TYPES)
                    metricType = obj.METRIC_TYPES{i};
                    % Convert to valid field name
                    fieldName = strrep(metricType, ' ', '_');
                    
                    % Generate different simulated metrics
                    switch metricType
                        case 'Mean'
                            obj.AllMetrics.(fieldName) = 100 - mod(abs(obj.CurrentPosition), 100);
                        case 'Median'
                            obj.AllMetrics.(fieldName) = 80 - mod(abs(obj.CurrentPosition), 80);
                        case 'Std Dev'
                            obj.AllMetrics.(fieldName) = 20 + mod(abs(obj.CurrentPosition), 30);
                        case 'Max'
                            obj.AllMetrics.(fieldName) = 200 - mod(abs(obj.CurrentPosition), 150);
                        case 'Focus Score'
                            obj.AllMetrics.(fieldName) = 50 - abs(mod(obj.CurrentPosition, 100) - 50);
                    end
                end
            else
                try
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
                        for i = 1:length(obj.METRIC_TYPES)
                            metricType = obj.METRIC_TYPES{i};
                            fieldName = strrep(metricType, ' ', '_');
                            obj.AllMetrics.(fieldName) = NaN;
                        end
                    end
                catch
                    % If error occurs, set all metrics to NaN
                    for i = 1:length(obj.METRIC_TYPES)
                        metricType = obj.METRIC_TYPES{i};
                        fieldName = strrep(metricType, ' ', '_');
                        obj.AllMetrics.(fieldName) = NaN;
                    end
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
            
            obj.AutoTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', delay, ...
                'TimerFcn', @(~,~) obj.executeAutoStep(stepSize));
            
            start(obj.AutoTimer);
            obj.notifyStatusChanged();
            
            fprintf('Auto-stepping started: %d steps of %.1f μm\n', numSteps, stepSize);
        end
        
        function stopAutoStepping(obj)
            try
                obj.stopTimer(obj.AutoTimer);
                obj.AutoTimer = [];
                obj.IsAutoRunning = false;
                obj.notifyStatusChanged();
                
                fprintf('Auto-stepping completed at position %.1f μm\n', obj.CurrentPosition);
                
                % Notify completion
                obj.notifyAutoStepComplete();
                
            catch e
                % Handle any errors
                fprintf('Error in stopAutoStepping: %s\n', e.message);
                obj.IsAutoRunning = false;
                obj.AutoTimer = [];
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
                obj.MarkedPositions.Positions(existingIdx) = [];
                obj.MarkedPositions.Metrics(existingIdx) = [];
            end
            
            % Add new bookmark with current metric
            obj.MarkedPositions.Labels{end+1} = label;
            obj.MarkedPositions.Positions(end+1) = obj.CurrentPosition;
            obj.MarkedPositions.Metrics{end+1} = struct(...
                'Type', obj.CurrentMetricType, ...
                'Value', obj.CurrentMetric);
            
            fprintf('Position marked: "%s" at %.1f μm (Metric: %.2f)\n', ...
                label, obj.CurrentPosition, obj.CurrentMetric);
        end
        
        function goToMarkedPosition(obj, index)
            if obj.isValidBookmarkIndex(index) && ~obj.IsAutoRunning
                position = obj.MarkedPositions.Positions(index);
                label = obj.MarkedPositions.Labels{index};
                
                obj.setPosition(position);
                fprintf('Moved to bookmark "%s": %.1f μm\n', label, position);
            end
        end
        
        function deleteMarkedPosition(obj, index)
            if obj.isValidBookmarkIndex(index)
                label = obj.MarkedPositions.Labels{index};
                obj.MarkedPositions.Labels(index) = [];
                obj.MarkedPositions.Positions(index) = [];
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
        
        function should = shouldRefreshPosition(obj)
            should = ~obj.SimulationMode && ...
                     ~obj.IsAutoRunning && ...
                     isvalid(obj.etZPos);
        end
        
        function handleConnectionLoss(obj)
            obj.SimulationMode = true;
            obj.setSimulationMode(true, obj.TEXT.LostConnection);
        end
        
        function executeAutoStep(obj, stepSize)
            try
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
            catch e
                % Handle any errors that might occur
                fprintf('Error in executeAutoStep: %s\n', e.message);
                obj.stopAutoStepping();
            end
        end
        
        function pixelData = getImageData(obj)
            pixelData = [];
            try
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
            catch
                pixelData = [];
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
                case 'Mean'
                    value = mean(pixelData(:));
                case 'Median'
                    value = median(pixelData(:));
                case 'Std Dev'
                    value = std(pixelData(:));
                case 'Max'
                    value = max(pixelData(:));
                case 'Focus Score'
                    % Calculate gradient-based focus score
                    [Gx, Gy] = gradient(pixelData);
                    value = mean(sqrt(Gx.^2 + Gy.^2), 'all');
                otherwise
                    value = mean(pixelData(:));
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
                obj.MarkedPositions.Positions(existingIdx) = [];
                obj.MarkedPositions.Metrics(existingIdx) = [];
            end
            
            % Add new bookmark
            obj.MarkedPositions.Labels{end+1} = label;
            obj.MarkedPositions.Positions(end+1) = obj.CurrentPosition;
            obj.MarkedPositions.Metrics{end+1} = struct(...
                'Type', metricType, ...
                'Value', value);
            
            % Log the bookmark creation
            fprintf('Created bookmark for maximum %s: %.1f at position %.1f μm\n', ...
                metricType, value, obj.CurrentPosition);
        end
        
        function valid = isValidBookmarkIndex(obj, index)
            valid = index >= 1 && index <= length(obj.MarkedPositions.Labels);
        end
        
        function stopTimer(obj, timer)
            if ~isempty(timer) && isvalid(timer)
                stop(timer);
                delete(timer);
            end
        end
        
        function cleanup(obj)
            % Stop auto-stepping
            if obj.IsAutoRunning
                obj.stopAutoStepping();
            end
            
            % Clean up any timers
            obj.stopTimer(obj.AutoTimer);
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
    end
end 