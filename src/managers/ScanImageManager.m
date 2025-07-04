classdef ScanImageManager < handle
    properties (Access = public)
        SimulationMode (1,1) logical = true
        StatusMessage char = ''
    end

    properties (Access = public, Hidden)
        hSI
        motorFig
        etZPos
        etXPos
        etYPos
        Zstep
        Xstep
        Ystep
        Zdec
        Zinc
        Xdec
        Xinc
        Ydec
        Yinc
    end

    properties (Constant, Access = private)
        MOVEMENT_WAIT_TIME = 0.2
        TEXT = struct(...
            'Ready', 'Ready', ...
            'Simulation', 'Simulation Mode', ...
            'Initializing', 'Initializing...', ...
            'Connected', 'Connected', ...
            'NotRunning', 'ScanImage not running', ...
            'WindowNotFound', 'Motor Controls window not found', ...
            'MissingElements', 'Missing UI elements in Motor Controls', ...
            'LostConnection', 'Lost connection')
    end
    
    methods (Access = public)
        function obj = ScanImageManager()
            % Constructor
        end

        function [success, message] = connect(obj)
            try
                if ~obj.isScanImageRunning()
                    obj.setSimulationMode(true, obj.TEXT.NotRunning);
                    success = false;
                    message = obj.TEXT.NotRunning;
                    return;
                end
                
                if ~obj.findMotorControlWindow()
                    obj.setSimulationMode(true, obj.TEXT.WindowNotFound);
                    success = false;
                    message = obj.TEXT.WindowNotFound;
                    return;
                end
                
                if ~obj.findMotorUIElements()
                    obj.setSimulationMode(true, obj.TEXT.MissingElements);
                    success = false;
                    message = obj.TEXT.MissingElements;
                    return;
                end
                
                obj.setSimulationMode(false, obj.TEXT.Connected);
                success = true;
                message = obj.TEXT.Connected;
                
            catch ex
                obj.setSimulationMode(true, ['Error: ' ex.message]);
                success = false;
                message = ['Error: ' ex.message];
            end
        end

        function positions = getPositions(obj)
            positions = struct(...
                'x', obj.readUIPosition(obj.etXPos, 0), ...
                'y', obj.readUIPosition(obj.etYPos, 0), ...
                'z', obj.readUIPosition(obj.etZPos, 0) ...
            );
        end

        function newPosition = moveStage(obj, axisName, microns)
            axisInfo = obj.getAxisInfo(upper(axisName));
            
            if obj.SimulationMode || isempty(axisInfo.etPos)
                currentPos = obj.getSinglePosition(axisName);
                newPosition = currentPos + microns;
            else
                % Set step size in the UI
                if ~isempty(axisInfo.step)
                    axisInfo.step.String = num2str(abs(microns));
                    if isprop(axisInfo.step, 'Callback') && ~isempty(axisInfo.step.Callback)
                        axisInfo.step.Callback(axisInfo.step, []);
                    end
                end
                
                % Determine which button to press
                buttonToPress = [];
                if microns > 0 && ~isempty(axisInfo.inc)
                    buttonToPress = axisInfo.inc;
                elseif microns < 0 && ~isempty(axisInfo.dec)
                    buttonToPress = axisInfo.dec;
                end
                
                % Trigger the button callback
                if ~isempty(buttonToPress) && isprop(buttonToPress, 'Callback') && ~isempty(buttonToPress.Callback)
                    buttonToPress.Callback(buttonToPress, []);
                end
                
                % Pause and read back the new position
                pause(obj.MOVEMENT_WAIT_TIME);
                pos = str2double(axisInfo.etPos.String);
                if ~isnan(pos)
                    newPosition = pos;
                else
                    currentPos = obj.getSinglePosition(axisName);
                    newPosition = currentPos + microns; % Fallback
                end
            end
        end

        function pixelData = getImageData(obj)
            pixelData = [];
            if obj.SimulationMode
                return; 
            end

            FoilviewUtils.safeExecute(@() doGetImageData(), 'getImageData', true);
            
            function doGetImageData()
                if ~isempty(obj.hSI) && isprop(obj.hSI, 'hDisplay')
                    roiData = obj.hSI.hDisplay.getRoiDataArray();
                    if ~isempty(roiData) && isprop(roiData(1), 'imageData') && ~isempty(roiData(1).imageData)
                        pixelData = roiData(1).imageData{1}{1};
                    end
                    
                    if isempty(pixelData) && isprop(obj.hSI.hDisplay, 'stripeDataBuffer')
                        buffer = obj.hSI.hDisplay.stripeDataBuffer;
                        if ~isempty(buffer) && iscell(buffer) && ~isempty(buffer{1})
                            pixelData = buffer{1}.roiData{1}.imageData{1}{1};
                        end
                    end
                end
            end
        end
    end

    methods (Access = private)
        function setSimulationMode(obj, isSimulation, message)
            obj.SimulationMode = isSimulation;
            obj.StatusMessage = message;
        end

        function isRunning = isScanImageRunning(obj)
            isRunning = evalin('base', 'exist(''hSI'', ''var'') && isobject(hSI)');
            if isRunning
                obj.hSI = evalin('base', 'hSI');
            end
        end

        function found = findMotorControlWindow(obj)
            obj.motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
            found = ~isempty(obj.motorFig);
        end

        function found = findMotorUIElements(obj)
            tags = {'etZPos', 'etXPos', 'etYPos', 'Zstep', 'Xstep', 'Ystep', ...
                    'Zdec', 'Zinc', 'Xdec', 'Xinc', 'Ydec', 'Yinc'};
            for i = 1:length(tags)
                obj.(tags{i}) = findall(obj.motorFig, 'Tag', tags{i});
            end
            
            found = ~any(cellfun(@isempty, {obj.etZPos, obj.Zstep, obj.Zdec, obj.Zinc}));
        end

        function pos = readUIPosition(~, handle, defaultValue)
            if ~isempty(handle) && isvalid(handle)
                pos = str2double(handle.String);
                if isnan(pos)
                    pos = defaultValue;
                end
            else
                pos = defaultValue;
            end
        end

        function currentPos = getSinglePosition(obj, axisName)
            switch upper(axisName)
                case 'X'
                    currentPos = obj.readUIPosition(obj.etXPos, 0);
                case 'Y'
                    currentPos = obj.readUIPosition(obj.etYPos, 0);
                case 'Z'
                    currentPos = obj.readUIPosition(obj.etZPos, 0);
                otherwise
                    currentPos = 0;
            end
        end

        function axisInfo = getAxisInfo(obj, axisName)
            switch upper(axisName)
                case 'X'
                    axisInfo = struct('etPos', obj.etXPos, 'step', obj.Xstep, 'inc', obj.Xinc, 'dec', obj.Xdec);
                case 'Y'
                    axisInfo = struct('etPos', obj.etYPos, 'step', obj.Ystep, 'inc', obj.Yinc, 'dec', obj.Ydec);
                case 'Z'
                    axisInfo = struct('etPos', obj.etZPos, 'step', obj.Zstep, 'inc', obj.Zinc, 'dec', obj.Zdec);
                otherwise
                    error('Invalid axis name: %s', axisName);
            end
        end
    end
end 