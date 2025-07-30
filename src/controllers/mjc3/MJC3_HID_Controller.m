classdef MJC3_HID_Controller < BaseMJC3Controller
    % MJC3_HID_Controller - Read the Thorlabs MJC3 USB HID joystick and
    % translate Z‑axis movements into ScanImage Z‑control commands.
    %
    % This class uses Psychtoolbox's PsychHID functions to access the
    % MJC3 joystick directly and integrates with the existing StageControlService.
    %
    % USAGE:
    %   % Create with Z-controller
    %   zController = ScanImageZController(hSI.hMotors);
    %   controller = MJC3_HID_Controller(zController, stepFactor);
    %   controller.start();

    properties
        device         % PsychHID device handle
        timerObj       % MATLAB timer object used for polling
        lastZValue     % Last Z-axis value to detect changes
        deviceIndex    % HID device index
    end

    methods
        function obj = MJC3_HID_Controller(zController, stepFactor)
            % Constructor
            % zController: Z-controller (must implement relativeMove method)
            % stepFactor: micrometres moved per unit of joystick deflection

            % Call parent constructor
            obj@BaseMJC3Controller(zController, stepFactor);

            % Find and verify MJC3 HID device
            obj.findMJC3Device();

            % Configure a safer timer with error handling
            obj.timerObj = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', 0.05, ...        % Poll at 20 Hz
                'TimerFcn', @(~,~)obj.safePoll(), ...
                'ErrorFcn', @(~,~)obj.handleTimerError());
        end

        function start(obj)
            % Start polling the joystick
            if ~obj.running
                obj.running = true;
                start(obj.timerObj);
                fprintf('MJC3 HID Controller started (Step factor: %.1f μm/unit)\n', obj.stepFactor);
            end
        end

        function stop(obj)
            % Stop polling the joystick
            if obj.running
                obj.running = false;
                stop(obj.timerObj);
                fprintf('MJC3 HID Controller stopped\n');
            end
        end

        function success = connectToMJC3(obj)
            % Check if MJC3 is connected
            success = ~isempty(obj.device);
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

        function safePoll(obj)
            % Safe polling with comprehensive error handling
            if ~obj.running || isempty(obj.device)
                return;
            end

            try
                obj.poll();
            catch ME
                fprintf('MJC3 Controller polling error: %s\n', ME.message);
                obj.stop();
            end
        end

        function poll(obj)
            % Poll the HID device and translate joystick movements into Z moves
            try
                % HID report: [xVal,yVal,zVal,button,speed]
                reportLength = 5;
                data = PsychHID('GetReport', obj.device, 1, 0, reportLength);

                if numel(data) < reportLength
                    return;
                end

                % Cast to signed ints; data is uint8
                zVal = typecast(uint8(data(3)), 'int8');
                speed = double(data(5)) / 255; % normalize [0,1]

                % Only move if Z value changed (avoid continuous movement)
                if zVal ~= obj.lastZValue && zVal ~= 0
                    % Compute movement in micrometres
                    dz = double(zVal) * obj.stepFactor * max(speed, 0.1); % Minimum 10% speed

                    if abs(dz) > 0.01  % Minimum movement threshold
                        success = obj.zController.relativeMove(dz);
                        if ~success
                            fprintf('MJC3: Failed to move Z-axis by %.2f μm\n', dz);
                        end
                    end

                    obj.lastZValue = zVal;
                elseif zVal == 0
                    obj.lastZValue = 0; % Reset when joystick returns to center
                end

            catch ME
                if contains(ME.message, 'Invalid device')
                    fprintf('MJC3: Device disconnected, stopping controller\n');
                    obj.stop();
                else
                    fprintf('MJC3: HID read error: %s\n', ME.message);
                end
            end
        end
    end

    methods (Access = private)
        function findMJC3Device(obj)
            % Find and open MJC3 HID device safely
            try
                devs = PsychHID('Devices');
                idx = find([devs.vendorID] == hex2dec('1313') & [devs.productID] == hex2dec('9000'), 1);

                if isempty(idx)
                    error('MJC3 HID joystick not found. Check USB connection.');
                end

                obj.deviceIndex = idx;
                fprintf('MJC3 device found: %s\n', devs(idx).product);

                % Open the device with error handling
                [h, ~] = PsychHID('OpenDevice', idx);
                obj.device = h;

            catch ME
                error('Failed to connect to MJC3 device: %s', ME.message);
            end
        end

        function handleTimerError(obj)
            % Handle timer errors gracefully
            fprintf('MJC3 Controller: Timer error occurred, stopping controller\n');
            obj.running = false;
        end
    end
end 