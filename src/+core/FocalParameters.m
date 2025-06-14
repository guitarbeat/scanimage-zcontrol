classdef FocalParameters < handle
    % FocalParameters - Parameter class for focus control in FocalSweep
    %
    % This class stores and manages Z scanning parameters used by FocalSweep 
    % and related components.
    
    properties
        % Z-scanning parameters
        stepSize = 1            % Z step size for scanning
        initialStepSize = 20    % Initial step size for coarse search
        scanPauseTime = 0.5     % Pause time between steps
        rangeLow = -25          % Lower range limit
        rangeHigh = 25          % Upper range limit
        
        % Focus calculation parameters
        smoothingWindow = 3     % Window size for smoothing curves
        
        % Auto-update parameters
        autoUpdateFrequency = 1 % Frequency of auto updates in seconds
        lastAutoUpdateTime = 0  % Timestamp of last auto update
        
        % Brightness monitor parameters
        maxPoints = 1000        % Maximum number of data points to store
        defaultMetric = 7       % Default metric index to use (7=Mean)
        averageTimeWindow = 5   % Default time window for averaging (seconds)
        monitoringTimerPeriod = 0.25 % Period for monitoring timer (seconds)
    end
    
    methods
        function obj = FocalParameters(varargin)
            % Constructor for FocalParameters
            %
            % Optional parameter/value pairs can be provided to set initial values
            % Example: params = core.FocalParameters('stepSize', 5, 'rangeLow', -30)
            
            % Process any parameter/value pairs if provided
            if nargin > 0
                obj.setParameters(varargin{:});
            end
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
    end
end 