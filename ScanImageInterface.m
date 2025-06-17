
%% ScanImage Interface Class (Separate file recommended)
classdef ScanImageInterface < handle
    % ScanImageInterface - Encapsulates ScanImage communication
    
    properties (Access = private)
        hSI         % ScanImage handle
        motorFig    % Motor Controls figure
        etZPos      % Z position field
        Zstep       % Z step field  
        Zdec        % Z decrease button
        Zinc        % Z increase button
        connected = false
    end
    
    methods
        function [success, message] = connect(obj)
            success = false;
            message = '';
            
            try
                % Check for ScanImage
                if ~evalin('base', 'exist(''hSI'', ''var'') && isobject(hSI)')
                    message = 'ScanImage not running';
                    return;
                end
                
                obj.hSI = evalin('base', 'hSI');
                
                % Find motor controls
                obj.motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                if isempty(obj.motorFig)
                    message = 'Motor Controls window not found';
                    return;
                end
                
                % Find UI elements
                obj.etZPos = findall(obj.motorFig, 'Tag', 'etZPos');
                obj.Zstep = findall(obj.motorFig, 'Tag', 'Zstep');
                obj.Zdec = findall(obj.motorFig, 'Tag', 'Zdec');
                obj.Zinc = findall(obj.motorFig, 'Tag', 'Zinc');
                
                if any(cellfun(@isempty, {obj.etZPos, obj.Zstep, obj.Zdec, obj.Zinc}))
                    message = 'Missing UI elements';
                    return;
                end
                
                obj.connected = true;
                success = true;
                message = 'Connected';
                
            catch ex
                message = ex.message;
            end
        end
        
        function position = getPosition(obj)
            position = 0;
            if obj.connected && isvalid(obj.etZPos)
                position = str2double(obj.etZPos.String);
                if isnan(position)
                    position = 0;
                end
            end
        end
        
        function position = moveRelative(obj, microns)
            if ~obj.connected
                position = nan;
                return;
            end
            
            % Set step size and press button
            obj.Zstep.String = num2str(abs(microns));
            
            if microns > 0
                obj.Zinc.Callback(obj.Zinc, []);
            else
                obj.Zdec.Callback(obj.Zdec, []);
            end
            
            pause(0.1);
            position = obj.getPosition();
        end
        
        function position = moveAbsolute(obj, targetPosition)
            if ~obj.connected
                position = nan;
                return;
            end
            
            currentPosition = obj.getPosition();
            delta = targetPosition - currentPosition;
            
            if abs(delta) > 0.01  % Only move if significant
                position = obj.moveRelative(delta);
            else
                position = currentPosition;
            end
        end
        
        function tf = isConnected(obj)
            tf = obj.connected && isvalid(obj.motorFig);
        end
    end
end