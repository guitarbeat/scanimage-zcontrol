classdef MJC3_HID_Controller < handle
    % MJC3_HID_Controller - Read the Thorlabs MJC3 USB HID joystick and
    % translate Z‑axis movements into ScanImage Z‑control commands.
    %
    % This class uses Psychtoolbox's PsychHID functions to access the
    % MJC3 joystick directly.  The joystick is identified by its
    % Vendor ID (0x1313) and Product ID (0x9000). Each HID
    % report from the joystick contains five bytes:
    %   Byte 0 – x axis or rotary encoder (int8)
    %   Byte 1 – y axis (int8)
    %   Byte 2 – z axis (int8)
    %   Byte 3 – button state (0 or 1)
    %   Byte 4 – speed knob (0–255)
    %
    % The class polls the joystick at a fixed rate and maps the z axis
    % value and speed knob to a relative Z move in micrometres.  It
    % creates a ScanImage-compatible Z-control object that interfaces
    % with hSI.hMotors for motor movement.
    %
    % USAGE:
    %   % Create with ScanImage handle (auto-detects hSI.hMotors)
    %   controller = MJC3_HID_Controller(hSI, stepFactor);
    %   controller.start();
    %
    %   % Create with custom Z-control object
    %   zCtrl = ScanImageZController(hSI.hMotors);
    %   controller = MJC3_HID_Controller(zCtrl, stepFactor);

    properties
        ctrl      % Handle to the ScanImage Z‑controller (ScanImageZController or hSI)
        device    % PsychHID device handle
        timerObj  % MATLAB timer object used for polling
        stepFactor  % Micrometres moved per unit of joystick deflection
        running     % Logical flag indicating whether polling is active
        zController % Internal Z-controller object
    end

    methods
        function obj = MJC3_HID_Controller(ctrl, stepFactor)
            % Constructor
            %
            % obj = MJC3_HID_Controller(ctrl, stepFactor)
            %
            % ``ctrl`` can be:
            %   - ScanImage handle (hSI) - will auto-create ScanImageZController
            %   - Custom Z-controller object with relativeMove(dz) method
            % ``stepFactor`` (optional) scales joystick values into
            % micrometres; the default is 5 µm per unit.

            if nargin < 1
                error('You must provide a ScanImage handle (hSI) or Z‑control object');
            end
            if nargin < 2
                stepFactor = 5; % default micrometres per unit of zVal
            end
            
            obj.ctrl = ctrl;
            obj.stepFactor = stepFactor;
            obj.running = false;
            
            % Create appropriate Z-controller based on input type
            obj.createZController();

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
                'Period', 0.05, ...        % Poll at 20 Hz
                'TimerFcn', @(~,~)obj.poll());
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
                if abs(dz) > 0.01  % Minimum movement threshold
                    try
                        obj.zController.relativeMove(dz);
                    catch ME
                        warning(ME.identifier, 'Failed to move Z-axis: %s', ME.message);
                        obj.stop();
                    end
                end
            catch ME
                warning(ME.identifier, 'Error reading MJC3 HID device: %s', ME.message);
                obj.stop();
            end
        end
        
        function setStepFactor(obj, newStepFactor)
            % Update the step factor for joystick sensitivity
            if newStepFactor > 0
                obj.stepFactor = newStepFactor;
                fprintf('MJC3 step factor updated to %.1f μm/unit\n', newStepFactor);
            else
                warning('Step factor must be positive');
            end
        end
    end
    
    methods (Access = private)
        function createZController(obj)
            % Create appropriate Z-controller based on input type
            try
                % Check if input is a ScanImage handle
                if isa(obj.ctrl, 'scanimage.SI') || (isobject(obj.ctrl) && isprop(obj.ctrl, 'hMotors'))
                    % Create ScanImage Z-controller
                    obj.zController = ScanImageZController(obj.ctrl.hMotors);
                    fprintf('Created ScanImage Z-controller using hSI.hMotors\n');
                elseif isobject(obj.ctrl) && ismethod(obj.ctrl, 'relativeMove')
                    % Use provided Z-controller directly
                    obj.zController = obj.ctrl;
                    fprintf('Using provided Z-controller object\n');
                else
                    % Try to access hSI from base workspace
                    try
                        hSI = evalin('base', 'hSI');
                        if ~isempty(hSI) && isprop(hSI, 'hMotors')
                            obj.zController = ScanImageZController(hSI.hMotors);
                            fprintf('Created ScanImage Z-controller using hSI from base workspace\n');
                        else
                            error('Invalid ScanImage handle');
                        end
                    catch
                        error('Could not create Z-controller. Provide hSI handle or custom Z-controller with relativeMove method');
                    end
                end
            catch ME
                error('Failed to create Z-controller: %s', ME.message);
            end
        end
    end
end


