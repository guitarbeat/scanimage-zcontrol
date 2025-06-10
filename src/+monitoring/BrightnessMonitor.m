classdef BrightnessMonitor < handle
    % BrightnessMonitor - Handles brightness monitoring and data collection.

    properties (Access = public)
        activeChannel = 1 % Active channel for monitoring
        isMonitoring = false % Monitoring state flag
        selectedMetric = 1 % Currently selected metric
    end

    properties (Access = private)
        controller      % Handle to the main controller
        hSI             % Main ScanImage handle
        
        % Brightness monitoring properties
        monitorData     % Structure with brightness data fields
        currentIndex    % Current data index
        startTime       % Start time for monitoring
        
        % Monitoring state
        originalCallback % Original data scope callback
        monitorTimer    % Timer for monitoring when callbacks aren't available
        
        % Display properties
        rollingAverageFactor = 1 % Rolling average factor for display
        displaySettings  % Display settings handle
        
        % Metrics management
        metrics         % Structure with metric configurations
        
        % Simulation mode
        simulationMode = false % Flag for simulation mode
    end

    methods
        function obj = BrightnessMonitor(controller, hSI)
            obj.controller = controller;
            obj.hSI = hSI;
            
            % Check if we're in simulation mode
            try
                obj.simulationMode = evalin('base', 'exist(''SIM_MODE'', ''var'') && SIM_MODE == true');
            catch
                obj.simulationMode = false;
            end
            
            % Handle display settings gracefully
            try
                if isfield(obj.hSI, 'hDisplay') && ~isempty(obj.hSI.hDisplay)
                    obj.displaySettings = obj.hSI.hDisplay;
                    if isfield(obj.displaySettings, 'displayRollingAverageFactor')
                        obj.rollingAverageFactor = obj.displaySettings.displayRollingAverageFactor;
                    else
                        obj.rollingAverageFactor = 1;
                    end
                else
                    % Create empty display settings if not available
                    obj.displaySettings = struct('displayRollingAverageFactor', 1);
                    obj.rollingAverageFactor = 1;
                end
            catch
                % Create empty display settings if not available
                obj.displaySettings = struct('displayRollingAverageFactor', 1);
                obj.rollingAverageFactor = 1;
            end
            
            % Initialize metrics first so we can set the default metric
            obj.initializeMetrics();
            
            % Initialize selectedMetric from parameters or default to Mean (index 7)
            obj.selectedMetric = obj.getParameter('defaultMetric', obj.metrics.defaultIndex);
            
            % Initialize data storage
            obj.initializeDataStorage();
        end

        function start(obj)
            % Start brightness monitoring
            if obj.isMonitoring
                return;
            end
            
            try
                % Reset data storage
                obj.initializeDataStorage();
                
                % Set display settings for monitoring (if available)
                try
                    obj.displaySettings.displayRollingAverageFactor = 1;
                catch
                    % Ignore errors in setting display properties
                end
                
                % Create a timer instead of trying to hook into ScanImage callbacks
                % This is more reliable across different ScanImage versions
                obj.createMonitoringTimer();
                
                obj.isMonitoring = true;
                obj.controller.updateStatus('Monitoring started');
                
            catch ME
                obj.handleError(ME, 'start monitoring');
            end
        end

        function stop(obj)
            % Stop brightness monitoring
            if ~obj.isMonitoring
                return;
            end
            
            try
                % Stop any timer
                obj.stopMonitoringTimer();
                
                % Restore display settings if possible
                try
                    obj.displaySettings.displayRollingAverageFactor = obj.rollingAverageFactor;
                catch
                    % Ignore errors when restoring display settings
                end
                
                obj.isMonitoring = false;
                obj.controller.updateStatus('Monitoring stopped');
                
            catch ME
                obj.handleError(ME, 'stop monitoring');
            end
        end

        function brightnessCallback(obj, ~, ~)
            % Callback function for brightness monitoring
            try
                % Get current frame data safely
                frameData = [];
                try
                    if isfield(obj.hSI, 'hDisplay') && ~isempty(obj.hSI.hDisplay) && ...
                       isfield(obj.hSI.hDisplay, 'lastAveragedFrame') && ~isempty(obj.hSI.hDisplay.lastAveragedFrame)
                        frameData = obj.hSI.hDisplay.lastAveragedFrame;
                    elseif obj.simulationMode
                        % Generate random data in simulation mode
                        frameData = rand(512);
                    end
                catch
                    % If we can't get frame data, generate random data
                    if obj.simulationMode
                        frameData = rand(512);
                    end
                end
                
                if isempty(frameData)
                    return;
                end
                
                % Calculate and store metrics
                obj.calculateMetrics(frameData);
                
                % Update plot
                obj.updatePlot();
            catch ME
                obj.handleError(ME, 'brightness callback', false);
            end
        end

        function [brightness, currentZ] = getCurrentBrightness(obj)
            % Get the current brightness and Z position
            try
                % Get current frame data
                frameData = [];
                try
                    if isfield(obj.hSI, 'hDisplay') && ~isempty(obj.hSI.hDisplay) && ...
                       isfield(obj.hSI.hDisplay, 'lastAveragedFrame') && ~isempty(obj.hSI.hDisplay.lastAveragedFrame)
                        frameData = obj.hSI.hDisplay.lastAveragedFrame;
                    elseif obj.simulationMode
                        % Generate random data in simulation mode
                        frameData = rand(512);
                    end
                catch
                    % If we can't get frame data, generate random data
                    if obj.simulationMode
                        frameData = rand(512);
                    end
                end
                
                if isempty(frameData)
                    brightness = NaN;
                    currentZ = NaN;
                    return;
                end
                
                % Get current Z position
                currentZ = obj.controller.getZ();
                
                % Calculate brightness using selected metric
                metricIndex = obj.getSelectedMetricIndex();
                brightness = obj.metrics.functions{metricIndex}(frameData);
                
            catch ME
                obj.handleError(ME, 'get current brightness', false);
                brightness = NaN;
                currentZ = NaN;
            end
        end

        function [bData, zData] = getScanData(obj)
            % Get valid scan data (non-zero values)
            validIdx = obj.monitorData.brightness ~= 0;
            bData = obj.monitorData.brightness(validIdx);
            zData = obj.monitorData.zPosition(validIdx);
        end

        function [maxBrightness, maxZ] = getMaxBrightness(obj)
            % Get maximum brightness and corresponding Z position
            if obj.currentIndex > 1
                [b, z] = obj.getScanData();
                [maxBrightness, maxIdx] = max(b);
                maxZ = z(maxIdx);
            else
                maxBrightness = nan;
                maxZ = nan;
            end
        end
        
        function [avgBrightness, stdBrightness] = getAverageBrightness(obj, zPosition, timeWindow)
            % Get average brightness for a specific Z position within a time window
            try
                % Default time window
                if nargin < 3
                    timeWindow = obj.getParameter('averageTimeWindow', 5); % Default 5 second window
                end
                
                % Find data points within time window and at specified Z position
                currentTime = toc(obj.startTime);
                validIndices = obj.monitorData.time > (currentTime - timeWindow) & ...
                              abs(obj.monitorData.zPosition - zPosition) < 1; % Within 1 unit of Z position
                
                if any(validIndices)
                    avgBrightness = mean(obj.monitorData.brightness(validIndices));
                    stdBrightness = std(obj.monitorData.brightness(validIndices));
                else
                    avgBrightness = NaN;
                    stdBrightness = NaN;
                end
            catch ME
                obj.handleError(ME, 'get average brightness');
                avgBrightness = NaN;
                stdBrightness = NaN;
            end
        end

        function moveToMaxBrightness(obj)
            % Move to the Z position with maximum brightness
            try
                [maxBrightness, maxZ] = obj.getMaxBrightness();
                if ~isnan(maxZ)
                    obj.controller.updateStatus(sprintf('Moving to Z=%.2f (brightness=%.2f)', maxZ, maxBrightness));
                    obj.controller.absoluteMove(maxZ);
                else
                    obj.controller.updateStatus('No brightness data available yet.');
                end
            catch ME
                obj.handleError(ME, 'move to maximum brightness');
            end
        end

        function toggleMonitor(obj, state)
            % Toggle monitoring state
            if state
                obj.start();
            else
                obj.stop();
            end
        end

        function updatePlot(obj)
            % Update the plot in the GUI with the latest data
            if obj.isGuiValid()
                % Get scan data
                [bData, zData] = obj.getScanData();
                % Update plot through the GUI
                obj.controller.gui.updatePlot(zData, bData, obj.activeChannel);
            end
        end
        
        function metricIndex = getSelectedMetricIndex(obj)
            % Get the selected metric index from the GUI or property
            metricIndex = obj.selectedMetric;
            
            if obj.isGuiValid() && isfield(obj.controller.gui, 'hMetricDropDown')
                try
                    metricIndex = obj.controller.gui.hMetricDropDown.Value;
                catch
                    % Use default on error
                end
            end
            
            % Return the index value
            return;
        end
        
        function metric = getBrightnessMetric(obj)
            % Get the metric name for the selected index in the format expected by the UI
            metricIndex = obj.getSelectedMetricIndex();
            
            % Map internal metric index to UI metric name - Mean, Median, Max, 95th Percentile
            % Default to Mean if the index is invalid
            if metricIndex == 7
                metric = 'Mean';
            elseif metricIndex == 8
                metric = 'Median';
            elseif metricIndex == 9
                metric = 'Max';
            elseif metricIndex == 10
                metric = '95th Percentile';
            else
                % Default to Mean for other internal metrics
                metric = 'Mean';
            end
        end

        function calculateMetrics(obj, frameData)
            % Calculate metrics for the current frame
            if isempty(frameData)
                return;
            end
            
            % Get current Z position
            currentZ = obj.controller.getZ();
            
            % Calculate all metrics
            metricValues = zeros(1, length(obj.metrics.functions));
            for i = 1:length(obj.metrics.functions)
                metricValues(i) = obj.metrics.functions{i}(frameData);
            end
            
            % Store metric data
            obj.metrics.data(end+1, :) = metricValues;
            obj.metrics.zData(end+1) = currentZ;
            
            % Keep arrays at reasonable size
            maxPoints = obj.getParameter('maxPoints', 1000);
            if length(obj.metrics.zData) > maxPoints
                obj.metrics.data = obj.metrics.data(end-maxPoints+1:end, :);
                obj.metrics.zData = obj.metrics.zData(end-maxPoints+1:end);
            end
            
            % Store the selected metric
            metricIndex = obj.getSelectedMetricIndex();
            if metricIndex <= size(metricValues, 2)
                obj.storeDataPoint(metricValues(metricIndex), currentZ);
            end
        end
    end

    methods (Access = private)
        function handleError(obj, ME, operation, throwError)
            % Standardized error handling
            if nargin < 4
                throwError = true;
            end
            
            % Format error message
            errorMsg = sprintf('Error during %s: %s', operation, ME.message);
            
            % Get verbosity setting from controller
            verbosity = 0;
            try
                verbosity = obj.controller.verbosity;
            catch
                % Default to basic verbosity if not available
                verbosity = 1;
            end
            
            if verbosity > 0
                warning(errorMsg);
            end
            
            % Update status if controller is available
            obj.controller.updateStatus(errorMsg);
            
            if verbosity > 1
                disp(getReport(ME));
            end
            
            % Re-throw error if required
            if throwError
                error('BrightnessMonitor:%s', operation, errorMsg);
            end
        end
        
        function val = getParameter(obj, name, defaultValue)
            % Get parameter value from controller.params or use default
            val = defaultValue;
            
            try
                % Try to get from controller's parameter object
                if isfield(obj.controller, 'params') && ...
                   ~isempty(obj.controller.params) && ...
                   isprop(obj.controller.params, name)
                    val = obj.controller.params.(name);
                end
            catch
                % Use default on error
            end
        end
        
        function valid = isGuiValid(obj)
            % Helper function to check if GUI is valid
            try
                valid = isfield(obj.controller, 'gui') && ...
                       ~isempty(obj.controller.gui) && ...
                       isvalid(obj.controller.gui);
            catch
                valid = false;
            end
        end

        function initializeDataStorage(obj)
            % Initialize data storage arrays with structure for better organization
            maxPoints = obj.getParameter('maxPoints', 1000);
            
            obj.monitorData = struct(...
                'brightness', zeros(1, maxPoints), ...
                'zPosition', zeros(1, maxPoints), ...
                'time', zeros(1, maxPoints));
                
            obj.currentIndex = 1;
            obj.startTime = tic;
        end
        
        function initializeMetrics(obj)
            % Initialize metrics structure with consistent naming and functions
            obj.metrics = struct(...
                'names', {{'Variance', 'StdDev', 'Sobel', 'Tenengrad', 'Laplacian', 'Entropy', 'Mean', 'Median', 'Max', '95th Percentile'}}, ...
                'uiNames', {{'Mean', 'Median', 'Max', '95th Percentile'}}, ... % Names used in the UI dropdown
                'functions', {{...
                    @(x) var(double(x(:))), ...
                    @(x) std(double(x(:))), ...
                    @(x) sum(sum(edge(x, 'sobel'))), ...
                    @(x) sum(sum(sqrt(imgradientxy(double(x))))), ...
                    @(x) sum(sum(abs(imgaussfilt(double(x), 2) - double(x)))), ...
                    @(x) entropy(x), ...
                    @(x) mean(double(x(:))), ...
                    @(x) median(double(x(:))), ...
                    @(x) max(double(x(:))), ...
                    @(x) prctile(double(x(:)), 95)...
                }}, ...
                'data', zeros(0, 10), ...  % Empty array to store all metric values
                'zData', zeros(0, 1), ...  % Empty array to store Z positions
                'defaultIndex', 7 ...      % Default to Mean (index 7)
            );
        end

        function stopMonitoringTimer(obj)
            % Stop monitoring timer safely
            if isfield(obj, 'monitorTimer') && ~isempty(obj.monitorTimer)
                try
                    if isvalid(obj.monitorTimer)
                        stop(obj.monitorTimer);
                        delete(obj.monitorTimer);
                    end
                catch
                    % Ignore errors when stopping timer
                end
                obj.monitorTimer = [];
            end
        end

        function createMonitoringTimer(obj)
            % Create a timer for monitoring when direct callbacks aren't available
            obj.stopMonitoringTimer();
            
            % Use parameter for timer period
            timerPeriod = obj.getParameter('monitoringTimerPeriod', 0.25);
            
            % Create a timer that calls brightnessCallback
            obj.monitorTimer = timer('ExecutionMode', 'fixedRate', ...
                                    'Period', timerPeriod, ...
                                    'TimerFcn', @(~,~) obj.brightnessCallback([], []), ...
                                    'ErrorFcn', @(~,~) obj.handleError(MException('Timer:Error', 'Monitoring timer error'), 'timer execution', false));
            start(obj.monitorTimer);
        end

        function storeDataPoint(obj, brightness, currentZ)
            % Store brightness and position data in the monitoring data structure
            maxPoints = obj.getParameter('maxPoints', 1000);
            
            % Store data
            obj.monitorData.brightness(obj.currentIndex) = brightness;
            obj.monitorData.zPosition(obj.currentIndex) = currentZ;
            obj.monitorData.time(obj.currentIndex) = toc(obj.startTime);
            
            % Increment index with wraparound
            obj.currentIndex = mod(obj.currentIndex, maxPoints) + 1;
        end
    end
end 