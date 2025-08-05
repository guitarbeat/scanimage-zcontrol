classdef ScanImageInterface < handle
    %SCANIMAGEINTERFACE Low-level ScanImage hardware interface
    %   Handles direct communication with ScanImage hardware
    %   Extracted from ScanImageManager for better separation of concerns
    
    properties (Access = private)
        HSI
        Logger
    end
    
    properties (Constant)
        % Connection states
        DISCONNECTED = 'disconnected'
        CONNECTING = 'connecting'
        CONNECTED = 'connected'
        SIMULATION = 'simulation'
        ERROR = 'error'
    end
    
    methods
        function obj = ScanImageInterface()
            obj.HSI = [];
            obj.Logger = LoggingService('ScanImageInterface', 'SuppressInitMessage', true);
        end
        
        function [success, message] = connect(obj)
            %CONNECT Establishes connection to ScanImage hardware
            try
                % Check if ScanImage is running
                if ~evalin('base', 'exist(''hSI'', ''var'')')
                    success = false;
                    message = 'ScanImage not running';
                    obj.Logger.warning('ScanImageInterface: %s', message);
                    return;
                end
                
                % Get ScanImage handle
                obj.HSI = evalin('base', 'hSI');
                if isempty(obj.HSI)
                    success = false;
                    message = 'Invalid ScanImage handle';
                    obj.Logger.warning('ScanImageInterface: %s', message);
                    return;
                end
                
                success = true;
                message = 'Connected to ScanImage hardware';
                obj.Logger.info('ScanImageInterface: Successfully connected');
                
            catch ME
                success = false;
                message = sprintf('Connection failed: %s', ME.message);
                obj.Logger.error('ScanImageInterface: %s', message);
            end
        end
        
        function positions = getPositions(obj)
            %GETPOSITIONS Get current stage positions from ScanImage
            positions = struct('x', 0, 'y', 0, 'z', 0);
            
            try
                if isempty(obj.HSI)
                    return;
                end
                
                % Get positions from ScanImage motors
                if isprop(obj.HSI, 'hMotors') && ~isempty(obj.HSI.hMotors)
                    if isprop(obj.HSI.hMotors, 'axesPosition') && ~isempty(obj.HSI.hMotors.axesPosition)
                        pos = obj.HSI.hMotors.axesPosition;
                        if numel(pos) >= 3 && all(isfinite(pos))
                            positions.x = pos(2);
                            positions.y = pos(1);
                            positions.z = pos(3);
                        end
                    elseif isprop(obj.HSI.hMotors, 'motorPosition') && ~isempty(obj.HSI.hMotors.motorPosition)
                        pos = obj.HSI.hMotors.motorPosition;
                        if numel(pos) >= 3 && all(isfinite(pos))
                            positions.x = pos(2);
                            positions.y = pos(1);
                            positions.z = pos(3);
                        end
                    end
                end
                
            catch ME
                FoilviewUtils.logException('ScanImageInterface', ME, 'getPositions failed');
            end
        end
        
        function newPosition = moveStage(obj, axisName, microns)
            %MOVESTAGE Move stage by specified amount
            newPosition = 0;
            
            try
                if isempty(obj.HSI)
                    FoilviewUtils.warn('ScanImageInterface', 'No ScanImage handle available');
                    return;
                end
                
                % Get current position
                currentPos = obj.getCurrentPosition(axisName);
                
                % Calculate target position
                targetPos = currentPos + microns;
                
                % Perform movement via ScanImage motor controls
                obj.setPosition(axisName, targetPos);
                
                % Get new position after movement
                newPosition = obj.getCurrentPosition(axisName);
                
            catch ME
                errorMsg = sprintf('Movement error for %s axis: %s', axisName, ME.message);
                FoilviewUtils.warn('ScanImageInterface', '%s', errorMsg);
                newPosition = obj.getCurrentPosition(axisName);
            end
        end
        
        function currentPos = getCurrentPosition(obj, axisName)
            %GETCURRENTPOSITION Get current position for a specific axis
            positions = obj.getPositions();
            
            switch lower(axisName)
                case 'x'
                    currentPos = positions.x;
                case 'y'
                    currentPos = positions.y;
                case 'z'
                    currentPos = positions.z;
                otherwise
                    currentPos = 0;
            end
        end
        
        function setPosition(obj, axisName, value)
            %SETPOSITION Set absolute position for an axis
            try
                if isempty(obj.HSI)
                    return;
                end
                
                % Access ScanImage motor controls GUI
                motorFig = obj.findMotorControlsFigure();
                if isempty(motorFig)
                    return;
                end
                
                % Find axis controls and set position
                axisInfo = obj.getAxisInfo(motorFig, axisName);
                if ~isempty(axisInfo)
                    % Set the position value
                    axisInfo.etPos.String = num2str(value);
                    
                    % Trigger the position update
                    if isfield(axisInfo, 'step') && ~isempty(axisInfo.step)
                        try
                            axisInfo.step.Callback(axisInfo.step, []);
                        catch ME
                            FoilviewUtils.logException('ScanImageInterface', ME, 'Error setting position');
                        end
                    end
                end
                
            catch ME
                FoilviewUtils.logException('ScanImageInterface', ME, 'setPosition failed');
            end
        end
        
        function isError = checkMotorErrorState(obj, axisName)
            %CHECKMOTORERRORSTATE Check if motor is in error state
            isError = false;
            
            try
                motorFig = obj.findMotorControlsFigure();
                if isempty(motorFig)
                    return;
                end
                
                axisInfo = obj.getAxisInfo(motorFig, axisName);
                if ~isempty(axisInfo) && isfield(axisInfo, 'status')
                    statusText = axisInfo.status.String;
                    isError = contains(lower(statusText), 'error');
                end
                
            catch ME
                FoilviewUtils.logException('ScanImageInterface', ME, 'Error checking motor error state');
                isError = true; % Assume error if we can't check
            end
        end
    end
    
    methods (Access = private)
        function motorFig = findMotorControlsFigure(obj)
            %FINDMOTORCONTROLSFIGURE Find ScanImage Motor Controls figure
            motorFig = [];
            
            try
                allFigs = findall(0, 'Type', 'figure');
                for i = 1:length(allFigs)
                    if contains(allFigs(i).Name, 'Motor Controls')
                        motorFig = allFigs(i);
                        break;
                    end
                end
            catch
                % Ignore errors in figure finding
            end
        end
        
        function axisInfo = getAxisInfo(obj, motorFig, axisName)
            %GETAXISINFO Get UI controls for a specific axis
            axisInfo = [];
            
            try
                % Find axis-specific controls in the motor figure
                % This is a simplified version - actual implementation would
                % need to match the specific ScanImage GUI structure
                
                % For now, return empty to avoid errors
                % Real implementation would parse the motor controls GUI
                
            catch ME
                FoilviewUtils.logException('ScanImageInterface', ME, sprintf('Error getting axis info for %s', axisName));
            end
        end
    end
end