%% ScanImageZController - Adapter class for ScanImage motor control
classdef ScanImageZController < handle
    % ScanImageZController - Adapter for ScanImage hMotors Z-axis control
    %
    % This class provides a relativeMove interface that works with
    % ScanImage's hMotors component for Z-axis movement.
    
    properties (Access = private)
        hMotors     % ScanImage motors handle
        zAxisIndex  % Z-axis index (typically 3 for [X,Y,Z])
    end
    
    methods
        function obj = ScanImageZController(hMotors)
            % Constructor
            % hMotors: ScanImage hMotors handle (hSI.hMotors)
            
            if nargin < 1 || isempty(hMotors)
                error('ScanImage hMotors handle is required');
            end
            
            obj.hMotors = hMotors;
            obj.zAxisIndex = 3; % Z is typically the 3rd axis [X,Y,Z]
            
            % Verify hMotors is valid and has required methods
            if ~isobject(hMotors)
                error('hMotors must be a valid ScanImage Motors object');
            end
            
            fprintf('ScanImageZController initialized for Z-axis control\n');
        end
        
        function relativeMove(obj, dz)
            % Perform relative Z-axis movement
            % dz: relative movement in micrometers
            
            if abs(dz) < 0.001
                return; % Skip very small movements
            end
            
            try
                % Check if motor system is available and not busy
                if obj.hMotors.moveInProgress
                    return; % Skip if already moving
                end
                
                % Get current position
                currentPos = obj.getCurrentPosition();
                
                % Calculate new absolute position
                newPos = currentPos + dz;
                
                % Perform the move using ScanImage's motor interface
                obj.performMove(newPos);
                
            catch ME
                warning('ScanImageZController:MoveError', 'Z-axis move failed: %s', ME.message);
            end
        end
        
        function position = getCurrentPosition(obj)
            % Get current Z-axis position
            try
                % Try samplePosition first (more accurate)
                if isprop(obj.hMotors, 'samplePosition') && ~isempty(obj.hMotors.samplePosition)
                    positions = obj.hMotors.samplePosition;
                    if length(positions) >= obj.zAxisIndex
                        position = positions(obj.zAxisIndex);
                        return;
                    end
                end
                
                % Fallback to axesPosition
                if isprop(obj.hMotors, 'axesPosition') && ~isempty(obj.hMotors.axesPosition)
                    positions = obj.hMotors.axesPosition;
                    if length(positions) >= obj.zAxisIndex
                        position = positions(obj.zAxisIndex);
                        return;
                    end
                end
                
                % Default fallback
                position = 0;
                
            catch ME
                warning('ScanImageZController:PositionError', 'Could not get Z position: %s', ME.message);
                position = 0;
            end
        end
        
        function success = performMove(obj, newPos)
            % Perform absolute move to new Z position
            success = false;
            
            try
                % Try different ScanImage motor movement methods
                if ismethod(obj.hMotors, 'moveCompleteRelative')
                    % Use relative move if available
                    currentPos = obj.getCurrentPosition();
                    dz = newPos - currentPos;
                    moveVector = [0, 0, dz]; % [X, Y, Z] - only move Z
                    obj.hMotors.moveCompleteRelative(moveVector);
                    success = true;
                    
                elseif ismethod(obj.hMotors, 'moveCompleteAbsolute')
                    % Use absolute move
                    currentPos = obj.hMotors.samplePosition;
                    newPosVector = currentPos;
                    newPosVector(obj.zAxisIndex) = newPos;
                    obj.hMotors.moveCompleteAbsolute(newPosVector);
                    success = true;
                    
                elseif ismethod(obj.hMotors, 'moveSample')
                    % Alternative ScanImage method
                    currentPos = obj.hMotors.samplePosition;
                    newPosVector = currentPos;
                    newPosVector(obj.zAxisIndex) = newPos;
                    obj.hMotors.moveSample(newPosVector);
                    success = true;
                    
                else
                    % Try setting samplePosition directly (last resort)
                    currentPos = obj.hMotors.samplePosition;
                    newPosVector = currentPos;
                    newPosVector(obj.zAxisIndex) = newPos;
                    obj.hMotors.samplePosition = newPosVector;
                    success = true;
                end
                
            catch ME
                warning('ScanImageZController:MoveMethodError', 'Move method failed: %s', ME.message);
                success = false;
            end
        end
        
        function status = getStatus(obj)
            % Get motor status information
            status = struct();
            
            try
                status.position = obj.getCurrentPosition();
                status.moveInProgress = obj.hMotors.moveInProgress;
                status.isHomed = obj.hMotors.isHomed(obj.zAxisIndex);
                status.errorMsg = obj.hMotors.errorMsg;
                status.motorErrorMsg = obj.hMotors.motorErrorMsg{obj.zAxisIndex};
            catch ME
                status.error = ME.message;
            end
        end
    end
end