classdef HIDController < handle
    % HIDController - Manages MJC3 HID joystick integration with ScanImage
    %
    % This controller bridges the MJC3_HID_Controller with the main application,
    % providing UI integration and status management for joystick-based Z-control.
    
    properties (Access = private)
        hidController    % Instance of MJC3_HID_Controller
        zController     % Z-axis controller (must implement relativeMove method)
        uiComponents    % UI components for HID controls
        isEnabled       % Current enable/disable state
        stepFactor      % Current step factor setting
    end
    
    properties (Constant)
        DEFAULT_STEP_FACTOR = 5;  % Default micrometers per joystick unit
        POLL_RATE = 0.05;         % 20 Hz polling rate
    end
    
    methods
        function obj = HIDController(uiComponents, zController)
            % Constructor
            % uiComponents: struct containing HID UI controls from UiBuilder
            % zController: object that implements relativeMove(dz) method
            
            if nargin < 2
                error('HIDController requires UI components and Z-controller');
            end
            
            obj.uiComponents = uiComponents;
            obj.zController = zController;
            obj.isEnabled = false;
            obj.stepFactor = obj.DEFAULT_STEP_FACTOR;
            obj.hidController = [];
            
            obj.setupUICallbacks();
            obj.updateUI();
        end
        
        function delete(obj)
            % Destructor - ensure HID controller is properly cleaned up
            obj.disable();
        end
        
        function enable(obj)
            % Enable MJC3 joystick control
            try
                if obj.isEnabled
                    return; % Already enabled
                end
                
                % Check if Psychtoolbox is available
                if ~exist('PsychHID', 'file')
                    error('Psychtoolbox not found. Please install Psychtoolbox to use MJC3 joystick control.');
                end
                
                % Create and start HID controller
                obj.hidController = MJC3_HID_Controller(obj.zController, obj.stepFactor);
                obj.hidController.start();
                
                obj.isEnabled = true;
                obj.updateUI();
                
                fprintf('MJC3 HID Controller enabled (Step factor: %.1f μm/unit)\n', obj.stepFactor);
                
            catch ME
                obj.isEnabled = false;
                obj.updateUI();
                
                % Show user-friendly error message
                if contains(ME.message, 'MJC3 HID joystick not found')
                    errordlg('MJC3 joystick not detected. Please check USB connection.', 'Joystick Not Found');
                elseif contains(ME.message, 'Psychtoolbox')
                    errordlg('Psychtoolbox is required for joystick control. Please install Psychtoolbox.', 'Missing Dependency');
                else
                    errordlg(sprintf('Failed to enable joystick control: %s', ME.message), 'HID Controller Error');
                end
                
                warning('Failed to enable MJC3 HID Controller: %s', ME.message);
            end
        end
        
        function disable(obj)
            % Disable MJC3 joystick control
            try
                if ~isempty(obj.hidController)
                    obj.hidController.stop();
                    delete(obj.hidController);
                    obj.hidController = [];
                end
                
                obj.isEnabled = false;
                obj.updateUI();
                
                fprintf('MJC3 HID Controller disabled\n');
                
            catch ME
                warning('Error disabling MJC3 HID Controller: %s', ME.message);
            end
        end
        
        function setStepFactor(obj, newStepFactor)
            % Update the step factor for joystick sensitivity
            if newStepFactor <= 0
                warning('Step factor must be positive. Using default value.');
                newStepFactor = obj.DEFAULT_STEP_FACTOR;
            end
            
            obj.stepFactor = newStepFactor;
            
            % Update the HID controller if it's running
            if ~isempty(obj.hidController)
                obj.hidController.stepFactor = newStepFactor;
            end
            
            % Update UI
            obj.uiComponents.StepFactorField.Value = newStepFactor;
        end
        
        function showSettings(obj)
            % Show settings dialog for MJC3 configuration
            
            % Create settings dialog
            dlg = uifigure('Name', 'MJC3 Joystick Settings', 'Position', [100 100 400 300]);
            dlg.Resize = 'off';
            
            grid = uigridlayout(dlg, [6, 2]);
            grid.RowHeight = {'fit', 'fit', 'fit', 'fit', '1x', 'fit'};
            grid.ColumnWidth = {'fit', '1x'};
            grid.Padding = [20 20 20 20];
            grid.RowSpacing = 15;
            grid.ColumnSpacing = 10;
            
            % Title
            titleLabel = uilabel(grid);
            titleLabel.Text = 'MJC3 Joystick Configuration';
            titleLabel.FontSize = 16;
            titleLabel.FontWeight = 'bold';
            titleLabel.Layout.Row = 1;
            titleLabel.Layout.Column = [1 2];
            
            % Step Factor
            stepLabel = uilabel(grid);
            stepLabel.Text = 'Step Factor (μm/unit):';
            stepLabel.Layout.Row = 2;
            stepLabel.Layout.Column = 1;
            
            stepField = uieditfield(grid, 'numeric');
            stepField.Value = obj.stepFactor;
            stepField.Limits = [0.1 100];
            stepField.Layout.Row = 2;
            stepField.Layout.Column = 2;
            
            % Poll Rate Info
            pollLabel = uilabel(grid);
            pollLabel.Text = 'Poll Rate:';
            pollLabel.Layout.Row = 3;
            pollLabel.Layout.Column = 1;
            
            pollInfo = uilabel(grid);
            pollInfo.Text = sprintf('%.0f Hz (fixed)', 1/obj.POLL_RATE);
            pollInfo.FontColor = [0.5 0.5 0.5];
            pollInfo.Layout.Row = 3;
            pollInfo.Layout.Column = 2;
            
            % Device Info
            deviceLabel = uilabel(grid);
            deviceLabel.Text = 'Device Info:';
            deviceLabel.Layout.Row = 4;
            deviceLabel.Layout.Column = 1;
            
            deviceInfo = uilabel(grid);
            if obj.isEnabled
                deviceInfo.Text = '✅ Connected (VID:1313, PID:9000)';
                deviceInfo.FontColor = [0 0.7 0];
            else
                deviceInfo.Text = '❌ Not connected';
                deviceInfo.FontColor = [0.7 0 0];
            end
            deviceInfo.Layout.Row = 4;
            deviceInfo.Layout.Column = 2;
            
            % Help text
            helpText = uitextarea(grid);
            helpText.Value = {
                'The MJC3 joystick controls Z-axis movement:', ...
                '', ...
                '• Z-axis: Move joystick up/down for Z movement', ...
                '• Speed knob: Controls movement speed (0-100%)', ...
                '• Step factor: Micrometers moved per joystick unit', ...
                '', ...
                'Higher step factor = more sensitive movement'
            };
            helpText.Editable = 'off';
            helpText.Layout.Row = 5;
            helpText.Layout.Column = [1 2];
            
            % Buttons
            buttonGrid = uigridlayout(grid, [1, 3]);
            buttonGrid.Layout.Row = 6;
            buttonGrid.Layout.Column = [1 2];
            buttonGrid.ColumnWidth = {'1x', 'fit', 'fit'};
            buttonGrid.ColumnSpacing = 10;
            
            % Spacer
            uilabel(buttonGrid);
            
            % Apply button
            applyBtn = uibutton(buttonGrid, 'push');
            applyBtn.Text = 'Apply';
            applyBtn.ButtonPushedFcn = @(~,~) obj.applySettings(stepField.Value, dlg);
            
            % Close button
            closeBtn = uibutton(buttonGrid, 'push');
            closeBtn.Text = 'Close';
            closeBtn.ButtonPushedFcn = @(~,~) close(dlg);
        end
    end
    
    methods (Access = private)
        function setupUICallbacks(obj)
            % Set up callbacks for UI components
            
            % Enable/Disable button
            obj.uiComponents.EnableButton.ButtonPushedFcn = @(~,~) obj.toggleEnable();
            
            % Step factor field
            obj.uiComponents.StepFactorField.ValueChangedFcn = @(src,~) obj.setStepFactor(src.Value);
            
            % Settings button
            obj.uiComponents.SettingsButton.ButtonPushedFcn = @(~,~) obj.showSettings();
        end
        
        function toggleEnable(obj)
            % Toggle enable/disable state
            if obj.isEnabled
                obj.disable();
            else
                obj.enable();
            end
        end
        
        function updateUI(obj)
            % Update UI components to reflect current state
            
            if obj.isEnabled
                obj.uiComponents.EnableButton.Text = '⏸ Disable';
                obj.uiComponents.EnableButton.BackgroundColor = [0.8 0.4 0.4]; % Red-ish for disable
                obj.uiComponents.StatusLabel.Text = '🟢 Connected';
                obj.uiComponents.StatusLabel.FontColor = [0 0.7 0]; % Green
            else
                obj.uiComponents.EnableButton.Text = '▶ Enable';
                obj.uiComponents.EnableButton.BackgroundColor = [0.4 0.7 0.4]; % Green-ish for enable
                obj.uiComponents.StatusLabel.Text = '⚪ Disconnected';
                obj.uiComponents.StatusLabel.FontColor = [0.5 0.5 0.5]; % Gray
            end
            
            % Update step factor display
            obj.uiComponents.StepFactorField.Value = obj.stepFactor;
        end
        
        function applySettings(obj, newStepFactor, dialog)
            % Apply settings from the settings dialog
            obj.setStepFactor(newStepFactor);
            close(dialog);
            
            % Show confirmation
            uialert(obj.uiComponents.EnableButton.Parent.Parent, ...
                sprintf('Settings applied. Step factor: %.1f μm/unit', obj.stepFactor), ...
                'Settings Updated', 'Icon', 'success');
        end
    end
end