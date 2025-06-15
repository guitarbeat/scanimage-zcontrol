% src\FocalSweepApp.m
classdef FocalSweepApp < handle
    % FocalSweepApp - Main class for the Focal Sweep tool.

    %% Configuration Constants (from AppConfig)
    properties (Constant)
        VERSION = '1.1.0'
        BUILD_DATE = 'May 2025'
        DEFAULT_STEP_SIZE = 1
        DEFAULT_INITIAL_STEP_SIZE = 20
        DEFAULT_SCAN_PAUSE_TIME = 0.2
        DEFAULT_RANGE_LOW = -25
        DEFAULT_RANGE_HIGH = 25
        DEFAULT_SMOOTHING_WINDOW = 2
        DEFAULT_AUTO_UPDATE_FREQUENCY = 1
        DEFAULT_MAX_POINTS = 1000
        DEFAULT_METRIC = 7
        DEFAULT_AVERAGE_TIME_WINDOW = 5
        DEFAULT_MONITORING_TIMER_PERIOD = 0.2
    end

    %% Public Properties
    properties (Access = public)
        gui                 % GUI Manager
        hSI                 % ScanImage handle

        % Parameters
        stepSize
        initialStepSize
        scanPauseTime
        rangeLow
        rangeHigh
        smoothingWindow
        autoUpdateFrequency
        maxPoints
        defaultMetric
        averageTimeWindow
        monitoringTimerPeriod

        % State Variables
        isRunning = false
        isClosing = false
        simulationMode = false
    end

    %% Private Properties
    properties (Access = private)
        % Motor Control Handles
        motorFig
        etZPos
        Zstep
        Zdec
        Zinc

        % Simulation properties
        simZPosition = 0
        simStepSize = 5

        % Verbosity for logging
        verbosity = 0
    end

    %% Constructor & Initialization
    methods
        function obj = FocalSweepApp(options)
            if nargin < 1, options = struct(); end
            if isfield(options, 'verbosity'), obj.verbosity = options.verbosity; end

            obj.log(1, 'Initializing FocalSweepApp...');
            obj.initializeParameters();
            obj.checkSimulationMode();
            obj.initializeSI();
            obj.initializeMotorControls();

            obj.gui = FocusGUI(obj);
            obj.gui.create();

            obj.updateZPosition();
            obj.log(1, 'FocalSweepApp is ready.');
        end

        function initializeParameters(obj)
            fields = properties(obj);
            for k = 1:numel(fields)
                prop = fields{k};
                if isprop(obj, ['DEFAULT_' prop])
                    obj.(prop) = obj.(['DEFAULT_' prop]);
                end
            end
        end

        function checkSimulationMode(obj)
            try
                obj.simulationMode = evalin('base', 'exist(''SIM_MODE'', ''var'') && SIM_MODE');
            catch
                % If we can't check for SIM_MODE, default to simulation mode
                obj.simulationMode = true;
                assignin('base', 'SIM_MODE', true);
                obj.log(1, 'SIM_MODE not found, defaulting to simulation mode.');
            end
        end

        function initializeSI(obj)
            if obj.simulationMode
                obj.log(1, 'Simulation mode active.');
                % Create a simple simulation structure with required functions
                obj.hSI = struct();
                obj.hSI.startFocus = @() obj.log(1, 'Simulated: Focus started');
                obj.hSI.startGrab = @() obj.log(1, 'Simulated: Frame grabbed');
                obj.hSI.abort = @() obj.log(1, 'Simulated: Operation aborted');
                return;
            end
            
            % Check if hSI exists and is an object
            siExists = evalin('base', 'exist(''hSI'', ''var'')');
            if ~siExists
                obj.log(1, 'ScanImage not running, switching to simulation mode.');
                obj.simulationMode = true;
                obj.initializeSI(); % Recursive call to set up simulation
                return;
            end
            
            % Now check if it's a valid object
            isValidSI = evalin('base', 'isobject(hSI)');
            if ~isValidSI
                obj.log(1, 'hSI is not a valid object, switching to simulation mode.');
                obj.simulationMode = true;
                obj.initializeSI(); % Recursive call to set up simulation
                return;
            end
            
            % ScanImage is running with valid hSI
            obj.hSI = evalin('base', 'hSI');
        end

        function initializeMotorControls(obj)
            if obj.simulationMode
                obj.log(1, 'Using simulated motor controls.');
                return;
            end

            obj.motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
            if isempty(obj.motorFig)
                obj.log(1, 'Motor Controls window not found, switching to simulation mode.');
                obj.simulationMode = true;
                return;
            end

            obj.etZPos = findall(obj.motorFig, 'Tag', 'etZPos');
            obj.Zstep = findall(obj.motorFig, 'Tag', 'Zstep');
            obj.Zdec = findall(obj.motorFig, 'Tag', 'Zdec');
            obj.Zinc = findall(obj.motorFig, 'Tag', 'Zinc');

            if any(cellfun(@isempty, {obj.etZPos, obj.Zstep, obj.Zdec, obj.Zinc}))
                obj.log(1, 'Missing UI elements in Motor Controls, switching to simulation mode.');
                obj.simulationMode = true;
            end
        end
    end

    %% Public Methods
    methods
        function updateParameters(obj, params)
            fields = fieldnames(params);
            for i = 1:numel(fields)
                if isprop(obj, fields{i})
                    obj.(fields{i}) = params.(fields{i});
                end
            end
            obj.updateStatus('Parameters updated.', 'success');
        end

        function moveZUp(obj)
            obj.setMotorStepSize(obj.stepSize);
            obj.pressZdec();
            obj.updateZPosition();
        end

        function moveZDown(obj)
            obj.setMotorStepSize(obj.stepSize);
            obj.pressZinc();
            obj.updateZPosition();
        end

        function z = getZ(obj)
            if obj.simulationMode
                z = obj.simZPosition;
            else
                z = str2double(obj.etZPos.String);
                if isnan(z), z = 0; end
            end
        end

        function abortAllOperations(obj)
            if ~obj.simulationMode, obj.hSI.abort(); end
            obj.updateStatus('Operations aborted.');
        end

        function closeFigure(obj)
            if ~obj.isClosing
                obj.gui.closeFigure();
            end
        end
    end

    %% Private Utility Methods
    methods (Access = private)
        function setMotorStepSize(obj, val)
            if obj.simulationMode
                obj.simStepSize = val;
            else
                obj.Zstep.String = num2str(val);
            end
        end

        function pressZdec(obj)
            if obj.simulationMode
                obj.simZPosition = obj.simZPosition - obj.simStepSize;
            else
                obj.Zdec.Callback(obj.Zdec, []);
            end
        end

        function pressZinc(obj)
            if obj.simulationMode
                obj.simZPosition = obj.simZPosition + obj.simStepSize;
            else
                obj.Zinc.Callback(obj.Zinc, []);
            end
        end

        function updateZPosition(obj)
            if ~isempty(obj.gui) && isvalid(obj.gui)
                obj.gui.updateZPosition();
            end
        end

        function updateStatus(obj, message, messageType)
            if nargin < 3, messageType = 'info'; end
            if ~isempty(obj.gui) && isvalid(obj.gui)
                obj.gui.updateStatus(message, messageType);
            end
        end

        function log(obj, level, message)
            if obj.verbosity >= level
                fprintf('[%s] %s\n', datestr(now, 'HH:MM:SS.FFF'), message);
            end
        end
    end
end
