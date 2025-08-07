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
        
        function positions = getPositions(~, hSI, simulationMode)
            %GETPOSITIONS Get current stage positions from ScanImage
            positions = struct('x', 0, 'y', 0, 'z', 0);
            
            try
                if simulationMode || isempty(hSI)
                    % Return simulated positions
                    positions.x = 0;
                    positions.y = 0;
                    positions.z = 0;
                    return;
                end
                
                % Get positions from ScanImage motors
                if isprop(hSI, 'hMotors') && ~isempty(hSI.hMotors)
                    if isprop(hSI.hMotors, 'axesPosition') && ~isempty(hSI.hMotors.axesPosition)
                        pos = hSI.hMotors.axesPosition;
                        if numel(pos) >= 3 && all(isfinite(pos))
                            positions.y = pos(1);
                            positions.x = pos(2);
                            positions.z = pos(3);
                        end
                    elseif isprop(hSI.hMotors, 'motorPosition') && ~isempty(hSI.hMotors.motorPosition)
                        pos = hSI.hMotors.motorPosition;
                        if numel(pos) >= 3 && all(isfinite(pos))
                            positions.y = pos(1);
                            positions.x = pos(2);
                            positions.z = pos(3);
                        end
                    end
                end
                
            catch ME
                FoilviewUtils.logException('ScanImageInterface', ME, 'getPositions failed');
            end
        end
        
        function newPosition = moveStage(obj, hSI, axisName, microns, simulationMode, logger)
            %MOVESTAGE Move stage by specified amount
            newPosition = 0;
            
            try
                if simulationMode
                    % Simulate movement
                    currentPos = obj.getCurrentPositionFromHSI(hSI, axisName, simulationMode);
                    newPosition = currentPos + microns;
                    if strcmpi(axisName, 'Z')
                        logger.info('[Sim] Z: %+0.2f μm → %0.2f μm', microns, newPosition);
                    else
                        logger.info('[Sim] %s: %+0.2f μm → %0.2f μm', axisName, microns, newPosition);
                    end
                    return;
                end
                
                if isempty(hSI)
                    FoilviewUtils.warn('ScanImageInterface', 'No ScanImage handle available');
                    return;
                end
                
                % Find motor controls figure
                motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                if isempty(motorFig)
                    error('Motor Controls window not found. Please ensure ScanImage Motor Controls window is open.');
                end
                
                % Check for motor errors
                if obj.checkMotorErrorStateFromFig(motorFig, axisName)
                    logger.warning('Attempting to clear motor error for %s axis', axisName);
                    obj.clearMotorError(motorFig, axisName);
                    pause(0.5); % Wait for error to clear
                    
                    if obj.checkMotorErrorStateFromFig(motorFig, axisName)
                        error('Motor is still in error state for %s axis. Please manually clear the error in ScanImage Motor Controls.', axisName);
                    end
                end
                
                % Get axis information
                axisInfo = obj.getAxisInfoFromFig(motorFig, axisName);
                if isempty(axisInfo.etPos)
                    error('Position field not found for axis %s. Check if Motor Controls window is properly initialized.', axisName);
                end
                
                currentPos = str2double(axisInfo.etPos.String);
                if isnan(currentPos)
                    FoilviewUtils.warn('ScanImageInterface', 'Could not read current position for %s axis', axisName);
                    currentPos = 0;
                end
                
                % Set step size for X/Y axes (Z handled separately in manager)
                if ~strcmpi(axisName, 'Z') && ~isempty(axisInfo.step)
                    axisInfo.step.String = num2str(abs(microns));
                    if isprop(axisInfo.step, 'Callback') && ~isempty(axisInfo.step.Callback)
                        try
                            axisInfo.step.Callback(axisInfo.step, []);
                        catch ME
                            FoilviewUtils.logException('ScanImageInterface', ME, 'Error setting step size');
                        end
                    end
                end
                
                % Determine which button to press
                buttonToPress = [];
                if microns > 0 && ~isempty(axisInfo.inc)
                    buttonToPress = axisInfo.inc;
                elseif microns < 0 && ~isempty(axisInfo.dec)
                    buttonToPress = axisInfo.dec;
                end
                
                if isempty(buttonToPress)
                    error('No movement button found for %s axis. Direction: %s, Microns: %.1f', axisName, ...
                          ternary(microns > 0, 'positive', 'negative'), microns);
                end
                
                if isprop(buttonToPress, 'Enable') && strcmp(buttonToPress.Enable, 'off')
                    error('Motor button is disabled. The motor may be in an error state. Please check ScanImage Motor Controls.');
                end
                
                % Execute movement
                if isprop(buttonToPress, 'Callback') && ~isempty(buttonToPress.Callback)
                    try
                        buttonToPress.Callback(buttonToPress, []);
                        logger.info('Triggered %s movement of %.1f μm', axisName, microns);
                    catch ME
                        if contains(ME.message, 'error state')
                            error('Motor is in error state. Please clear the error in ScanImage Motor Controls before attempting movement.');
                        else
                            rethrow(ME);
                        end
                    end
                else
                    error('Button callback not available for %s axis', axisName);
                end
                
                pause(0.2); % Wait for movement
                newPosition = str2double(axisInfo.etPos.String);
                if isnan(newPosition)
                    FoilviewUtils.warn('ScanImageInterface', 'Could not read new position for %s axis, using current position', axisName);
                    newPosition = obj.getCurrentPositionFromHSI(hSI, axisName, simulationMode);
                end
                
                logger.info('%s stage moved %.1f μm from %.1f to %.1f μm', axisName, microns, currentPos, newPosition);
                
            catch ME
                errorMsg = sprintf('Movement error for %s axis: %s', axisName, ME.message);
                FoilviewUtils.warn('ScanImageInterface', '%s', errorMsg);
                newPosition = obj.getCurrentPositionFromHSI(hSI, axisName, simulationMode);
            end
        end
        
        function currentPos = getCurrentPosition(obj, axisName)
            %GETCURRENTPOSITION Get current position for a specific axis
            positions = obj.getPositions(obj.HSI, false);
            
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
        
        function currentPos = getCurrentPositionFromHSI(obj, hSI, axisName, simulationMode)
            %GETCURRENTPOSITIONFROMHSI Get current position for a specific axis from HSI
            positions = obj.getPositions(hSI, simulationMode);
            
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
        function motorFig = findMotorControlsFigure(~)
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
        
        function axisInfo = getAxisInfo(~, ~, ~)
            %GETAXISINFO Get UI controls for a specific axis
            axisInfo = [];
            
            % This is a simplified version - actual implementation would
            % need to match the specific ScanImage GUI structure
            
            % For now, return empty to avoid errors
            % Real implementation would parse the motor controls GUI
        end
        
        function axisInfo = getAxisInfoFromFig(~, motorFig, axisName)
            %GETAXISINFOFROMFIG Get UI controls for a specific axis from figure
            axisInfo = struct('etPos', [], 'step', [], 'inc', [], 'dec', []);
            
            try
                % Map axis names to GUI tags
                switch upper(axisName)
                    case 'X'
                        posTag = 'etXPos';
                        stepTag = 'etXStep';
                        incTag = 'pbXInc';
                        decTag = 'pbXDec';
                    case 'Y'
                        posTag = 'etYPos';
                        stepTag = 'etYStep';
                        incTag = 'pbYInc';
                        decTag = 'pbYDec';
                    case 'Z'
                        posTag = 'etZPos';
                        stepTag = 'etZStep';
                        incTag = 'pbZInc';
                        decTag = 'pbZDec';
                    otherwise
                        return;
                end
                
                % Find controls by tag
                axisInfo.etPos = findall(motorFig, 'Tag', posTag);
                axisInfo.step = findall(motorFig, 'Tag', stepTag);
                axisInfo.inc = findall(motorFig, 'Tag', incTag);
                axisInfo.dec = findall(motorFig, 'Tag', decTag);
                
            catch ME
                FoilviewUtils.logException('ScanImageInterface', ME, sprintf('Error getting axis info for %s', axisName));
            end
        end
        
        function isError = checkMotorErrorStateFromFig(~, motorFig, axisName)
            %CHECKMOTORERRORSTATEFROMFIG Check if motor is in error state from figure
            isError = false;
            
            try
                % Map axis names to status tags
                switch upper(axisName)
                    case 'X'
                        statusTag = 'stXStatus';
                    case 'Y'
                        statusTag = 'stYStatus';
                    case 'Z'
                        statusTag = 'stZStatus';
                    otherwise
                        return;
                end
                
                statusControl = findall(motorFig, 'Tag', statusTag);
                if ~isempty(statusControl) && isprop(statusControl, 'String')
                    statusText = statusControl.String;
                    isError = contains(lower(statusText), 'error');
                end
                
            catch ME
                FoilviewUtils.logException('ScanImageInterface', ME, 'Error checking motor error state');
                isError = true; % Assume error if we can't check
            end
        end
        
        function clearMotorError(~, motorFig, axisName)
            %CLEARMOTORERROR Clear motor error for specified axis
            try
                % Map axis names to clear error button tags
                switch upper(axisName)
                    case 'X'
                        clearTag = 'pbXClearError';
                    case 'Y'
                        clearTag = 'pbYClearError';
                    case 'Z'
                        clearTag = 'pbZClearError';
                    otherwise
                        return;
                end
                
                clearButton = findall(motorFig, 'Tag', clearTag);
                if ~isempty(clearButton) && isprop(clearButton, 'Callback')
                    clearButton.Callback(clearButton, []);
                end
                
            catch ME
                FoilviewUtils.logException('ScanImageInterface', ME, 'Error clearing motor error');
            end
        end
    end
end