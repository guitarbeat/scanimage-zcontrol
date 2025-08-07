%==============================================================================
% MJC3VIEW.M
%==============================================================================
% UI view class for MJC3 joystick control in Foilview.
%
% This class implements the user interface for MJC3 joystick control, including
% manual and auto-stepping controls, metric display, and status reporting. It
% integrates with the controller and service layers to provide a responsive and
% interactive user experience for Z-control and focus optimization.
%
% Key Features:
%   - Manual and auto-stepping controls
%   - Real-time metric and position display
%   - Status and error reporting
%   - Integration with MJC3 controller and services
%   - UI layout and style management
%
% Dependencies:
%   - FoilviewController: Main controller
%   - UIController: UI state management
%   - MATLAB App Designer: UI components
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   view = MJC3View(app, controller);
%
%==============================================================================

classdef MJC3View < handle
    % MJC3View - Dedicated window for MJC3 Joystick Control
    % Provides a separate interface for joystick configuration, monitoring, and control
    
    properties (Access = public)
        % UI Components
        UIFigure
        MainLayout
        
        % Essential Control Components (simplified)
        EnableButton
        StatusLabel
        StepFactorField
        ConnectionStatus
        
        % State Management (public for testing and external access)
        IsEnabled = false
        IsConnected = false
        
        % Crash prevention flags (public for testing and external monitoring)
        IsClosing = false
        IsDeleting = false
        CleanupComplete = false
    end
    
    properties (Access = private)
        % Controller Reference
        HIDController
        
        % Monitoring
        UpdateTimer
        MovementData = struct('time', {}, 'direction', {}, 'type', {})
        
        % UI State
        WindowPosition = [300, 300, 400, 600]  % Default window size and position
        
        % Logging
        Logger
        
        % Hardware detection cache
        HardwareDetectionCache = struct('isDetected', false, 'lastCheck', 0, 'cacheTimeout', 5.0)
        
        % Preview timers for axis calibration
        PreviewTimers
    end
    
    methods
        function obj = MJC3View()
            % Constructor: Creates the MJC3 control window
            
            % Initialize logger
            obj.Logger = LoggingService('MJC3View', 'SuppressInitMessage', true);
            
            % Initialize PreviewTimers to avoid sharing between instances
            obj.PreviewTimers = containers.Map();
            
            obj.createUI();
            obj.setupCallbacks();
            obj.initialize();
        end
        
        function delete(obj)
            % Destructor: Clean up resources with crash prevention
            
            % Prevent recursive deletion
            if obj.IsDeleting || obj.CleanupComplete
                return;
            end
            obj.IsDeleting = true;
            
            try
                obj.Logger.info('Cleaning up MJC3 view resources...');
                
                % Stop monitoring timer first (most crash-prone)
                obj.safeStopMonitoring();
                
                % Stop and disconnect the controller
                obj.safeStopController();
                
                % Delete UI figure safely
                obj.safeDeleteUIFigure();
                
                obj.CleanupComplete = true;
                obj.Logger.info('MJC3 view cleanup complete');
                
            catch ME
                obj.Logger.error('Error during cleanup: %s', ME.message);
                % Force cleanup completion to prevent hanging
                obj.CleanupComplete = true;
            end
        end
        
        function setController(obj, controller)
            % Set the HID controller reference with robust error handling
            try
                % Validate the controller if provided
                if ~isempty(controller)
                    if ~isvalid(controller)
                        obj.Logger.warning('Invalid controller provided - ignoring');
                        controller = [];
                    else
                        % Display controller type information
                        controllerType = class(controller);
                        if contains(controllerType, 'MEX')
                            obj.Logger.info('Using high-performance MEX controller');
                        else
                            obj.Logger.info('Using %s controller', controllerType);
                        end
                    end
                else
                    obj.Logger.warning('No controller provided (manual mode)');
                end
                
                % Set the controller reference
                obj.HIDController = controller;
                
                % Check controller connection status
                if ~isempty(obj.HIDController) && isvalid(obj.HIDController)
                    try
                        % Check if controller reports being connected
                        if ismethod(obj.HIDController, 'connectToMJC3')
                            obj.IsConnected = obj.HIDController.connectToMJC3();
                            obj.Logger.debug('Controller connection status: %s', mat2str(obj.IsConnected));
                        else
                            % For simulation controllers, assume connected
                            obj.IsConnected = true;
                            obj.Logger.info('Simulation controller - assuming connected');
                        end
                    catch ME
                        obj.Logger.warning('Error checking controller connection: %s', ME.message);
                        obj.IsConnected = false;
                    end
                else
                    obj.IsConnected = false;
                end
                
                % Update UI state
                obj.updateConnectionStatus();
                obj.detectHardware(); % Check hardware detection status
                obj.updateUI(); % Update button state based on new controller
                
            catch ME
                obj.Logger.error('Error setting controller: %s', ME.message);
                % Clear controller reference on error
                obj.HIDController = [];
                obj.IsEnabled = false;
                obj.IsConnected = false;
            end
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
            % Uses caching to prevent repeated detection checks and logging
            
            % Check cache first
            currentTime = now;
            if currentTime - obj.HardwareDetectionCache.lastCheck < obj.HardwareDetectionCache.cacheTimeout / 86400
                isDetected = obj.HardwareDetectionCache.isDetected;
                return;
            end
            
            isDetected = false;
            
            try
                % Method 1: Try Windows API detection (most reliable)
                try
                    cmd = 'powershell "Get-WmiObject Win32_PnPEntity | Where-Object {$_.DeviceID -like ''*VID_1313*'' -and $_.DeviceID -like ''*PID_9000*''} | Select-Object Name, DeviceID"';
                    [status, result] = system(cmd);
                    
                    if status == 0 && contains(result, 'VID_1313')
                        isDetected = true;
                        % Only log if this is a new detection (not cached)
                        if ~obj.HardwareDetectionCache.isDetected
                            obj.Logger.info('MJC3 hardware detected via Windows API');
                        end
                        % Update cache
                        obj.HardwareDetectionCache.isDetected = isDetected;
                        obj.HardwareDetectionCache.lastCheck = currentTime;
                        return;
                    end
                catch
                    % Windows API failed, continue
                    obj.Logger.debug('Windows API detection failed, trying alternative method');
                end
                
                % Method 2: Check if controller reports detection
                if ~isempty(obj.HIDController)
                    % Try the connectToMJC3 method to check detection
                    isDetected = obj.HIDController.connectToMJC3();
                    if isDetected
                        % Only log if this is a new detection (not cached)
                        if ~obj.HardwareDetectionCache.isDetected
                            obj.Logger.info('MJC3 hardware detected via controller');
                        end
                    else
                        % Only log if this is a new non-detection (not cached)
                        if obj.HardwareDetectionCache.isDetected
                            obj.Logger.warning('MJC3 hardware not detected via controller');
                        end
                    end
                end
                
                % Update cache
                obj.HardwareDetectionCache.isDetected = isDetected;
                obj.HardwareDetectionCache.lastCheck = currentTime;
                
            catch ME
                obj.Logger.error('Hardware detection check failed: %s', ME.message);
                % Don't update cache on error, keep previous result
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
            
            % Log the current status for debugging
            obj.Logger.debug('Connection status updated - IsEnabled: %s, IsConnected: %s, HardwareDetected: %s', ...
                mat2str(obj.IsEnabled), mat2str(obj.IsConnected), mat2str(obj.checkHardwareDetection()));
        end
        
        function detectHardware(obj)
            % Detect MJC3 hardware and update status
            isDetected = obj.checkHardwareDetection();
            if isDetected
                obj.Logger.info('MJC3 hardware detected');
            else
                obj.Logger.info('MJC3 hardware not detected');
            end
            obj.updateConnectionStatus();
        end
    end
    
    methods (Access = private)
        function createUI(obj)
            % Create and configure all UI components - MAXIMUM COMPATIBILITY VERSION
            
            try
                % Main Figure - Use basic uifigure only
                obj.UIFigure = uifigure('Visible', 'off');
                obj.UIFigure.Name = 'MJC3 Joystick Control';
                obj.UIFigure.Position = [300, 300, 350, 480];
                obj.UIFigure.Color = [0.96 0.96 0.98];
                
                % Use absolute positioning instead of grid layout for maximum compatibility
                obj.createBasicUI();
                
                % Make figure visible
                obj.UIFigure.Visible = 'on';
                
            catch ME
                obj.Logger.error('Error creating UI: %s', ME.message);
                % Clean up on error
                if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                    delete(obj.UIFigure);
                    obj.UIFigure = [];
                end
                rethrow(ME);
            end
        end
        
        function createBasicUI(obj)
            % Create UI using basic components with absolute positioning for maximum compatibility
            
            % Title
            titleLabel = uilabel(obj.UIFigure);
            titleLabel.Text = 'MJC3 Joystick Control';
            titleLabel.FontSize = 18;
            titleLabel.FontWeight = 'bold';
            titleLabel.HorizontalAlignment = 'center';
            titleLabel.FontColor = [0.2 0.2 0.4];
            titleLabel.Position = [20, 400, 310, 30];
            
            % Connection Status
            obj.ConnectionStatus = uilabel(obj.UIFigure);
            obj.ConnectionStatus.Text = 'Disconnected';
            obj.ConnectionStatus.FontSize = 14;
            obj.ConnectionStatus.FontWeight = 'bold';
            obj.ConnectionStatus.HorizontalAlignment = 'center';
            obj.ConnectionStatus.FontColor = [0.8 0.2 0.2];
            obj.ConnectionStatus.Position = [20, 370, 310, 25];
            
            % Enable Button - Large and prominent
            obj.EnableButton = uibutton(obj.UIFigure, 'push');
            obj.EnableButton.Text = 'Enable Joystick';
            obj.EnableButton.FontSize = 16;
            obj.EnableButton.FontWeight = 'bold';
            obj.EnableButton.BackgroundColor = [0.16 0.68 0.38];
            obj.EnableButton.FontColor = [1 1 1];
            obj.EnableButton.Position = [50, 320, 250, 40];
            obj.EnableButton.Tooltip = 'Click to enable/disable joystick control';
            
            % Speed Section
            speedLabel = uilabel(obj.UIFigure);
            speedLabel.Text = 'Movement Speed:';
            speedLabel.FontSize = 14;
            speedLabel.FontWeight = 'bold';
            speedLabel.HorizontalAlignment = 'center';
            speedLabel.FontColor = [0.3 0.3 0.5];
            speedLabel.Position = [20, 280, 310, 25];
            
            % Speed Buttons
            slowButton = uibutton(obj.UIFigure, 'push');
            slowButton.Text = 'Slow';
            slowButton.FontSize = 12;
            slowButton.BackgroundColor = [0.9 0.9 0.95];
            slowButton.Position = [30, 245, 80, 30];
            slowButton.ButtonPushedFcn = @(~,~) obj.setSpeed(1);
            slowButton.Tooltip = 'Slow, precise movement (1 μm/unit)';
            
            mediumButton = uibutton(obj.UIFigure, 'push');
            mediumButton.Text = 'Medium';
            mediumButton.FontSize = 12;
            mediumButton.BackgroundColor = [0.8 0.9 0.8];
            mediumButton.Position = [135, 245, 80, 30];
            mediumButton.ButtonPushedFcn = @(~,~) obj.setSpeed(5);
            mediumButton.Tooltip = 'Medium speed movement (5 μm/unit)';
            
            fastButton = uibutton(obj.UIFigure, 'push');
            fastButton.Text = 'Fast';
            fastButton.FontSize = 12;
            fastButton.BackgroundColor = [0.9 0.8 0.8];
            fastButton.Position = [240, 245, 80, 30];
            fastButton.ButtonPushedFcn = @(~,~) obj.setSpeed(20);
            fastButton.Tooltip = 'Fast movement (20 μm/unit)';
            
            % Current Speed Display
            speedFieldLabel = uilabel(obj.UIFigure);
            speedFieldLabel.Text = 'Custom Speed:';
            speedFieldLabel.FontSize = 12;
            speedFieldLabel.FontWeight = 'bold';
            speedFieldLabel.HorizontalAlignment = 'left';
            speedFieldLabel.FontColor = [0.3 0.3 0.5];
            speedFieldLabel.Position = [30, 210, 120, 20];
            
            obj.StepFactorField = uieditfield(obj.UIFigure, 'numeric');
            obj.StepFactorField.Value = 5;
            obj.StepFactorField.FontSize = 12;
            obj.StepFactorField.Limits = [0.1 100];
            obj.StepFactorField.HorizontalAlignment = 'center';
            obj.StepFactorField.Position = [160, 208, 80, 25];
            obj.StepFactorField.Tooltip = 'Custom speed: micrometers moved per joystick unit';
            
            speedUnitsLabel = uilabel(obj.UIFigure);
            speedUnitsLabel.Text = 'μm/unit';
            speedUnitsLabel.FontSize = 11;
            speedUnitsLabel.FontColor = [0.5 0.5 0.5];
            speedUnitsLabel.HorizontalAlignment = 'left';
            speedUnitsLabel.Position = [250, 210, 60, 20];
            
            % Calibration Section
            calibrationLabel = uilabel(obj.UIFigure);
            calibrationLabel.Text = 'Calibration:';
            calibrationLabel.FontSize = 14;
            calibrationLabel.FontWeight = 'bold';
            calibrationLabel.HorizontalAlignment = 'center';
            calibrationLabel.FontColor = [0.3 0.3 0.5];
            calibrationLabel.Position = [20, 150, 310, 25];
            
            % Manual Calibration Button
            manualCalButton = uibutton(obj.UIFigure, 'push');
            manualCalButton.Text = 'Manual Calibration';
            manualCalButton.FontSize = 12;
            manualCalButton.FontWeight = 'bold';
            manualCalButton.BackgroundColor = [0.85 0.9 1.0];
            manualCalButton.Position = [30, 120, 200, 25];
            manualCalButton.ButtonPushedFcn = @(~,~) obj.openManualCalibration();
            manualCalButton.Tooltip = 'Open detailed calibration settings';
            
            % Reset Calibration Button
            resetCalButton = uibutton(obj.UIFigure, 'push');
            resetCalButton.Text = 'Reset';
            resetCalButton.FontSize = 12;
            resetCalButton.BackgroundColor = [0.95 0.9 0.9];
            resetCalButton.Position = [240, 120, 80, 25];
            resetCalButton.ButtonPushedFcn = @(~,~) obj.resetCalibration();
            resetCalButton.Tooltip = 'Reset all calibration to defaults';
            
            % Status Section
            statusTitle = uilabel(obj.UIFigure);
            statusTitle.Text = 'Status:';
            statusTitle.FontSize = 12;
            statusTitle.FontWeight = 'bold';
            statusTitle.HorizontalAlignment = 'center';
            statusTitle.FontColor = [0.3 0.3 0.5];
            statusTitle.Position = [20, 75, 310, 20];
            
            obj.StatusLabel = uilabel(obj.UIFigure);
            obj.StatusLabel.Text = 'Ready';
            obj.StatusLabel.FontSize = 14;
            obj.StatusLabel.FontWeight = 'bold';
            obj.StatusLabel.HorizontalAlignment = 'center';
            obj.StatusLabel.FontColor = [0.5 0.5 0.5];
            obj.StatusLabel.Position = [20, 45, 310, 25];
            
            % Help Button
            helpButton = uibutton(obj.UIFigure, 'push');
            helpButton.Text = '?';
            helpButton.FontSize = 14;
            helpButton.FontWeight = 'bold';
            helpButton.BackgroundColor = [0.9 0.9 0.9];
            helpButton.Position = [20, 15, 30, 25];
            helpButton.ButtonPushedFcn = @(~,~) obj.showHelp();
            helpButton.Tooltip = 'Show help and usage instructions';
        end
        

        
        function setSpeed(obj, speed)
            % Set joystick movement speed with user-friendly presets
            try
                obj.StepFactorField.Value = speed;
                
                % Update controller if available
                if ~isempty(obj.HIDController) && isvalid(obj.HIDController)
                    obj.HIDController.setStepFactor(speed);
                end
                
                % Provide feedback with simple if-else instead of containers.Map
                if speed == 1
                    speedName = 'Slow';
                elseif speed == 5
                    speedName = 'Medium';
                elseif speed == 20
                    speedName = 'Fast';
                else
                    speedName = 'Custom';
                end
                
                obj.Logger.info('Speed set to %s (%.1f μm/unit)', speedName, speed);
                
            catch ME
                obj.Logger.error('Error setting speed: %s', ME.message);
            end
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
            
            try
                if obj.IsEnabled
                    obj.Logger.debug('Updating UI to ENABLED state');
                    obj.EnableButton.Text = 'Disable';  % Remove emoji for compatibility
                    obj.EnableButton.BackgroundColor = [0.86 0.24 0.24];
                    obj.StatusLabel.Text = 'Active';
                    obj.StatusLabel.FontColor = [0.16 0.68 0.38];
                else
                    obj.Logger.debug('Updating UI to DISABLED state');
                    % Check if we have a controller to determine button state
                    if isempty(obj.HIDController)
                        obj.EnableButton.Text = 'No Controller';  % Remove emoji for compatibility
                        obj.EnableButton.BackgroundColor = [0.7 0.7 0.7];
                        obj.EnableButton.Enable = 'off';  % Disable button when no controller
                        obj.StatusLabel.Text = 'No Controller Available';
                        obj.StatusLabel.FontColor = [0.8 0.4 0.4];
                    else
                        obj.EnableButton.Text = 'Enable';  % Remove emoji for compatibility
                        obj.EnableButton.BackgroundColor = [0.16 0.68 0.38];
                        obj.EnableButton.Enable = 'on';   % Enable button when controller available
                        obj.StatusLabel.Text = 'Ready to Enable';
                        obj.StatusLabel.FontColor = [0.5 0.5 0.5];
                    end
                end
                
                obj.updateConnectionStatus();
                
                % Force UI refresh
                drawnow;
                
            catch ME
                obj.Logger.error('Error updating UI: %s', ME.message);
            end
        end
        
        function startMonitoring(obj)
            % Start real-time monitoring timer with robust error handling
            try
                % Don't start if we're closing or deleting
                if obj.IsClosing || obj.IsDeleting
                    return;
                end
                
                % Stop any existing timer first
                obj.safeStopMonitoring();
                
                % Validate objects before starting timer
                if ~obj.validateObjects()
                    obj.Logger.warning('Cannot start monitoring - objects not valid');
                    return;
                end
                
                if isempty(obj.UpdateTimer) || ~isvalid(obj.UpdateTimer)
                    obj.UpdateTimer = timer(...
                        'ExecutionMode', 'fixedRate', ...
                        'Period', 0.1, ...  % Update at 10 Hz
                        'TimerFcn', @(~,~) obj.safeUpdateDisplay(), ...
                        'ErrorFcn', @(~,~) obj.handleTimerError());
                    start(obj.UpdateTimer);
                    obj.Logger.info('Monitoring timer started');
                end
            catch ME
                obj.Logger.error('Failed to start monitoring timer: %s', ME.message);
                obj.safeStopMonitoring();
            end
        end
        
        function stopMonitoring(obj)
            % Stop monitoring timer with robust error handling (legacy method)
            obj.safeStopMonitoring();
        end
        
        function updateDisplay(obj)
            % Update real-time display elements with robust error handling (legacy method)
            obj.safeUpdateDisplay();
        end
        
        function updateAnalogControls(~)
            % Simplified version - no analog displays in the basic interface
            % The joystick data is still being processed by the controller,
            % but we don't need to update any display components since they were removed
            % for simplification. The actual joystick movement is handled by the controller.
            
            % This method is kept for compatibility but does nothing in the simplified interface
            % The joystick input is still working - you can see the "SIMULATION: X-axis would move" messages
        end
        

        

        
        function resetCalibration(obj)
            % Reset all axis calibration to defaults
            try
                % Show confirmation dialog
                response = uiconfirm(obj.UIFigure, ...
                    'This will reset all axis calibration to default values. Continue?', ...
                    'Reset Calibration', ...
                    'Options', {'Reset', 'Cancel'}, ...
                    'DefaultOption', 'Cancel', ...
                    'Icon', 'warning');
                
                if strcmp(response, 'Cancel')
                    return;
                end
                
                % Reset calibration using the controller
                if ~isempty(obj.HIDController) && ismethod(obj.HIDController, 'resetCalibration')
                    obj.HIDController.resetCalibration('all');
                    
                    % Show success message
                    uialert(obj.UIFigure, ...
                        '✅ All calibration data has been reset to defaults.', ...
                        'Calibration Reset', 'Icon', 'success');
                    
                    obj.Logger.info('All axis calibration reset to defaults');
                else
                    obj.Logger.error('Controller does not support calibration reset');
                    error('Controller does not support calibration reset');
                end
                
            catch ME
                obj.Logger.error('Failed to reset calibration: %s', ME.message);
                uialert(obj.UIFigure, sprintf('Reset failed: %s', ME.message), ...
                    'Reset Error', 'Icon', 'error');
            end
        end
        
        function openManualCalibration(obj)
            % Open manual calibration dialog
            try
                if isempty(obj.HIDController)
                    uialert(obj.UIFigure, 'No controller available for manual calibration.', ...
                        'Manual Calibration Error', 'Icon', 'warning');
                    return;
                end
                
                obj.Logger.info('Opening manual calibration dialog');
                obj.createManualCalibrationDialog();
                
            catch ME
                obj.Logger.error('Failed to open manual calibration dialog: %s', ME.message);
                uialert(obj.UIFigure, sprintf('Failed to open manual calibration: %s', ME.message), ...
                    'Manual Calibration Error', 'Icon', 'error');
            end
        end
        
        % Callback Methods
        function onEnableButtonPushed(obj)
            % Toggle enable/disable state with enhanced crash prevention
            try
                % Check if we're in shutdown mode
                if obj.IsClosing || obj.IsDeleting || obj.CleanupComplete
                    obj.Logger.debug('Ignoring enable button - shutdown in progress');
                    return;
                end
                
                % Validate objects before proceeding
                if ~obj.validateObjects()
                    obj.Logger.warning('Cannot toggle enable state - objects not valid');
                    return;
                end
                
                % Disable button temporarily to prevent double-clicks
                if ~isempty(obj.EnableButton) && isvalid(obj.EnableButton)
                    obj.EnableButton.Enable = 'off';
                end
                
                if ~obj.IsEnabled
                    % Trying to enable - check hardware first
                    if isempty(obj.HIDController)
                        obj.showSafeAlert(['No HID controller available.\n\n' ...
                            'The joystick controller needs to be initialized by the main application first.\n\n' ...
                            'This usually means:\n' ...
                            '• The main Foilview application is not running\n' ...
                            '• The MJC3 hardware is not detected\n' ...
                            '• The controller failed to initialize\n\n' ...
                            'Try:\n' ...
                            '1. Close this window\n' ...
                            '2. Restart the main Foilview application\n' ...
                            '3. Open the joystick window again'], 'No Controller Available');
                        obj.enableButton();
                        obj.updateUI(); % Make sure UI is updated even on failure
                        return;
                    end
                    
                    % Validate controller is still valid
                    if ~isvalid(obj.HIDController)
                        obj.Logger.warning('Controller is no longer valid');
                        obj.HIDController = [];
                        obj.showSafeAlert('Controller is no longer valid. Please restart the application.', 'Invalid Controller');
                        obj.enableButton();
                        obj.updateUI(); % Make sure UI is updated even on failure
                        return;
                    end
                    
                    % Check if hardware is detected
                    isDetected = obj.checkHardwareDetection();
                    if ~isDetected
                        obj.showSafeAlert('MJC3 hardware not detected. Please check USB connection and try again.', 'Hardware Not Found');
                        obj.enableButton();
                        obj.updateUI(); % Make sure UI is updated even on failure
                        return;
                    end
                    
                    % Try to start the controller
                    try
                        obj.HIDController.start();
                        obj.IsEnabled = true;
                        obj.IsConnected = true;
                        obj.Logger.info('MJC3 controller enabled and active');
                    catch ME
                        obj.IsEnabled = false;
                        obj.IsConnected = false;
                        errorMsg = sprintf('Failed to start controller: %s\n\nHardware detected but connection failed. Try:\n• Reconnecting USB cable\n• Restarting application\n• Checking device permissions', ME.message);
                        obj.showSafeAlert(errorMsg, 'Connection Failed');
                    end
                else
                    % Disabling controller - use safe method
                    obj.safeStopController();
                    obj.Logger.info('MJC3 controller disabled by user');
                end
                
                % Re-enable button and update UI
                obj.enableButton();
                obj.updateUI();
                
            catch ME
                obj.Logger.error('Error in enable/disable toggle: %s', ME.message);
                % Reset to safe state
                obj.IsEnabled = false;
                obj.IsConnected = false;
                obj.enableButton();
                obj.updateUI();
            end
        end
        
        function onStepFactorChanged(obj)
            % Update step factor in controller
            if ~isempty(obj.HIDController)
                obj.HIDController.setStepFactor(obj.StepFactorField.Value);
            end
        end
        
        function onDetectButtonPushed(obj)
            % Manual hardware detection with detailed feedback
            obj.Logger.info('Scanning for MJC3 hardware...');
            
            % Show scanning status
            originalText = obj.ConnectionStatus.Text;
            obj.ConnectionStatus.Text = '🔄 Scanning...';
            obj.ConnectionStatus.FontColor = [0.2 0.6 0.8];
            drawnow;
            
            % Perform detection
            isDetected = obj.checkHardwareDetection();
            
            % Create detailed status message
            if isDetected
                statusMsg = sprintf(['✅ MJC3 Hardware Detected!\n\n' ...
                    'Device: Thorlabs MJC3 Joystick\n' ...
                    'VID: 0x1313, PID: 0x9000\n\n' ...
                    'Status: Ready for connection\n' ...
                    'Click "Enable" to start using the joystick.']);
                iconType = 'success';
                obj.Logger.info('✅ MJC3 hardware detected successfully');
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
                obj.Logger.info('❌ MJC3 hardware not detected');
            end
            
            % Update status and show dialog
            obj.updateConnectionStatus();
            uialert(obj.UIFigure, statusMsg, 'Hardware Detection', 'Icon', iconType);
            
            % Restore original status text if detection failed
            if ~isDetected
                obj.ConnectionStatus.Text = originalText;
                obj.ConnectionStatus.FontColor = [0.8 0.2 0.2]; % Red for failure
            end
        end
        
        function onWindowClose(obj)
            % Handle window close event - ensure proper cleanup with crash prevention
            
            % Prevent recursive close handling
            if obj.IsClosing || obj.IsDeleting || obj.CleanupComplete
                return;
            end
            obj.IsClosing = true;
            
            try
                obj.Logger.info('MJC3View: Window close requested...');
                
                % Disable the UI immediately to prevent further interactions
                obj.disableUI();
                
                % Stop the controller safely
                obj.safeStopController();
                
                % Delete the object (which will trigger the delete method)
                obj.Logger.info('MJC3View: Initiating cleanup...');
                delete(obj);
                
            catch ME
                obj.Logger.error('MJC3View: Error during window close: %s', ME.message);
                % Force cleanup to prevent hanging
                try
                    obj.CleanupComplete = true;
                    if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                        obj.UIFigure.CloseRequestFcn = '';
                        delete(obj.UIFigure);
                    end
                catch
                    % Ignore final cleanup errors
                end
            end
        end
        

        
        % Removed complex methods - simplified UI now uses analog controls
        
        function showHelp(obj)
            % Show help dialog with usage instructions
            helpText = sprintf(['🕹️ MJC3 Joystick Control - Help\n\n' ...
                'Getting Started:\n' ...
                '1. Connect your Thorlabs MJC3 joystick\n' ...
                '2. Click "Enable" to start control\n' ...
                '3. Move the joystick to control stage position\n\n' ...
                'Analog Controls:\n' ...
                '• Z-axis: Up/down joystick movement\n' ...
                '• X-axis: Left/right joystick movement\n' ...
                '• Y-axis: Forward/backward joystick movement\n' ...
                '• Sensitivity: Adjust movement speed\n' ...
                '• Action: Choose movement type\n' ...
                '• Calibrate: Improve accuracy\n\n' ...
                'Calibration:\n' ...
                '• Click "Cal X", "Cal Y", or "Cal Z" to calibrate each axis\n' ...
                '• Move joystick through full range during calibration\n' ...
                '• System will collect 100 samples automatically\n' ...
                '• Calibration data is saved permanently\n' ...
                '• Click "Reset" to restore default calibration\n\n' ...
                'Troubleshooting:\n' ...
                '• If joystick not detected, check USB connection\n' ...
                '• Adjust step factor for different movement speeds\n' ...
                '• Use calibration for precise control\n' ...
                '• Check ScanImage integration if stage not moving']);
            
            uialert(obj.UIFigure, helpText, 'Help', 'Icon', 'info');
        end
    end
    
    % === CRASH PREVENTION METHODS ===
    methods (Access = private)
        function safeStopMonitoring(obj)
            % Safely stop monitoring timer with comprehensive error handling
            try
                if ~isempty(obj.UpdateTimer)
                    if isvalid(obj.UpdateTimer)
                        try
                            stop(obj.UpdateTimer);
                            obj.Logger.debug('Timer stopped successfully');
                        catch ME
                            obj.Logger.warning('Error stopping timer: %s', ME.message);
                        end
                        
                        try
                            delete(obj.UpdateTimer);
                            obj.Logger.debug('Timer deleted successfully');
                        catch ME
                            obj.Logger.warning('Error deleting timer: %s', ME.message);
                        end
                    end
                    obj.UpdateTimer = [];
                end
            catch ME
                obj.Logger.error('Critical error in safeStopMonitoring: %s', ME.message);
                % Force cleanup
                obj.UpdateTimer = [];
            end
        end
        
        function safeStopController(obj)
            % Safely stop HID controller with error handling
            try
                if ~isempty(obj.HIDController) && isvalid(obj.HIDController)
                    if obj.IsEnabled
                        try
                            obj.Logger.info('Stopping HID controller...');
                            obj.HIDController.disable();
                            obj.Logger.info('HID controller stopped successfully');
                        catch ME
                            obj.Logger.warning('Error stopping HID controller: %s', ME.message);
                        end
                    end
                end
                
                % Reset state regardless of success/failure
                obj.IsEnabled = false;
                obj.IsConnected = false;
                
            catch ME
                obj.Logger.error('Critical error in safeStopController: %s', ME.message);
                % Force state reset
                obj.IsEnabled = false;
                obj.IsConnected = false;
            end
        end
        
        function safeDeleteUIFigure(obj)
            % Safely delete UI figure with error handling
            try
                if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                    % Clear the close request function to prevent recursion
                    obj.UIFigure.CloseRequestFcn = '';
                    
                    try
                        delete(obj.UIFigure);
                        obj.Logger.debug('UI figure deleted successfully');
                    catch ME
                        obj.Logger.warning('Error deleting UI figure: %s', ME.message);
                    end
                end
                obj.UIFigure = [];
                
            catch ME
                obj.Logger.error('Critical error in safeDeleteUIFigure: %s', ME.message);
                obj.UIFigure = [];
            end
        end
        
        function safeUpdateDisplay(obj)
            % Safely update display with comprehensive error handling
            try
                % Check if we're in the process of closing/deleting
                if obj.IsClosing || obj.IsDeleting || obj.CleanupComplete
                    return;
                end
                
                % Validate all objects before proceeding
                if ~obj.validateObjects()
                    obj.Logger.debug('Objects not valid, stopping monitoring');
                    obj.safeStopMonitoring();
                    return;
                end
                
                % Only update if enabled and controller is available
                if ~isempty(obj.HIDController) && obj.IsEnabled
                    obj.updateAnalogControls();
                end
                
            catch ME
                obj.Logger.error('Error in safeUpdateDisplay: %s', ME.message);
                % Stop monitoring to prevent repeated crashes
                obj.safeStopMonitoring();
            end
        end
        
        function handleTimerError(obj)
            % Handle timer errors gracefully
            try
                obj.Logger.error('Timer error occurred, stopping monitoring');
                obj.safeStopMonitoring();
            catch ME
                obj.Logger.error('Error in timer error handler: %s', ME.message);
            end
        end
        
        function disableUI(obj)
            % Disable UI components to prevent interaction during shutdown (simplified)
            try
                if ~isempty(obj.EnableButton) && isvalid(obj.EnableButton)
                    obj.EnableButton.Enable = 'off';
                end
                
                if ~isempty(obj.StepFactorField) && isvalid(obj.StepFactorField)
                    obj.StepFactorField.Enable = 'off';
                end
                
            catch ME
                obj.Logger.warning('Error disabling UI: %s', ME.message);
            end
        end
        
        function isValid = validateObjects(obj)
            % Enhanced object validation with crash prevention
            isValid = true;
            
            try
                % Check if we're in cleanup mode
                if obj.IsClosing || obj.IsDeleting || obj.CleanupComplete
                    isValid = false;
                    return;
                end
                
                % Check if the main UI figure is valid
                if isempty(obj.UIFigure) || ~isvalid(obj.UIFigure)
                    obj.Logger.debug('UIFigure is invalid or deleted');
                    isValid = false;
                    return;
                end
                
                % Check critical UI components
                criticalComponents = {obj.EnableButton, obj.StatusLabel, obj.ConnectionStatus};
                for i = 1:length(criticalComponents)
                    if isempty(criticalComponents{i}) || ~isvalid(criticalComponents{i})
                        obj.Logger.debug('Critical UI component %d is invalid', i);
                        isValid = false;
                        return;
                    end
                end
                
            catch ME
                obj.Logger.error('Error in validateObjects: %s', ME.message);
                isValid = false;
            end
        end
        
        function showSafeAlert(obj, message, title)
            % Safely show alert dialog with error handling
            try
                if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure) && ~obj.IsClosing
                    uialert(obj.UIFigure, message, title);
                else
                    % Fallback to command window if UI is not available
                    fprintf('Alert: %s - %s\n', title, message);
                end
            catch ME
                obj.Logger.warning('Error showing alert: %s', ME.message);
                fprintf('Alert: %s - %s\n', title, message);
            end
        end
        
        function enableButton(obj)
            % Safely re-enable the enable button (but only if we have a controller)
            try
                if ~isempty(obj.EnableButton) && isvalid(obj.EnableButton) && ~obj.IsClosing
                    % Only enable the button if we have a controller
                    if ~isempty(obj.HIDController)
                        obj.EnableButton.Enable = 'on';
                    else
                        obj.EnableButton.Enable = 'off';  % Keep disabled if no controller
                    end
                end
            catch ME
                obj.Logger.warning('Error enabling button: %s', ME.message);
            end
        end
        
        function createManualCalibrationDialog(obj)
            % Create manual calibration dialog window
            
            % Create dialog figure
            dlg = uifigure('Name', 'Manual Joystick Calibration', ...
                'Position', [200, 200, 600, 500], ...
                'Resize', 'off', ...
                'WindowStyle', 'modal');
            
            % Main grid layout
            mainGrid = uigridlayout(dlg, [4, 1]);
            mainGrid.RowHeight = {'fit', '1x', 'fit', 'fit'};
            mainGrid.Padding = [20, 20, 20, 20];
            mainGrid.RowSpacing = 15;
            
            % Title
            titleLabel = uilabel(mainGrid);
            titleLabel.Text = 'Manual Joystick Calibration';
            titleLabel.FontSize = 18;
            titleLabel.FontWeight = 'bold';
            titleLabel.HorizontalAlignment = 'center';
            titleLabel.FontColor = [0.2 0.2 0.4];
            
            % Tab group for axes
            tabGroup = uitabgroup(mainGrid);
            
            % Create tabs for each axis
            axes = {'X', 'Y', 'Z'};
            axisColors = {[0.85 0.9 1.0], [0.9 1.0 0.85], [1.0 0.9 0.85]};
            
            for i = 1:length(axes)
                axisName = axes{i};
                axisColor = axisColors{i};
                
                tab = uitab(tabGroup, 'Title', sprintf('%s Axis', axisName));
                obj.createAxisCalibrationTab(tab, axisName, axisColor);
            end
            
            % Instructions
            instructionText = uitextarea(mainGrid);
            instructionText.Value = {
                'Manual Calibration Instructions:', ...
                '1. Select an axis tab above', ...
                '2. Move joystick to negative position and click "Set Negative"', ...
                '3. Center joystick and click "Set Center"', ...
                '4. Move joystick to positive position and click "Set Positive"', ...
                '5. Adjust analog parameters as needed', ...
                '6. Click "Apply" to save calibration for that axis'
            };
            instructionText.Editable = 'off';
            instructionText.FontSize = 11;
            instructionText.BackgroundColor = [0.95 0.95 0.98];
            
            % Button panel
            buttonPanel = uipanel(mainGrid);
            buttonPanel.BorderType = 'none';
            
            buttonGrid = uigridlayout(buttonPanel, [1, 3]);
            buttonGrid.ColumnWidth = {'1x', 'fit', 'fit'};
            buttonGrid.ColumnSpacing = 10;
            
            % Spacer
            uilabel(buttonGrid);
            
            % Close button
            closeBtn = uibutton(buttonGrid, 'push');
            closeBtn.Text = 'Close';
            closeBtn.FontSize = 12;
            closeBtn.ButtonPushedFcn = @(~,~) close(dlg);
            
            % Help button
            helpBtn = uibutton(buttonGrid, 'push');
            helpBtn.Text = 'Help';
            helpBtn.FontSize = 12;
            helpBtn.ButtonPushedFcn = @(~,~) obj.showManualCalibrationHelp();
        end
        
        function createAxisCalibrationTab(obj, parent, axisName, axisColor)
            % Create calibration controls for a specific axis
            
            % Main grid for axis tab
            axisGrid = uigridlayout(parent, [3, 2]);
            axisGrid.RowHeight = {'fit', '1x', 'fit'};
            axisGrid.ColumnWidth = {'1x', '1x'};
            axisGrid.Padding = [15, 15, 15, 15];
            axisGrid.RowSpacing = 15;
            axisGrid.ColumnSpacing = 15;
            
            % Position Settings Panel
            posPanel = uipanel(axisGrid);
            posPanel.Title = sprintf('%s Axis Position Settings', axisName);
            posPanel.FontWeight = 'bold';
            posPanel.BackgroundColor = axisColor;
            posPanel.Layout.Row = 1;
            posPanel.Layout.Column = [1, 2];
            
            posGrid = uigridlayout(posPanel, [4, 4]);
            posGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
            posGrid.ColumnWidth = {'fit', '1x', 'fit', 'fit'};
            posGrid.Padding = [10, 10, 10, 10];
            posGrid.RowSpacing = 8;
            posGrid.ColumnSpacing = 10;
            
            % Current Value Display
            uilabel(posGrid, 'Text', 'Current Value:', 'FontWeight', 'bold');
            currentValueLabel = uilabel(posGrid, 'Text', '0', 'FontColor', [0.2 0.2 0.8]);
            currentValueLabel.Tag = sprintf('CurrentValue_%s', axisName);
            uilabel(posGrid); % Spacer
            
            refreshBtn = uibutton(posGrid, 'push');
            refreshBtn.Text = 'Refresh';
            refreshBtn.FontSize = 10;
            refreshBtn.ButtonPushedFcn = @(~,~) obj.refreshCurrentValue(axisName, currentValueLabel);
            
            % Negative Position
            uilabel(posGrid, 'Text', 'Negative Pos:', 'FontWeight', 'bold');
            negField = uieditfield(posGrid, 'numeric');
            negField.Value = obj.getAxisParameterSafe(axisName, 'min');
            negField.Tag = sprintf('NegativePos_%s', axisName);
            negField.Limits = [-127, 127];
            
            setNegBtn = uibutton(posGrid, 'push');
            setNegBtn.Text = 'Set Negative';
            setNegBtn.FontSize = 10;
            setNegBtn.BackgroundColor = [1.0 0.9 0.9];
            setNegBtn.ButtonPushedFcn = @(~,~) obj.setCurrentPosition(axisName, 'negative', negField, currentValueLabel);
            
            uilabel(posGrid); % Spacer
            
            % Center Position
            uilabel(posGrid, 'Text', 'Center Pos:', 'FontWeight', 'bold');
            centerField = uieditfield(posGrid, 'numeric');
            centerField.Value = obj.getAxisParameterSafe(axisName, 'center');
            centerField.Tag = sprintf('CenterPos_%s', axisName);
            centerField.Limits = [-127, 127];
            
            setCenterBtn = uibutton(posGrid, 'push');
            setCenterBtn.Text = 'Set Center';
            setCenterBtn.FontSize = 10;
            setCenterBtn.BackgroundColor = [0.9 1.0 0.9];
            setCenterBtn.ButtonPushedFcn = @(~,~) obj.setCurrentPosition(axisName, 'center', centerField, currentValueLabel);
            
            uilabel(posGrid); % Spacer
            
            % Positive Position
            uilabel(posGrid, 'Text', 'Positive Pos:', 'FontWeight', 'bold');
            posField = uieditfield(posGrid, 'numeric');
            posField.Value = obj.getAxisParameterSafe(axisName, 'max');
            posField.Tag = sprintf('PositivePos_%s', axisName);
            posField.Limits = [-127, 127];
            
            setPosBtn = uibutton(posGrid, 'push');
            setPosBtn.Text = 'Set Positive';
            setPosBtn.FontSize = 10;
            setPosBtn.BackgroundColor = [0.9 0.9 1.0];
            setPosBtn.ButtonPushedFcn = @(~,~) obj.setCurrentPosition(axisName, 'positive', posField, currentValueLabel);
            
            uilabel(posGrid); % Spacer
            
            % Analog Parameters Panel
            analogPanel = uipanel(axisGrid);
            analogPanel.Title = 'Analog Parameters';
            analogPanel.FontWeight = 'bold';
            analogPanel.Layout.Row = 2;
            analogPanel.Layout.Column = 1;
            
            analogGrid = uigridlayout(analogPanel, [5, 2]);
            analogGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};
            analogGrid.ColumnWidth = {'fit', '1x'};
            analogGrid.Padding = [10, 10, 10, 10];
            analogGrid.RowSpacing = 8;
            analogGrid.ColumnSpacing = 10;
            
            % Dead Zone
            uilabel(analogGrid, 'Text', 'Dead Zone:', 'FontWeight', 'bold');
            deadzoneField = uieditfield(analogGrid, 'numeric');
            deadzoneField.Value = obj.getAxisParameterSafe(axisName, 'deadzone');
            deadzoneField.Tag = sprintf('Deadzone_%s', axisName);
            deadzoneField.Limits = [0, 50];
            deadzoneField.Tooltip = 'Range around center where no movement occurs';
            
            % Resolution
            uilabel(analogGrid, 'Text', 'Resolution:', 'FontWeight', 'bold');
            resolutionField = uieditfield(analogGrid, 'numeric');
            resolutionField.Value = obj.getAxisParameterSafe(axisName, 'resolution');
            resolutionField.Tag = sprintf('Resolution_%s', axisName);
            resolutionField.Limits = [1, 100];
            resolutionField.Tooltip = 'Movement sensitivity/granularity';
            
            % Damping
            uilabel(analogGrid, 'Text', 'Damping:', 'FontWeight', 'bold');
            dampingField = uieditfield(analogGrid, 'numeric');
            dampingField.Value = obj.getAxisParameterSafe(axisName, 'damping');
            dampingField.Tag = sprintf('Damping_%s', axisName);
            dampingField.Limits = [0, 100];
            dampingField.Tooltip = 'Movement smoothing factor (0-100%)';
            
            % Sensitivity
            uilabel(analogGrid, 'Text', 'Sensitivity:', 'FontWeight', 'bold');
            sensitivityField = uieditfield(analogGrid, 'numeric');
            sensitivityField.Value = obj.getAxisParameterSafe(axisName, 'sensitivity');
            sensitivityField.Tag = sprintf('Sensitivity_%s', axisName);
            sensitivityField.Limits = [0.1, 5.0];
            sensitivityField.Tooltip = 'Overall axis sensitivity multiplier';
            
            % Invert Sense
            uilabel(analogGrid, 'Text', 'Invert Sense:', 'FontWeight', 'bold');
            invertCheckbox = uicheckbox(analogGrid);
            invertCheckbox.Value = obj.getAxisParameterSafe(axisName, 'invertSense');
            invertCheckbox.Tag = sprintf('InvertSense_%s', axisName);
            invertCheckbox.Text = 'Reverse axis direction';
            
            % Preview Panel
            previewPanel = uipanel(axisGrid);
            previewPanel.Title = 'Live Preview';
            previewPanel.FontWeight = 'bold';
            previewPanel.Layout.Row = 2;
            previewPanel.Layout.Column = 2;
            
            previewGrid = uigridlayout(previewPanel, [4, 1]);
            previewGrid.RowHeight = {'fit', 'fit', 'fit', '1x'};
            previewGrid.Padding = [10, 10, 10, 10];
            previewGrid.RowSpacing = 8;
            
            % Raw Value
            rawLabel = uilabel(previewGrid, 'Text', 'Raw: 0', 'FontWeight', 'bold');
            rawLabel.Tag = sprintf('RawPreview_%s', axisName);
            
            % Calibrated Value
            calLabel = uilabel(previewGrid, 'Text', 'Calibrated: 0.00', 'FontWeight', 'bold');
            calLabel.Tag = sprintf('CalibratedPreview_%s', axisName);
            calLabel.FontColor = [0.2 0.6 0.2];
            
            % Movement Value
            moveLabel = uilabel(previewGrid, 'Text', 'Movement: 0.00 μm', 'FontWeight', 'bold');
            moveLabel.Tag = sprintf('MovementPreview_%s', axisName);
            moveLabel.FontColor = [0.6 0.2 0.2];
            
            % Preview toggle
            previewToggle = uibutton(previewGrid, 'state');
            previewToggle.Text = 'Start Preview';
            previewToggle.ValueChangedFcn = @(src,~) obj.togglePreview(axisName, src);
            
            % Apply Button
            applyBtn = uibutton(axisGrid, 'push');
            applyBtn.Text = sprintf('Apply %s Calibration', axisName);
            applyBtn.FontSize = 12;
            applyBtn.FontWeight = 'bold';
            applyBtn.BackgroundColor = [0.2 0.7 0.2];
            applyBtn.FontColor = [1 1 1];
            applyBtn.Layout.Row = 3;
            applyBtn.Layout.Column = [1, 2];
            applyBtn.ButtonPushedFcn = @(~,~) obj.applyManualCalibration(axisName, parent);
        end
        
        function value = getAxisParameterSafe(obj, axisName, parameterName)
            % Safely get axis parameter with fallback to defaults
            try
                if ~isempty(obj.HIDController) && ismethod(obj.HIDController, 'getAxisParameter')
                    value = obj.HIDController.getAxisParameter(axisName, parameterName);
                    if isempty(value)
                        value = obj.getDefaultParameter(parameterName);
                    end
                else
                    value = obj.getDefaultParameter(parameterName);
                end
            catch
                value = obj.getDefaultParameter(parameterName);
            end
        end
        
        function value = getDefaultParameter(~, parameterName)
            % Get default parameter values
            switch parameterName
                case 'min'
                    value = -127;
                case 'center'
                    value = 0;
                case 'max'
                    value = 127;
                case 'deadzone'
                    value = 10;
                case 'resolution'
                    value = 20;
                case 'damping'
                    value = 0;
                case 'sensitivity'
                    value = 1.0;
                case 'invertSense'
                    value = false;
                otherwise
                    value = 0;
            end
        end
        
        function refreshCurrentValue(obj, axisName, currentValueLabel)
            % Refresh the current joystick value display
            try
                if ~isempty(obj.HIDController) && ismethod(obj.HIDController, 'getCurrentRawValue')
                    currentValue = obj.HIDController.getCurrentRawValue(axisName);
                    currentValueLabel.Text = sprintf('%d', currentValue);
                    currentValueLabel.FontColor = [0.2 0.2 0.8];
                else
                    currentValueLabel.Text = 'N/A';
                    currentValueLabel.FontColor = [0.8 0.2 0.2];
                end
            catch ME
                obj.Logger.error('Failed to refresh current value for %s: %s', axisName, ME.message);
                currentValueLabel.Text = 'Error';
                currentValueLabel.FontColor = [0.8 0.2 0.2];
            end
        end
        
        function setCurrentPosition(obj, axisName, positionType, field, currentValueLabel)
            % Set position field to current joystick value
            try
                if ~isempty(obj.HIDController) && ismethod(obj.HIDController, 'getCurrentRawValue')
                    currentValue = obj.HIDController.getCurrentRawValue(axisName);
                    field.Value = currentValue;
                    currentValueLabel.Text = sprintf('%d', currentValue);
                    obj.Logger.info('Set %s position for %s axis to %d', positionType, axisName, currentValue);
                else
                    uialert(field.Parent.Parent.Parent.Parent, 'No controller available to read current value.', ...
                        'Set Position Error', 'Icon', 'warning');
                end
            catch ME
                obj.Logger.error('Failed to set %s position for %s: %s', positionType, axisName, ME.message);
                uialert(field.Parent.Parent.Parent.Parent, sprintf('Failed to set position: %s', ME.message), ...
                    'Set Position Error', 'Icon', 'error');
            end
        end
        
        function applyManualCalibration(obj, axisName, parent)
            % Apply manual calibration settings for an axis
            try
                % Get all field values from the UI
                negField = findobj(parent, 'Tag', sprintf('NegativePos_%s', axisName));
                centerField = findobj(parent, 'Tag', sprintf('CenterPos_%s', axisName));
                posField = findobj(parent, 'Tag', sprintf('PositivePos_%s', axisName));
                deadzoneField = findobj(parent, 'Tag', sprintf('Deadzone_%s', axisName));
                resolutionField = findobj(parent, 'Tag', sprintf('Resolution_%s', axisName));
                dampingField = findobj(parent, 'Tag', sprintf('Damping_%s', axisName));
                sensitivityField = findobj(parent, 'Tag', sprintf('Sensitivity_%s', axisName));
                invertCheckbox = findobj(parent, 'Tag', sprintf('InvertSense_%s', axisName));
                
                % Validate that all fields were found
                if isempty(negField) || isempty(centerField) || isempty(posField)
                    obj.Logger.error('Could not find all required position fields');
                    error('Could not find all required position fields');
                end
                
                % Get values
                negativePos = negField.Value;
                centerPos = centerField.Value;
                positivePos = posField.Value;
                deadzone = deadzoneField.Value;
                resolution = resolutionField.Value;
                damping = dampingField.Value;
                sensitivity = sensitivityField.Value;
                invertSense = invertCheckbox.Value;
                
                % Apply calibration
                if ~isempty(obj.HIDController) && ismethod(obj.HIDController, 'setManualCalibration')
                    obj.HIDController.setManualCalibration(axisName, negativePos, centerPos, positivePos, ...
                        deadzone, resolution, damping, invertSense, sensitivity);
                    
                    % Show success message
                    uialert(parent.Parent.Parent, ...
                        sprintf('✅ %s axis calibration applied successfully!', axisName), ...
                        'Calibration Applied', 'Icon', 'success');
                    
                    obj.Logger.info('Manual calibration applied for %s axis', axisName);
                else
                    obj.Logger.error('Controller does not support manual calibration');
                    error('Controller does not support manual calibration');
                end
                
            catch ME
                obj.Logger.error('Failed to apply manual calibration for %s: %s', axisName, ME.message);
                uialert(parent.Parent.Parent, sprintf('Failed to apply calibration: %s', ME.message), ...
                    'Calibration Error', 'Icon', 'error');
            end
        end
        
        function showManualCalibrationHelp(obj)
            % Show help dialog for manual calibration
            helpText = {
                'Manual Joystick Calibration Help', ...
                '', ...
                'Position Settings:', ...
                '• Negative Position: Raw value when joystick is at maximum negative deflection', ...
                '• Center Position: Raw value when joystick is at rest/center', ...
                '• Positive Position: Raw value when joystick is at maximum positive deflection', ...
                '', ...
                'Analog Parameters:', ...
                '• Dead Zone: Range around center where no movement occurs (0-50)', ...
                '• Resolution: Movement sensitivity/granularity (1-100)', ...
                '• Damping: Movement smoothing factor 0-100% (higher = smoother)', ...
                '• Sensitivity: Overall axis sensitivity multiplier (0.1-5.0)', ...
                '• Invert Sense: Reverse the direction of axis movement', ...
                '', ...
                'Calibration Process:', ...
                '1. Move joystick to desired position', ...
                '2. Click "Set Negative/Center/Positive" to capture current value', ...
                '3. Adjust analog parameters as needed', ...
                '4. Use Live Preview to test settings', ...
                '5. Click "Apply" to save calibration', ...
                '', ...
                'Tips:', ...
                '• Use "Refresh" to see current joystick value', ...
                '• Test each axis independently', ...
                '• Start with default parameters and adjust as needed'
            };
            
            uialert(obj.UIFigure, helpText, 'Manual Calibration Help', 'Icon', 'info');
        end
        
        function togglePreview(obj, axisName, toggleButton)
            % Toggle live preview for an axis
            try
                if toggleButton.Value
                    % Start preview
                    toggleButton.Text = 'Stop Preview';
                    obj.startAxisPreview(axisName);
                else
                    % Stop preview
                    toggleButton.Text = 'Start Preview';
                    obj.stopAxisPreview(axisName);
                end
            catch ME
                obj.Logger.error('Failed to toggle preview for %s: %s', axisName, ME.message);
                toggleButton.Value = false;
                toggleButton.Text = 'Start Preview';
            end
        end
        
        function startAxisPreview(obj, axisName)
            % Start live preview for an axis
            try
                % Create timer for this axis preview
                timerName = sprintf('PreviewTimer_%s', axisName);
                
                % Stop any existing timer
                obj.stopAxisPreview(axisName);
                
                % Create new timer
                previewTimer = timer(...
                    'ExecutionMode', 'fixedRate', ...
                    'Period', 0.1, ...  % Update at 10 Hz
                    'TimerFcn', @(~,~) obj.updateAxisPreview(axisName), ...
                    'ErrorFcn', @(~,~) obj.handlePreviewError(axisName), ...
                    'Name', timerName);
                
                % Store timer reference
                obj.PreviewTimers(axisName) = previewTimer;
                
                start(previewTimer);
                obj.Logger.info('Started preview for %s axis', axisName);
                
            catch ME
                obj.Logger.error('Failed to start preview for %s: %s', axisName, ME.message);
            end
        end
        
        function stopAxisPreview(obj, axisName)
            % Stop live preview for an axis
            try
                if isKey(obj.PreviewTimers, axisName)
                    previewTimer = obj.PreviewTimers(axisName);
                    if isvalid(previewTimer)
                        stop(previewTimer);
                        delete(previewTimer);
                    end
                    remove(obj.PreviewTimers, axisName);
                    obj.Logger.info('Stopped preview for %s axis', axisName);
                end
            catch ME
                obj.Logger.error('Failed to stop preview for %s: %s', axisName, ME.message);
            end
        end
        
        function updateAxisPreview(obj, axisName)
            % Update preview display for an axis
            try
                if isempty(obj.HIDController)
                    return;
                end
                
                % Get current raw value
                rawValue = obj.HIDController.getCurrentRawValue(axisName);
                
                % Find preview labels
                rawLabel = findobj(obj.UIFigure, 'Tag', sprintf('RawPreview_%s', axisName));
                calLabel = findobj(obj.UIFigure, 'Tag', sprintf('CalibratedPreview_%s', axisName));
                moveLabel = findobj(obj.UIFigure, 'Tag', sprintf('MovementPreview_%s', axisName));
                
                if ~isempty(rawLabel)
                    rawLabel.Text = sprintf('Raw: %d', rawValue);
                end
                
                % Calculate calibrated value (simplified for preview)
                calibratedValue = obj.calculatePreviewCalibration(axisName, rawValue);
                
                if ~isempty(calLabel)
                    calLabel.Text = sprintf('Calibrated: %.2f', calibratedValue);
                end
                
                % Calculate movement (assuming 5 μm/unit step factor)
                stepFactor = 5.0;
                movement = calibratedValue * stepFactor;
                
                if ~isempty(moveLabel)
                    moveLabel.Text = sprintf('Movement: %.2f μm', movement);
                end
                
            catch ME
                obj.Logger.error('Failed to update preview for %s: %s', axisName, ME.message);
            end
        end
        
        function calibratedValue = calculatePreviewCalibration(obj, axisName, rawValue)
            % Calculate calibrated value for preview (simplified version)
            try
                % Get current UI values for preview calculation
                parent = obj.UIFigure;
                
                negField = findobj(parent, 'Tag', sprintf('NegativePos_%s', axisName));
                centerField = findobj(parent, 'Tag', sprintf('CenterPos_%s', axisName));
                posField = findobj(parent, 'Tag', sprintf('PositivePos_%s', axisName));
                deadzoneField = findobj(parent, 'Tag', sprintf('Deadzone_%s', axisName));
                sensitivityField = findobj(parent, 'Tag', sprintf('Sensitivity_%s', axisName));
                invertCheckbox = findobj(parent, 'Tag', sprintf('InvertSense_%s', axisName));
                
                if isempty(negField) || isempty(centerField) || isempty(posField)
                    calibratedValue = rawValue / 127; % Fallback to simple scaling
                    return;
                end
                
                % Get values
                negativePos = negField.Value;
                centerPos = centerField.Value;
                positivePos = posField.Value;
                deadzone = deadzoneField.Value;
                sensitivity = sensitivityField.Value;
                invertSense = invertCheckbox.Value;
                
                % Apply dead zone
                if abs(rawValue - centerPos) <= deadzone
                    calibratedValue = 0;
                    return;
                end
                
                % Calculate normalized position (-1 to 1)
                if rawValue > centerPos
                    % Positive direction
                    range = positivePos - centerPos;
                    if range > 0
                        normalized = (rawValue - centerPos) / range;
                    else
                        normalized = 0;
                    end
                else
                    % Negative direction
                    range = centerPos - negativePos;
                    if range > 0
                        normalized = -(centerPos - rawValue) / range;
                    else
                        normalized = 0;
                    end
                end
                
                % Apply sensitivity and clamp to [-1, 1]
                calibratedValue = normalized * sensitivity;
                calibratedValue = max(-1.0, min(1.0, calibratedValue));
                
                % Apply invert sense if enabled
                if invertSense
                    calibratedValue = -calibratedValue;
                end
                
            catch ME
                obj.Logger.error('Failed to calculate preview calibration for %s: %s', axisName, ME.message);
                calibratedValue = rawValue / 127; % Fallback
            end
        end
        
        function handlePreviewError(obj, axisName)
            % Handle preview timer errors
            obj.Logger.error('Preview timer error for %s axis', axisName);
            obj.stopAxisPreview(axisName);
        end
    end
end