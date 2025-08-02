%==============================================================================
% SCANIMAGEZCONTROLLER.M
%==============================================================================
% Z-axis specific interface to ScanImage's motor control system.
%
% This controller provides a specialized interface for Z-axis control within
% ScanImage's motor system. It focuses exclusively on Z-axis movements and
% provides a simplified interface compared to the full multi-axis controller.
% This is useful for applications that only need Z-axis control (like focus
% adjustment).
%
% Key Features:
%   - Z-axis specific control and positioning
%   - Relative movement interface for easy integration
%   - Simulation mode for testing without ScanImage
%   - Position validation and error handling
%   - Simplified interface compared to multi-axis controller
%   - Comprehensive logging and status reporting
%
% Z-axis Configuration:
%   - Z-axis: Index 3 (typically focus movement in ScanImage)
%   - Movement Range: Dependent on stage hardware
%   - Units: Micrometers (μm)
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
%   controller = ScanImageZController(hSI.hMotors);
%   success = controller.relativeMove(10.0);  % Move Z up by 10 μm
%   success = controller.moveToAbsolute(100.0);  % Move Z to 100 μm
%
%==============================================================================

classdef ScanImageZController < handle
    % ScanImageController - Interface to ScanImage's motor control
    % Provides a simple relativeMove interface for MJC3 controllers (X, Y, Z axes)
    
    properties (Access = private)
        hMotors     % ScanImage motors handle
        xAxisIndex  % Index of X-axis (typically 1)
        yAxisIndex  % Index of Y-axis (typically 2)
        zAxisIndex  % Index of Z-axis (typically 3)
    end
    
    methods
        function obj = ScanImageZController(hMotors)
            % Constructor
            % hMotors: ScanImage motors handle (hSI.hMotors) or empty for simulation
            
            if nargin < 1
                hMotors = [];
            end
            
            obj.hMotors = hMotors;
            obj.zAxisIndex = 3; % Z is typically the 3rd axis in ScanImage
            
            % Check if we're in simulation mode
            if isempty(hMotors)
                fprintf('ScanImageZController initialized in simulation mode\n');
            else
                % Verify the motors handle is valid
                if ~isprop(hMotors, 'axesPosition')
                    error('Invalid hMotors handle - missing axesPosition property');
                end
                fprintf('ScanImageZController initialized for Z-axis control\n');
            end
        end
        
        function success = relativeMove(obj, dz)
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
                currentPos = obj.getCurrentPosition();
                if isempty(currentPos)
                    warning('ScanImageZController:NoPosition', 'Could not get current Z position');
                    return;
                end
                
                % Calculate target position
                targetPos = currentPos + dz;
                
                % Move to target position
                success = obj.moveToAbsolute(targetPos);
                
                if success
                    fprintf('Z-axis moved by %.2f μm (to %.2f μm)\n', dz, targetPos);
                else
                    warning('ScanImageZController:MoveFailed', 'Failed to move Z-axis by %.2f μm', dz);
                end
                
            catch ME
                warning('ScanImageZController:RelativeMoveError', 'relativeMove error: %s', ME.message);
            end
        end
        
        function success = moveToAbsolute(obj, zPos)
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
                    warning('ScanImageZController:InvalidAxis', 'Z-axis index %d not available in axes position array', obj.zAxisIndex);
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
                warning('ScanImageZController:MoveToAbsoluteError', 'moveToAbsolute error: %s', ME.message);
            end
        end
        
        function pos = getCurrentPosition(obj)
            % Get current Z-axis position in micrometers
            % Returns: current Z position or empty if error
            
            pos = [];
            
            try
                % Check if we're in simulation mode
                if isempty(obj.hMotors)
                    % Simulation mode - return a dummy position
                    pos = 0.0;
                    return;
                end
                
                currentAxes = obj.hMotors.axesPosition;
                if length(currentAxes) >= obj.zAxisIndex
                    pos = currentAxes(obj.zAxisIndex);
                end
            catch ME
                warning('ScanImageZController:GetCurrentPositionError', 'getCurrentPosition error: %s', ME.message);
            end
        end
        
        function isMoving = isInMotion(obj)
            % Check if Z-axis is currently moving
            % Returns: true if moving, false if stationary or error
            
            isMoving = false;
            
            try
                % Check if we're in simulation mode
                if isempty(obj.hMotors)
                    % Simulation mode - always return false (not moving)
                    return;
                end
                
                if isprop(obj.hMotors, 'moveInProgress')
                    isMoving = obj.hMotors.moveInProgress;
                end
            catch ME
                warning('ScanImageZController:IsInMotionError', 'isInMotion error: %s', ME.message);
            end
        end
        
        function waitForMove(obj, timeout)
            % Wait for current move to complete
            % timeout: maximum wait time in seconds (default: 5)
            
            if nargin < 2
                timeout = 5;
            end
            
            % Check if we're in simulation mode
            if isempty(obj.hMotors)
                % Simulation mode - no need to wait
                fprintf('SIMULATION: Z-axis move completed instantly\n');
                return;
            end
            
            startTime = tic;
            while obj.isInMotion() && toc(startTime) < timeout
                pause(0.05);
            end
            
            if obj.isInMotion()
                warning('ScanImageZController:MoveTimeout', 'Z-axis move did not complete within %.1f seconds', timeout);
            end
        end
    end
end