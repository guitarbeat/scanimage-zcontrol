classdef BrightnessMonitor < handle
    % BrightnessMonitor - Handles brightness monitoring and data collection.

    properties (Access = public)
        activeChannel = 1 % Active channel for monitoring
        isMonitoring = false % Monitoring state flag
    end

    properties (Access = private)
        controller      % Handle to the main controller
        hSI             % Main ScanImage handle
        
        % Brightness monitoring properties
        brightnessData  % Brightness measurement data
        zPositionData   % Z position data
        timeData        % Time data
        currentIndex    % Current data index
        startTime       % Start time for monitoring
        maxPoints = 1000 % Maximum number of data points
        
        % Monitoring state
        originalCallback % Original data scope callback
        monitorTimer    % Timer for monitoring when callbacks aren't available
        
        % Display properties
        rollingAverageFactor = 1 % Rolling average factor for display
        displaySettings  % Display settings handle
    end

    methods
        function obj = BrightnessMonitor(controller, hSI)
            obj.controller = controller;
            obj.hSI = hSI;
            obj.displaySettings = obj.hSI.hDisplay;
            obj.rollingAverageFactor = obj.displaySettings.displayRollingAverageFactor;
        end

        function start(obj)
            % Start brightness monitoring
            if obj.isMonitoring
                return;
            end
            
            try
                % Initialize data storage
                obj.initializeDataStorage();
                
                % Set display settings for monitoring
                obj.displaySettings.displayRollingAverageFactor = 1;
                
                % Try different methods to set up frame monitoring based on ScanImage version
                if ~isempty(obj.hSI.hScan2D) && ~isempty(obj.hSI.hScan2D.hDataScope)
                    try
                        % First try the standard callback method
                        if isprop(obj.hSI.hScan2D.hDataScope, 'callback')
                            % Store original callback
                            obj.originalCallback = obj.hSI.hScan2D.hDataScope.callback;
                            % Set up new callback
                            obj.hSI.hScan2D.hDataScope.callback = @obj.brightnessCallback;
                        % Then try other known methods in different ScanImage versions
                        elseif isprop(obj.hSI.hScan2D.hDataScope, 'functionHandle')
                            obj.originalCallback = obj.hSI.hScan2D.hDataScope.functionHandle;
                            obj.hSI.hScan2D.hDataScope.functionHandle = @obj.brightnessCallback;
                        elseif isprop(obj.hSI.hScan2D, 'frameAcquiredFcn')
                            obj.originalCallback = obj.hSI.hScan2D.frameAcquiredFcn;
                            obj.hSI.hScan2D.frameAcquiredFcn = @obj.brightnessCallback;
                        else
                            % Create a timer as fallback if we can't hook into ScanImage directly
                            obj.createMonitoringTimer();
                        end
                    catch
                        % Fallback to timer-based monitoring
                        obj.createMonitoringTimer();
                    end
                else
                    % Fallback to timer-based monitoring
                    obj.createMonitoringTimer();
                end
                
                obj.isMonitoring = true;
                obj.controller.updateStatus('Monitoring started');
                
            catch ME
                error('Failed to start monitoring: %s', ME.message);
            end
        end

        function stop(obj)
            % Stop brightness monitoring
            if ~obj.isMonitoring
                return;
            end
            
            try
                % Check how we're monitoring and clean up appropriately
                if ~isempty(obj.hSI.hScan2D) && ~isempty(obj.hSI.hScan2D.hDataScope)
                    try
                        % Try to restore original callback using various methods
                        if isprop(obj.hSI.hScan2D.hDataScope, 'callback')
                            obj.hSI.hScan2D.hDataScope.callback = obj.originalCallback;
                        elseif isprop(obj.hSI.hScan2D.hDataScope, 'functionHandle')
                            obj.hSI.hScan2D.hDataScope.functionHandle = obj.originalCallback;
                        elseif isprop(obj.hSI.hScan2D, 'frameAcquiredFcn')
                            obj.hSI.hScan2D.frameAcquiredFcn = obj.originalCallback;
                        end
                    catch
                        % Ignore errors when trying to restore callbacks
                    end
                end
                
                % Stop any timer
                if isfield(obj, 'monitorTimer') && ~isempty(obj.monitorTimer) && isvalid(obj.monitorTimer)
                    stop(obj.monitorTimer);
                    delete(obj.monitorTimer);
                end
                
                % Restore display settings
                obj.displaySettings.displayRollingAverageFactor = obj.rollingAverageFactor;
                
                obj.isMonitoring = false;
                obj.controller.updateStatus('Monitoring stopped');
                
            catch ME
                error('Failed to stop monitoring: %s', ME.message);
            end
        end

        function brightnessCallback(obj, ~, ~)
            % Callback function for brightness monitoring
            try
                % Get current frame data
                frameData = obj.hSI.hDisplay.lastAveragedFrame;
                if isempty(frameData)
                    return;
                end
                % Get current Z position
                currentZ = obj.controller.getZ();
                % Calculate brightness using selected metric
                metric = obj.controller.getBrightnessMetric();
                switch metric
                    case 'Mean'
                        brightness = mean(frameData(:));
                    case 'Median'
                        brightness = median(frameData(:));
                    case 'Max'
                        brightness = max(frameData(:));
                    case '95th Percentile'
                        brightness = prctile(frameData(:), 95);
                    otherwise
                        brightness = mean(frameData(:));
                end
                % Store data
                obj.storeBrightnessData(brightness, currentZ);
                % Update plot
                obj.controller.updatePlot();
            catch ME
                warning('Error in brightness callback: %s', ME.message);
            end
        end

        function [brightness, currentZ] = getCurrentBrightness(obj)
            % Get the current brightness and Z position
            try
                % Get current frame data
                frameData = obj.hSI.hDisplay.lastAveragedFrame;
                if isempty(frameData)
                    brightness = NaN;
                    currentZ = NaN;
                    return;
                end
                
                % Get current Z position
                currentZ = obj.controller.getZ();
                
                % Calculate brightness using selected metric
                metric = obj.controller.getBrightnessMetric();
                switch metric
                    case 'Mean'
                        brightness = mean(frameData(:));
                    case 'Median'
                        brightness = median(frameData(:));
                    case 'Max'
                        brightness = max(frameData(:));
                    case '95th Percentile'
                        brightness = prctile(frameData(:), 95);
                    otherwise
                        brightness = mean(frameData(:));
                end
            catch ME
                warning('Error getting current brightness: %s', ME.message);
                brightness = NaN;
                currentZ = NaN;
            end
        end

        function [bData, zData] = getScanData(obj)
             validIdx = obj.brightnessData ~= 0;
             bData = obj.brightnessData(validIdx);
             zData = obj.zPositionData(validIdx);
        end

        function [maxBrightness, maxZ] = getMaxBrightness(obj)
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
            if nargin < 3
                timeWindow = 5; % Default 5 second window
            end
            
            try
                % Find data points within time window and at specified Z position
                currentTime = toc(obj.startTime);
                validIndices = obj.timeData > (currentTime - timeWindow) & ...
                              abs(obj.zPositionData - zPosition) < 1; % Within 1 unit of Z position
                
                if any(validIndices)
                    avgBrightness = mean(obj.brightnessData(validIndices));
                    stdBrightness = std(obj.brightnessData(validIndices));
                else
                    avgBrightness = NaN;
                    stdBrightness = NaN;
                end
            catch ME
                error('Failed to get average brightness: %s', ME.message);
            end
        end
    end

    methods (Access = private)
        function initializeDataStorage(obj)
            % Initialize data storage arrays
            obj.brightnessData = zeros(1, obj.maxPoints);
            obj.zPositionData = zeros(1, obj.maxPoints);
            obj.timeData = zeros(1, obj.maxPoints);
            obj.currentIndex = 1;
            obj.startTime = tic;
        end

        function createMonitoringTimer(obj)
            % Create a timer for monitoring when direct callbacks aren't available
            if isfield(obj, 'monitorTimer') && ~isempty(obj.monitorTimer) && isvalid(obj.monitorTimer)
                stop(obj.monitorTimer);
                delete(obj.monitorTimer);
            end
            
            % Create a timer that calls brightnessCallback every 0.25 seconds
            obj.monitorTimer = timer('ExecutionMode', 'fixedRate', ...
                                    'Period', 0.25, ...
                                    'TimerFcn', @(~,~) obj.brightnessCallback([], []), ...
                                    'ErrorFcn', @(~,~) warning('Error in monitoring timer'));
            start(obj.monitorTimer);
        end

        function storeBrightnessData(obj, brightness, currentZ)
            % Store brightness and position data
            obj.brightnessData(obj.currentIndex) = brightness;
            obj.zPositionData(obj.currentIndex) = currentZ;
            obj.timeData(obj.currentIndex) = toc(obj.startTime);
            
            % Increment index
            obj.currentIndex = mod(obj.currentIndex, obj.maxPoints) + 1;
        end
    end
end 