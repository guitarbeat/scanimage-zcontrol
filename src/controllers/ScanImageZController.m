classdef ScanImageZController < handle
    % ScanImageZController - Interface to ScanImage's Z-axis motor control
    % Provides a simple relativeMove(dz) interface for MJC3 controllers
    
    properties (Access = private)
        hMotors     % ScanImage motors handle
        zAxisIndex  % Index of Z-axis (typically 3)
    end
    
    methods
        function obj = ScanImageZController(hMotors)
            % Constructor
            % hMotors: ScanImage motors handle (hSI.hMotors)
            
            if nargin < 1 || isempty(hMotors)
                error('ScanImageZController requires a valid hMotors handle');
            end
            
            obj.hMotors = hMotors;
            obj.zAxisIndex = 3; % Z is typically the 3rd axis in ScanImage
            
            % Verify the motors handle is valid
            if ~isprop(hMotors, 'axesPosition')
                error('Invalid hMotors handle - missing axesPosition property');
            end
            
            fprintf('ScanImageZController initialized for Z-axis control\n');
        end
        
        function success = relativeMove(obj, dz)
            % Move Z-axis by relative amount in micrometers
            % dz: relative movement in micrometers (positive = up, negative = down)
            % Returns: true if successful, false otherwise
            
            success = false;
            
            try
                % Get current position
                currentPos = obj.getCurrentPosition();
                if isempty(currentPos)
                    warning('Could not get current Z position');
                    return;
                end
                
                % Calculate target position
                targetPos = currentPos + dz;
                
                % Move to target position
                success = obj.moveToAbsolute(targetPos);
                
                if success
                    fprintf('Z-axis moved by %.2f μm (to %.2f μm)\n', dz, targetPos);
                else
                    warning('Failed to move Z-axis by %.2f μm', dz);
                end
                
            catch ME
                warning('ScanImageZController relativeMove error: %s', ME.message);
            end
        end
        
        function success = moveToAbsolute(obj, zPos)
            % Move Z-axis to absolute position in micrometers
            % zPos: target position in micrometers
            % Returns: true if successful, false otherwise
            
            success = false;
            
            try
                % Get current axes positions
                currentAxes = obj.hMotors.axesPosition;
                if length(currentAxes) < obj.zAxisIndex
                    warning('Z-axis index %d not available in axes position array', obj.zAxisIndex);
                    return;
                end
                
                % Create new position array with updated Z
                newAxes = currentAxes;
                newAxes(obj.zAxisIndex) = zPos;
                
                % Set the new position
                obj.hMotors.axesPosition = newAxes;
                
                % Wait a moment for the move to initiate
                pause(0.01);
                
                success = true;
                
            catch ME
                warning('ScanImageZController moveToAbsolute error: %s', ME.message);
            end
        end
        
        function pos = getCurrentPosition(obj)
            % Get current Z-axis position in micrometers
            % Returns: current Z position or empty if error
            
            pos = [];
            
            try
                currentAxes = obj.hMotors.axesPosition;
                if length(currentAxes) >= obj.zAxisIndex
                    pos = currentAxes(obj.zAxisIndex);
                end
            catch ME
                warning('ScanImageZController getCurrentPosition error: %s', ME.message);
            end
        end
        
        function isMoving = isInMotion(obj)
            % Check if Z-axis is currently moving
            % Returns: true if moving, false if stationary or error
            
            isMoving = false;
            
            try
                if isprop(obj.hMotors, 'moveInProgress')
                    isMoving = obj.hMotors.moveInProgress;
                end
            catch ME
                warning('ScanImageZController isInMotion error: %s', ME.message);
            end
        end
        
        function waitForMove(obj, timeout)
            % Wait for current move to complete
            % timeout: maximum wait time in seconds (default: 5)
            
            if nargin < 2
                timeout = 5;
            end
            
            startTime = tic;
            while obj.isInMotion() && toc(startTime) < timeout
                pause(0.05);
            end
            
            if obj.isInMotion()
                warning('Z-axis move did not complete within %.1f seconds', timeout);
            end
        end
    end
end