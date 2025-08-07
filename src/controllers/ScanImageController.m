%==============================================================================
% ScanImageController - Motor Control Interface for ScanImage
%==============================================================================
%
% Purpose:
%   Provides a clean, object-oriented interface to ScanImage's motor control
%   system for X, Y, and Z-axis movement with relative and absolute positioning.
%
% Features:
%   - Relative movement (move by specified amount)
%   - Absolute positioning (move to specific coordinates)
%   - Simulation mode for testing without hardware
%   - Comprehensive error handling and logging
%   - Support for all three axes (X, Y, Z)
%
% Axis Configuration:
%   - X-axis: Index 1 (typically horizontal movement)
%   - Y-axis: Index 2 (typically vertical movement)
%   - Z-axis: Index 3 (typically focus movement)
%
% Dependencies:
%   - ScanImage: Primary motor control system
%   - hSI.hMotors: ScanImage motors handle
%   - MATLAB: Core functionality and error handling
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   controller = ScanImageController(hSI.hMotors);
%   success = controller.relativeMoveZ(10.0);  % Move Z up by 10 μm
%   success = controller.relativeMoveX(5.0);   % Move X by 5 μm
%   success = controller.moveZToAbsolute(100.0); % Move Z to 100 μm
%
%==============================================================================

classdef ScanImageController < handle
    % ScanImageController - Interface to ScanImage's motor control
    % Provides a simple relativeMove interface for MJC3 controllers (X, Y, Z axes)
    
    properties (Access = private)
        hMotors     % ScanImage motors handle
        xAxisIndex  % Index of X-axis (typically 1)
        yAxisIndex  % Index of Y-axis (typically 2)
        zAxisIndex  % Index of Z-axis (typically 3)
        Logger      % LoggingService instance
    end
    
    methods
        function obj = ScanImageController(hMotors)
            % Constructor - Initialize motor controller
            % 
            % Inputs:
            %   hMotors: ScanImage motors handle (hSI.hMotors) or empty for simulation
            %
            % Throws:
            %   error: If hMotors is provided but invalid
            
            if nargin < 1
                hMotors = [];
            end
            
            % Initialize LoggingService
            obj.Logger = LoggingService('ScanImageController', 'SuppressInitMessage', true);
            
            obj.hMotors = hMotors;
            obj.xAxisIndex = 1; % X is typically the 1st axis in ScanImage
            obj.yAxisIndex = 2; % Y is typically the 2nd axis in ScanImage
            obj.zAxisIndex = 3; % Z is typically the 3rd axis in ScanImage
            
            % Check if we're in simulation mode
            if isempty(hMotors)
                obj.Logger.info('ScanImageController initialized in simulation mode');
            else
                % Verify the motors handle is valid
                if ~isprop(hMotors, 'axesPosition')
                    obj.Logger.error('Invalid hMotors handle - missing axesPosition property');
                    error('Invalid hMotors handle - missing axesPosition property');
                end
                obj.Logger.info('ScanImageController initialized for X, Y, Z-axis control');
            end
        end
        
        function success = relativeMove(obj, dz)
            % Move Z-axis by relative amount in micrometers (backward compatibility)
            % 
            % Inputs:
            %   dz: relative movement in micrometers (positive = up, negative = down)
            % 
            % Returns:
            %   success: true if successful, false otherwise
            
            success = obj.relativeMoveZ(dz);
        end
        
        function success = relativeMoveZ(obj, dz)
            % Move Z-axis by relative amount in micrometers
            % 
            % Inputs:
            %   dz: relative movement in micrometers (positive = up, negative = down)
            % 
            % Returns:
            %   success: true if successful, false otherwise
            
            success = obj.relativeMoveAxis('Z', dz, obj.zAxisIndex);
        end
        
        function success = relativeMoveX(obj, dx)
            % Move X-axis by relative amount in micrometers
            % 
            % Inputs:
            %   dx: relative movement in micrometers
            % 
            % Returns:
            %   success: true if successful, false otherwise
            
            success = obj.relativeMoveAxis('X', dx, obj.xAxisIndex);
        end
        
        function success = relativeMoveY(obj, dy)
            % Move Y-axis by relative amount in micrometers
            % 
            % Inputs:
            %   dy: relative movement in micrometers
            % 
            % Returns:
            %   success: true if successful, false otherwise
            
            success = obj.relativeMoveAxis('Y', dy, obj.yAxisIndex);
        end
        
        function success = moveZToAbsolute(obj, zPos)
            % Move Z-axis to absolute position in micrometers
            % zPos: target position in micrometers
            % Returns: true if successful, false otherwise
            
            success = obj.moveAxisToAbsolute('Z', zPos, obj.zAxisIndex);
        end
        
        function success = moveXToAbsolute(obj, xPos)
            % Move X-axis to absolute position in micrometers
            % xPos: target position in micrometers
            % Returns: true if successful, false otherwise
            
            success = obj.moveAxisToAbsolute('X', xPos, obj.xAxisIndex);
        end
        
        function success = moveYToAbsolute(obj, yPos)
            % Move Y-axis to absolute position in micrometers
            % yPos: target position in micrometers
            % Returns: true if successful, false otherwise
            
            success = obj.moveAxisToAbsolute('Y', yPos, obj.yAxisIndex);
        end
        
        function zPos = getCurrentZPosition(obj)
            % Get current Z-axis position in micrometers
            % Returns: current Z position or empty if unavailable
            
            zPos = obj.getCurrentAxisPosition('Z', obj.zAxisIndex);
        end
        
        function xPos = getCurrentXPosition(obj)
            % Get current X-axis position in micrometers
            % Returns: current X position or empty if unavailable
            
            xPos = obj.getCurrentAxisPosition('X', obj.xAxisIndex);
        end
        
        function yPos = getCurrentYPosition(obj)
            % Get current Y-axis position in micrometers
            % Returns: current Y position or empty if unavailable
            
            yPos = obj.getCurrentAxisPosition('Y', obj.yAxisIndex);
        end
        
        % Backward compatibility method
        function currentPos = getCurrentPosition(obj)
            % Get current Z-axis position (backward compatibility)
            currentPos = obj.getCurrentZPosition();
        end
        
        % Backward compatibility method
        function success = moveToAbsolute(obj, zPos)
            % Move Z-axis to absolute position (backward compatibility)
            success = obj.moveZToAbsolute(zPos);
        end
    end
    
    methods (Access = private)
        function success = relativeMoveAxis(obj, axisName, distance, axisIndex)
            % Generic relative movement for any axis
            % 
            % Inputs:
            %   axisName: Name of axis ('X', 'Y', 'Z')
            %   distance: relative movement in micrometers
            %   axisIndex: Index of the axis in the motors array
            % 
            % Returns:
            %   success: true if successful, false otherwise
            
            success = false;
            
            try
                % Check if we're in simulation mode
                if isempty(obj.hMotors)
                    % Simulation mode - log the movement using LoggingService
                    obj.Logger.info('SIMULATION: %s-axis would move by %.2f μm', axisName, distance);
                    success = true;
                    return;
                end
                
                % Get current position
                currentPos = obj.getCurrentAxisPosition(axisName, axisIndex);
                if isempty(currentPos)
                    obj.Logger.warning('Could not get current %s position', axisName);
                    return;
                end
                
                % Calculate target position
                targetPos = currentPos + distance;
                
                % Move to target position
                success = obj.moveAxisToAbsolute(axisName, targetPos, axisIndex);
                
                if success
                    obj.Logger.info('%s-axis moved by %.2f μm (to %.2f μm)', axisName, distance, targetPos);
                else
                    obj.Logger.warning('Failed to move %s-axis by %.2f μm', axisName, distance);
                end
                
            catch ME
                obj.Logger.warning('relativeMove%s error: %s', axisName, ME.message);
            end
        end
        
        function success = moveAxisToAbsolute(obj, axisName, targetPos, axisIndex)
            % Generic absolute movement for any axis
            % 
            % Inputs:
            %   axisName: Name of axis ('X', 'Y', 'Z')
            %   targetPos: target position in micrometers
            %   axisIndex: Index of the axis in the motors array
            % 
            % Returns:
            %   success: true if successful, false otherwise
            
            success = false;
            
            try
                % Check if we're in simulation mode
                if isempty(obj.hMotors)
                    % Simulation mode - log the movement using LoggingService
                    obj.Logger.info('SIMULATION: %s-axis would move to %.2f μm', axisName, targetPos);
                    success = true;
                    return;
                end
                
                % Get current axes positions
                currentAxes = obj.hMotors.axesPosition;
                if length(currentAxes) < axisIndex
                    obj.Logger.warning('%s-axis index %d not available in axes position array', axisName, axisIndex);
                    return;
                end
                
                % Create new position array with updated axis
                newAxes = currentAxes;
                newAxes(axisIndex) = targetPos;
                
                % Move to new position
                obj.hMotors.axesPosition = newAxes;
                success = true;
                
            catch ME
                obj.Logger.warning('move%sToAbsolute error: %s', axisName, ME.message);
            end
        end
        
        function pos = getCurrentAxisPosition(obj, axisName, axisIndex)
            % Generic position getter for any axis
            % 
            % Inputs:
            %   axisName: Name of axis ('X', 'Y', 'Z')
            %   axisIndex: Index of the axis in the motors array
            % 
            % Returns:
            %   pos: current position or empty if unavailable
            
            pos = [];
            
            try
                if isempty(obj.hMotors)
                    % Simulation mode - return placeholder
                    pos = 0;
                    return;
                end
                
                currentAxes = obj.hMotors.axesPosition;
                if length(currentAxes) >= axisIndex
                    pos = currentAxes(axisIndex);
                end
                
            catch ME
                obj.Logger.warning('getCurrent%sPosition error: %s', axisName, ME.message);
            end
        end
    end
end 