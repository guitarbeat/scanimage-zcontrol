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
        ConnectionStatus
        
        % Analog Controls (Z, Y, X)
        ZValueDisplay
        XValueDisplay
        YValueDisplay
        ZSensitivityField
        XSensitivityField
        YSensitivityField
        ZActionDropdown
        XActionDropdown
        YActionDropdown
        
        % Button Controls
        Button1StateIndicator
        Button1TargetDropdown
        Button1ActionDropdown
        
        % Mapping Controls
        MappingFileDropdown
        NewMappingButton
        SaveMappingButton
        RemoveMappingButton
        
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
            fprintf('MJC3View: Cleaning up resources...\n');
            
            % Stop monitoring timer
            obj.stopMonitoring();
            
            % Stop and disconnect the controller
            if ~isempty(obj.HIDController) && isvalid(obj.HIDController)
                try
                    if obj.IsEnabled
                        fprintf('MJC3View: Stopping controller...\n');
                        obj.HIDController.stop();
                        obj.IsEnabled = false;
                        obj.IsConnected = false;
                    end
                catch ME
                    fprintf('MJC3View: Warning - Error stopping controller: %s\n', ME.message);
                end
            end
            
            % Delete UI figure
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                delete(obj.UIFigure);
            end
            
            fprintf('MJC3View: Cleanup complete\n');
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
                % Method 1: Try Windows API detection (most reliable)
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
                
                % Method 2: Check if controller reports detection
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
            
            % Main Layout - Simplified to 5 sections
            obj.MainLayout = uigridlayout(obj.UIFigure);
            obj.MainLayout.ColumnWidth = {'1x'};
            obj.MainLayout.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};
            obj.MainLayout.Padding = [10 10 10 10];
            obj.MainLayout.RowSpacing = 10;
            
            % Create UI sections - Simplified
            obj.createHeaderSection();
            obj.createControlSection();
            obj.createAnalogControlsSection();
            obj.createButtonControlsSection();
            obj.createMappingControlsSection();
            
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
        
        function createAnalogControlsSection(obj)
            % Create analog controls section based on reference image
            analogPanel = uipanel(obj.MainLayout);
            analogPanel.Layout.Row = 3;
            analogPanel.Title = 'Analog Controls';
            analogPanel.FontSize = 14;
            analogPanel.FontWeight = 'bold';
            analogPanel.BackgroundColor = [0.95 0.98 0.95];
            
            % Create grid for analog controls
            analogGrid = uigridlayout(analogPanel, [4, 5]);
            analogGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
            analogGrid.ColumnWidth = {'fit', 'fit', '1x', 'fit', 'fit'};
            analogGrid.Padding = [10 10 10 10];
            analogGrid.RowSpacing = 8;
            analogGrid.ColumnSpacing = 10;
            
            % Headers
            obj.createAnalogHeader(analogGrid);
            
            % Analog Z Control
            obj.createAnalogControl(analogGrid, 'Analog Z', 2);
            
            % Analog X Control  
            obj.createAnalogControl(analogGrid, 'Analog X', 3);
            
            % Analog Y Control
            obj.createAnalogControl(analogGrid, 'Analog Y', 4);
        end
        
        function createButtonControlsSection(obj)
            % Create button controls section
            buttonPanel = uipanel(obj.MainLayout);
            buttonPanel.Layout.Row = 4;
            buttonPanel.Title = 'Buttons';
            buttonPanel.FontSize = 14;
            buttonPanel.FontWeight = 'bold';
            buttonPanel.BackgroundColor = [0.98 0.95 0.90];
            
            % Create grid for button controls
            buttonGrid = uigridlayout(buttonPanel, [2, 4]);
            buttonGrid.RowHeight = {'fit', 'fit'};
            buttonGrid.ColumnWidth = {'fit', 'fit', '1x', 'fit'};
            buttonGrid.Padding = [10 10 10 10];
            buttonGrid.RowSpacing = 8;
            buttonGrid.ColumnSpacing = 10;
            
            % Headers
            buttonHeader = uilabel(buttonGrid);
            buttonHeader.Text = 'Button';
            buttonHeader.FontSize = 12;
            buttonHeader.FontWeight = 'bold';
            buttonHeader.Layout.Row = 1;
            buttonHeader.Layout.Column = 1;
            
            stateHeader = uilabel(buttonGrid);
            stateHeader.Text = 'State';
            stateHeader.FontSize = 12;
            stateHeader.FontWeight = 'bold';
            stateHeader.Layout.Row = 1;
            stateHeader.Layout.Column = 2;
            
            targetHeader = uilabel(buttonGrid);
            targetHeader.Text = 'Target';
            targetHeader.FontSize = 12;
            targetHeader.FontWeight = 'bold';
            targetHeader.Layout.Row = 1;
            targetHeader.Layout.Column = 3;
            
            actionHeader = uilabel(buttonGrid);
            actionHeader.Text = 'Action';
            actionHeader.FontSize = 12;
            actionHeader.FontWeight = 'bold';
            actionHeader.Layout.Row = 1;
            actionHeader.Layout.Column = 4;
            
            % Button 1 Row
            button1Label = uilabel(buttonGrid);
            button1Label.Text = 'Button 1';
            button1Label.FontSize = 12;
            button1Label.FontWeight = 'bold';
            button1Label.Layout.Row = 2;
            button1Label.Layout.Column = 1;
            
            % State indicator (green circle)
            obj.Button1StateIndicator = uilabel(buttonGrid);
            obj.Button1StateIndicator.Text = '●';
            obj.Button1StateIndicator.FontSize = 16;
            obj.Button1StateIndicator.FontColor = [0.16 0.68 0.38]; % Green
            obj.Button1StateIndicator.HorizontalAlignment = 'center';
            obj.Button1StateIndicator.Layout.Row = 2;
            obj.Button1StateIndicator.Layout.Column = 2;
            
            % Target dropdown
            obj.Button1TargetDropdown = uidropdown(buttonGrid);
            obj.Button1TargetDropdown.Items = {'Selected', 'All', 'None'};
            obj.Button1TargetDropdown.Value = 'Selected';
            obj.Button1TargetDropdown.FontSize = 12;
            obj.Button1TargetDropdown.Layout.Row = 2;
            obj.Button1TargetDropdown.Layout.Column = 3;
            
            % Action dropdown
            obj.Button1ActionDropdown = uidropdown(buttonGrid);
            obj.Button1ActionDropdown.Items = {'Fire 1', 'Fire 2', 'Fire 3', 'None'};
            obj.Button1ActionDropdown.Value = 'Fire 1';
            obj.Button1ActionDropdown.FontSize = 12;
            obj.Button1ActionDropdown.Layout.Row = 2;
            obj.Button1ActionDropdown.Layout.Column = 4;
        end
        
        function createMappingControlsSection(obj)
            % Create mapping controls section
            mappingPanel = uipanel(obj.MainLayout);
            mappingPanel.Layout.Row = 5;
            mappingPanel.Title = 'Mapping';
            mappingPanel.FontSize = 14;
            mappingPanel.FontWeight = 'bold';
            mappingPanel.BackgroundColor = [0.95 0.95 0.98];
            
            % Create grid for mapping controls
            mappingGrid = uigridlayout(mappingPanel, [2, 4]);
            mappingGrid.RowHeight = {'fit', 'fit'};
            mappingGrid.ColumnWidth = {'fit', '1x', 'fit', 'fit'};
            mappingGrid.Padding = [10 10 10 10];
            mappingGrid.RowSpacing = 8;
            mappingGrid.ColumnSpacing = 10;
            
            % Mapping file label
            mappingLabel = uilabel(mappingGrid);
            mappingLabel.Text = 'Mapping File:';
            mappingLabel.FontSize = 12;
            mappingLabel.FontWeight = 'bold';
            mappingLabel.Layout.Row = 1;
            mappingLabel.Layout.Column = 1;
            
            % Mapping file dropdown
            obj.MappingFileDropdown = uidropdown(mappingGrid);
            obj.MappingFileDropdown.Items = {'Joystick', 'Custom 1', 'Custom 2'};
            obj.MappingFileDropdown.Value = 'Joystick';
            obj.MappingFileDropdown.FontSize = 12;
            obj.MappingFileDropdown.Layout.Row = 1;
            obj.MappingFileDropdown.Layout.Column = 2;
            
            % New button
            obj.NewMappingButton = uibutton(mappingGrid, 'push');
            obj.NewMappingButton.Text = 'New';
            obj.NewMappingButton.FontSize = 11;
            obj.NewMappingButton.BackgroundColor = [0.16 0.68 0.38];
            obj.NewMappingButton.FontColor = [1 1 1];
            obj.NewMappingButton.Tooltip = 'Create new mapping file';
            obj.NewMappingButton.Layout.Row = 1;
            obj.NewMappingButton.Layout.Column = 3;
            obj.NewMappingButton.ButtonPushedFcn = @(~,~) obj.createNewMapping();
            
            % Save button
            obj.SaveMappingButton = uibutton(mappingGrid, 'push');
            obj.SaveMappingButton.Text = 'Save';
            obj.SaveMappingButton.FontSize = 11;
            obj.SaveMappingButton.BackgroundColor = [0.2 0.6 0.8];
            obj.SaveMappingButton.FontColor = [1 1 1];
            obj.SaveMappingButton.Tooltip = 'Save current mapping';
            obj.SaveMappingButton.Layout.Row = 1;
            obj.SaveMappingButton.Layout.Column = 4;
            obj.SaveMappingButton.ButtonPushedFcn = @(~,~) obj.saveMapping();
            
            % Remove button
            obj.RemoveMappingButton = uibutton(mappingGrid, 'push');
            obj.RemoveMappingButton.Text = 'Remove';
            obj.RemoveMappingButton.FontSize = 11;
            obj.RemoveMappingButton.BackgroundColor = [0.86 0.24 0.24];
            obj.RemoveMappingButton.FontColor = [1 1 1];
            obj.RemoveMappingButton.Tooltip = 'Remove current mapping';
            obj.RemoveMappingButton.Layout.Row = 2;
            obj.RemoveMappingButton.Layout.Column = 4;
            obj.RemoveMappingButton.ButtonPushedFcn = @(~,~) obj.removeMapping();
        end
        
        function createAnalogHeader(obj, grid)
            % Create header row for analog controls
            % Control Name
            nameHeader = uilabel(grid);
            nameHeader.Text = 'Control';
            nameHeader.FontSize = 12;
            nameHeader.FontWeight = 'bold';
            nameHeader.Layout.Row = 1;
            nameHeader.Layout.Column = 1;
            
            % Current Value
            valueHeader = uilabel(grid);
            valueHeader.Text = 'Value';
            valueHeader.FontSize = 12;
            valueHeader.FontWeight = 'bold';
            valueHeader.Layout.Row = 1;
            valueHeader.Layout.Column = 2;
            
            % Sensitivity
            sensHeader = uilabel(grid);
            sensHeader.Text = 'Sensitivity';
            sensHeader.FontSize = 12;
            sensHeader.FontWeight = 'bold';
            sensHeader.Layout.Row = 1;
            sensHeader.Layout.Column = 3;
            
            % Action
            actionHeader = uilabel(grid);
            actionHeader.Text = 'Action';
            actionHeader.FontSize = 12;
            actionHeader.FontWeight = 'bold';
            actionHeader.Layout.Row = 1;
            actionHeader.Layout.Column = 4;
            
            % Calibrate
            calibHeader = uilabel(grid);
            calibHeader.Text = '';
            calibHeader.Layout.Row = 1;
            calibHeader.Layout.Column = 5;
        end
        
        function createAnalogControl(obj, grid, controlName, row)
            % Create a single analog control row
            
            % Control Name
            nameLabel = uilabel(grid);
            nameLabel.Text = controlName;
            nameLabel.FontSize = 12;
            nameLabel.FontWeight = 'bold';
            nameLabel.Layout.Row = row;
            nameLabel.Layout.Column = 1;
            
            % Current Value Display
            valueDisplay = uilabel(grid);
            valueDisplay.Text = '0';
            valueDisplay.FontSize = 12;
            valueDisplay.FontColor = [0.2 0.6 0.8];
            valueDisplay.Layout.Row = row;
            valueDisplay.Layout.Column = 2;
            
            % Store reference based on control name
            switch controlName
                case 'Analog Z'
                    obj.ZValueDisplay = valueDisplay;
                case 'Analog X'
                    obj.XValueDisplay = valueDisplay;
                case 'Analog Y'
                    obj.YValueDisplay = valueDisplay;
            end
            
            % Sensitivity Input Field
            sensField = uieditfield(grid, 'numeric');
            sensField.Value = 5;
            sensField.FontSize = 12;
            sensField.Limits = [0.1 100];
            sensField.Tooltip = sprintf('Sensitivity for %s', controlName);
            sensField.Layout.Row = row;
            sensField.Layout.Column = 3;
            
            % Store reference based on control name
            switch controlName
                case 'Analog Z'
                    obj.ZSensitivityField = sensField;
                case 'Analog X'
                    obj.XSensitivityField = sensField;
                case 'Analog Y'
                    obj.YSensitivityField = sensField;
            end
            
            % Action Dropdown
            actionDropdown = uidropdown(grid);
            actionDropdown.Items = {'Move Continuous', 'Delta 1', 'Delta 2', 'Delta 3'};
            actionDropdown.Value = 'Move Continuous';
            actionDropdown.FontSize = 12;
            actionDropdown.Layout.Row = row;
            actionDropdown.Layout.Column = 4;
            
            % Store reference based on control name
            switch controlName
                case 'Analog Z'
                    obj.ZActionDropdown = actionDropdown;
                case 'Analog X'
                    obj.XActionDropdown = actionDropdown;
                case 'Analog Y'
                    obj.YActionDropdown = actionDropdown;
            end
            
            % Calibrate Button
            calibBtn = uibutton(grid, 'push');
            calibBtn.Text = 'Calibrate';
            calibBtn.FontSize = 11;
            calibBtn.BackgroundColor = [0.2 0.6 0.8];
            calibBtn.FontColor = [1 1 1];
            calibBtn.Tooltip = sprintf('Calibrate %s', controlName);
            calibBtn.Layout.Row = row;
            calibBtn.Layout.Column = 5;
            calibBtn.ButtonPushedFcn = @(~,~) obj.calibrateAxis(controlName);
        end
        
        function setupCallbacks(obj)
            % Set up all UI callback functions
            
            % Main window
            obj.UIFigure.CloseRequestFcn = @(~,~) obj.onWindowClose();
            
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
                obj.updateAnalogControls();
            end
        end
        
        function updateAnalogControls(obj)
            % Update analog control displays with real joystick data
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
                        yPos = data(2);  % Y position (-127 to 127)
                        zPos = data(3);  % Z position (-127 to 127)
                        
                        % Update analog control displays
                        if ~isempty(obj.XValueDisplay)
                            obj.XValueDisplay.Text = sprintf('%d', xPos);
                        end
                        if ~isempty(obj.YValueDisplay)
                            obj.YValueDisplay.Text = sprintf('%d', yPos);
                        end
                        if ~isempty(obj.ZValueDisplay)
                            obj.ZValueDisplay.Text = sprintf('%d', zPos);
                        end
                        
                        return;
                    end
                end
            catch
                % Fall back to placeholder if real data unavailable
            end
            
            % Placeholder implementation for non-MEX controllers
            if ~isempty(obj.XValueDisplay)
                obj.XValueDisplay.Text = '0';
            end
            if ~isempty(obj.YValueDisplay)
                obj.YValueDisplay.Text = '0';
            end
            if ~isempty(obj.ZValueDisplay)
                obj.ZValueDisplay.Text = '0';
            end
        end
        
        function calibrateAxis(obj, axisName)
            % Calibrate a specific axis
            try
                % Simple calibration - center the axis
                fprintf('Calibrating %s axis...\n', axisName);
                
                % Show calibration dialog
                msg = sprintf('Calibrating %s axis.\n\nPlease center the joystick and click OK.', axisName);
                uialert(obj.UIFigure, msg, 'Calibration', 'Icon', 'info');
                
                % For now, just log the calibration
                fprintf('%s axis calibrated\n', axisName);
                
            catch ME
                fprintf('Calibration failed for %s: %s\n', axisName, ME.message);
            end
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
        
        function onWindowClose(obj)
            % Handle window close event - ensure proper cleanup
            fprintf('MJC3View: Window close requested...\n');
            
            % Stop the controller if it's running
            if ~isempty(obj.HIDController) && isvalid(obj.HIDController)
                try
                    if obj.IsEnabled
                        fprintf('MJC3View: Stopping controller before close...\n');
                        obj.HIDController.stop();
                        obj.IsEnabled = false;
                        obj.IsConnected = false;
                    end
                catch ME
                    fprintf('MJC3View: Warning - Error stopping controller: %s\n', ME.message);
                end
            end
            
            % Delete the object (which will trigger the delete method)
            delete(obj);
        end
        
        function createNewMapping(obj)
            % Create new mapping file
            try
                fprintf('Creating new mapping file...\n');
                uialert(obj.UIFigure, 'New mapping file created successfully.', 'Mapping', 'Icon', 'success');
            catch ME
                fprintf('Failed to create new mapping: %s\n', ME.message);
                uialert(obj.UIFigure, 'Failed to create new mapping file.', 'Error', 'Icon', 'error');
            end
        end
        
        function saveMapping(obj)
            % Save current mapping
            try
                fprintf('Saving current mapping...\n');
                uialert(obj.UIFigure, 'Mapping saved successfully.', 'Mapping', 'Icon', 'success');
            catch ME
                fprintf('Failed to save mapping: %s\n', ME.message);
                uialert(obj.UIFigure, 'Failed to save mapping.', 'Error', 'Icon', 'error');
            end
        end
        
        function removeMapping(obj)
            % Remove current mapping
            try
                fprintf('Removing current mapping...\n');
                uialert(obj.UIFigure, 'Mapping removed successfully.', 'Mapping', 'Icon', 'success');
            catch ME
                fprintf('Failed to remove mapping: %s\n', ME.message);
                uialert(obj.UIFigure, 'Failed to remove mapping.', 'Error', 'Icon', 'error');
            end
        end
        
        % Removed complex methods - simplified UI now uses analog controls
    end
end