%==============================================================================
% HIDCONTROLLER.M
%==============================================================================
% HID (Human Interface Device) controller for MJC3 joystick integration.
%
% This controller manages the MJC3 joystick device and provides a bridge between
% the physical joystick hardware and the main Foilview application. It handles
% device connection, joystick polling, and Z-axis movement control through
% the MJC3_MEX_Controller.
%
% Key Features:
%   - MJC3 joystick device detection and connection
%   - Real-time joystick polling (20Hz)
%   - Configurable step factor for movement sensitivity
%   - UI integration with enable/disable controls
%   - Settings dialog for joystick configuration
%   - Error handling for device connection issues
%
% Dependencies:
%   - MJC3_MEX_Controller: Low-level joystick interface
%   - MJC3ControllerFactory: Controller creation and management
%   - LoggingService: Unified logging system
%   - Z-controller: Stage movement interface (must implement relativeMove)
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   hidController = HIDController(uiComponents, zController);
%   hidController.enable();  % Enable joystick control
%   hidController.setStepFactor(5.0);  % Set sensitivity
%
%==============================================================================

classdef HIDController < handle
    % HIDController - Manages MJC3 joystick integration with ScanImage
    %
    % This controller bridges the MJC3_MEX_Controller with the main application,
    % providing UI integration and status management for joystick-based Z-control.
    
    properties (Access = private)
        zController     % Z-axis controller (must implement relativeMove method)
        uiComponents    % UI components for HID controls
        isEnabled       % Current enable/disable state
        stepFactor      % Current step factor setting
        Logger          % Logging service for structured output
    end
    
    properties (Access = public)
        hidController    % Instance of MJC3_MEX_Controller (public for external access)
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
            
            % Initialize logger
            obj.Logger = LoggingService('HIDController', 'SuppressInitMessage', true);
            
            obj.uiComponents = uiComponents;
            obj.zController = zController;
            obj.isEnabled = false;
            obj.stepFactor = obj.DEFAULT_STEP_FACTOR;
            obj.hidController = [];
            
            obj.Logger.info('HID controller initialized with step factor: %.1f μm/unit', obj.stepFactor);
            
            obj.setupUICallbacks();
            obj.updateUI();
        end
        
        function delete(obj)
            % Destructor - ensure HID controller is properly cleaned up
            obj.Logger.info('Cleaning up HID controller');
            obj.disable();
        end
        
        function enable(obj)
            % Enable MJC3 joystick control
            try
                if obj.isEnabled
                    obj.Logger.debug('Already enabled, skipping');
                    return; % Already enabled
                end
                
                obj.Logger.info('Enabling MJC3 joystick control...');
                
                % Create and start MEX controller using factory
                obj.hidController = MJC3ControllerFactory.createController(obj.zController, obj.stepFactor);
                obj.hidController.start();
                
                obj.isEnabled = true;
                obj.updateUI();
                
                obj.Logger.info('Joystick control enabled (Step factor: %.1f μm/unit)', obj.stepFactor);
                
            catch ME
                obj.isEnabled = false;
                obj.updateUI();
                
                obj.Logger.error('Failed to enable joystick control: %s', ME.message);
                
                % Show user-friendly error message
                if contains(ME.message, 'MEX function') || contains(ME.message, 'mjc3_joystick_mex')
                    errordlg('MEX controller not available. Please run build_mjc3_mex() to compile the MEX function.', 'MEX Not Found');
                    obj.Logger.warning('MEX controller not available - run build_mjc3_mex() to enable');
                elseif contains(ME.message, 'MJC3 device not connected')
                    errordlg('MJC3 joystick not detected. Please check USB connection.', 'Joystick Not Found');
                    obj.Logger.warning('MJC3 device not detected - check USB connection');
                else
                    errordlg(sprintf('Failed to enable joystick control: %s', ME.message), 'Controller Error');
                    obj.Logger.error('Unknown error during enable: %s', ME.message);
                end
            end
        end
        
        function disable(obj)
            % Disable MJC3 joystick control
            try
                if ~isempty(obj.hidController)
                    obj.Logger.info('Stopping joystick controller...');
                    obj.hidController.disable();
                    delete(obj.hidController);
                    obj.hidController = [];
                end
                
                obj.isEnabled = false;
                obj.updateUI();
                
                obj.Logger.info('Joystick control disabled');
                
            catch ME
                obj.Logger.error('Error disabling joystick control: %s', ME.message);
            end
        end
        
        function setStepFactor(obj, newStepFactor)
            % Update the step factor for joystick sensitivity
            if newStepFactor <= 0
                obj.Logger.warning('Step factor must be positive. Using default value.');
                newStepFactor = obj.DEFAULT_STEP_FACTOR;
            end
            
            obj.stepFactor = newStepFactor;
            obj.Logger.info('Step factor updated to %.1f μm/unit', newStepFactor);
            
            % Update the HID controller if it's running
            if ~isempty(obj.hidController)
                obj.hidController.setStepFactor(newStepFactor);
            end
            
            % Update UI
            obj.uiComponents.StepFactorField.Value = newStepFactor;
        end
        
        function showSettings(obj)
            % Show settings dialog for MJC3 configuration
            
            obj.Logger.info('Opening settings dialog');
            
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
                obj.Logger.info('User requested disable');
                obj.disable();
            else
                obj.Logger.info('User requested enable');
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
                obj.Logger.debug('UI updated: Enabled state');
            else
                obj.uiComponents.EnableButton.Text = '▶ Enable';
                obj.uiComponents.EnableButton.BackgroundColor = [0.4 0.7 0.4]; % Green-ish for enable
                obj.uiComponents.StatusLabel.Text = '⚪ Disconnected';
                obj.uiComponents.StatusLabel.FontColor = [0.5 0.5 0.5]; % Gray
                obj.Logger.debug('UI updated: Disabled state');
            end
            
            % Update step factor display
            obj.uiComponents.StepFactorField.Value = obj.stepFactor;
        end
        
        function applySettings(obj, newStepFactor, dialog)
            % Apply settings from the settings dialog
            obj.Logger.info('Applying settings from dialog');
            obj.setStepFactor(newStepFactor);
            close(dialog);
            
            % Show confirmation
            uialert(obj.uiComponents.EnableButton.Parent.Parent, ...
                sprintf('Settings applied. Step factor: %.1f μm/unit', obj.stepFactor), ...
                'Settings Updated', 'Icon', 'success');
        end
    end
end