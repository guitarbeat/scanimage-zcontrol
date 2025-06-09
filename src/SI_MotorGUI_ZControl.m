classdef SI_MotorGUI_ZControl < handle
    % SI_MotorGUI_ZControl - Control Z via ScanImage Motor Controls GUI
    %
    % This class provides a base interface for controlling Z-axis movement
    % through ScanImage's Motor Controls GUI. It handles finding and
    % interacting with the motor control elements.
    %
    % Usage:
    %   z = SI_MotorGUI_ZControl();
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
    end
    
    methods
        function obj = SI_MotorGUI_ZControl()
            % Constructor - Initialize motor control handles
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
        
        function z = getZ(obj)
            % Get current Z position
            try
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
                obj.Zstep.String = num2str(val);
            catch ME
                error('Failed to set step size: %s', ME.message);
            end
        end
        
        function moveUp(obj)
            % Move Z position up by one step
            try
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
    end
end 