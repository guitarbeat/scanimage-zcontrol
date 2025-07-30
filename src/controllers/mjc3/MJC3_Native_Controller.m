classdef MJC3_Native_Controller < BaseMJC3Controller
    % MJC3_Native_Controller - Direct Windows API access to MJC3 joystick
    % Bypasses PsychHID by using Windows joystick API directly
    
    properties (Access = protected)
        timerObj       % Timer for polling
        lastZValue     % Last Z-axis value
        joystickID     % Windows joystick ID
    end
    
    properties
        stepFactor     % Micrometres moved per unit of joystick deflection
        running        % Logical flag indicating whether polling is active
    end
    
    methods
        function obj = MJC3_Native_Controller(zController, stepFactor)
            % Constructor
            % zController: Z-controller (must implement relativeMove method)
            % stepFactor: micrometres moved per unit (optional)
            
            % Call parent constructor
            obj@BaseMJC3Controller(zController, stepFactor);
            
            obj.lastZValue = 0;
            obj.joystickID = -1;
            
            % Find MJC3 joystick
            obj.findMJC3Joystick();
            
            % Setup polling timer
            obj.timerObj = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.05, ...        % Poll at 20 Hz
                'TimerFcn', @(~,~)obj.poll());
            
            fprintf('MJC3 Native Controller initialized (Step factor: %.1f μm/unit)\n', obj.stepFactor);
        end
        
        function start(obj)
            % Start polling the joystick
            if obj.joystickID == -1
                fprintf('No joystick found - cannot start\n');
                return;
            end
            
            if ~obj.running
                obj.running = true;
                start(obj.timerObj);
                fprintf('MJC3 Native Controller started\n');
            end
        end
        
        function stop(obj)
            % Stop polling
            if obj.running
                obj.running = false;
                stop(obj.timerObj);
                fprintf('MJC3 Native Controller stopped\n');
            end
        end
        
        function success = connectToMJC3(obj)
            % Check if MJC3 is connected
            success = obj.joystickID ~= -1;
        end
        
        function delete(obj)
            obj.stop();
            if ~isempty(obj.timerObj) && isvalid(obj.timerObj)
                delete(obj.timerObj);
            end
        end
        
        function poll(obj)
            % Poll joystick using Windows API
            if ~obj.running || obj.joystickID == -1
                return;
            end
            
            try
                % Get joystick position using Windows API
                [status, result] = system(sprintf('powershell "Add-Type -TypeDefinition ''using System; using System.Runtime.InteropServices; public class Win32 { [DllImport(\\\"winmm.dll\\\")] public static extern uint joyGetPos(uint uJoyID, ref JOYINFO pji); [StructLayout(LayoutKind.Sequential)] public struct JOYINFO { public uint wXpos; public uint wYpos; public uint wZpos; public uint wButtons; } }''; $info = New-Object Win32+JOYINFO; $result = [Win32]::joyGetPos(%d, [ref]$info); if ($result -eq 0) { Write-Output \\\"$($info.wXpos),$($info.wYpos),$($info.wZpos),$($info.wButtons)\\\" } else { Write-Output \\\"ERROR\\\" }"', obj.joystickID));
                
                if status == 0 && ~contains(result, 'ERROR')
                    % Parse joystick data
                    data = str2double(strsplit(strtrim(result), ','));
                    if length(data) >= 3
                        % Convert Z position to signed value (assuming center is 32768)
                        zRaw = data(3);
                        zVal = (zRaw - 32768) / 32768; % Normalize to -1 to +1
                        
                        % Only move if Z value changed significantly
                        if abs(zVal - obj.lastZValue) > 0.1 && abs(zVal) > 0.1
                            % Compute movement in micrometres
                            dz = zVal * obj.stepFactor;
                            
                            if abs(dz) > 0.01  % Minimum movement threshold
                                success = obj.zController.relativeMove(dz);
                                if ~success
                                    fprintf('MJC3: Failed to move Z-axis by %.2f μm\n', dz);
                                end
                            end
                            
                            obj.lastZValue = zVal;
                        elseif abs(zVal) <= 0.1
                            obj.lastZValue = 0; % Reset when joystick returns to center
                        end
                    end
                end
                
            catch ME
                fprintf('MJC3 polling error: %s\n', ME.message);
            end
        end
    end
    
    methods (Access = private)
        function success = findMJC3Joystick(obj)
            % Find MJC3 joystick using Windows API
            success = false;
            
            try
                % Check for joystick devices (Windows supports up to 16)
                for joyID = 0:15
                    % Use Windows multimedia API to check joystick
                    [status, result] = system(sprintf('powershell "Add-Type -TypeDefinition ''using System; using System.Runtime.InteropServices; public class Win32 { [DllImport(\\\"winmm.dll\\\")] public static extern uint joyGetNumDevs(); [DllImport(\\\"winmm.dll\\\")] public static extern uint joyGetDevCaps(uint uJoyID, ref JOYCAPS pjc, uint cbjc); [StructLayout(LayoutKind.Sequential)] public struct JOYCAPS { public ushort wMid; public ushort wPid; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szPname; public uint wXmin; public uint wXmax; public uint wYmin; public uint wYmax; public uint wZmin; public uint wZmax; public uint wNumButtons; public uint wPeriodMin; public uint wPeriodMax; public uint wRmin; public uint wRmax; public uint wUmin; public uint wUmax; public uint wVmin; public uint wVmax; public uint wCaps; public uint wMaxAxes; public uint wNumAxes; public uint wMaxButtons; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szRegKey; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string szOEMVxD; } }''; $caps = New-Object Win32+JOYCAPS; $result = [Win32]::joyGetDevCaps(%d, [ref]$caps, [System.Runtime.InteropServices.Marshal]::SizeOf($caps)); if ($result -eq 0) { Write-Output $caps.szPname } else { Write-Output \\\"NONE\\\" }"', joyID));
                    
                    if status == 0 && contains(result, 'MJC3', 'IgnoreCase', true)
                        obj.joystickID = joyID;
                        success = true;
                        fprintf('MJC3 joystick found at ID %d\n', joyID);
                        break;
                    end
                end
                
                if ~success
                    % Fallback: assume first joystick is MJC3
                    [status, ~] = system('powershell "$numJoy = Add-Type -TypeDefinition ''using System; using System.Runtime.InteropServices; public class Win32 { [DllImport(\\\"winmm.dll\\\")] public static extern uint joyGetNumDevs(); }'' -PassThru; [Win32]::joyGetNumDevs()"');
                    if status == 0
                        obj.joystickID = 0; % Use first joystick
                        success = true;
                        fprintf('Using first available joystick as MJC3 (ID 0)\n');
                    end
                end
                
            catch ME
                fprintf('Error finding MJC3 joystick: %s\n', ME.message);
            end
        end
    end
end 