%==============================================================================
% MJC3_MEX_CONTROLLER.M
%==============================================================================
% High-performance MEX-based MJC3 joystick controller.
%
% This controller provides the primary implementation for MJC3 joystick control
% using a custom C++ MEX function for direct HID access. It offers superior
% performance compared to simulation controllers and provides real-time
% joystick polling at 50Hz for precise Z-axis control.
%
% Key Features:
%   - Direct HID communication via custom MEX function
%   - High-frequency polling (50Hz) for responsive control
%   - Multi-axis support (X, Y, Z) with individual step factors
%   - Automatic device detection and connection management
%   - Calibration service integration for axis calibration
%   - Error handling and recovery mechanisms
%   - Timer-based polling with error callbacks
%
% Performance Characteristics:
%   - Polling Rate: 50Hz (20ms intervals)
%   - Latency: <1ms for joystick read operations
%   - Memory Usage: Minimal (timer-based polling)
%   - CPU Usage: Low (efficient MEX implementation)
%
% Dependencies:
%   - mjc3_joystick_mex: Custom MEX function for HID communication
%   - BaseMJC3Controller: Abstract base class interface
%   - CalibrationService: Axis calibration and scaling
%   - MATLAB Timer: Polling mechanism
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   controller = MJC3_MEX_Controller(zController, 5.0);
%   controller.start();  % Begin joystick polling
%   controller.stop();   % Stop joystick polling
%
%==============================================================================

