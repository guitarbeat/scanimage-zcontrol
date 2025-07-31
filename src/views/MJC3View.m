classdef MJC3View < handle
    % MJC3View - Dedicated window for MJC3 Joystick Control
    % Provides a separate interface for joystick configuration, monitoring, and control
    
    properties (Access = public)
        % UI Components
        UIFigure
        MainLayout
        
        % Control Components
        EnableButton
        StatusLabel
        StepFactorField
        SettingsButton
        
        % Monitoring Components
        PositionDisplay
        MovementHistory
        ConnectionStatus
        
        % Advanced Controls
        CalibrationPanel
        LoggingPanel
        
        % Real-time Display
        JoystickVisualizer
        MovementLog
        
        % State Management (public for testing and external access)
        IsEnabled = false
        IsConnected = false
    end
    
    properties (Access = private)
        % Controller Reference
        HIDController
        
        % Monitoring
        UpdateTimer
        MovementData = struct('time', {}, 'direction', {}, 'type', {})
        
        % UI State
        WindowPosition = [300, 300, 400, 600]  % Default window size and position
    end
    
    methods
        function obj = MJC3View()
            % Constructor: Creates the MJC3 control window
            obj.createUI();
            obj.setupCallbacks();
            obj.initialize();
        end
        
        function delete(obj)
            % Destructor: Clean up resources
            obj.stopMonitoring();
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                delete(obj.UIFigure);
            end
        end
        
        function setController(obj, controller)
            % Set the HID controller reference
            obj.HIDController = controller;
            
            % Display controller type information
            if ~isempty(controller)
                controllerType = class(controller);
                if contains(controllerType, 'MEX')
                    fprintf('🚀 MJC3View: Using high-performance MEX controller\n');
                else
                    fprintf('ℹ️  MJC3View: Using %s controller\n', controllerType);
                end
            else
                fprintf('⚠️  MJC3View: No controller provided (manual mode)\n');
            end
            
            obj.updateConnectionStatus();
            obj.detectHardware(); % Check hardware detection status
        end
        
        function bringToFront(obj)
            % Brings the UI figure to the front
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                figure(obj.UIFigure);
            end
        end
        
        function show(obj)
            % Show the window
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                obj.UIFigure.Visible = 'on';
                obj.bringToFront();
            end
        end
        
        function hide(obj)
            % Hide the window
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                obj.UIFigure.Visible = 'off';
            end
        end
        
        function isDetected = checkHardwareDetection(obj)
            % Check if MJC3 hardware is detected (not necessarily connected)
            isDetected = false;
            
            try
                % Method 1: Try PsychHID detection (most reliable)
                try
                    devs = PsychHID('Devices');
                    idx = find([devs.vendorID] == hex2dec('1313') & [devs.productID] == hex2dec('9000'), 1);
                    if ~isempty(idx)
                        isDetected = true;
                        return;
                    end
                catch
                    % PsychHID not available, continue to next method
                end
                
                % Method 2: Try Windows API detection
                try
                    cmd = 'powershell "Get-WmiObject Win32_PnPEntity | Where-Object {$_.DeviceID -like ''*VID_1313*'' -and $_.DeviceID -like ''*PID_9000*''} | Select-Object Name, DeviceID"';
                    [status, result] = system(cmd);
                    
                    if status == 0 && contains(result, 'VID_1313')
                        isDetected = true;
                        return;
                    end
                catch
                    % Windows API failed, continue
                end
                
                % Method 3: Check if controller reports detection
                if ~isempty(obj.HIDController)
                    % Try the connectToMJC3 method to check detection
                    isDetected = obj.HIDController.connectToMJC3();
                end
                
            catch ME
                fprintf('Hardware detection check failed: %s\n', ME.message);
                isDetected = false;
            end
        end
        
        function updateConnectionStatus(obj)
            % Update connection status display with detailed states
            if isempty(obj.HIDController)
                obj.ConnectionStatus.Text = '⚫ No Controller';
                obj.ConnectionStatus.FontColor = [0.5 0.5 0.5];
                obj.StatusLabel.Text = 'No controller available';
                obj.StatusLabel.FontColor = [0.5 0.5 0.5];
            elseif obj.IsEnabled && obj.IsConnected
                obj.ConnectionStatus.Text = '🟢 Active';
                obj.ConnectionStatus.FontColor = [0.16 0.68 0.38];
                obj.StatusLabel.Text = 'Active and polling';
                obj.StatusLabel.FontColor = [0.16 0.68 0.38];
            elseif obj.IsConnected
                obj.ConnectionStatus.Text = '🟡 Connected';
                obj.ConnectionStatus.FontColor = [0.9 0.6 0.2];
                obj.StatusLabel.Text = 'Connected but inactive';
                obj.StatusLabel.FontColor = [0.9 0.6 0.2];
            else
                % Check if hardware is detected but not connected
                isDetected = obj.checkHardwareDetection();
                if isDetected
                    obj.ConnectionStatus.Text = '🟠 Detected';
                    obj.ConnectionStatus.FontColor = [1.0 0.5 0.0];
                    obj.StatusLabel.Text = 'Hardware detected, not connected';
                    obj.StatusLabel.FontColor = [1.0 0.5 0.0];
                else
                    obj.ConnectionStatus.Text = '🔴 Not Found';
                    obj.ConnectionStatus.FontColor = [0.8 0.2 0.2];
                    obj.StatusLabel.Text = 'Hardware not detected';
                    obj.StatusLabel.FontColor = [0.8 0.2 0.2];
                end
            end
        end
        
        function detectHardware(obj)
            % Detect MJC3 hardware and update status
            isDetected = obj.checkHardwareDetection();
            if isDetected
                fprintf('MJC3 hardware detected\n');
            else
                fprintf('MJC3 hardware not detected\n');
            end
            obj.updateConnectionStatus();
        end
    end
    
    methods (Access = private)
        function createUI(obj)
            % Create and configure all UI components
            
            % Main Figure
            obj.UIFigure = uifigure('Visible', 'off');
            obj.UIFigure.Name = 'MJC3 Joystick Control';
            obj.UIFigure.Position = obj.WindowPosition;
            obj.UIFigure.AutoResizeChildren = 'on';
            obj.UIFigure.Color = [0.94 0.94 0.94];
            
            % Main Layout - 6 sections
            obj.MainLayout = uigridlayout(obj.UIFigure);
            obj.MainLayout.ColumnWidth = {'1x'};
            obj.MainLayout.RowHeight = {'fit', 'fit', '1x', 'fit', 'fit', 'fit'};
            obj.MainLayout.Padding = [10 10 10 10];
            obj.MainLayout.RowSpacing = 10;
            
            % Create UI sections
            obj.createHeaderSection();
            obj.createControlSection();
            obj.createVisualizerSection();
            obj.createMonitoringSection();
            obj.createCalibrationSection();
            obj.createLoggingSection();
            
            % Make figure visible
            obj.UIFigure.Visible = 'on';
        end
        
        function createHeaderSection(obj)
            % Create header with title and connection status
            headerPanel = uipanel(obj.MainLayout);
            headerPanel.Layout.Row = 1;
            headerPanel.Title = '';
            headerPanel.BorderType = 'none';
            headerPanel.BackgroundColor = [0.94 0.94 0.94];
            
            headerGrid = uigridlayout(headerPanel, [2, 1]);
            headerGrid.RowHeight = {'fit', 'fit'};
            headerGrid.Padding = [5 5 5 5];
            headerGrid.RowSpacing = 5;
            
            % Title
            titleLabel = uilabel(headerGrid);
            titleLabel.Text = '🕹️ MJC3 Joystick Control';
            titleLabel.FontSize = 18;
            titleLabel.FontWeight = 'bold';
            titleLabel.HorizontalAlignment = 'center';
            titleLabel.Layout.Row = 1;
            
            % Connection Status
            obj.ConnectionStatus = uilabel(headerGrid);
            obj.ConnectionStatus.Text = '🔴 Disconnected';
            obj.ConnectionStatus.FontSize = 14;
            obj.ConnectionStatus.FontWeight = 'bold';
            obj.ConnectionStatus.HorizontalAlignment = 'center';
            obj.ConnectionStatus.FontColor = [0.8 0.2 0.2];
            obj.ConnectionStatus.Layout.Row = 2;
        end
        
        function createControlSection(obj)
            % Create main control buttons and settings
            controlPanel = uipanel(obj.MainLayout);
            controlPanel.Layout.Row = 2;
            controlPanel.Title = 'Control';
            controlPanel.FontSize = 14;
            controlPanel.FontWeight = 'bold';
            controlPanel.BackgroundColor = [0.98 0.98 1.0];
            
            controlGrid = uigridlayout(controlPanel, [3, 2]);
            controlGrid.RowHeight = {'fit', 'fit', 'fit'};
            controlGrid.ColumnWidth = {'1x', '1x'};
            controlGrid.Padding = [10 10 10 10];
            controlGrid.RowSpacing = 8;
            controlGrid.ColumnSpacing = 10;
            
            % Enable/Disable Button
            obj.EnableButton = uibutton(controlGrid, 'push');
            obj.EnableButton.Text = '▶ Enable';
            obj.EnableButton.Layout.Row = 1;
            obj.EnableButton.Layout.Column = [1 2];
            obj.EnableButton.BackgroundColor = [0.16 0.68 0.38];
            obj.EnableButton.FontColor = [1 1 1];
            obj.EnableButton.FontSize = 14;
            obj.EnableButton.FontWeight = 'bold';
            obj.EnableButton.Tooltip = 'Enable/Disable MJC3 joystick control';
            
            % Step Factor Control
            stepLabel = uilabel(controlGrid);
            stepLabel.Text = 'Step Factor:';
            stepLabel.FontSize = 12;
            stepLabel.FontWeight = 'bold';
            stepLabel.Layout.Row = 2;
            stepLabel.Layout.Column = 1;
            stepLabel.HorizontalAlignment = 'right';
            
            stepPanel = uipanel(controlGrid);
            stepPanel.Layout.Row = 2;
            stepPanel.Layout.Column = 2;
            stepPanel.BorderType = 'none';
            stepPanel.BackgroundColor = [0.98 0.98 1.0];
            
            stepGrid = uigridlayout(stepPanel, [1, 2]);
            stepGrid.ColumnWidth = {'1x', 'fit'};
            stepGrid.Padding = [0 0 0 0];
            stepGrid.ColumnSpacing = 5;
            
            obj.StepFactorField = uieditfield(stepGrid, 'numeric');
            obj.StepFactorField.Value = 5;
            obj.StepFactorField.FontSize = 12;
            obj.StepFactorField.Limits = [0.1 100];
            obj.StepFactorField.Tooltip = 'Micrometers moved per unit of joystick deflection';
            
            stepUnits = uilabel(stepGrid);
            stepUnits.Text = 'μm/unit';
            stepUnits.FontSize = 12;
            stepUnits.FontColor = [0.5 0.5 0.5];
            
            % Status Display
            statusLabel = uilabel(controlGrid);
            statusLabel.Text = 'Status:';
            statusLabel.FontSize = 12;
            statusLabel.FontWeight = 'bold';
            statusLabel.Layout.Row = 3;
            statusLabel.Layout.Column = 1;
            statusLabel.HorizontalAlignment = 'right';
            
            obj.StatusLabel = uilabel(controlGrid);
            obj.StatusLabel.Text = 'Ready';
            obj.StatusLabel.FontSize = 12;
            obj.StatusLabel.FontColor = [0.5 0.5 0.5];
            obj.StatusLabel.Layout.Row = 3;
            obj.StatusLabel.Layout.Column = 2;
        end
        
        function createVisualizerSection(obj)
            % Create joystick position visualizer
            visualizerPanel = uipanel(obj.MainLayout);
            visualizerPanel.Layout.Row = 3;
            visualizerPanel.Title = 'Joystick Position';
            visualizerPanel.FontSize = 14;
            visualizerPanel.FontWeight = 'bold';
            visualizerPanel.BackgroundColor = [0.95 0.98 0.95];
            
            % Create axes for joystick visualization
            obj.JoystickVisualizer = uiaxes(visualizerPanel);
            obj.JoystickVisualizer.XLim = [-128 128];
            obj.JoystickVisualizer.YLim = [-128 128];
            obj.JoystickVisualizer.XGrid = 'on';
            obj.JoystickVisualizer.YGrid = 'on';
            obj.JoystickVisualizer.Title.String = 'Real-time Joystick Position';
            obj.JoystickVisualizer.XLabel.String = 'X Axis';
            obj.JoystickVisualizer.YLabel.String = 'Z Axis (Vertical)';
            
            % Draw center crosshairs
            hold(obj.JoystickVisualizer, 'on');
            plot(obj.JoystickVisualizer, [-128 128], [0 0], 'k--', 'Color', [0.5 0.5 0.5]);
            plot(obj.JoystickVisualizer, [0 0], [-128 128], 'k--', 'Color', [0.5 0.5 0.5]);
            
            % Initialize position indicator
            scatter(obj.JoystickVisualizer, 0, 0, 100, 'r', 'filled', 'Tag', 'PositionIndicator');
        end
        
        function createMonitoringSection(obj)
            % Create movement monitoring display
            monitorPanel = uipanel(obj.MainLayout);
            monitorPanel.Layout.Row = 4;
            monitorPanel.Title = 'Movement Monitoring';
            monitorPanel.FontSize = 14;
            monitorPanel.FontWeight = 'bold';
            monitorPanel.BackgroundColor = [1.0 0.98 0.95];
            
            monitorGrid = uigridlayout(monitorPanel, [2, 2]);
            monitorGrid.RowHeight = {'fit', 'fit'};
            monitorGrid.ColumnWidth = {'1x', '1x'};
            monitorGrid.Padding = [10 10 10 10];
            monitorGrid.RowSpacing = 5;
            monitorGrid.ColumnSpacing = 10;
            
            % Current Position
            posLabel = uilabel(monitorGrid);
            posLabel.Text = 'Current Position:';
            posLabel.FontSize = 12;
            posLabel.FontWeight = 'bold';
            posLabel.Layout.Row = 1;
            posLabel.Layout.Column = 1;
            
            obj.PositionDisplay = uilabel(monitorGrid);
            obj.PositionDisplay.Text = '0.0 μm';
            obj.PositionDisplay.FontSize = 14;
            obj.PositionDisplay.FontWeight = 'bold';
            obj.PositionDisplay.FontColor = [0.2 0.6 0.8];
            obj.PositionDisplay.Layout.Row = 1;
            obj.PositionDisplay.Layout.Column = 2;
            
            % Movement Count
            moveLabel = uilabel(monitorGrid);
            moveLabel.Text = 'Movements:';
            moveLabel.FontSize = 12;
            moveLabel.FontWeight = 'bold';
            moveLabel.Layout.Row = 2;
            moveLabel.Layout.Column = 1;
            
            obj.MovementHistory = uilabel(monitorGrid);
            obj.MovementHistory.Text = '0';
            obj.MovementHistory.FontSize = 12;
            obj.MovementHistory.FontColor = [0.5 0.5 0.5];
            obj.MovementHistory.Layout.Row = 2;
            obj.MovementHistory.Layout.Column = 2;
        end
        
        function createCalibrationSection(obj)
            % Create calibration controls
            obj.CalibrationPanel = uipanel(obj.MainLayout);
            obj.CalibrationPanel.Layout.Row = 5;
            obj.CalibrationPanel.Title = 'Calibration & Testing';
            obj.CalibrationPanel.FontSize = 14;
            obj.CalibrationPanel.FontWeight = 'bold';
            obj.CalibrationPanel.BackgroundColor = [0.98 0.95 0.90];
            
            calibGrid = uigridlayout(obj.CalibrationPanel, [1, 3]);
            calibGrid.ColumnWidth = {'1x', '1x', '1x'};
            calibGrid.Padding = [10 10 10 10];
            calibGrid.ColumnSpacing = 10;
            
            % Test Up Button
            testUpBtn = uibutton(calibGrid, 'push');
            testUpBtn.Text = '▲ Test Up';
            testUpBtn.Layout.Column = 1;
            testUpBtn.BackgroundColor = [0.16 0.68 0.38];
            testUpBtn.FontColor = [1 1 1];
            testUpBtn.Tooltip = 'Test upward movement';
            testUpBtn.ButtonPushedFcn = @(~,~) obj.testMovement('up');
            
            % Test Down Button
            testDownBtn = uibutton(calibGrid, 'push');
            testDownBtn.Text = '▼ Test Down';
            testDownBtn.Layout.Column = 2;
            testDownBtn.BackgroundColor = [0.86 0.24 0.24];
            testDownBtn.FontColor = [1 1 1];
            testDownBtn.Tooltip = 'Test downward movement';
            testDownBtn.ButtonPushedFcn = @(~,~) obj.testMovement('down');
            
            % Calibrate Button
            calibrateBtn = uibutton(calibGrid, 'push');
            calibrateBtn.Text = '⚙ Calibrate';
            calibrateBtn.Layout.Column = 3;
            calibrateBtn.BackgroundColor = [0.2 0.6 0.8];
            calibrateBtn.FontColor = [1 1 1];
            calibrateBtn.Tooltip = 'Calibrate joystick sensitivity';
            calibrateBtn.ButtonPushedFcn = @(~,~) obj.calibrateJoystick();
        end
        
        function createLoggingSection(obj)
            % Create logging and export controls
            obj.LoggingPanel = uipanel(obj.MainLayout);
            obj.LoggingPanel.Layout.Row = 6;
            obj.LoggingPanel.Title = 'Data Logging';
            obj.LoggingPanel.FontSize = 14;
            obj.LoggingPanel.FontWeight = 'bold';
            obj.LoggingPanel.BackgroundColor = [0.95 0.95 0.98];
            
            logGrid = uigridlayout(obj.LoggingPanel, [1, 3]);
            logGrid.ColumnWidth = {'1x', '1x', '1x'};
            logGrid.Padding = [10 10 10 10];
            logGrid.ColumnSpacing = 10;
            
            % Clear Log Button
            clearBtn = uibutton(logGrid, 'push');
            clearBtn.Text = '🗑 Clear';
            clearBtn.Layout.Column = 1;
            clearBtn.BackgroundColor = [0.86 0.24 0.24];
            clearBtn.FontColor = [1 1 1];
            clearBtn.Tooltip = 'Clear movement history';
            clearBtn.ButtonPushedFcn = @(~,~) obj.clearMovementLog();
            
            % Export Button
            exportBtn = uibutton(logGrid, 'push');
            exportBtn.Text = '📤 Export';
            exportBtn.Layout.Column = 2;
            exportBtn.BackgroundColor = [0.2 0.6 0.8];
            exportBtn.FontColor = [1 1 1];
            exportBtn.Tooltip = 'Export movement data';
            exportBtn.ButtonPushedFcn = @(~,~) obj.exportMovementData();
            
            % Detect Hardware Button
            detectBtn = uibutton(logGrid, 'push');
            detectBtn.Text = '🔍 Detect';
            detectBtn.Layout.Column = 3;
            detectBtn.BackgroundColor = [0.2 0.6 0.8];
            detectBtn.FontColor = [1 1 1];
            detectBtn.Tooltip = 'Scan for MJC3 hardware';
            detectBtn.ButtonPushedFcn = @(~,~) obj.onDetectButtonPushed();
            
            % Store reference for later use
            obj.SettingsButton = detectBtn;
        end
        
        function setupCallbacks(obj)
            % Set up all UI callback functions
            
            % Main window
            obj.UIFigure.CloseRequestFcn = @(~,~) obj.hide();  % Hide instead of delete
            
            % Control callbacks
            obj.EnableButton.ButtonPushedFcn = @(~,~) obj.onEnableButtonPushed();
            obj.StepFactorField.ValueChangedFcn = @(~,~) obj.onStepFactorChanged();
        end
        
        function initialize(obj)
            % Initialize the application
            obj.updateUI();
            obj.startMonitoring();
        end
        
        function updateUI(obj)
            % Update UI state based on current conditions
            
            if obj.IsEnabled
                obj.EnableButton.Text = '⏸ Disable';
                obj.EnableButton.BackgroundColor = [0.86 0.24 0.24];
                obj.StatusLabel.Text = 'Active';
                obj.StatusLabel.FontColor = [0.16 0.68 0.38];
            else
                obj.EnableButton.Text = '▶ Enable';
                obj.EnableButton.BackgroundColor = [0.16 0.68 0.38];
                obj.StatusLabel.Text = 'Inactive';
                obj.StatusLabel.FontColor = [0.5 0.5 0.5];
            end
            
            obj.updateConnectionStatus();
        end
        
        function startMonitoring(obj)
            % Start real-time monitoring timer
            if isempty(obj.UpdateTimer) || ~isvalid(obj.UpdateTimer)
                obj.UpdateTimer = timer(...
                    'ExecutionMode', 'fixedRate', ...
                    'Period', 0.1, ...  % Update at 10 Hz
                    'TimerFcn', @(~,~) obj.updateDisplay());
                start(obj.UpdateTimer);
            end
        end
        
        function stopMonitoring(obj)
            % Stop monitoring timer
            if ~isempty(obj.UpdateTimer) && isvalid(obj.UpdateTimer)
                stop(obj.UpdateTimer);
                delete(obj.UpdateTimer);
                obj.UpdateTimer = [];
            end
        end
        
        function updateDisplay(obj)
            % Update real-time display elements
            if ~isempty(obj.HIDController) && obj.IsEnabled
                % This would be called by the timer to update displays
                % Implementation depends on how you want to interface with the controller
                obj.updateJoystickVisualizer();
                obj.updateMovementHistory();
            end
        end
        
        function updateJoystickVisualizer(obj)
            % Update the joystick position visualization with real data
            if isempty(obj.HIDController) || ~obj.IsEnabled
                return;
            end
            
            % Try to get real joystick data if MEX controller is available
            try
                if isa(obj.HIDController, 'MJC3_MEX_Controller')
                    % Get real-time joystick data from MEX controller
                    data = obj.HIDController.readJoystick();
                    if length(data) >= 5
                        xPos = data(1);  % X position (-127 to 127)
                        zPos = data(3);  % Z position (-127 to 127)
                        
                        % Find existing position indicator
                        posIndicator = findobj(obj.JoystickVisualizer, 'Tag', 'PositionIndicator');
                        if ~isempty(posIndicator)
                            set(posIndicator, 'XData', xPos, 'YData', zPos);
                            
                            % Update color based on movement
                            if abs(xPos) > 5 || abs(zPos) > 5
                                set(posIndicator, 'CData', [1 0 0]); % Red when moving
                            else
                                set(posIndicator, 'CData', [0 1 0]); % Green when centered
                            end
                        end
                        
                        % Update position display with actual values
                        obj.PositionDisplay.Text = sprintf('X: %d, Z: %d', xPos, zPos);
                        return;
                    end
                end
            catch
                % Fall back to placeholder if real data unavailable
            end
            
            % Placeholder implementation for non-MEX controllers
            posIndicator = findobj(obj.JoystickVisualizer, 'Tag', 'PositionIndicator');
            if ~isempty(posIndicator)
                % Keep current position or return to center
                set(posIndicator, 'XData', 0, 'YData', 0);
                set(posIndicator, 'CData', [0.5 0.5 0.5]); % Gray when no data
            end
        end
        
        function updateMovementHistory(obj)
            % Update movement history display
            % Placeholder implementation
            movementCount = length(obj.MovementData);
            obj.MovementHistory.Text = sprintf('%d', movementCount);
        end
        
        % Callback Methods
        function onEnableButtonPushed(obj)
            % Toggle enable/disable state with detailed status feedback
            
            if ~obj.IsEnabled
                % Trying to enable - check hardware first
                if isempty(obj.HIDController)
                    uialert(obj.UIFigure, 'No controller available. Please check hardware connection.', 'No Controller');
                    return;
                end
                
                % Check if hardware is detected
                isDetected = obj.checkHardwareDetection();
                if ~isDetected
                    uialert(obj.UIFigure, 'MJC3 hardware not detected. Please check USB connection and try again.', 'Hardware Not Found');
                    return;
                end
                
                % Try to start the controller
                try
                    obj.HIDController.start();
                    obj.IsEnabled = true;
                    obj.IsConnected = true;
                    fprintf('MJC3 controller enabled and active\n');
                catch ME
                    obj.IsEnabled = false;
                    obj.IsConnected = false;
                    uialert(obj.UIFigure, sprintf('Failed to start controller: %s\n\nHardware detected but connection failed. Try:\n• Reconnecting USB cable\n• Restarting application\n• Checking device permissions', ME.message), 'Connection Failed');
                end
            else
                % Disabling controller
                if ~isempty(obj.HIDController)
                    try
                        obj.HIDController.stop();
                        fprintf('MJC3 controller disabled\n');
                    catch ME
                        fprintf('Warning: Error stopping controller: %s\n', ME.message);
                    end
                end
                obj.IsEnabled = false;
                obj.IsConnected = false;
            end
            
            obj.updateUI();
        end
        
        function onStepFactorChanged(obj)
            % Update step factor in controller
            if ~isempty(obj.HIDController)
                obj.HIDController.setStepFactor(obj.StepFactorField.Value);
            end
        end
        
        function onDetectButtonPushed(obj)
            % Manual hardware detection with detailed feedback
            fprintf('Scanning for MJC3 hardware...\n');
            
            % Show scanning status
            originalText = obj.ConnectionStatus.Text;
            obj.ConnectionStatus.Text = '🔄 Scanning...';
            obj.ConnectionStatus.FontColor = [0.2 0.6 0.8];
            drawnow;
            
            % Perform detection
            isDetected = obj.checkHardwareDetection();
            
            % Create detailed status message
            statusMsg = '';
            iconType = 'info';
            
            if isDetected
                statusMsg = sprintf(['✅ MJC3 Hardware Detected!\n\n' ...
                    'Device: Thorlabs MJC3 Joystick\n' ...
                    'VID: 0x1313, PID: 0x9000\n\n' ...
                    'Status: Ready for connection\n' ...
                    'Click "Enable" to start using the joystick.']);
                iconType = 'success';
                fprintf('✅ MJC3 hardware detected successfully\n');
            else
                statusMsg = sprintf(['❌ MJC3 Hardware Not Found\n\n' ...
                    'Troubleshooting:\n' ...
                    '• Check USB cable connection\n' ...
                    '• Verify device is powered on\n' ...
                    '• Try different USB port\n' ...
                    '• Check Windows Device Manager\n' ...
                    '• Restart the application\n\n' ...
                    'Looking for: Thorlabs MJC3 (VID: 0x1313, PID: 0x9000)']);
                iconType = 'warning';
                fprintf('❌ MJC3 hardware not detected\n');
            end
            
            % Update status and show dialog
            obj.updateConnectionStatus();
            uialert(obj.UIFigure, statusMsg, 'Hardware Detection', 'Icon', iconType);
        end
        
        function testMovement(obj, direction)
            % Test movement in specified direction
            if ~isempty(obj.HIDController)
                % Use manual control methods for testing
                if strcmp(direction, 'up')
                    obj.HIDController.moveUp(1);
                else
                    obj.HIDController.moveDown(1);
                end
                
                % Log the test movement
                obj.MovementData(end+1) = struct('time', datetime('now'), 'direction', direction, 'type', 'test');
                obj.updateMovementHistory();
            else
                uialert(obj.UIFigure, 'Controller not available for testing.', 'Test Error');
            end
        end
        
        function calibrateJoystick(obj)
            % Placeholder for calibration routine
            uialert(obj.UIFigure, 'Calibration routine would run here.', 'Calibration', 'Icon', 'info');
        end
        
        function clearMovementLog(obj)
            % Clear movement history
            obj.MovementData = struct('time', {}, 'direction', {}, 'type', {});
            obj.updateMovementHistory();
        end
        
        function exportMovementData(obj)
            % Export movement data to file
            if isempty(obj.MovementData)
                uialert(obj.UIFigure, 'No movement data to export.', 'Export');
                return;
            end
            
            [file, path] = uiputfile('*.csv', 'Export Movement Data');
            if isequal(file, 0)
                return;
            end
            
            % Create table and export
            dataTable = struct2table(obj.MovementData);
            writetable(dataTable, fullfile(path, file));
            
            uialert(obj.UIFigure, sprintf('Movement data exported to %s', file), 'Export Complete');
        end
    end
end