classdef ZScanner < handle
    % ZScanner - Handles automated Z-scanning.

    properties (Access = private)
        controller      % Handle to the main controller
        
        % Z-scan properties
        isScanning      % Scanning state flag
        scanTimer       % Timer for scanning
        scanStepSize    % Step size for scanning
        scanRange       % Range for scanning
        scanDirection   % Direction of scanning
        scanStartZ      % Starting Z position
        scanEndZ        % Ending Z position
        scanCurrentZ    % Current Z position
        scanPauseTime   % Pause time between steps
        
        % Adaptive scan properties
        initialStepSize = 20  % Initial step size
        minStepSize = 1      % Minimum step size
        brightnessThreshold = 0.1  % Brightness change threshold
        lastBrightness = 0   % Last measured brightness
        consecutiveDecreases = 0  % Consecutive brightness decreases
        maxConsecutiveDecreases = 3  % Maximum consecutive decreases
    end

    methods
        function obj = ZScanner(controller)
            obj.controller = controller;
            obj.isScanning = false;
            obj.scanStepSize = 5;
            obj.scanPauseTime = 0.5;
        end

        function start(obj, stepSize, pauseTime)
            % Start Z-scanning
            try
                % Set scan parameters
                obj.setScanParameters(stepSize, pauseTime);
                % Start scanning if not already scanning
                if ~obj.isScanning
                    obj.initializeScan();
                end
            catch ME
                error('Failed to start Z-scan: %s', ME.message);
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
                    obj.scanCurrentZ = obj.scanCurrentZ + obj.scanStepSize * obj.scanDirection;
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
                        obj.scanCurrentZ, obj.scanStepSize));
                catch ME
                    warning('Error in scan step: %s', ME.message);
                    obj.stop();
                end
            end
        end
    end

    methods (Access = private)
        function setScanParameters(obj, stepSize, pauseTime)
            % Set scan parameters
            obj.scanStepSize = stepSize;
            obj.initialStepSize = stepSize;
            obj.scanPauseTime = pauseTime;
        end
        
        function initializeScan(obj)
            % Initialize and start scanning between Z limits
            currentZ = obj.controller.getZ();
            % Get Z limits from motor controls
            minZ = obj.controller.getZLimit('min');
            maxZ = obj.controller.getZLimit('max');
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
            pause(obj.scanPauseTime);
            % Start the scan timer
            obj.isScanning = true;
            obj.scanTimer = timer('Period', obj.scanPauseTime, ...
                'ExecutionMode', 'fixedRate', ...
                'TimerFcn', @(~,~) obj.scanStep());
            start(obj.scanTimer);
            obj.controller.updateStatus(sprintf('Scanning from Z=%.2f to Z=%.2f', obj.scanStartZ, obj.scanEndZ));
        end
    end
end 