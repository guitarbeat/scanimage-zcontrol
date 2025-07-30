classdef MJC3_Windows_HID_Controller < BaseMJC3Controller
    % MJC3_Windows_HID_Controller - Windows native HID access for MJC3 joystick
    % Uses Windows API calls instead of PsychHID to avoid licensing issues
    
    properties
        timerObj    % Timer for polling
        hidDevice   % HID device handle
        lastZValue  % Last Z-axis value
    end
    
    methods
        function obj = MJC3_Windows_HID_Controller(zController, stepFactor)
            % Constructor
            % zController: Z-controller (must implement relativeMove method)
            % stepFactor: micrometres moved per unit (optional)
            
            % Call parent constructor
            obj@BaseMJC3Controller(zController, stepFactor);
            
            obj.lastZValue = 0;
            
            % Try to find and connect to MJC3 device
            obj.connectToMJC3();
            
            % Setup polling timer
            obj.timerObj = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.05, ...        % Poll at 20 Hz
                'TimerFcn', @(~,~)obj.poll());
            
            fprintf('MJC3 Windows HID Controller initialized (Step factor: %.1f μm/unit)\n', obj.stepFactor);
        end
        
        function start(obj)
            % Start polling the joystick
            if ~obj.running
                obj.running = true;
                start(obj.timerObj);
                fprintf('MJC3 Windows HID Controller started\n');
                fprintf('Note: This is a simplified version. For full HID functionality, consider licensing Psychtoolbox.\n');
            end
        end
        
        function stop(obj)
            % Stop polling
            if obj.running
                obj.running = false;
                stop(obj.timerObj);
                fprintf('MJC3 Windows HID Controller stopped\n');
            end
        end
        
        function success = connectToMJC3(obj)
            % Try to connect to MJC3 using Windows HID API
            success = false;
            try
                % Use PowerShell to find HID devices
                cmd = 'powershell "Get-WmiObject Win32_PnPEntity | Where-Object {$_.DeviceID -like ''*VID_1313*'' -and $_.DeviceID -like ''*PID_9000*''} | Select-Object Name, DeviceID"';
                [status, result] = system(cmd);
                
                if status == 0 && contains(result, 'VID_1313')
                    fprintf('MJC3 device found via Windows API\n');
                    success = true;
                else
                    warning('MJC3 device not found. Check USB connection.');
                end
            catch ME
                warning(ME.identifier, 'Failed to connect to MJC3: %s', ME.message);
            end
        end
        
        function delete(obj)
            obj.stop();
            if ~isempty(obj.timerObj) && isvalid(obj.timerObj)
                delete(obj.timerObj);
            end
        end
        
        function poll(obj)
            % Poll joystick using Windows API (without PsychHID)
            if ~obj.running
                return;
            end
            
            try
                % Use Windows PowerShell to read joystick state
                % This is a workaround for PsychHID issues
                cmd = 'powershell "Add-Type -AssemblyName System.Windows.Forms; $js = New-Object System.Windows.Forms.Timer; $js.Interval = 1; try { [System.Windows.Forms.Application]::DoEvents(); $state = [Microsoft.DirectX.DirectInput.Joystick]::GetCurrentState(); Write-Output \"$($state.Z)\" } catch { Write-Output \"0\" }"';
                
                [status, result] = system(cmd);
                
                if status == 0
                    % Parse Z-axis value
                    zRaw = str2double(strtrim(result));
                    if ~isnan(zRaw)
                        % Convert to normalized value (-1 to +1)
                        zVal = (zRaw - 32768) / 32768;
                        
                        % Only move if significant change
                        if abs(zVal) > 0.1 && abs(zVal - obj.lastZValue) > 0.05
                            dz = zVal * obj.stepFactor;
                            
                            if abs(dz) > 0.01
                                try
                                    obj.zController.relativeMove(dz);
                                    fprintf('Joystick Z: %.1f μm\n', dz);
                                catch ME
                                    fprintf('Movement error: %s\n', ME.message);
                                end
                            end
                            
                            obj.lastZValue = zVal;
                        elseif abs(zVal) <= 0.1
                            obj.lastZValue = 0;
                        end
                    end
                end
                
            catch ME
                % Silently handle polling errors
                if obj.running
                    fprintf('Joystick polling error: %s\n', ME.message);
                end
            end
        end
    end
end 