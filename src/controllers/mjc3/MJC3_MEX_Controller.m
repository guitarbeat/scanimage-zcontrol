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
                        obj.Logger.debug('Z-axis moved by %.2f μm (calibrated: %.3f, speed: %.2f)', dz, calibratedZ, speedFactor);
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
        
        % Calibration Methods
        function calibrateAxis(obj, axisName, samples)
            % Calibrate a specific axis using joystick samples
            % axisName: 'X', 'Y', or 'Z'
            % samples: Number of samples to collect (default: 100)
            
            if nargin < 3
                samples = 100;
            end
            
            try
                obj.Logger.info('Starting calibration for %s axis (%d samples)...', axisName, samples);
                obj.Logger.info('Please move the joystick through its full range for %s axis', axisName);
                
                % Collect samples
                rawValues = [];
                obj.Logger.debug('Collecting %d calibration samples...', samples);
                
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
                    
                    % Log progress every 10 samples
                    if mod(i, 10) == 0
                        obj.Logger.debug('Calibration progress: %d/%d samples collected', i, samples);
                    end
                end
                
                obj.Logger.debug('Collected %d raw values for %s axis calibration', length(rawValues), axisName);
                obj.Logger.debug('Raw value range: [%d, %d]', min(rawValues), max(rawValues));
                
                % Perform calibration
                obj.CalibrationService.calibrateAxis(axisName, rawValues);
                
                obj.Logger.info('%s axis calibration completed successfully (%d samples)', axisName, length(rawValues));
                obj.Logger.debug('Calibration data saved for %s axis', axisName);
                
            catch ME
                obj.Logger.error('Calibration failed for %s axis: %s', axisName, ME.message);
                obj.Logger.debug('Calibration error details: %s', ME.getReport());
                error('Calibration failed: %s', ME.message);
            end
        end
        
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
    end
end