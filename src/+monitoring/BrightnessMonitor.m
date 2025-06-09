classdef BrightnessMonitor < handle
    % BrightnessMonitor - Handles brightness monitoring and data collection.

    properties (Access = public)
        activeChannel = 1 % Active channel for monitoring
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
        isMonitoring = false % Monitoring state flag
        
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
                % Verify data scope is available
                if isempty(obj.hSI.hScan2D) || isempty(obj.hSI.hScan2D.hDataScope)
                    error('Data scope not available. Make sure ScanImage is properly initialized.');
                end
                
                % Store original callback
                obj.originalCallback = obj.hSI.hScan2D.hDataScope.callback;
                
                % Set up new callback
                obj.hSI.hScan2D.hDataScope.callback = @obj.brightnessCallback;
                
                % Initialize data storage
                obj.initializeDataStorage();
                
                % Set display settings for monitoring
                obj.displaySettings.displayRollingAverageFactor = 1;
                
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
                % Verify data scope is available
                if ~isempty(obj.hSI.hScan2D) && ~isempty(obj.hSI.hScan2D.hDataScope)
                    % Restore original callback
                    obj.hSI.hScan2D.hDataScope.callback = obj.originalCallback;
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