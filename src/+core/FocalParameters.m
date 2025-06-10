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
            
            % Define parameters with validation
            p.addParameter('stepSize', obj.stepSize, @isnumeric);
            p.addParameter('initialStepSize', obj.initialStepSize, @isnumeric);
            p.addParameter('scanPauseTime', obj.scanPauseTime, @isnumeric);
            p.addParameter('rangeLow', obj.rangeLow, @isnumeric);
            p.addParameter('rangeHigh', obj.rangeHigh, @isnumeric);
            p.addParameter('smoothingWindow', obj.smoothingWindow, @isnumeric);
            p.addParameter('autoUpdateFrequency', obj.autoUpdateFrequency, @isnumeric);
            p.addParameter('maxPoints', obj.maxPoints, @isnumeric);
            p.addParameter('defaultMetric', obj.defaultMetric, @isnumeric);
            p.addParameter('averageTimeWindow', obj.averageTimeWindow, @isnumeric);
            p.addParameter('monitoringTimerPeriod', obj.monitoringTimerPeriod, @isnumeric);
            
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