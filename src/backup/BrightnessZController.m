classdef BrightnessZController < core.MotorGUI_ZControl
    % BrightnessZController - Z-position control with brightness monitoring
    %
    % This class acts as the main controller, coordinating the GUI,
    % brightness monitoring, and Z-scanning components.
    
    properties (Access = public)
        % Component Handles
        gui             % GUI Manager
        monitor         % Brightness Monitor
        scanner         % Z-Scanner
        
        % ScanImage handles
        hSI             % Main ScanImage handle
        
        % Public properties for GUI access
        initialStepSize = 20
        scanPauseTime = 0.5
    end
    
    properties (Access = private)
        % ScanImage handles
        hCSFocus         % Focus coordinate system handle
        hCSSample        % Sample coordinate system handle
        channelSettings  % Channel settings handle
    end
    
    methods
        %% GUI Construction and Initialization
        function obj = BrightnessZController()
            % Constructor - Initialize the brightness Z-control system
            
            % Initialize base class
            obj@core.MotorGUI_ZControl();
            
            try
                % Get ScanImage handle
                obj.hSI = evalin('base', 'hSI');
                
                % Create components
                obj.gui = gui.BrightnessZControlGUIv2(obj);
                obj.monitor = monitoring.BrightnessMonitor(obj, obj.hSI);
                obj.scanner = scan.ZScanner(obj);

                % Initialize components
                obj.initializeComponents();

                % Create the GUI
                obj.gui.create();
                
                % Initialize the current Z position display (for v2 GUI)
                obj.updateCurrentZDisplay();
                
            catch ME
                error('Failed to initialize brightness Z-control: %s', ME.message);
            end
        end
        
        function initializeComponents(obj)
            % Initialize all system components
            obj.initializeCoordinateSystems();
            obj.initializeChannelSettings();
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
                
                if ~ismember(obj.monitor.activeChannel, obj.channelSettings.channelsActive)
                    warning('Channel %d is not active', obj.monitor.activeChannel);
                    obj.monitor.activeChannel = obj.channelSettings.channelsActive(1);
                end
            catch ME
                error('Failed to initialize channel settings: %s', ME.message);
            end
        end
        
        %% Public Methods for Component Callbacks
        function updateStatus(obj, message)
            % Update status text in the GUI
            obj.gui.updateStatus(message);
        end
        
        function updatePlot(obj)
            % Update the plot in the GUI with the latest data from the monitor
            [bData, zData] = obj.monitor.getScanData();
            obj.gui.updatePlot(zData, bData, obj.monitor.activeChannel);
        end

        function metric = getBrightnessMetric(obj)
            % Get the selected brightness metric from the GUI
            metric = obj.gui.hMetricDropDown.Value;
        end
        
        function val = getZLimit(obj, which)
            % Get Z min or max limit from motor controls
            if strcmpi(which, 'min')
                val = str2double(get(obj.findByTag('pbMinLim'), 'UserData'));
                if isnan(val)
                    val = -Inf;
                end
            else
                val = str2double(get(obj.findByTag('pbMaxLim'), 'UserData'));
                if isnan(val)
                    val = Inf;
                end
            end
        end

        %% GUI Actions
        function toggleMonitor(obj, state)
            % Toggle monitoring state
            if state
                obj.monitor.start();
            else
                obj.monitor.stop();
            end
        end
        
        function toggleZScan(obj, state)
            % Toggle Z-scan state
            if state
                stepSize = max(1, round(obj.gui.hStepSizeSlider.Value)); % Ensure positive value
                pauseTime = str2double(obj.gui.hPauseTimeEdit.Value);
                obj.gui.hStepSizeValue.Text = num2str(stepSize);
                obj.scanner.start(stepSize, pauseTime);
                obj.updateStatus('Z-Scan started');
            else
                obj.scanner.stop();
                obj.updateStatus('Z-Scan stopped');
            end
        end
        
        function moveToMaxBrightness(obj)
            % Move to the Z position with maximum brightness
            try
                [maxBrightness, maxZ] = obj.monitor.getMaxBrightness();
                if ~isnan(maxZ)
                    obj.updateStatus(sprintf('Moving to Z=%.2f (brightness=%.2f)', maxZ, maxBrightness));
                    obj.absoluteMove(maxZ);
                else
                    obj.updateStatus('No brightness data available yet.');
                end
            catch ME
                error('Failed to move to maximum brightness: %s', ME.message);
            end
        end
        
        function updateStepSizeImmediate(obj, value)
            % Update step size label and set step size in ScanImage motor controls immediately
            obj.gui.hStepSizeValue.Text = num2str(round(value));
            obj.setStepSize(round(value));
        end
        
        function setMinZLimit(obj)
            % Move to Min Z, press SetLim (min)
            minZ = obj.gui.hMinZEdit.Value;
            obj.absoluteMove(minZ);
            pause(0.2);
            obj.pressSetLimMin();
            obj.updateStatus(sprintf('Set Min Z limit to %.2f', minZ));
        end
        
        function setMaxZLimit(obj)
            % Move to Max Z, press SetLim (max)
            maxZ = obj.gui.hMaxZEdit.Value;
            obj.absoluteMove(maxZ);
            pause(0.2);
            obj.pressSetLimMax();
            obj.updateStatus(sprintf('Set Max Z limit to %.2f', maxZ));
        end

        function moveZUp(obj)
            % Move Z stage up (decrease Z in ScanImage)
            try
                % Get current step size from slider
                stepSize = max(1, round(obj.gui.hStepSizeSlider.Value));
                
                % Update step size in ScanImage
                obj.setStepSize(stepSize);
                
                % Call the Zdec button in ScanImage (up arrow)
                obj.pressZdec();
                
                % Update status
                currentZ = obj.getZ();
                obj.updateStatus(sprintf('Moved Z up by %d to %.2f', stepSize, currentZ));
                
                % Update current Z position display in the v2 GUI
                if isa(obj.gui, 'gui.BrightnessZControlGUIv2')
                    obj.gui.updateCurrentZ(currentZ);
                end
            catch ME
                obj.updateStatus(sprintf('Error moving Z up: %s', ME.message));
            end
        end
        
        function moveZDown(obj)
            % Move Z stage down (increase Z in ScanImage)
            try
                % Get current step size from slider
                stepSize = max(1, round(obj.gui.hStepSizeSlider.Value));
                
                % Update step size in ScanImage
                obj.setStepSize(stepSize);
                
                % Call the Zinc button in ScanImage (down arrow)
                obj.pressZinc();
                
                % Update status
                currentZ = obj.getZ();
                obj.updateStatus(sprintf('Moved Z down by %d to %.2f', stepSize, currentZ));
                
                % Update current Z position display in the v2 GUI
                if isa(obj.gui, 'gui.BrightnessZControlGUIv2')
                    obj.gui.updateCurrentZ(currentZ);
                end
            catch ME
                obj.updateStatus(sprintf('Error moving Z down: %s', ME.message));
            end
        end

        function pressZdec(obj)
            % Press the Zdec button (up arrow) in ScanImage Motor Controls
            try
                % Find Zdec button
                btn = obj.findByTag('Zdec');
                if ~isempty(btn) && isprop(btn, 'Callback') && ~isempty(btn.Callback)
                    % Call button's callback
                    btn.Callback(btn, []);
                else
                    % Fallback to parent class method
                    obj.moveUp();
                end
            catch ME
                error('Failed to press Z decrease button: %s', ME.message);
            end
        end
        
        function pressZinc(obj)
            % Press the Zinc button (down arrow) in ScanImage Motor Controls
            try
                % Find Zinc button
                btn = obj.findByTag('Zinc');
                if ~isempty(btn) && isprop(btn, 'Callback') && ~isempty(btn.Callback)
                    % Call button's callback
                    btn.Callback(btn, []);
                else
                    % Fallback to parent class method
                    obj.moveDown();
                end
            catch ME
                error('Failed to press Z increase button: %s', ME.message);
            end
        end

        function startSIFocus(obj)
            % Start Focus mode in ScanImage
            try
                % Make sure ScanImage is available
                if isempty(obj.hSI) || ~isvalid(obj.hSI)
                    obj.updateStatus('ScanImage handle not available. Cannot start Focus mode.');
                    return;
                end
                
                % Check if startFocus method exists (compatibility check)
                if ~ismethod(obj.hSI, 'startFocus')
                    % Try alternative method
                    if isfield(obj.hSI, 'hDisplay') && ismethod(obj.hSI.hDisplay, 'startFocus')
                        obj.hSI.hDisplay.startFocus();
                    elseif isfield(obj.hSI, 'startLoop')
                        obj.hSI.startLoop();
                    else
                        obj.updateStatus('Focus function not found in ScanImage. Check ScanImage version.');
                        return;
                    end
                else
                    obj.hSI.startFocus();
                end
                
                obj.updateStatus('Started ScanImage Focus mode');
                
                % Start monitoring if not already active
                if ~obj.gui.hMonitorToggle.Value
                    obj.gui.hMonitorToggle.Value = true;
                    obj.toggleMonitor(true);
                end
            catch ME
                obj.updateStatus(sprintf('Error starting Focus: %s', ME.message));
            end
        end
        
        function grabSIFrame(obj)
            % Grab a single frame in ScanImage
            try
                % Make sure ScanImage is available
                if isempty(obj.hSI) || ~isvalid(obj.hSI)
                    obj.updateStatus('ScanImage handle not available. Cannot grab frame.');
                    return;
                end
                
                % Stop Focus mode if it's running
                if isfield(obj.hSI, 'acqState') && isfield(obj.hSI.acqState, 'acquiringFocus') && obj.hSI.acqState.acquiringFocus
                    obj.hSI.abort();
                    pause(0.2); % Give time for focus to stop
                end
                
                % Check if startGrab method exists (compatibility check)
                if ~ismethod(obj.hSI, 'startGrab') 
                    % Try alternative method
                    if isfield(obj.hSI, 'hDisplay') && ismethod(obj.hSI.hDisplay, 'startGrab')
                        obj.hSI.hDisplay.startGrab();
                    elseif isfield(obj.hSI, 'grab')
                        obj.hSI.grab();
                    else
                        obj.updateStatus('Grab function not found in ScanImage. Check ScanImage version.');
                        return;
                    end
                else
                    obj.hSI.startGrab();
                end
                
                obj.updateStatus('Grabbed ScanImage frame');
                
                % Wait for grab to complete
                pause(0.5);
                obj.updateStatus('Frame acquired');
            catch ME
                obj.updateStatus(sprintf('Error grabbing frame: %s', ME.message));
            end
        end
        
        function abortAllOperations(obj)
            % Abort all ongoing operations
            try
                % Stop scanning
                obj.scanner.stop();
                
                % Abort any ScanImage acquisition
                if ~isempty(obj.hSI) && isvalid(obj.hSI)
                    % Try different abort methods based on ScanImage version
                    if ismethod(obj.hSI, 'abort')
                        obj.hSI.abort();
                    elseif isfield(obj.hSI, 'hScan2D') && ismethod(obj.hSI.hScan2D, 'stop')
                        obj.hSI.hScan2D.stop();
                    end
                end
                
                % Keep monitoring active for safety
                if ~obj.monitor.isMonitoring
                    obj.monitor.start();
                    obj.gui.hMonitorToggle.Value = true;
                end
                
                obj.updateStatus('All operations aborted');
            catch ME
                obj.updateStatus(sprintf('Error during abort: %s', ME.message));
            end
        end

        function closeFigure(obj)
            % Handle figure close request
            try
                % Stop components
                obj.monitor.stop();
                obj.scanner.stop();
                
                % Delete GUI
                delete(obj.gui);
            catch ME
                warning('Error closing figure: %s', ME.message);
            end
        end

        % Override absoluteMove to update current Z display
        function absoluteMove(obj, targetZ)
            % Move to an absolute Z position and update the display
            try
                % Call parent method to perform the actual move
                absoluteMove@core.MotorGUI_ZControl(obj, targetZ);
                
                % Update current Z position display in the v2 GUI
                if isa(obj.gui, 'gui.BrightnessZControlGUIv2')
                    obj.gui.updateCurrentZ(targetZ);
                end
            catch ME
                obj.updateStatus(sprintf('Error moving to Z=%.2f: %s', targetZ, ME.message));
            end
        end
        
        function updateCurrentZDisplay(obj)
            % Update the current Z position display in the GUI
            try
                currentZ = obj.getZ();
                if isa(obj.gui, 'gui.BrightnessZControlGUIv2')
                    obj.gui.updateCurrentZ(currentZ);
                end
            catch ME
                warning('Error updating Z position display: %s', ME.message);
            end
        end
    end
end