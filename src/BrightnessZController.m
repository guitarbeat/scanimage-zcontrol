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
                obj.gui = gui.BrightnessZControlGUI(obj);
                obj.monitor = monitoring.BrightnessMonitor(obj, obj.hSI);
                obj.scanner = scan.ZScanner(obj);

                % Initialize components
                obj.initializeComponents();

                % Create the GUI
                obj.gui.create();
                
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
                stepSize = round(obj.gui.hStepSizeSlider.Value);
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
    end
end