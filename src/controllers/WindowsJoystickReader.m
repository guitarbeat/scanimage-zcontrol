classdef WindowsJoystickReader < handle
    % WindowsJoystickReader - Simple Windows joystick reader without PsychHID
    % Uses Windows registry and device manager to read joystick state
    
    properties (Access = private)
        joystickFound = false
        lastPosition = [0, 0, 0] % X, Y, Z
    end
    
    methods
        function obj = WindowsJoystickReader()
            obj.detectJoystick();
        end
        
        function success = detectJoystick(obj)
            % Detect if MJC3 joystick is connected
            success = false;
            
            try
                % Method 1: Check Windows device manager
                [status, result] = system('powershell "Get-WmiObject Win32_PnPEntity | Where-Object {$_.DeviceID -like ''*VID_1313*'' -and $_.DeviceID -like ''*PID_9000*''} | Select-Object -First 1 | Select-Object Name"');
                
                if status == 0 && contains(result, 'MJC3', 'IgnoreCase', true)
                    obj.joystickFound = true;
                    success = true;
                    fprintf('MJC3 joystick detected via device manager\n');
                    return;
                end
                
                % Method 2: Check for any HID joystick device
                [status, result] = system('powershell "Get-WmiObject Win32_PnPEntity | Where-Object {$_.PNPClass -eq ''HIDClass'' -and $_.Name -like ''*joystick*''} | Select-Object -First 1 | Select-Object Name"');
                
                if status == 0 && ~isempty(strtrim(result)) && ~contains(result, 'No instances')
                    obj.joystickFound = true;
                    success = true;
                    fprintf('Generic joystick detected, assuming MJC3\n');
                    return;
                end
                
                % Method 3: Simple registry check
                [status, ~] = system('reg query "HKEY_CURRENT_USER\System\CurrentControlSet\Control\MediaResources\Joystick" 2>nul');
                if status == 0
                    obj.joystickFound = true;
                    success = true;
                    fprintf('Joystick registry entries found\n');
                end
                
            catch ME
                fprintf('Joystick detection error: %s\n', ME.message);
            end
        end
        
        function [x, y, z, buttons] = readJoystick(obj)
            % Read joystick position (simplified simulation)
            x = 0; y = 0; z = 0; buttons = 0;
            
            if ~obj.joystickFound
                return;
            end
            
            % This is a placeholder - real implementation would need
            % Windows API calls or a MEX file to read joystick data
            % For now, return neutral position
            
            % In a real implementation, you would:
            % 1. Call Windows joyGetPos() API
            % 2. Parse the JOYINFO structure
            % 3. Convert raw values to normalized coordinates
            
            % Placeholder: simulate some movement for testing
            persistent counter;
            if isempty(counter)
                counter = 0;
            end
            counter = counter + 1;
            
            % Simulate occasional Z movement for testing
            if mod(counter, 100) == 0
                z = 0.1 * sin(counter / 100);
            end
        end
        
        function isConnected = isJoystickConnected(obj)
            % Check if joystick is still connected
            isConnected = obj.joystickFound;
            
            % Periodically re-check connection
            persistent lastCheck;
            if isempty(lastCheck)
                lastCheck = tic;
            end
            
            if toc(lastCheck) > 5 % Check every 5 seconds
                obj.detectJoystick();
                lastCheck = tic;
            end
        end
    end
end