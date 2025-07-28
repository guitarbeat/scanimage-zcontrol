classdef MJC3_HID_Controller < handle
    % MJC3_HID_Controller - Read the Thorlabs MJC3 USB HID joystick and
    % translate Z‑axis movements into ScanImage Z‑control commands.
    %
    % This class uses Psychtoolbox's PsychHID functions to access the
    % MJC3 joystick directly.  The joystick is identified by its
    % Vendor ID (0x1313) and Product ID (0x9000)【490547707256661†L14-L18】.  Each HID
    % report from the joystick contains five bytes【754721178379980†L263-L307】:
    %   Byte 0 – x axis or rotary encoder (int8)
    %   Byte 1 – y axis (int8)
    %   Byte 2 – z axis (int8)
    %   Byte 3 – button state (0 or 1)
    %   Byte 4 – speed knob (0–255)
    %
    % The class polls the joystick at a fixed rate and maps the z axis
    % value and speed knob to a relative Z move in micrometres.  It
    % invokes the ``relativeMove`` method on the provided Z‑control
    % object.  You can supply your own controller object as long as it
    % exposes a ``relativeMove(dz)`` method; for example, an instance of
    % SI_MotorGUI_ZControl or a similar class from this repository.

    properties
        ctrl      % Handle to the ScanImage Z‑controller (must implement relativeMove)
        device    % PsychHID device handle
        timerObj  % MATLAB timer object used for polling
        stepFactor  % Micrometres moved per unit of joystick deflection
        running     % Logical flag indicating whether polling is active
    end

    methods
        function obj = MJC3_HID_Controller(ctrl, stepFactor)
            % Constructor
            %
            % obj = MJC3_HID_Controller(ctrl, stepFactor)
            %
            % ``ctrl`` is the object responsible for moving the Z stage.
            % ``stepFactor`` (optional) scales joystick values into
            % micrometres; the default is 5 µm per unit.

            if nargin < 1
                error('You must provide a Z‑control object that implements relativeMove(dz)');
            end
            if nargin < 2
                stepFactor = 5; % default micrometres per unit of zVal
            end
            obj.ctrl = ctrl;
            obj.stepFactor = stepFactor;
            obj.running = false;

            % Identify the MJC3 HID device
            devs = PsychHID('Devices');
            idx = find([devs.vendorID] == hex2dec('1313') & [devs.productID] == hex2dec('9000'), 1);
            if isempty(idx)
                error('MJC3 HID joystick not found.  Is it connected?');
            end

            % Open the device.  PsychHID returns a handle and device info
            [h, ~] = PsychHID('OpenDevice', idx);
            obj.device = h;

            % Configure a fixed‑rate timer to poll the HID reports
            obj.timerObj = timer('ExecutionMode', 'fixedRate', ...
                                 'Period', 0.05, ...        % Poll at 20 Hz
                                 'TimerFcn', @(~,~)obj.poll());
        end

        function start(obj)
            % Start polling the joystick
            if ~obj.running
                obj.running = true;
                start(obj.timerObj);
            end
        end

        function stop(obj)
            % Stop polling the joystick
            if obj.running
                obj.running = false;
                stop(obj.timerObj);
            end
        end

        function delete(obj)
            % Destructor: ensure polling stops and the HID device closes
            obj.stop();
            if ~isempty(obj.device)
                try
                    PsychHID('CloseDevice', obj.device);
                catch
                    % device may already be closed
                end
            end
            if ~isempty(obj.timerObj) && isvalid(obj.timerObj)
                delete(obj.timerObj);
            end
        end

        function poll(obj)
            % Poll the HID device and translate joystick movements into Z moves
            if ~obj.running || isempty(obj.device)
                return;
            end
            try
                % HID report: [xVal,yVal,zVal,button,speed]
                reportLength = 5;
                data = PsychHID('GetReport', obj.device, 1, 0, reportLength);
                if numel(data) < reportLength
                    return;
                end
                % Cast to signed ints; data is uint8
                xVal = typecast(uint8(data(1)), 'int8'); %#ok<NASGU> 
                yVal = typecast(uint8(data(2)), 'int8'); %#ok<NASGU> 
                zVal = typecast(uint8(data(3)), 'int8');
                button = data(4); %#ok<NASGU>
                speed = double(data(5)) / 255; % normalize [0,1]

                % Compute movement in micrometres.  Positive zVal = clockwise
                dz = double(zVal) * obj.stepFactor * speed;
                if dz ~= 0
                    try
                        obj.ctrl.relativeMove(dz);
                    catch ME
                        warning('Failed to invoke relativeMove: %s', ME.message);
                        obj.stop();
                    end
                end
            catch ME
                warning('Error reading MJC3 HID device: %s', ME.message);
                obj.stop();
            end
        end
    end
end