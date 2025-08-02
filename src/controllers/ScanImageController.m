%==============================================================================
% SCANIMAGECONTROLLER.M
%==============================================================================
% Interface to ScanImage's motor control system.
%
% This controller provides a unified interface to ScanImage's motor control
% system, supporting X, Y, and Z-axis movements. It abstracts the complexity
% of ScanImage's motor API and provides a simple relative movement interface
% that can be used by other controllers (like MJC3 controllers).
%
% Key Features:
%   - Multi-axis support (X, Y, Z) with individual control
%   - Relative movement interface for easy integration
%   - Simulation mode for testing without ScanImage
%   - Position validation and error handling
%   - Backward compatibility with single-axis interfaces
%   - Comprehensive logging and status reporting
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
    end
    
    methods
        function obj = ScanImageController(hMotors)
            % Constructor
            % hMotors: ScanImage motors handle (hSI.hMotors) or empty for simulation
            
            if nargin < 1
                hMotors = [];
            end
            
            obj.hMotors = hMotors;
            obj.xAxisIndex = 1; % X is typically the 1st axis in ScanImage
            obj.yAxisIndex = 2; % Y is typically the 2nd axis in ScanImage
            obj.zAxisIndex = 3; % Z is typically the 3rd axis in ScanImage
            
            % Check if we're in simulation mode
            if isempty(hMotors)
                fprintf('ScanImageController initialized in simulation mode\n');
            else
                % Verify the motors handle is valid
                if ~isprop(hMotors, 'axesPosition')
                    error('Invalid hMotors handle - missing axesPosition property');
                end
                fprintf('ScanImageController initialized for X, Y, Z-axis control\n');
            end
        end
        
        function success = relativeMove(obj, dz)
            % Move Z-axis by relative amount in micrometers (backward compatibility)
            % dz: relative movement in micrometers (positive = up, negative = down)
            % Returns: true if successful, false otherwise
            
            success = obj.relativeMoveZ(dz);
        end
        
        function success = relativeMoveZ(obj, dz)
            % Move Z-axis by relative amount in micrometers
            % dz: relative movement in micrometers (positive = up, negative = down)
            % Returns: true if successful, false otherwise
            
            success = false;
            
            try
                % Check if we're in simulation mode
                if isempty(obj.hMotors)
                    % Simulation mode - just log the movement
                    fprintf('SIMULATION: Z-axis would move by %.2f μm\n', dz);
                    success = true;
                    return;
                end
                
                % Get current position
                currentPos = obj.getCurrentZPosition();
                if isempty(currentPos)
                    warning('ScanImageController:NoPosition', 'Could not get current Z position');
                    return;
                end
                
                % Calculate target position
                targetPos = currentPos + dz;
                
                % Move to target position
                success = obj.moveZToAbsolute(targetPos);
                
                if success
                    fprintf('Z-axis moved by %.2f μm (to %.2f μm)\n', dz, targetPos);
                else
                    warning('ScanImageController:MoveFailed', 'Failed to move Z-axis by %.2f μm', dz);
                end
                
            catch ME
                warning('ScanImageController:RelativeMoveError', 'relativeMoveZ error: %s', ME.message);
            end
        end
        
        function success = relativeMoveX(obj, dx)
            % Move X-axis by relative amount in micrometers
            % dx: relative movement in micrometers
            % Returns: true if successful, false otherwise
            
            success = false;
            
            try
                % Check if we're in simulation mode
                if isempty(obj.hMotors)
                    % Simulation mode - just log the movement
                    fprintf('SIMULATION: X-axis would move by %.2f μm\n', dx);
                    success = true;
                    return;
                end
                
                % Get current position
                currentPos = obj.getCurrentXPosition();
                if isempty(currentPos)
                    warning('ScanImageController:NoPosition', 'Could not get current X position');
                    return;
                end
                
                % Calculate target position
                targetPos = currentPos + dx;
                
                % Move to target position
                success = obj.moveXToAbsolute(targetPos);
                
                if success
                    fprintf('X-axis moved by %.2f μm (to %.2f μm)\n', dx, targetPos);
                else
                    warning('ScanImageController:MoveFailed', 'Failed to move X-axis by %.2f μm', dx);
                end
                
            catch ME
                warning('ScanImageController:RelativeMoveError', 'relativeMoveX error: %s', ME.message);
            end
        end
        
        function success = relativeMoveY(obj, dy)
            % Move Y-axis by relative amount in micrometers
            % dy: relative movement in micrometers
            % Returns: true if successful, false otherwise
            
            success = false;
            
            try
                % Check if we're in simulation mode
                if isempty(obj.hMotors)
                    % Simulation mode - just log the movement
                    fprintf('SIMULATION: Y-axis would move by %.2f μm\n', dy);
                    success = true;
                    return;
                end
                
                % Get current position
                currentPos = obj.getCurrentYPosition();
                if isempty(currentPos)
                    warning('ScanImageController:NoPosition', 'Could not get current Y position');
                    return;
                end
                
                % Calculate target position
                targetPos = currentPos + dy;
                
                % Move to target position
                success = obj.moveYToAbsolute(targetPos);
                
                if success
                    fprintf('Y-axis moved by %.2f μm (to %.2f μm)\n', dy, targetPos);
                else
                    warning('ScanImageController:MoveFailed', 'Failed to move Y-axis by %.2f μm', dy);
                end
                
            catch ME
                warning('ScanImageController:RelativeMoveError', 'relativeMoveY error: %s', ME.message);
            end
        end
        
        function success = moveZToAbsolute(obj, zPos)
            % Move Z-axis to absolute position in micrometers
            % zPos: target position in micrometers
            % Returns: true if successful, false otherwise
            
            success = false;
            
            try
                % Check if we're in simulation mode
                if isempty(obj.hMotors)
                    % Simulation mode - just log the movement
                    fprintf('SIMULATION: Z-axis would move to %.2f μm\n', zPos);
                    success = true;
                    return;
                end
                
                % Get current axes positions
                currentAxes = obj.hMotors.axesPosition;
                if length(currentAxes) < obj.zAxisIndex
                    warning('ScanImageController:InvalidAxis', 'Z-axis index %d not available in axes position array', obj.zAxisIndex);
                    return;
                end
                
                % Create new position array with updated Z
                newAxes = currentAxes;
                newAxes(obj.zAxisIndex) = zPos;
                
                % Move to new position
                obj.hMotors.axesPosition = newAxes;
                success = true;
                
            catch ME
                warning('ScanImageController:MoveToAbsoluteError', 'moveZToAbsolute error: %s', ME.message);
            end
        end
        
        function success = moveXToAbsolute(obj, xPos)
            % Move X-axis to absolute position in micrometers
            % xPos: target position in micrometers
            % Returns: true if successful, false otherwise
            
            success = false;
            
            try
                % Check if we're in simulation mode
                if isempty(obj.hMotors)
                    % Simulation mode - just log the movement
                    fprintf('SIMULATION: X-axis would move to %.2f μm\n', xPos);
                    success = true;
                    return;
                end
                
                % Get current axes positions
                currentAxes = obj.hMotors.axesPosition;
                if length(currentAxes) < obj.xAxisIndex
                    warning('ScanImageController:InvalidAxis', 'X-axis index %d not available in axes position array', obj.xAxisIndex);
                    return;
                end
                
                % Create new position array with updated X
                newAxes = currentAxes;
                newAxes(obj.xAxisIndex) = xPos;
                
                % Move to new position
                obj.hMotors.axesPosition = newAxes;
                success = true;
                
            catch ME
                warning('ScanImageController:MoveToAbsoluteError', 'moveXToAbsolute error: %s', ME.message);
            end
        end
        
        function success = moveYToAbsolute(obj, yPos)
            % Move Y-axis to absolute position in micrometers
            % yPos: target position in micrometers
            % Returns: true if successful, false otherwise
            
            success = false;
            
            try
                % Check if we're in simulation mode
                if isempty(obj.hMotors)
                    % Simulation mode - just log the movement
                    fprintf('SIMULATION: Y-axis would move to %.2f μm\n', yPos);
                    success = true;
                    return;
                end
                
                % Get current axes positions
                currentAxes = obj.hMotors.axesPosition;
                if length(currentAxes) < obj.yAxisIndex
                    warning('ScanImageController:InvalidAxis', 'Y-axis index %d not available in axes position array', obj.yAxisIndex);
                    return;
                end
                
                % Create new position array with updated Y
                newAxes = currentAxes;
                newAxes(obj.yAxisIndex) = yPos;
                
                % Move to new position
                obj.hMotors.axesPosition = newAxes;
                success = true;
                
            catch ME
                warning('ScanImageController:MoveToAbsoluteError', 'moveYToAbsolute error: %s', ME.message);
            end
        end
        
        function zPos = getCurrentZPosition(obj)
            % Get current Z-axis position in micrometers
            % Returns: current Z position or empty if unavailable
            
            zPos = [];
            
            try
                if isempty(obj.hMotors)
                    % Simulation mode - return placeholder
                    zPos = 0;
                    return;
                end
                
                currentAxes = obj.hMotors.axesPosition;
                if length(currentAxes) >= obj.zAxisIndex
                    zPos = currentAxes(obj.zAxisIndex);
                end
                
            catch ME
                warning('ScanImageController:GetPositionError', 'getCurrentZPosition error: %s', ME.message);
            end
        end
        
        function xPos = getCurrentXPosition(obj)
            % Get current X-axis position in micrometers
            % Returns: current X position or empty if unavailable
            
            xPos = [];
            
            try
                if isempty(obj.hMotors)
                    % Simulation mode - return placeholder
                    xPos = 0;
                    return;
                end
                
                currentAxes = obj.hMotors.axesPosition;
                if length(currentAxes) >= obj.xAxisIndex
                    xPos = currentAxes(obj.xAxisIndex);
                end
                
            catch ME
                warning('ScanImageController:GetPositionError', 'getCurrentXPosition error: %s', ME.message);
            end
        end
        
        function yPos = getCurrentYPosition(obj)
            % Get current Y-axis position in micrometers
            % Returns: current Y position or empty if unavailable
            
            yPos = [];
            
            try
                if isempty(obj.hMotors)
                    % Simulation mode - return placeholder
                    yPos = 0;
                    return;
                end
                
                currentAxes = obj.hMotors.axesPosition;
                if length(currentAxes) >= obj.yAxisIndex
                    yPos = currentAxes(obj.yAxisIndex);
                end
                
            catch ME
                warning('ScanImageController:GetPositionError', 'getCurrentYPosition error: %s', ME.message);
            end
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
end 