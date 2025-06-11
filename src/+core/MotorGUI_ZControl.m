classdef MotorGUI_ZControl < handle
    % MotorGUI_ZControl - Interface for Z-axis control via ScanImage Motor Controls GUI
    %
    % Provides programmatic access to Z-position, step size, and movement controls
    % in the ScanImage Motor Controls GUI. Supports absolute/relative movement,
    % step size adjustment, and Z limit setting.
    %
    % Usage:
    %   z = core.MotorGUI_ZControl();
    %   z.getZ();                    % Get current Z position
    %   z.setStepSize(5);            % Set step size to 5 units
    %   z.moveUp();                  % Move up one step
    %   z.moveDown();                % Move down one step
    %   z.relativeMove(10);          % Move up 10 units
    %   z.absoluteMove(12000);       % Move to absolute position 12000
    %
    % Author: Manus AI (2025)
    
    properties (Access = private)
        motorFig    % Handle to Motor Controls figure
        etZPos      % Handle to Z position edit field
        Zstep       % Handle to step size control
        Zdec        % Handle to decrease Z button
        Zinc        % Handle to increase Z button
        
        % Simulation mode properties
        simulationMode = false  % Whether running in simulation mode
        simZPosition = 0        % Simulated Z position
        simStepSize = 5         % Simulated step size
        simMinLimit = -100      % Simulated min Z limit
        simMaxLimit = 100       % Simulated max Z limit
    end
    
    methods
        %% Initialization
        function obj = MotorGUI_ZControl()
            % Constructor - Find and validate all required motor control handles
            
            % Check if we're in simulation mode
            try
                obj.simulationMode = evalin('base', 'exist(''SIM_MODE'', ''var'') && SIM_MODE == true');
            catch
                obj.simulationMode = false;
            end
            
            if obj.simulationMode
                % Create mock objects for simulation mode
                obj.createSimulatedControls();
                return;
            end
            
            try
                obj.motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                if isempty(obj.motorFig)
                    error('Motor Controls window not found. Please ensure ScanImage is running and the Motor Controls window is open.');
                end
                obj.etZPos = findall(obj.motorFig, 'Tag', 'etZPos');
                obj.Zstep = findall(obj.motorFig, 'Tag', 'Zstep');
                obj.Zdec = findall(obj.motorFig, 'Tag', 'Zdec');
                obj.Zinc = findall(obj.motorFig, 'Tag', 'Zinc');
                % Validate all handles were found
                if any(cellfun(@isempty, {obj.etZPos, obj.Zstep, obj.Zdec, obj.Zinc}))
                    error('One or more motor control elements not found. Please verify ScanImage setup.');
                end
                % Add tooltips for accessibility
                if isprop(obj.etZPos, 'TooltipString')
                    obj.etZPos.TooltipString = 'Current Z position';
                end
                if isprop(obj.Zstep, 'TooltipString')
                    obj.Zstep.TooltipString = 'Step size for Z movement';
                end
                if isprop(obj.Zdec, 'TooltipString')
                    obj.Zdec.TooltipString = 'Move Z up by one step';
                end
                if isprop(obj.Zinc, 'TooltipString')
                    obj.Zinc.TooltipString = 'Move Z down by one step';
                end
            catch ME
                error('Failed to initialize motor control: %s', ME.message);
            end
        end
        
        %% Z Position and Step Size
        function z = getZ(obj)
            % Get current Z position from the GUI
            try
                if obj.simulationMode
                    z = obj.simZPosition;
                    return;
                end
                
                z = str2double(obj.etZPos.String);
                if isnan(z)
                    error('Invalid Z position value');
                end
            catch ME
                error('Failed to get Z position: %s', ME.message);
            end
        end
        
        function setStepSize(obj, val)
            % Set the step size for Z movement
            try
                validateattributes(val, {'numeric'}, {'positive', 'finite', 'scalar'});
                
                if obj.simulationMode
                    obj.simStepSize = val;
                    return;
                end
                
                obj.Zstep.String = num2str(val);
            catch ME
                error('Failed to set step size: %s', ME.message);
            end
        end
        
        %% Z Movement
        function moveUp(obj)
            % Move Z position up by one step
            try
                if obj.simulationMode
                    obj.simZPosition = obj.simZPosition - obj.simStepSize;
                    return;
                end
                
                if isprop(obj.Zdec, 'Callback') && ~isempty(obj.Zdec.Callback)
                    obj.Zdec.Callback(obj.Zdec, []);
                else
                    error('Z decrease callback not available');
                end
            catch ME
                error('Failed to move up: %s', ME.message);
            end
        end
        
        function moveDown(obj)
            % Move Z position down by one step
            try
                if obj.simulationMode
                    obj.simZPosition = obj.simZPosition + obj.simStepSize;
                    return;
                end
                
                if isprop(obj.Zinc, 'Callback') && ~isempty(obj.Zinc.Callback)
                    obj.Zinc.Callback(obj.Zinc, []);
                else
                    error('Z increase callback not available');
                end
            catch ME
                error('Failed to move down: %s', ME.message);
            end
        end
        
        function relativeMove(obj, distance)
            % Move by a relative distance (positive = up, negative = down)
            try
                validateattributes(distance, {'numeric'}, {'finite', 'scalar'});
                
                if obj.simulationMode
                    obj.simZPosition = obj.simZPosition - distance; % Note: negative because up is negative Z
                    return;
                end
                
                step = abs(distance);
                obj.setStepSize(step);
                n = round(abs(distance) / step);
                if distance > 0
                    for i = 1:n
                        obj.moveUp();
                    end
                elseif distance < 0
                    for i = 1:n
                        obj.moveDown();
                    end
                end
            catch ME
                error('Failed to perform relative move: %s', ME.message);
            end
        end
        
        function absoluteMove(obj, targetZ)
            % Move to an absolute Z position using steps
            try
                validateattributes(targetZ, {'numeric'}, {'finite', 'scalar'});
                
                currentZ = obj.getZ();
                distance = targetZ - currentZ;
                obj.relativeMove(distance);
            catch ME
                error('Failed to perform absolute move: %s', ME.message);
            end
        end

        %% Z Limit and Utility Methods
        function setMaxZStep(obj, value)
            % Set the Max Z-Step field (value can be numeric or 'Inf')
            
            if obj.simulationMode
                return; % No action needed in simulation mode
            end
            
            if isnumeric(value)
                valueStr = num2str(value);
            else
                valueStr = value;
            end
            set(obj.findByTag('etMaxZStep'), 'String', valueStr);
        end

        function pressSetLimMax(obj)
            % Press the SetLim button for max Z
            
            if obj.simulationMode
                obj.simMaxLimit = obj.simZPosition;
                return;
            end
            
            btn = obj.findByTag('pbMaxLim');
            if ~isempty(btn)
                btn.Callback(btn, []);
            end
        end

        function pressSetLimMin(obj)
            % Press the SetLim button for min Z
            
            if obj.simulationMode
                obj.simMinLimit = obj.simZPosition;
                return;
            end
            
            btn = obj.findByTag('pbMinLim');
            if ~isempty(btn)
                btn.Callback(btn, []);
            end
        end

        function h = findByTag(obj, tag)
            % Utility to find a control by tag in the Motor Controls window
            
            if obj.simulationMode
                % Create mock object with UserData for Z limits
                if strcmp(tag, 'pbMinLim')
                    h = struct('UserData', num2str(obj.simMinLimit));
                elseif strcmp(tag, 'pbMaxLim')
                    h = struct('UserData', num2str(obj.simMaxLimit));
                elseif strcmp(tag, 'etMaxZStep')
                    h = struct('String', 'Inf');
                else
                    h = [];
                end
                return;
            end
            
            h = findall(obj.motorFig, 'Tag', tag);
        end
    end
    
    methods (Access = private)
        function createSimulatedControls(obj)
            % Create simulated controls for simulation mode
            
            % Create mock objects with minimal properties needed for simulation
            obj.motorFig = struct('Type', 'figure', 'Tag', 'MotorControls');
            
            % Create simulated Z position control with a String property
            obj.etZPos = struct('String', '0', 'TooltipString', 'Current Z position');
            
            % Create simulated step size control with a String property
            obj.Zstep = struct('String', '5', 'TooltipString', 'Step size for Z movement');
            
            % Create simulated up/down buttons with empty callbacks
            obj.Zdec = struct('Callback', [], 'TooltipString', 'Move Z up by one step');
            obj.Zinc = struct('Callback', [], 'TooltipString', 'Move Z down by one step');
            
            % Initialize simulation properties with default values
            obj.simZPosition = 0;
            obj.simStepSize = 5;
            obj.simMinLimit = -100;
            obj.simMaxLimit = 100;
        end
    end
end 