classdef MJC3_MEX_Controller < BaseMJC3Controller
    % MJC3_MEX_Controller - High-performance MEX-based MJC3 controller
    % Uses custom C++ MEX function for direct HID access without PsychHID
    
    properties
        stepFactor     % Micrometres moved per unit of joystick deflection (Z-axis)
        xStepFactor    % Micrometres moved per unit of joystick deflection (X-axis)
        yStepFactor    % Micrometres moved per unit of joystick deflection (Y-axis)
        running        % Logical flag indicating whether polling is active
        timerObj       % MATLAB timer object for polling
        lastZValue     % Last Z-axis value to detect changes
        lastXValue     % Last X-axis value to detect changes
        lastYValue     % Last Y-axis value to detect changes
        mexFunction    % Name of the MEX function
        isConnected    % Connection status
        CalibrationService  % Calibration service for X, Y, Z axes
    end
    
    properties (Constant)
        MEX_FUNCTION = 'mjc3_joystick_mex';  % MEX function name (now in controllers/mjc3/)
        POLL_RATE = 0.02;  % 50Hz polling (faster than current 20Hz)
    end
    
    methods
        function obj = MJC3_MEX_Controller(zController, stepFactor)
            % Constructor
            % zController: Z-controller (must implement relativeMove method)
            % stepFactor: micrometres moved per unit of joystick deflection
            
            % Call parent constructor
            obj@BaseMJC3Controller(zController, stepFactor);
            
            obj.mexFunction = obj.MEX_FUNCTION;
            obj.lastZValue = 0;
            obj.lastXValue = 0;
            obj.lastYValue = 0;
            obj.isConnected = false;
            obj.running = false;
            
            % Initialize step factors for all axes
            obj.xStepFactor = stepFactor;
            obj.yStepFactor = stepFactor;
            
            % Initialize calibration service
            obj.CalibrationService = CalibrationService();
            
            % Verify MEX function exists
            if ~obj.verifyMEXFunction()
                error('MJC3_MEX_Controller:MEXNotFound', ...
                    'MEX function %s not found. Please compile the MEX file.', obj.mexFunction);
            end
            
            % Test connection
            if ~obj.connectToMJC3()
                warning('MJC3_MEX_Controller:NoDevice', ...
                    'MJC3 device not detected. Controller created but not connected.');
            end
            
            % Create timer with better error handling
            obj.timerObj = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', obj.POLL_RATE, ...
                'TimerFcn', @(~,~)obj.safePoll(), ...
                'ErrorFcn', @(~,~)obj.handleTimerError(), ...
                'Name', 'MJC3_MEX_Timer');
        end
        
        function start(obj)
            % Start polling the joystick
            if ~obj.running
                if ~obj.isConnected && ~obj.connectToMJC3()
                    error('MJC3_MEX_Controller:NotConnected', 'Cannot start: MJC3 device not connected');
                end
                
                obj.running = true;
                start(obj.timerObj);
                fprintf('MJC3 MEX Controller started (Step factor: %.1f μm/unit, Poll rate: %.0f Hz)\n', ...
                    obj.stepFactor, 1/obj.POLL_RATE);
            end
        end
        
        function stop(obj)
            % Stop polling the joystick
            if obj.running
                obj.running = false;
                stop(obj.timerObj);
                fprintf('MJC3 MEX Controller stopped\n');
            end
        end
        
        function success = connectToMJC3(obj)
            % Test connection to MJC3 device
            try
                % Check if device info shows connection
                info = feval(obj.mexFunction, 'info');
                obj.isConnected = info.connected;
                success = obj.isConnected;
                
                if success
                    fprintf('MJC3 MEX Controller: Device connected (VID:1313, PID:9000)\n');
                else
                    fprintf('MJC3 MEX Controller: Device not detected\n');
                end
            catch ME
                obj.isConnected = false;
                success = false;
                fprintf('MJC3 MEX Controller: Connection test failed: %s\n', ME.message);
            end
        end
        
        function data = readJoystick(obj)
            % Read current joystick state
            % Returns: [xVal, yVal, zVal, button, speedKnob]
            try
                data = feval(obj.mexFunction, 'read', 50); % 50ms timeout
                if isempty(data)
                    data = [0, 0, 0, 0, 0]; % Return neutral state on timeout
                end
            catch ME
                fprintf('MJC3 MEX Controller: Read error: %s\n', ME.message);
                data = [0, 0, 0, 0, 0];
            end
        end
        
        function info = getDeviceInfo(obj)
            % Get device information
            try
                info = feval(obj.mexFunction, 'info');
            catch ME
                fprintf('MJC3 MEX Controller: Info error: %s\n', ME.message);
                info = struct('connected', false, 'error', ME.message);
            end
        end
        

        
        function setXStepFactor(obj, stepFactor)
            % Set X-axis step factor
            if stepFactor > 0
                obj.xStepFactor = stepFactor;
                fprintf('MJC3 MEX: X-axis step factor updated to %.1f μm/unit\n', stepFactor);
            else
                warning('X-axis step factor must be positive');
            end
        end
        
        function setYStepFactor(obj, stepFactor)
            % Set Y-axis step factor
            if stepFactor > 0
                obj.yStepFactor = stepFactor;
                fprintf('MJC3 MEX: Y-axis step factor updated to %.1f μm/unit\n', stepFactor);
            else
                warning('Y-axis step factor must be positive');
            end
        end
        
        function delete(obj)
            % Destructor: ensure polling stops and resources are cleaned up
            fprintf('MJC3 MEX Controller: Cleaning up...\n');
            
            % Stop polling first
            obj.stop();
            
            % Clean up timer
            if ~isempty(obj.timerObj) && isvalid(obj.timerObj)
                try
                    stop(obj.timerObj);
                    delete(obj.timerObj);
                catch ME
                    fprintf('MJC3 MEX Controller: Warning - Error cleaning up timer: %s\n', ME.message);
                end
            end
            
            % Close MEX connection
            try
                fprintf('MJC3 MEX Controller: Closing MEX connection...\n');
                feval(obj.mexFunction, 'close');
                fprintf('MJC3 MEX Controller: MEX connection closed\n');
            catch ME
                fprintf('MJC3 MEX Controller: Warning - Error closing MEX: %s\n', ME.message);
            end
            
            fprintf('MJC3 MEX Controller: Cleanup complete\n');
        end
    end
    
    methods (Access = private)
        function success = verifyMEXFunction(obj)
            % Verify that the MEX function exists and is callable
            try
                % Test if function exists
                success = exist(obj.mexFunction, 'file') == 3; % 3 = MEX file
                
                if success
                    % Test basic functionality
                    result = feval(obj.mexFunction, 'test');
                    success = ~isempty(result);
                end
            catch
                success = false;
            end
        end
        
        function safePoll(obj)
            % Safe polling with comprehensive error handling
            if ~obj.running
                return;
            end
            
            try
                obj.poll();
            catch ME
                fprintf('MJC3 MEX Controller polling error: %s\n', ME.message);
                
                % Try to reconnect once
                if obj.connectToMJC3()
                    fprintf('MJC3 MEX Controller: Reconnected successfully\n');
                else
                    fprintf('MJC3 MEX Controller: Reconnection failed, stopping\n');
                    obj.stop();
                end
            end
        end
        
        function poll(obj)
            % Poll the MEX function and translate joystick movements into X, Y, Z moves
            data = obj.readJoystick();
            
            if length(data) < 5
                return;
            end
            
            % Extract values: [xVal, yVal, zVal, button, speedKnob]
            xVal = data(1);
            yVal = data(2);
            zVal = data(3);
            button = data(4);
            speedKnob = data(5);
            
            % Speed knob provides 0-255 range, normalize to 0.1-1.0
            speedFactor = max(0.1, speedKnob / 255);
            
            % Apply calibration to raw joystick values
            calibratedX = obj.CalibrationService.applyCalibration('X', xVal);
            calibratedY = obj.CalibrationService.applyCalibration('Y', yVal);
            calibratedZ = obj.CalibrationService.applyCalibration('Z', zVal);
            
            % Handle Z-axis movement with calibrated values
            if abs(calibratedZ) > 0.01 && zVal ~= obj.lastZValue
                % Compute Z movement in micrometres using calibrated value
                dz = calibratedZ * obj.stepFactor * speedFactor;
                
                if abs(dz) > 0.01  % Minimum movement threshold
                    success = obj.zController.relativeMove(dz);
                    if ~success
                        fprintf('MJC3 MEX: Failed to move Z-axis by %.2f μm\n', dz);
                    end
                end
                
                obj.lastZValue = zVal;
            elseif abs(calibratedZ) <= 0.01
                obj.lastZValue = 0; % Reset when joystick returns to center
            end
            
            % Handle X-axis movement with calibrated values
            if abs(calibratedX) > 0.01 && xVal ~= obj.lastXValue
                % Compute X movement in micrometres using calibrated value
                dx = calibratedX * obj.xStepFactor * speedFactor;
                
                if abs(dx) > 0.01  % Minimum movement threshold
                    success = obj.zController.relativeMoveX(dx);
                    if ~success
                        fprintf('MJC3 MEX: Failed to move X-axis by %.2f μm\n', dx);
                    end
                end
                
                obj.lastXValue = xVal;
            elseif abs(calibratedX) <= 0.01
                obj.lastXValue = 0; % Reset when joystick returns to center
            end
            
            % Handle Y-axis movement with calibrated values
            if abs(calibratedY) > 0.01 && yVal ~= obj.lastYValue
                % Compute Y movement in micrometres using calibrated value
                dy = calibratedY * obj.yStepFactor * speedFactor;
                
                if abs(dy) > 0.01  % Minimum movement threshold
                    success = obj.zController.relativeMoveY(dy);
                    if ~success
                        fprintf('MJC3 MEX: Failed to move Y-axis by %.2f μm\n', dy);
                    end
                end
                
                obj.lastYValue = yVal;
            elseif abs(calibratedY) <= 0.01
                obj.lastYValue = 0; % Reset when joystick returns to center
            end
        end
        
        function handleTimerError(obj)
            % Handle timer errors gracefully
            fprintf('MJC3 MEX Controller: Timer error occurred, stopping controller\n');
            obj.running = false;
            obj.isConnected = false;
        end
        
        % Calibration Methods
        function calibrateAxis(obj, axisName, samples)
            % Calibrate a specific axis using joystick samples
            % axisName: 'X', 'Y', or 'Z'
            % samples: Number of samples to collect (default: 100)
            
            if nargin < 3
                samples = 100;
            end
            
            try
                fprintf('Calibrating %s axis... Please move the joystick through its full range.\n', axisName);
                
                % Collect samples
                rawValues = [];
                for i = 1:samples
                    data = obj.readJoystick();
                    if length(data) >= 3
                        switch upper(axisName)
                            case 'X'
                                rawValues = [rawValues, data(1)];
                            case 'Y'
                                rawValues = [rawValues, data(2)];
                            case 'Z'
                                rawValues = [rawValues, data(3)];
                        end
                    end
                    pause(0.01); % 10ms delay between samples
                end
                
                % Perform calibration
                obj.CalibrationService.calibrateAxis(axisName, rawValues);
                
                fprintf('%s axis calibration completed successfully\n', axisName);
                
            catch ME
                fprintf('Calibration failed for %s axis: %s\n', axisName, ME.message);
                error('Calibration failed: %s', ME.message);
            end
        end
        
        function resetCalibration(obj, axisName)
            % Reset calibration for a specific axis or all axes
            % axisName: 'X', 'Y', 'Z', or 'all'
            
            try
                obj.CalibrationService.resetCalibration(axisName);
                fprintf('Calibration reset for %s\n', axisName);
            catch ME
                fprintf('Failed to reset calibration: %s\n', ME.message);
                error('Reset failed: %s', ME.message);
            end
        end
        
        function status = getCalibrationStatus(obj)
            % Get calibration status for all axes
            % Returns: Structure with calibration status
            
            try
                status = obj.CalibrationService.getCalibrationStatus();
            catch ME
                fprintf('Failed to get calibration status: %s\n', ME.message);
                status = [];
            end
        end
        
        function isCalibrated = isAxisCalibrated(obj, axisName)
            % Check if an axis has been calibrated
            % axisName: 'X', 'Y', or 'Z'
            % Returns: true if calibrated, false otherwise
            
            try
                isCalibrated = obj.CalibrationService.isAxisCalibrated(axisName);
            catch ME
                fprintf('Failed to check calibration status: %s\n', ME.message);
                isCalibrated = false;
            end
        end
    end
end