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
%   - LoggingService: Unified logging system
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
        stepFactor     % Micrometres moved per unit of joystick deflection (Z-axis) - from abstract base
        running        % Logical flag indicating whether polling is active - from abstract base
        xStepFactor    % Micrometres moved per unit of joystick deflection (X-axis)
        yStepFactor    % Micrometres moved per unit of joystick deflection (Y-axis)
        timerObj       % MATLAB timer object for polling
        lastZValue     % Last Z-axis value to detect changes
        lastXValue     % Last X-axis value to detect changes
        lastYValue     % Last Y-axis value to detect changes
        lastButtonState % Last button state to detect changes
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
            obj.lastButtonState = 0;
            obj.isConnected = false;
            obj.running = false;
            
            % Initialize step factors for all axes
            obj.xStepFactor = stepFactor;
            obj.yStepFactor = stepFactor;
            
            % Initialize calibration service
            obj.CalibrationService = CalibrationService();
            
            % Verify MEX function exists
            if ~obj.verifyMEXFunction()
                obj.Logger.error('MEX function %s not found. Please compile the MEX file.', obj.mexFunction);
                error('MJC3_MEX_Controller:MEXNotFound', ...
                    'MEX function %s not found. Please compile the MEX file.', obj.mexFunction);
            end
            
            % Test connection
            if ~obj.connectToMJC3()
                obj.Logger.warning('MJC3 device not detected. Controller created but not connected.');
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
                    obj.Logger.error('Cannot start: MJC3 device not connected');
                    error('MJC3_MEX_Controller:NotConnected', 'Cannot start: MJC3 device not connected');
                end
                
                obj.running = true;
                start(obj.timerObj);
                obj.Logger.info('Started polling (Step factor: %.1f μm/unit, Poll rate: %.0f Hz)', ...
                    obj.stepFactor, 1/obj.POLL_RATE);
            end
        end
        
        function stop(obj)
            % Stop polling the joystick
            if obj.running
                obj.running = false;
                stop(obj.timerObj);
                obj.Logger.info('Stopped polling');
            end
        end
        
        function success = connectToMJC3(obj)
            % Test connection to MJC3 device
            try
                obj.Logger.debug('Attempting to connect to MJC3 device...');
                
                % Check if device info shows connection
                info = feval(obj.mexFunction, 'info');
                obj.isConnected = info.connected;
                success = obj.isConnected;
                
                if success
                    obj.Logger.info('MJC3 device connected successfully (VID:1313, PID:9000)');
                    obj.Logger.debug('Device info: %s', jsonencode(info));
                else
                    obj.Logger.warning('MJC3 device not detected - check USB connection');
                    obj.Logger.debug('Connection test failed - device may be disconnected or not powered');
                end
            catch ME
                obj.isConnected = false;
                success = false;
                obj.Logger.error('Connection test failed: %s', ME.message);
                obj.Logger.debug('Connection error details: %s', ME.getReport());
            end
        end
        
        function data = readJoystick(obj)
            % Read current joystick state
            % Returns: [xVal, yVal, zVal, button, speedKnob]
            try
                data = feval(obj.mexFunction, 'read', 50); % 50ms timeout
                if isempty(data)
                    data = [0, 0, 0, 0, 0]; % Return neutral state on timeout
                    obj.Logger.debug('Joystick read timeout - returning neutral state');
                end
            catch ME
                obj.Logger.error('Joystick read error: %s', ME.message);
                obj.Logger.debug('Read error details: %s', ME.getReport());
                data = [0, 0, 0, 0, 0];
            end
        end
        
        function info = getDeviceInfo(obj)
            % Get device information
            try
                info = feval(obj.mexFunction, 'info');
                obj.Logger.debug('Device info retrieved: %s', jsonencode(info));
            catch ME
                obj.Logger.error('Device info error: %s', ME.message);
                obj.Logger.debug('Info error details: %s', ME.getReport());
                info = struct('connected', false, 'error', ME.message);
            end
        end
        
        function setXStepFactor(obj, stepFactor)
            % Set X-axis step factor
            if stepFactor > 0
                obj.xStepFactor = stepFactor;
                obj.Logger.info('X-axis step factor updated to %.1f μm/unit', stepFactor);
            else
                obj.Logger.warning('X-axis step factor must be positive (got: %.1f)', stepFactor);
            end
        end
        
        function setYStepFactor(obj, stepFactor)
            % Set Y-axis step factor
            if stepFactor > 0
                obj.yStepFactor = stepFactor;
                obj.Logger.info('Y-axis step factor updated to %.1f μm/unit', stepFactor);
            else
                obj.Logger.warning('Y-axis step factor must be positive (got: %.1f)', stepFactor);
            end
        end
        
        function delete(obj)
            % Destructor: ensure polling stops and resources are cleaned up
            obj.Logger.info('Cleaning up MJC3 MEX controller resources...');
            
            % Stop polling first
            obj.stop();
            
            % Clean up timer
            if ~isempty(obj.timerObj) && isvalid(obj.timerObj)
                try
                    stop(obj.timerObj);
                    delete(obj.timerObj);
                    obj.Logger.debug('Timer object cleaned up successfully');
                catch ME
                    obj.Logger.warning('Error cleaning up timer: %s', ME.message);
                end
            end
            
            % Close MEX connection
            try
                obj.Logger.debug('Closing MEX connection...');
                feval(obj.mexFunction, 'close');
                obj.Logger.debug('MEX connection closed successfully');
            catch ME
                obj.Logger.warning('Error closing MEX connection: %s', ME.message);
            end
            
            obj.Logger.info('MJC3 MEX controller cleanup complete');
        end
    end
    
    methods (Access = private)
        function success = verifyMEXFunction(obj)
            % Verify that the MEX function exists and is callable
            try
                obj.Logger.debug('Verifying MEX function: %s', obj.mexFunction);
                
                % Test if function exists
                success = exist(obj.mexFunction, 'file') == 3; % 3 = MEX file
                
                if success
                    obj.Logger.debug('MEX function file found, testing functionality...');
                    % Test basic functionality
                    result = feval(obj.mexFunction, 'test');
                    success = ~isempty(result);
                    
                    if success
                        obj.Logger.debug('MEX function test passed');
                    else
                        obj.Logger.warning('MEX function test failed - function exists but test failed');
                    end
                else
                    obj.Logger.warning('MEX function file not found: %s', obj.mexFunction);
                end
            catch ME
                obj.Logger.error('MEX function verification failed: %s', ME.message);
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
                obj.Logger.error('Polling error: %s', ME.message);
                obj.Logger.debug('Polling error details: %s', ME.getReport());
                
                % Try to reconnect once
                if obj.connectToMJC3()
                    obj.Logger.info('Reconnected successfully after polling error');
                else
                    obj.Logger.error('Reconnection failed after polling error, stopping controller');
                    obj.stop();
                end
            end
        end
        
        function poll(obj)
            % Poll the MEX function and translate joystick movements into X, Y, Z moves
            data = obj.readJoystick();
            
            if length(data) < 5
                obj.Logger.debug('Invalid joystick data length: %d (expected 5)', length(data));
                return;
            end
            
            % Extract values: [xVal, yVal, zVal, button, speedKnob]
            xVal = data(1);
            yVal = data(2);
            zVal = data(3);
            button = data(4);
            speedKnob = data(5);
            
            % Handle button state changes
            if button ~= obj.lastButtonState
                obj.Logger.debug('Button state changed: %d -> %d', obj.lastButtonState, button);
                obj.lastButtonState = button;
                
                % Button pressed (assuming button value > 0 indicates pressed)
                if button > 0
                    obj.handleButtonPress();
                end
            end
            
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
                        obj.Logger.warning('Failed to move Z-axis by %.2f μm', dz);
                    else
                        obj.Logger.debug('Z-axis moved by %.2f μm (raw: %d, calibrated: %.3f, speed: %.2f)', dz, zVal, calibratedZ, speedFactor);
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
                        obj.Logger.warning('Failed to move X-axis by %.2f μm', dx);
                    else
                        obj.Logger.debug('X-axis moved by %.2f μm (calibrated: %.3f, speed: %.2f)', dx, calibratedX, speedFactor);
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
                        obj.Logger.warning('Failed to move Y-axis by %.2f μm', dy);
                    else
                        obj.Logger.debug('Y-axis moved by %.2f μm (calibrated: %.3f, speed: %.2f)', dy, calibratedY, speedFactor);
                    end
                end
                
                obj.lastYValue = yVal;
            elseif abs(calibratedY) <= 0.01
                obj.lastYValue = 0; % Reset when joystick returns to center
            end
        end
        
        function handleTimerError(obj)
            % Handle timer errors gracefully
            obj.Logger.error('Timer error occurred, stopping controller');
            obj.running = false;
            obj.isConnected = false;
        end
        
        function handleButtonPress(obj)
            % Handle joystick button press events
            % This method can be extended to implement button-specific functionality
            % such as enabling/disabling movement, changing modes, etc.
            
            obj.Logger.info('Joystick button pressed (value: %d)', obj.lastButtonState);
            
            % TODO: Implement button-specific functionality
            % Examples:
            % - Toggle movement enable/disable
            % - Change movement speed modes
            % - Trigger calibration
            % - Emergency stop
        end
        
        % Calibration Methods

        
        function resetCalibration(obj, axisName)
            % Reset calibration for a specific axis or all axes
            % axisName: 'X', 'Y', 'Z', or 'all'
            
            try
                obj.Logger.info('Resetting calibration for %s...', axisName);
                obj.CalibrationService.resetCalibration(axisName);
                obj.Logger.info('Calibration reset successfully for %s', axisName);
            catch ME
                obj.Logger.error('Failed to reset calibration for %s: %s', axisName, ME.message);
                obj.Logger.debug('Reset error details: %s', ME.getReport());
                error('Reset failed: %s', ME.message);
            end
        end
        
        function status = getCalibrationStatus(obj)
            % Get calibration status for all axes
            % Returns: Structure with calibration status
            
            try
                status = obj.CalibrationService.getCalibrationStatus();
                obj.Logger.debug('Calibration status retrieved: %s', jsonencode(status));
            catch ME
                obj.Logger.error('Failed to get calibration status: %s', ME.message);
                obj.Logger.debug('Status error details: %s', ME.getReport());
                status = [];
            end
        end
        
        function isCalibrated = isAxisCalibrated(obj, axisName)
            % Check if an axis has been calibrated
            % axisName: 'X', 'Y', or 'Z'
            % Returns: true if calibrated, false otherwise
            
            try
                isCalibrated = obj.CalibrationService.isAxisCalibrated(axisName);
                obj.Logger.debug('%s axis calibration status: %s', axisName, mat2str(isCalibrated));
            catch ME
                obj.Logger.error('Failed to check calibration status for %s: %s', axisName, ME.message);
                obj.Logger.debug('Calibration check error details: %s', ME.getReport());
                isCalibrated = false;
            end
        end
        
        function setManualCalibration(obj, axisName, negativePos, centerPos, positivePos, deadzone, resolution, damping, invertSense)
            % Set manual calibration parameters for an axis
            % axisName: 'X', 'Y', or 'Z'
            % negativePos: Raw value at maximum negative deflection
            % centerPos: Raw value at center/rest position  
            % positivePos: Raw value at maximum positive deflection
            % deadzone: Dead zone around center (optional)
            % resolution: Movement resolution/sensitivity (optional)
            % damping: Movement damping factor (optional)
            % invertSense: Invert axis direction (optional)
            
            try
                obj.Logger.info('Setting manual calibration for %s axis...', axisName);
                obj.CalibrationService.setManualCalibration(axisName, negativePos, centerPos, positivePos, deadzone, resolution, damping, invertSense);
                obj.Logger.info('Manual calibration set successfully for %s axis', axisName);
            catch ME
                obj.Logger.error('Failed to set manual calibration for %s axis: %s', axisName, ME.message);
                obj.Logger.debug('Manual calibration error details: %s', ME.getReport());
                error('Manual calibration failed: %s', ME.message);
            end
        end
        
        function setAxisParameter(obj, axisName, parameterName, value)
            % Set a specific calibration parameter for an axis
            % axisName: 'X', 'Y', or 'Z'
            % parameterName: 'deadzone', 'resolution', 'damping', 'invertSense', 'sensitivity'
            % value: New parameter value
            
            try
                obj.Logger.info('Setting %s parameter to %s for %s axis', parameterName, mat2str(value), axisName);
                obj.CalibrationService.setAxisParameter(axisName, parameterName, value);
                obj.Logger.info('Parameter %s updated successfully for %s axis', parameterName, axisName);
            catch ME
                obj.Logger.error('Failed to set parameter %s for %s axis: %s', parameterName, axisName, ME.message);
                obj.Logger.debug('Parameter setting error details: %s', ME.getReport());
                error('Parameter setting failed: %s', ME.message);
            end
        end
        
        function value = getAxisParameter(obj, axisName, parameterName)
            % Get a specific calibration parameter for an axis
            % axisName: 'X', 'Y', or 'Z'
            % parameterName: 'center', 'min', 'max', 'deadzone', 'resolution', 'damping', 'invertSense', 'sensitivity'
            % Returns: Parameter value
            
            try
                value = obj.CalibrationService.getAxisParameter(axisName, parameterName);
                obj.Logger.debug('Retrieved %s parameter for %s axis: %s', parameterName, axisName, mat2str(value));
            catch ME
                obj.Logger.error('Failed to get parameter %s for %s axis: %s', parameterName, axisName, ME.message);
                obj.Logger.debug('Parameter retrieval error details: %s', ME.getReport());
                value = [];
            end
        end
        
        function currentValue = getCurrentRawValue(obj, axisName)
            % Get current raw joystick value for an axis (for manual calibration)
            % axisName: 'X', 'Y', or 'Z'
            % Returns: Current raw value for the specified axis
            
            try
                data = obj.readJoystick();
                if length(data) >= 3
                    switch upper(axisName)
                        case 'X'
                            currentValue = data(1);
                        case 'Y'
                            currentValue = data(2);
                        case 'Z'
                            currentValue = data(3);
                        otherwise
                            error('Invalid axis name: %s', axisName);
                    end
                    obj.Logger.debug('Current raw value for %s axis: %d', axisName, currentValue);
                else
                    obj.Logger.warning('Invalid joystick data received');
                    currentValue = 0;
                end
            catch ME
                obj.Logger.error('Failed to get current raw value for %s axis: %s', axisName, ME.message);
                obj.Logger.debug('Raw value retrieval error details: %s', ME.getReport());
                currentValue = 0;
            end
        end
    end
end