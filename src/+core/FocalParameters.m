classdef FocalParameters < handle
    % FocalParameters - Parameter class for focus control in FocalSweep
    %
    % This class stores and manages Z scanning parameters used by FocalSweep 
    % and related components.
    
    properties
        % Z-scanning parameters
        stepSize            % Z step size for scanning
        initialStepSize     % Initial step size for coarse search
        scanPauseTime       % Pause time between steps
        rangeLow            % Lower range limit
        rangeHigh           % Upper range limit
        
        % Focus calculation parameters
        smoothingWindow     % Window size for smoothing curves
        
        % Auto-update parameters
        autoUpdateFrequency % Frequency of auto updates in seconds
        lastAutoUpdateTime = 0  % Timestamp of last auto update
        
        % Brightness monitor parameters
        maxPoints           % Maximum number of data points to store
        defaultMetric       % Default metric index to use (7=Mean)
        averageTimeWindow   % Default time window for averaging (seconds)
        monitoringTimerPeriod % Period for monitoring timer (seconds)
    end
    
    methods
        function obj = FocalParameters(varargin)
            % Constructor for FocalParameters
            %
            % Optional parameter/value pairs can be provided to set initial values
            % Example: params = core.FocalParameters('stepSize', 5, 'rangeLow', -30)
            
            % Initialize with default values from AppConfig
            obj.initializeDefaults();
            
            % Process any parameter/value pairs if provided
            if nargin > 0
                obj.setParameters(varargin{:});
            end
        end
        
        function initializeDefaults(obj)
            % Initialize properties with default values from AppConfig
            obj.stepSize = core.AppConfig.DEFAULT_STEP_SIZE;
            obj.initialStepSize = core.AppConfig.DEFAULT_INITIAL_STEP_SIZE;
            obj.scanPauseTime = core.AppConfig.DEFAULT_SCAN_PAUSE_TIME;
            obj.rangeLow = core.AppConfig.DEFAULT_RANGE_LOW;
            obj.rangeHigh = core.AppConfig.DEFAULT_RANGE_HIGH;
            obj.smoothingWindow = core.AppConfig.DEFAULT_SMOOTHING_WINDOW;
            obj.autoUpdateFrequency = core.AppConfig.DEFAULT_AUTO_UPDATE_FREQUENCY;
            obj.maxPoints = core.AppConfig.DEFAULT_MAX_POINTS;
            obj.defaultMetric = core.AppConfig.DEFAULT_METRIC;
            obj.averageTimeWindow = core.AppConfig.DEFAULT_AVERAGE_TIME_WINDOW;
            obj.monitoringTimerPeriod = core.AppConfig.DEFAULT_MONITORING_TIMER_PERIOD;
        end
        
        function setParameters(obj, varargin)
            % Set parameters using name-value pairs
            %
            % Example:
            %   params.setParameters('stepSize', 5, 'rangeLow', -30)
            
            p = inputParser;
            p.KeepUnmatched = true;
            
            % Define parameters with more specific validation
            p.addParameter('stepSize', obj.stepSize, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('initialStepSize', obj.initialStepSize, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('scanPauseTime', obj.scanPauseTime, @(x) isnumeric(x) && isscalar(x) && x >= 0);
            p.addParameter('rangeLow', obj.rangeLow, @(x) isnumeric(x) && isscalar(x));
            p.addParameter('rangeHigh', obj.rangeHigh, @(x) isnumeric(x) && isscalar(x));
            p.addParameter('smoothingWindow', obj.smoothingWindow, @(x) isnumeric(x) && isscalar(x) && x > 0 && mod(x,1) == 0);
            p.addParameter('autoUpdateFrequency', obj.autoUpdateFrequency, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('maxPoints', obj.maxPoints, @(x) isnumeric(x) && isscalar(x) && x > 0 && mod(x,1) == 0);
            p.addParameter('defaultMetric', obj.defaultMetric, @(x) isnumeric(x) && isscalar(x) && x > 0 && mod(x,1) == 0);
            p.addParameter('averageTimeWindow', obj.averageTimeWindow, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('monitoringTimerPeriod', obj.monitoringTimerPeriod, @(x) isnumeric(x) && isscalar(x) && x > 0);
            
            % Parse parameters
            p.parse(varargin{:});
            
            % Update properties from the parser
            fields = fieldnames(p.Results);
            for i = 1:length(fields)
                field = fields{i};
                if isprop(obj, field)
                    obj.(field) = p.Results.(field);
                end
            end
        end
        
        function paramsStruct = getParameterStruct(obj)
            % Return parameters as a struct for easy access
            paramsStruct = struct();
            
            % Add all properties to the struct
            props = properties(obj);
            for i = 1:length(props)
                paramsStruct.(props{i}) = obj.(props{i});
            end
        end
        
        function validateParameters(obj)
            % Validate parameters and ensure they are within acceptable ranges
            
            % Validate numeric ranges
            core.CoreUtils.validateNumericRange(obj.stepSize, 0.1, 1000, 'stepSize');
            core.CoreUtils.validateNumericRange(obj.initialStepSize, 1, 1000, 'initialStepSize');
            core.CoreUtils.validateNumericRange(obj.scanPauseTime, 0, 60, 'scanPauseTime');
            
            % Ensure range values are coherent
            if obj.rangeLow >= obj.rangeHigh
                obj.rangeLow = obj.rangeHigh - 10;
            end
        end
    end
end 