classdef ThorlabsZControl < handle
    % ThorlabsZControl - Direct control of Thorlabs Z motors using APT ActiveX
    %
    % This class provides direct control of Thorlabs Kinesis/APT motors for Z positioning
    % in ScanImage, bypassing ScanImage's motor control API and using the Thorlabs
    % APT ActiveX controls directly.
    %
    % Based on the approach used in BakingTray (https://github.com/SWC-Advanced-Microscopy/BakingTray)
    %
    % Usage:
    %   1. Start ScanImage
    %   2. Run: z = ThorlabsZControl()
    %   3. Use z.moveAbsolute() or z.moveRelative() to control Z position
    %
    % Requirements:
    %   - Thorlabs APT software installed (32-bit or 64-bit matching MATLAB)
    %   - Thorlabs Kinesis motor connected via USB
    %
    % Author: Manus AI (2025)
    
    properties
        % ActiveX control properties
        figH            % Handle to hidden figure for ActiveX control
        hC              % Handle to ActiveX control
        loggingObject   % Handle to APT logging object
        
        % Motor properties
        controllerID    % Serial number of the controller
        isConnected = false  % Connection status
        
        % Position properties
        currentPosition = 0  % Current Z position
        minPosition = -1000  % Minimum allowed position
        maxPosition = 1000   % Maximum allowed position
        
        % Movement properties
        velocity = 2.0       % Movement velocity (mm/s)
        acceleration = 0.5   % Acceleration (mm/s^2)
        
        % Debug properties
        debugLevel = 1       % 0=none, 1=normal, 2=verbose
    end
    
    methods
        function obj = ThorlabsZControl()
            % Constructor - Initialize the ThorlabsZControl object
            
            % Create a hidden figure to host the ActiveX control
            obj.figH = figure('Visible', 'off', ...
                'Name', 'Thorlabs Z Control', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'HandleVisibility', 'off');
            
            % Set close request function to properly clean up ActiveX
            set(obj.figH, 'CloseRequestFcn', @obj.onClose);
            
            % Connect to the Thorlabs controller
            obj.connect();
            
            % Display initial status
            if obj.isConnected
                fprintf('ThorlabsZControl initialized. Current Z position: %.2f\n', obj.getCurrentPosition());
            else
                fprintf('Failed to connect to Thorlabs controller.\n');
            end
        end
        
        function delete(obj)
            % Destructor - Clean up ActiveX controls
            obj.disconnect();
        end
        
        function connect(obj)
            % Connect to the Thorlabs controller using ActiveX
            try
                % Create the APT logging object
                obj.log('Creating Thorlabs APT logging object...', 1);
                pos = [0, 0, 1, 1]; % Invisible size
                obj.loggingObject = actxcontrol('MG17SYSTEM.MG17SystemCtrl.1', pos, obj.figH);
                
                % Start the logging control
                obj.log('Starting APT logging object...', 1);
                obj.loggingObject.StartCtrl;
                
                % Check for available controllers
                [~, nMotorControllers] = obj.loggingObject.GetNumHWUnits(6, 0); % 6 is the type for BSC/KSC controllers
                
                if nMotorControllers < 1
                    obj.log('No Thorlabs motor controllers found.', 1);
                    obj.isConnected = false;
                    return;
                end
                
                % Get the controller ID
                [~, ID] = obj.loggingObject.GetHWSerialNum(6, 0, 0);
                obj.controllerID = ID;
                obj.log(sprintf('Found Thorlabs controller with ID: %d', ID), 1);
                
                % Create the motor control ActiveX
                obj.log('Creating Thorlabs motor control object...', 1);
                obj.hC = actxcontrol('MGMOTOR.MGMotorCtrl.1', pos, obj.figH);
                
                % Start the motor control
                obj.hC.StartCtrl;
                set(obj.hC, 'HWSerialNum', obj.controllerID);
                
                % Check connection
                [~, connected] = obj.hC.GetHWCommsOK(0);
                obj.isConnected = (connected == 1);
                
                if obj.isConnected
                    obj.log('Successfully connected to Thorlabs controller.', 1);
                    
                    % Configure motor settings
                    obj.setAcceleration(obj.acceleration);
                    obj.setVelocity(obj.velocity);
                    obj.hC.SetBLashDist(0, 0); % Disable backlash compensation
                    
                    % Get current position
                    obj.updatePosition();
                else
                    obj.log('Failed to connect to Thorlabs controller.', 1);
                end
            catch ME
                obj.log(sprintf('Error connecting to Thorlabs controller: %s', ME.message), 1);
                obj.isConnected = false;
            end
        end
        
        function disconnect(obj)
            % Disconnect from the Thorlabs controller
            try
                if ~isempty(obj.hC)
                    obj.log('Stopping Thorlabs motor control...', 1);
                    obj.hC.StopCtrl;
                end
                
                if ~isempty(obj.loggingObject)
                    obj.log('Stopping Thorlabs logging object...', 1);
                    obj.loggingObject.StopCtrl;
                end
                
                if ~isempty(obj.figH) && ishandle(obj.figH)
                    obj.log('Closing ActiveX figure...', 1);
                    delete(obj.figH);
                end
                
                obj.isConnected = false;
                obj.log('Disconnected from Thorlabs controller.', 1);
            catch ME
                obj.log(sprintf('Error disconnecting from Thorlabs controller: %s', ME.message), 1);
            end
        end
        
        function onClose(obj, ~, ~)
            % Handle figure close request
            obj.disconnect();
            delete(obj.figH);
        end
        
        function pos = getCurrentPosition(obj)
            % Get the current Z position
            pos = obj.currentPosition;
            
            if obj.isConnected
                try
                    [~, pos] = obj.hC.GetPosition(0, 0);
                    obj.currentPosition = pos;
                    obj.log(sprintf('Current Z position: %.2f', pos), 2);
                catch ME
                    obj.log(sprintf('Error getting position: %s', ME.message), 1);
                end
            end
        end
        
        function updatePosition(obj)
            % Update the stored current position
            obj.currentPosition = obj.getCurrentPosition();
        end
        
        function success = moveAbsolute(obj, targetPosition)
            % Move to an absolute Z position
            success = false;
            
            if ~obj.isConnected
                obj.log('Not connected to Thorlabs controller.', 1);
                return;
            end
            
            % Check if position is within bounds
            if targetPosition < obj.minPosition || targetPosition > obj.maxPosition
                obj.log(sprintf('Target position %.2f is outside allowed range [%.2f, %.2f]', ...
                    targetPosition, obj.minPosition, obj.maxPosition), 1);
                return;
            end
            
            try
                obj.log(sprintf('Moving to absolute position: %.2f', targetPosition), 1);
                obj.hC.SetAbsMovePos(0, targetPosition);
                obj.hC.MoveAbsolute(0, 0);
                
                % Wait for movement to complete
                obj.waitForMovementComplete();
                
                % Update position
                obj.updatePosition();
                obj.log(sprintf('Moved to position: %.2f', obj.currentPosition), 1);
                success = true;
            catch ME
                obj.log(sprintf('Error moving to position: %s', ME.message), 1);
            end
        end
        
        function success = moveRelative(obj, distance)
            % Move by a relative distance
            success = false;
            
            if ~obj.isConnected
                obj.log('Not connected to Thorlabs controller.', 1);
                return;
            end
            
            % Check if resulting position would be within bounds
            targetPosition = obj.currentPosition + distance;
            if targetPosition < obj.minPosition || targetPosition > obj.maxPosition
                obj.log(sprintf('Target position %.2f is outside allowed range [%.2f, %.2f]', ...
                    targetPosition, obj.minPosition, obj.maxPosition), 1);
                return;
            end
            
            try
                obj.log(sprintf('Moving by relative distance: %.2f', distance), 1);
                obj.hC.SetRelMoveDist(0, distance);
                obj.hC.MoveRelative(0, 0);
                
                % Wait for movement to complete
                obj.waitForMovementComplete();
                
                % Update position
                obj.updatePosition();
                obj.log(sprintf('Moved to position: %.2f', obj.currentPosition), 1);
                success = true;
            catch ME
                obj.log(sprintf('Error moving by distance: %s', ME.message), 1);
            end
        end
        
        function success = setVelocity(obj, velocity)
            % Set the movement velocity
            success = false;
            
            if ~obj.isConnected
                obj.log('Not connected to Thorlabs controller.', 1);
                return;
            end
            
            try
                obj.log(sprintf('Setting velocity to: %.2f', velocity), 1);
                obj.hC.SetVelParams(0, 0, acceleration, velocity);
                obj.velocity = velocity;
                success = true;
            catch ME
                obj.log(sprintf('Error setting velocity: %s', ME.message), 1);
            end
        end
        
        function success = setAcceleration(obj, acceleration)
            % Set the movement acceleration
            success = false;
            
            if ~obj.isConnected
                obj.log('Not connected to Thorlabs controller.', 1);
                return;
            end
            
            try
                obj.log(sprintf('Setting acceleration to: %.2f', acceleration), 1);
                obj.hC.SetVelParams(0, 0, acceleration, obj.velocity);
                obj.acceleration = acceleration;
                success = true;
            catch ME
                obj.log(sprintf('Error setting acceleration: %s', ME.message), 1);
            end
        end
        
        function waitForMovementComplete(obj, timeout)
            % Wait for movement to complete
            if nargin < 2
                timeout = 10; % Default timeout in seconds
            end
            
            if ~obj.isConnected
                return;
            end
            
            obj.log('Waiting for movement to complete...', 2);
            
            % Get status bits to check for movement
            tic;
            while toc < timeout
                if ~obj.isMoving()
                    obj.log('Movement completed.', 2);
                    return;
                end
                pause(0.1);
            end
            
            obj.log('Movement timed out!', 1);
        end
        
        function moving = isMoving(obj)
            % Check if the motor is currently moving
            moving = false;
            
            if ~obj.isConnected
                return;
            end
            
            try
                bits = obj.getStatusBits();
                if isempty(bits)
                    return;
                end
                
                % Bits 5 and 6 indicate movement
                if bitget(bits, 5) || bitget(bits, 6)
                    moving = true;
                end
            catch
                % Default to not moving if error
            end
        end
        
        function bits = getStatusBits(obj)
            % Get the status bits from the controller
            bits = [];
            
            if ~obj.isConnected
                return;
            end
            
            try
                [~, bits] = obj.hC.GetStatusBits(0);
            catch
                % Return empty if error
            end
        end
        
        function log(obj, message, level)
            % Log a message based on debug level
            if nargin < 3
                level = 1;
            end
            
            if obj.debugLevel >= level
                timestamp = datestr(now, 'HH:MM:SS');
                fprintf('[%s] ThorlabsZControl: %s\n', timestamp, message);
            end
        end
    end
end
