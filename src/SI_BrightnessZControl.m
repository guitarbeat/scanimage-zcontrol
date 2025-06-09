classdef SI_BrightnessZControl < SI_MotorGUI_ZControl
    % SI_BrightnessZControl - Monitor brightness and control Z position
    %
    % This class extends SI_MotorGUI_ZControl to add brightness monitoring
    % and automated Z-scanning capabilities. It provides a GUI interface
    % for controlling Z position based on image brightness.
    %
    % Usage:
    %   control = SI_BrightnessZControl();
    %   control.startMonitoring();    % Start brightness monitoring
    %   control.startZScan();         % Start automated Z scanning
    %   control.stopZScan();          % Stop automated Z scanning
    %   control.moveToMaxBrightness(); % Move to position of maximum brightness
    %
    % Author: Manus AI (2025)
    
    properties (Access = private)
        % ScanImage handles
        hSI              % Main ScanImage handle
        hCSFocus         % Focus coordinate system handle
        hCSSample        % Sample coordinate system handle
        channelSettings  % Channel settings handle
        displaySettings  % Display settings handle
        
        % Brightness monitoring properties
        hFig            % Main figure handle
        hAx             % Plot axes handle
        brightnessData  % Brightness measurement data
        zPositionData   % Z position data
        timeData        % Time data
        currentIndex    % Current data index
        startTime       % Start time for monitoring
        maxPoints = 1000 % Maximum number of data points
        
        % Monitoring state
        originalCallback % Original data scope callback
        isMonitoring = false % Monitoring state flag
        
        % Channel properties
        activeChannel = 1 % Active channel for monitoring
        
        % Display properties
        rollingAverageFactor = 1 % Rolling average factor for display
        
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
        
        % GUI elements
        hStatusText     % Status text label
        hStepSizeEdit   % Step size edit field
        hRangeEdit      % Range edit field
        hPauseTimeEdit  % Pause time edit field
        hStepSizeSlider % Step size slider
        hStepSizeValue  % Step size value label
        hMonitorToggle  % Monitor toggle button
        hZScanToggle    % Z-scan toggle button
        hTestDropDown   % Test function dropdown
        hZAboveEdit     % Z Above Focus edit field
        hZBelowEdit     % Z Below Focus edit field
        hMinZEdit       % Min Z edit field
        hMaxZEdit       % Max Z edit field
        hMetricDropDown % Metric dropdown
    end
    
    methods
        function obj = SI_BrightnessZControl()
            % Constructor - Initialize the brightness Z-control system
            
            % Initialize base class
            obj@SI_MotorGUI_ZControl();
            
            try
                % Get ScanImage handle
                obj.hSI = evalin('base', 'hSI');
                
                % Initialize components
                obj.initializeComponents();
                
                % Create the monitoring figure
                obj.createFigure();
                
            catch ME
                error('Failed to initialize brightness Z-control: %s', ME.message);
            end
        end
        
        function initializeComponents(obj)
            % Initialize all system components
            obj.initializeCoordinateSystems();
            obj.initializeChannelSettings();
            obj.initializeDisplaySettings();
            obj.initializeZScanProperties();
        end
        
        function initializeCoordinateSystems(obj)
            % Initialize coordinate system handles
            try
                obj.hCSFocus = obj.hSI.hCoordinateSystems.hCSFocus;
                obj.hCSSample = obj.hSI.hCoordinateSystems.hCSSampleRelative;
                
                if isempty(obj.hCSFocus) || isempty(obj.hCSSample)
                    warning('Coordinate systems not fully initialized');
                end
            catch ME
                error('Failed to initialize coordinate systems: %s', ME.message);
            end
        end
        
        function initializeChannelSettings(obj)
            % Initialize channel settings
            try
                obj.channelSettings = obj.hSI.hChannels;
                
                if ~ismember(obj.activeChannel, obj.channelSettings.channelsActive)
                    warning('Channel %d is not active', obj.activeChannel);
                    obj.activeChannel = obj.channelSettings.channelsActive(1);
                end
            catch ME
                error('Failed to initialize channel settings: %s', ME.message);
            end
        end
        
        function initializeDisplaySettings(obj)
            % Initialize display settings
            try
                obj.displaySettings = obj.hSI.hDisplay;
                obj.rollingAverageFactor = obj.displaySettings.displayRollingAverageFactor;
            catch ME
                error('Failed to initialize display settings: %s', ME.message);
            end
        end
        
        function initializeZScanProperties(obj)
            % Initialize Z-scan properties
            obj.isScanning = false;
            obj.scanStepSize = 5;  % Default step size
            obj.scanPauseTime = 0.5;  % Default pause between steps
        end
        
        function startMonitoring(obj)
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
                obj.updateStatus('Monitoring started');
                
            catch ME
                error('Failed to start monitoring: %s', ME.message);
            end
        end
        
        function initializeDataStorage(obj)
            % Initialize data storage arrays
            obj.brightnessData = zeros(1, obj.maxPoints);
            obj.zPositionData = zeros(1, obj.maxPoints);
            obj.timeData = zeros(1, obj.maxPoints);
            obj.currentIndex = 1;
            obj.startTime = tic;
        end
        
        function stopMonitoring(obj)
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
                obj.updateStatus('Monitoring stopped');
                
            catch ME
                error('Failed to stop monitoring: %s', ME.message);
            end
        end
        
        function startZScan(obj)
            % Start Z-scanning
            try
                % Get and validate parameters
                [stepSize, pauseTime] = obj.getScanParameters();
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
        
        function [stepSize, pauseTime] = getScanParameters(obj)
            % Get and validate scan parameters from GUI
            stepSize = str2double(obj.hStepSizeValue.Text);
            pauseTime = str2double(obj.hPauseTimeEdit.Value);
            if isnan(stepSize) || isnan(pauseTime)
                error('Invalid parameters. Please check input values.');
            end
        end
        
        function setScanParameters(obj, stepSize, pauseTime)
            % Set scan parameters (now ignores zAbove/zBelow, uses Z limits)
            obj.scanStepSize = stepSize;
            obj.initialStepSize = stepSize;
            obj.scanPauseTime = pauseTime;
        end
        
        function initializeScan(obj)
            % Initialize and start scanning between Z limits
            currentZ = obj.getZ();
            % Get Z limits from motor controls
            minZ = obj.getZLimit('min');
            maxZ = obj.getZLimit('max');
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
            obj.absoluteMove(obj.scanStartZ);
            pause(obj.scanPauseTime);
            % Start the scan timer
            obj.isScanning = true;
            obj.scanTimer = timer('Period', obj.scanPauseTime, ...
                'ExecutionMode', 'fixedRate', ...
                'TimerFcn', @(~,~) obj.scanStep());
            start(obj.scanTimer);
            obj.updateStatus(sprintf('Scanning from Z=%.2f to Z=%.2f', obj.scanStartZ, obj.scanEndZ));
        end
        
        function val = getZLimit(obj, which)
            % Get Z min or max limit from motor controls
            if strcmpi(which, 'min')
                % Assume min limit is the value set when pbMinLim was pressed
                % (You may need to store this in your class if not available from GUI)
                val = str2double(get(obj.findByTag('pbMinLim'), 'UserData'));
                if isnan(val)
                    val = -Inf;
                end
            else
                % Assume max limit is the value set when pbMaxLim was pressed
                val = str2double(get(obj.findByTag('pbMaxLim'), 'UserData'));
                if isnan(val)
                    val = Inf;
                end
            end
        end
        
        function stopZScan(obj)
            % Stop Z-scanning
            if obj.isScanning
                stop(obj.scanTimer);
                delete(obj.scanTimer);
                obj.isScanning = false;
                obj.updateStatus('Scan stopped. Ready to move to max brightness.');
            end
        end
        
        function moveToMaxBrightness(obj)
            % Move to the Z position with maximum brightness
            try
                if obj.currentIndex > 1
                    [maxBrightness, maxIdx] = max(obj.brightnessData(1:obj.currentIndex-1));
                    maxZ = obj.zPositionData(maxIdx);
                    
                    obj.updateStatus(sprintf('Moving to Z=%d (brightness=%.2f)', maxZ, maxBrightness));
                    obj.absoluteMove(maxZ);
                else
                    obj.updateStatus('No brightness data available yet.');
                end
            catch ME
                error('Failed to move to maximum brightness: %s', ME.message);
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
        
        function brightnessCallback(obj, ~, ~)
            % Callback function for brightness monitoring
            try
                % Get current frame data
                frameData = obj.hSI.hDisplay.lastAveragedFrame;
                if isempty(frameData)
                    return;
                end
                % Get current Z position
                currentZ = obj.getZ();
                % Calculate brightness using selected metric
                metric = obj.hMetricDropDown.Value;
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
                obj.updatePlot();
            catch ME
                warning('Error in brightness callback: %s', ME.message);
            end
        end
        
        function storeBrightnessData(obj, brightness, currentZ)
            % Store brightness and position data
            obj.brightnessData(obj.currentIndex) = brightness;
            obj.zPositionData(obj.currentIndex) = currentZ;
            obj.timeData(obj.currentIndex) = toc(obj.startTime);
            
            % Increment index
            obj.currentIndex = mod(obj.currentIndex, obj.maxPoints) + 1;
        end
        
        function updatePlot(obj)
            % Update the brightness vs Z-position plot with visual markers
            try
                % Get valid data indices
                validIdx = obj.brightnessData ~= 0;
                zData = obj.zPositionData(validIdx);
                bData = obj.brightnessData(validIdx);
                
                % Clear axes
                cla(obj.hAx);
                hold(obj.hAx, 'on');
                
                % Plot scan trace
                plot(obj.hAx, zData, bData, 'b.-', 'DisplayName', 'Scan Trace');
                
                % Mark scan start and end positions
                if ~isempty(zData)
                    % Start marker
                    plot(obj.hAx, zData(1), bData(1), 'go', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Scan Start');
                    % End marker
                    plot(obj.hAx, zData(end), bData(end), 'mo', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Scan End');
                end
                
                % Mark brightest point
                if ~isempty(bData)
                    [maxB, maxIdx] = max(bData);
                    maxZ = zData(maxIdx);
                    plot(obj.hAx, maxZ, maxB, 'rp', 'MarkerSize', 14, 'LineWidth', 2, 'DisplayName', 'Brightest Point');
                    text(obj.hAx, maxZ, maxB, sprintf('  Max: %.2f', maxB), 'Color', 'red', 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
                end
                
                % Labels and legend
                title(obj.hAx, sprintf('Brightness vs Z-Position (Channel %d)', obj.activeChannel), 'FontWeight', 'bold');
                xlabel(obj.hAx, 'Z Position (µm)');
                ylabel(obj.hAx, 'Brightness (a.u.)');
                grid(obj.hAx, 'on');
                legend(obj.hAx, 'show', 'Location', 'best');
                hold(obj.hAx, 'off');
                drawnow;
            catch ME
                warning('Error updating plot: %s', ME.message);
            end
        end
        
        function createFigure(obj)
            % Create main figure with compact, grid-based layout
            obj.hFig = uifigure('Name', 'Brightness Z-Control', ...
                'Position', [100 100 700 520], ...
                'Color', [0.97 0.97 0.97], ...
                'CloseRequestFcn', @obj.closeFigure, ...
                'Resize', 'on');

            % Remove Dev Tools panel and related controls
            % Expand plot area and adjust grid layout
            mainGrid = uigridlayout(obj.hFig, [4, 2]);
            mainGrid.RowHeight = {'fit', 50, '1x', 30};
            mainGrid.ColumnWidth = {'2x', '1x'};
            mainGrid.Padding = [10 10 10 10];
            mainGrid.RowSpacing = 5;
            mainGrid.ColumnSpacing = 10;

            % --- Scan Parameters Panel (Row 1, Col 1:2) ---
            paramPanel = uipanel(mainGrid, 'Title', 'Scan Parameters', 'FontWeight', 'bold');
            paramPanel.Layout.Row = 1;
            paramPanel.Layout.Column = [1 2];
            paramGrid = uigridlayout(paramPanel, [2, 5]);
            paramGrid.RowHeight = {22, 22};
            paramGrid.ColumnWidth = {'fit','fit','fit','fit','fit'};
            paramGrid.Padding = [5 5 5 5];
            paramGrid.RowSpacing = 2;
            paramGrid.ColumnSpacing = 5;

            % Step Size
            lbl = uilabel(paramGrid, 'Text', 'Step Size:', 'Tooltip', 'Set the Z scan step size (µm)');
            lbl.Layout.Row = 1;
            lbl.Layout.Column = 1;

            obj.hStepSizeSlider = uislider(paramGrid, ...
                'Limits', [1 50], 'Value', obj.initialStepSize, ...
                'Tooltip', 'Set the Z scan step size (µm)', ...
                'ValueChangingFcn', @(src,event) obj.updateStepSizeImmediate(event.Value));
            obj.hStepSizeSlider.Layout.Row = 1;
            obj.hStepSizeSlider.Layout.Column = 2;

            obj.hStepSizeValue = uilabel(paramGrid, 'Text', num2str(obj.initialStepSize));
            obj.hStepSizeValue.Layout.Row = 1;
            obj.hStepSizeValue.Layout.Column = 3;

            lbl = uilabel(paramGrid, 'Text', 'Pause (s):', 'Tooltip', 'Pause between Z steps (seconds)');
            lbl.Layout.Row = 2;
            lbl.Layout.Column = 1;
            obj.hPauseTimeEdit = uieditfield(paramGrid, 'text', ...
                'Value', num2str(obj.scanPauseTime), 'Tooltip', 'Pause between Z steps (seconds)');
            obj.hPauseTimeEdit.Layout.Row = 2;
            obj.hPauseTimeEdit.Layout.Column = 2;

            % Min Z
            lbl = uilabel(paramGrid, 'Text', 'Min Z:', 'Tooltip', 'Set minimum Z limit');
            lbl.Layout.Row = 2;
            lbl.Layout.Column = 3;
            obj.hMinZEdit = uieditfield(paramGrid, 'numeric', 'Tooltip', 'Minimum Z limit');
            obj.hMinZEdit.Layout.Row = 2;
            obj.hMinZEdit.Layout.Column = 4;
            btn = uibutton(paramGrid, 'Text', 'Set Min Z', 'Tooltip', 'Set minimum Z limit', ...
                'ButtonPushedFcn', @(~,~) obj.setMinZLimit());
            btn.Layout.Row = 2;
            btn.Layout.Column = 5;

            % Max Z
            lbl = uilabel(paramGrid, 'Text', 'Max Z:', 'Tooltip', 'Set maximum Z limit');
            lbl.Layout.Row = 3;
            lbl.Layout.Column = 3;
            obj.hMaxZEdit = uieditfield(paramGrid, 'numeric', 'Tooltip', 'Maximum Z limit');
            obj.hMaxZEdit.Layout.Row = 3;
            obj.hMaxZEdit.Layout.Column = 4;
            btn = uibutton(paramGrid, 'Text', 'Set Max Z', 'Tooltip', 'Set maximum Z limit', ...
                'ButtonPushedFcn', @(~,~) obj.setMaxZLimit());
            btn.Layout.Row = 3;
            btn.Layout.Column = 5;

            % Brightness Metric
            lbl = uilabel(paramGrid, 'Text', 'Brightness Metric:', 'Tooltip', 'Select brightness metric');
            lbl.Layout.Row = 4;
            lbl.Layout.Column = 1;
            obj.hMetricDropDown = uidropdown(paramGrid, ...
                'Items', {'Mean', 'Median', 'Max', '95th Percentile'}, ...
                'Tooltip', 'Select brightness metric', ...
                'Value', 'Mean');
            obj.hMetricDropDown.Layout.Row = 4;
            obj.hMetricDropDown.Layout.Column = 2;

            % --- Actions Panel (Row 2, Col 2) ---
            actionPanel = uipanel(mainGrid, 'Title', 'Actions', 'FontWeight', 'bold');
            actionPanel.Layout.Row = 2;
            actionPanel.Layout.Column = 2;
            actionGrid = uigridlayout(actionPanel, [1, 3]);
            actionGrid.RowHeight = {'1x'};
            actionGrid.ColumnWidth = {'1x','1x','1x'};

            % Monitor Button
            obj.hMonitorToggle = uibutton(actionGrid, 'state', ...
                'Text', 'Monitor', 'FontSize', 11, ...
                'Tooltip', 'Start/stop brightness monitoring', ...
                'ValueChangedFcn', @(src,~) obj.toggleMonitor(src));
            obj.hMonitorToggle.Layout.Row = 1;
            obj.hMonitorToggle.Layout.Column = 1;

            % Z-Scan Button
            obj.hZScanToggle = uibutton(actionGrid, 'state', ...
                'Text', 'Z-Scan', 'FontSize', 11, ...
                'Tooltip', 'Start/stop Z scanning', ...
                'ValueChangedFcn', @(src,~) obj.toggleZScan(src));
            obj.hZScanToggle.Layout.Row = 1;
            obj.hZScanToggle.Layout.Column = 2;

            % Move to Max Button
            btn = uibutton(actionGrid, 'Text', 'Move to Max', 'FontSize', 11, ...
                'Tooltip', 'Move to the Z position with maximum brightness', ...
                'ButtonPushedFcn', @(~,~) obj.moveToMaxBrightness());
            btn.Layout.Row = 1;
            btn.Layout.Column = 3;

            % --- Help Button (bottom right) ---
            btn = uibutton(mainGrid, 'Text', 'Help', ...
                'Tooltip', 'Show usage guide', ...
                'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) helpdlg([ ...
                    '1. Set step size and pause time.' newline ...
                    '2. Use Monitor and Z-Scan to acquire data.' newline ...
                    '3. Move to Max to go to brightest Z.' newline ...
                    '4. Dev Tools: run quick tests.' ...
                ], 'Usage Guide'));
            btn.Layout.Row = 4;
            btn.Layout.Column = 1;
        end
        
        function closeFigure(obj, ~, ~)
            % Handle figure close request
            try
                % Stop monitoring if active
                if obj.isMonitoring
                    obj.stopMonitoring();
                end
                
                % Delete figure
                delete(obj.hFig);
            catch ME
                warning('Error closing figure: %s', ME.message);
            end
        end
        
        function updateStatus(obj, message)
            % Update status text
            try
                set(obj.hStatusText, 'String', message);
                drawnow;
            catch ME
                warning('Error updating status: %s', ME.message);
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
                        obj.stopZScan();
                        obj.updateStatus('Scan completed. Ready to move to max brightness.');
                        return;
                    end
                    % Move to the new position
                    obj.absoluteMove(obj.scanCurrentZ);
                    % Mark brightness data on plot
                    obj.updatePlot();
                    % Update status
                    obj.updateStatus(sprintf('Scanning: Z=%.2f, Step=%.2f', ...
                        obj.scanCurrentZ, obj.scanStepSize));
                catch ME
                    warning('Error in scan step: %s', ME.message);
                    obj.stopZScan();
                end
            end
        end
        
        function toggleMonitor(obj, src)
            % Toggle monitoring state
            if src.Value
                obj.startMonitoring();
                obj.updateStatus('Monitoring started');
            else
                obj.stopMonitoring();
                obj.updateStatus('Monitoring stopped');
            end
        end
        
        function toggleZScan(obj, src)
            % Toggle Z-scan state
            if src.Value
                % Get parameters from GUI
                stepSize = round(obj.hStepSizeSlider.Value);
                obj.scanStepSize = stepSize;
                obj.initialStepSize = stepSize;
                obj.scanPauseTime = obj.hPauseTimeEdit.Value;
                obj.hStepSizeValue.Text = num2str(stepSize);
                obj.startZScan();
                obj.updateStatus('Z-Scan started');
            else
                obj.stopZScan();
                obj.updateStatus('Z-Scan stopped');
            end
        end
        
        function runTestFromDropdown(obj)
            % Run test based on dropdown selection
            val = obj.hTestDropDown.Value;
            switch val
                case 'Run All Tests'
                    obj.runTest('zMovement');
                    obj.runTest('monitoring');
                    obj.runTest('zScan');
                    obj.runTest('maxBrightness');
                case 'Test Z Movement'
                    obj.runTest('zMovement');
                case 'Test Monitoring'
                    obj.runTest('monitoring');
                case 'Test Z-Scan'
                    obj.runTest('zScan');
                case 'Test Max Brightness'
                    obj.runTest('maxBrightness');
            end
        end
        
        function runTest(obj, testType)
            % Run the specified test
            try
                switch testType
                    case 'zMovement'
                        obj.updateStatus('Testing Z movement...');
                        currentZ = obj.getZ();
                        fprintf('Current Z position: %.2f µm\n', currentZ);
                        
                        fprintf('Moving up 1 µm...\n');
                        obj.moveUp();
                        pause(1);
                        
                        fprintf('Moving down 1 µm...\n');
                        obj.moveDown();
                        pause(1);
                        
                        obj.updateStatus('Z movement test completed');
                        
                    case 'monitoring'
                        obj.updateStatus('Testing brightness monitoring...');
                        
                        fprintf('Starting monitoring...\n');
                        obj.startMonitoring();
                        pause(5); % Monitor for 5 seconds
                        
                        fprintf('Stopping monitoring...\n');
                        obj.stopMonitoring();
                        
                        obj.updateStatus('Brightness monitoring test completed');
                        
                    case 'zScan'
                        obj.updateStatus('Testing Z-scan...');
                        
                        fprintf('Starting Z-scan...\n');
                        obj.startZScan();
                        pause(5); % Scan for 5 seconds
                        
                        fprintf('Stopping Z-scan...\n');
                        obj.stopZScan();
                        
                        obj.updateStatus('Z-scan test completed');
                        
                    case 'maxBrightness'
                        obj.updateStatus('Testing maximum brightness detection...');
                        
                        fprintf('Moving to maximum brightness position...\n');
                        obj.moveToMaxBrightness();
                        
                        obj.updateStatus('Maximum brightness test completed');
                end
            catch ME
                fprintf('Error in test: %s\n', ME.message);
                obj.updateStatus(sprintf('Test error: %s', ME.message));
            end
        end
        
        function updateStepSizeImmediate(obj, value)
            % Update step size label and set step size in ScanImage motor controls immediately
            obj.hStepSizeValue.Text = num2str(round(value));
            obj.setStepSize(round(value));
        end
        
        function setMinZLimit(obj)
            % Move to Min Z, press SetLim (min)
            minZ = obj.hMinZEdit.Value;
            obj.absoluteMove(minZ);
            pause(0.2);
            obj.pressSetLimMin();
            obj.updateStatus(sprintf('Set Min Z limit to %.2f', minZ));
        end
        
        function setMaxZLimit(obj)
            % Move to Max Z, press SetLim (max)
            maxZ = obj.hMaxZEdit.Value;
            obj.absoluteMove(maxZ);
            pause(0.2);
            obj.pressSetLimMax();
            obj.updateStatus(sprintf('Set Max Z limit to %.2f', maxZ));
        end
    end
end

function vis = toggleVisibility(current)
    if strcmp(current, 'off')
        vis = 'on';
    else
        vis = 'off';
    end
end 