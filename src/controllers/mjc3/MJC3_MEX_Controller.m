classdef MJC3_MEX_Controller < BaseMJC3Controller
    % MJC3_MEX_Controller - High-performance MEX-based MJC3 controller
    % Uses custom C++ MEX function for direct HID access without PsychHID
    
    properties
        stepFactor     % Micrometres moved per unit of joystick deflection
        running        % Logical flag indicating whether polling is active
        timerObj       % MATLAB timer object for polling
        lastZValue     % Last Z-axis value to detect changes
        mexFunction    % Name of the MEX function
        isConnected    % Connection status
    end
    
    properties (Constant)
        MEX_FUNCTION = 'mjc3_joystick_mex';  % MEX function name
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
            obj.isConnected = false;
            obj.running = false;
            
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
        
        function delete(obj)
            % Destructor: ensure polling stops and resources are cleaned up
            obj.stop();
            if ~isempty(obj.timerObj) && isvalid(obj.timerObj)
                delete(obj.timerObj);
            end
            
            % Close MEX connection
            try
                feval(obj.mexFunction, 'close');
            catch
                % MEX may already be closed
            end
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
            % Poll the MEX function and translate joystick movements into Z moves
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
            
            % Only move if Z value changed (avoid continuous movement)
            if zVal ~= obj.lastZValue && zVal ~= 0
                % Compute movement in micrometres
                % Speed knob provides 0-255 range, normalize to 0.1-1.0
                speedFactor = max(0.1, speedKnob / 255);
                dz = double(zVal) * obj.stepFactor * speedFactor;
                
                if abs(dz) > 0.01  % Minimum movement threshold
                    success = obj.zController.relativeMove(dz);
                    if ~success
                        fprintf('MJC3 MEX: Failed to move Z-axis by %.2f μm\n', dz);
                    end
                end
                
                obj.lastZValue = zVal;
            elseif zVal == 0
                obj.lastZValue = 0; % Reset when joystick returns to center
            end
        end
        
        function handleTimerError(obj)
            % Handle timer errors gracefully
            fprintf('MJC3 MEX Controller: Timer error occurred, stopping controller\n');
            obj.running = false;
            obj.isConnected = false;
        end
    end
end