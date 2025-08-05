%==============================================================================
% STAGECONTROLSERVICE.M
%==============================================================================
% Stage control service for the Foilview application.
%
% This service handles all stage positioning, movement validation, and
% coordinate management for the Foilview application. It provides a pure
% business logic layer with no UI dependencies, focused on core stage
% control functionality.
%
% Key Features:
%   - Multi-axis stage movement (X, Y, Z)
%   - Movement validation and constraint checking
%   - Position tracking and synchronization
%   - Event-driven position change notifications
%   - Simulation mode support
%
% Movement Constraints:
%   - Minimum step size: 0.01 μm
%   - Maximum step size: 1000 μm
%   - Position tolerance: 0.01 μm
%   - Movement wait time: 0.2 seconds
%
% Dependencies:
%   - ScanImageManager: Stage movement interface
%   - FoilviewUtils: Error handling and logging
%   - MATLAB: Core functionality and events
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   stageService = StageControlService(scanImageManager);
%   success = stageService.moveStage('Z', 10.0);
%
%==============================================================================

classdef StageControlService < handle
    % StageControlService - Pure business logic for stage movement operations
    % Handles all stage positioning, movement validation, and coordinate management
    % No UI dependencies - focused on core stage control functionality
    
    properties (Constant, Access = public)
        % Movement constraints
        MIN_STEP_SIZE = 0.01
        MAX_STEP_SIZE = 1000
        POSITION_TOLERANCE = 0.01
        MOVEMENT_WAIT_TIME = 0.2
        
        % Default step sizes for UI integration
        STEP_SIZES = [0.1, 0.5, 1, 5, 10, 50]
        DEFAULT_STEP_SIZE = 1.0
    end
    
    properties (Access = private)
        ScanImageManager
        CurrentXPosition = 0
        CurrentYPosition = 0
        CurrentZPosition = 0
        SimulationMode = true
    end
    
    events
        PositionChanged
    end
    
    methods (Access = public)
        function obj = StageControlService(scanImageManager)
            % Constructor - requires ScanImageManager dependency
            if nargin >= 1 && ~isempty(scanImageManager)
                obj.ScanImageManager = scanImageManager;
                obj.SimulationMode = scanImageManager.isSimulationMode();
            else
                error('StageControlService requires a ScanImageManager instance');
            end
        end
        
        function positions = getCurrentPositions(obj)
            % Get current stage positions as a structure
            positions = struct();
            positions.x = obj.CurrentXPosition;
            positions.y = obj.CurrentYPosition;
            positions.z = obj.CurrentZPosition;
        end
        
        function success = moveStage(obj, axis, microns)
            % Move stage along specified axis by given amount
            % axis: 'X', 'Y', or 'Z'
            % microns: distance to move (positive or negative)
            
            success = false;
            
            % Validate inputs
            if ~obj.validateMovement(microns)
                return;
            end
            
            if ~obj.isValidAxis(axis)
                FoilviewUtils.error('StageControlService', 'Invalid axis: %s. Must be X, Y, or Z', axis);
                return;
            end
            
            try
                % Perform the movement
                newPos = obj.ScanImageManager.moveStage(axis, microns);
                
                % Update internal position tracking
                switch upper(axis)
                    case 'X'
                        obj.CurrentXPosition = newPos;
                        fprintf('X Stage moved %.1f μm to position %.1f μm\n', microns, newPos);
                    case 'Y'
                        obj.CurrentYPosition = newPos;
                        fprintf('Y Stage moved %.1f μm to position %.1f μm\n', microns, newPos);
                    case 'Z'
                        obj.CurrentZPosition = newPos;
                        % Only print in real mode, not simulation (ScanImageManager handles simulation print)
                        if ~obj.ScanImageManager.isSimulationMode()
                            fprintf('Z Stage moved %.1f μm to position %.1f μm\n', microns, newPos);
                        end
                end
                
                % Notify listeners of position change
                obj.notifyPositionChanged();
                success = true;
                
            catch ME
                FoilviewUtils.logException('StageControlService.moveStage', ME);
            end
        end
        
        function success = setAbsolutePosition(obj, axis, position)
            % Set absolute position for specified axis
            % axis: 'X', 'Y', or 'Z'
            % position: target absolute position
            
            success = false;
            
            % Validate inputs
            if ~obj.validatePosition(position)
                return;
            end
            
            if ~obj.isValidAxis(axis)
                FoilviewUtils.error('StageControlService', 'Invalid axis: %s. Must be X, Y, or Z', axis);
                return;
            end
            
            try
                % Calculate required movement
                currentPos = obj.getCurrentAxisPosition(axis);
                delta = position - currentPos;
                
                % Only move if difference is significant
                if abs(delta) > obj.POSITION_TOLERANCE
                    success = obj.moveStage(axis, delta);
                else
                    % Already at target position
                    obj.notifyPositionChanged();
                    success = true;
                end
                
            catch ME
                FoilviewUtils.logException('StageControlService.setAbsolutePosition', ME);
            end
        end
        
        function success = setXYZPosition(obj, xPos, yPos, zPos)
            % Set X, Y, and Z positions simultaneously
            success = false;
            
            try
                % Validate all positions
                if ~obj.validatePosition(xPos) || ~obj.validatePosition(yPos) || ~obj.validatePosition(zPos)
                    return;
                end
                
                % Move each axis if needed
                xSuccess = obj.setAbsolutePosition('X', xPos);
                ySuccess = obj.setAbsolutePosition('Y', yPos);
                zSuccess = obj.setAbsolutePosition('Z', zPos);
                
                success = xSuccess && ySuccess && zSuccess;
                
                if success
                    fprintf('Position set to X:%.1f, Y:%.1f, Z:%.1f μm\n', ...
                           obj.CurrentXPosition, obj.CurrentYPosition, obj.CurrentZPosition);
                end
                
            catch ME
                FoilviewUtils.logException('StageControlService.setXYZPosition', ME);
            end
        end
        
        function success = resetPosition(obj, axis)
            % Reset specified axis to zero position
            % axis: 'X', 'Y', 'Z', or 'ALL' for all axes
            
            success = false;
            
            try
                if nargin < 2 || strcmpi(axis, 'ALL')
                    % Reset all axes
                    success = obj.setXYZPosition(0, 0, 0);
                    if success
                        fprintf('All positions reset to 0 μm\n');
                    end
                else
                    % Reset specific axis
                    oldPos = obj.getCurrentAxisPosition(axis);
                    success = obj.setAbsolutePosition(axis, 0);
                    if success
                        fprintf('%s position reset to 0 μm (was %.1f μm)\n', upper(axis), oldPos);
                    end
                end
                
            catch ME
                FoilviewUtils.logException('StageControlService.resetPosition', ME);
            end
        end
        
        function success = refreshPositions(obj)
            % Refresh positions from ScanImage manager
            success = false;
            
            try
                positions = obj.ScanImageManager.getPositions();
                
                % Check for changes
                xChanged = abs(positions.x - obj.CurrentXPosition) > obj.POSITION_TOLERANCE;
                yChanged = abs(positions.y - obj.CurrentYPosition) > obj.POSITION_TOLERANCE;
                zChanged = abs(positions.z - obj.CurrentZPosition) > obj.POSITION_TOLERANCE;
                
                % Update positions
                obj.CurrentXPosition = positions.x;
                obj.CurrentYPosition = positions.y;
                obj.CurrentZPosition = positions.z;
                
                % Notify if any position changed
                if xChanged || yChanged || zChanged
                    obj.notifyPositionChanged();
                end
                
                success = true;
                
            catch ME
                FoilviewUtils.logException('StageControlService.refreshPositions', ME);
            end
        end
        
        function success = initializePositions(obj)
            % Initialize positions from ScanImage manager
            success = obj.refreshPositions();
            if success
                FoilviewUtils.info('StageControlService', 'Positions initialized: X:%.1f, Y:%.1f, Z:%.1f μm', ...
                    obj.CurrentXPosition, obj.CurrentYPosition, obj.CurrentZPosition);
            end
        end
        
        function distance = calculateDistance(obj, targetX, targetY, targetZ)
            % Calculate 3D distance to target position
            if nargin < 4
                targetZ = obj.CurrentZPosition;
            end
            if nargin < 3
                targetY = obj.CurrentYPosition;
            end
            
            dx = targetX - obj.CurrentXPosition;
            dy = targetY - obj.CurrentYPosition;
            dz = targetZ - obj.CurrentZPosition;
            
            distance = sqrt(dx^2 + dy^2 + dz^2);
        end
        
        function inBounds = isPositionInBounds(obj, x, y, z)
            % Check if position is within allowed bounds
            if nargin < 4, z = obj.CurrentZPosition; end
            if nargin < 3, y = obj.CurrentYPosition; end
            if nargin < 2, x = obj.CurrentXPosition; end
            
            inBounds = obj.validatePosition(x) && obj.validatePosition(y) && obj.validatePosition(z);
        end
        
        function stepSize = getOptimalStepSize(obj, targetDistance)
            % Get optimal step size based on target distance
            if targetDistance <= 1
                stepSize = 0.1;
            elseif targetDistance <= 5
                stepSize = 0.5;
            elseif targetDistance <= 20
                stepSize = 1.0;
            elseif targetDistance <= 100
                stepSize = 5.0;
            else
                stepSize = 10.0;
            end
            
            % Ensure step size is within bounds
            stepSize = max(obj.MIN_STEP_SIZE, min(obj.MAX_STEP_SIZE, stepSize));
        end
    end
    
    methods (Access = private)
        function valid = validateMovement(obj, microns)
            % Validate movement parameters
            valid = FoilviewUtils.validateNumericRange(microns, -obj.MAX_STEP_SIZE, obj.MAX_STEP_SIZE, 'Movement distance');
        end
        
        function valid = validatePosition(obj, position)
            % Validate absolute position
            valid = true;
        end
        
        function valid = isValidAxis(~, axis)
            % Check if axis is valid
            valid = ischar(axis) && ismember(upper(axis), {'X', 'Y', 'Z'});
        end
        
        function position = getCurrentAxisPosition(obj, axis)
            % Get current position for specified axis
            switch upper(axis)
                case 'X'
                    position = obj.CurrentXPosition;
                case 'Y'
                    position = obj.CurrentYPosition;
                case 'Z'
                    position = obj.CurrentZPosition;
                otherwise
                    error('Invalid axis: %s', axis);
            end
        end
        
        function notifyPositionChanged(obj)
            % Notify listeners that position has changed
            try
                % eventData = struct();
                % eventData.positions = obj.getCurrentPositions();
                % eventData.timestamp = datetime('now');
                notify(obj, 'PositionChanged');
            catch ME
                FoilviewUtils.logException('StageControlService.notifyPositionChanged', ME);
            end
        end
    end
    
    methods (Static)
        function [valid, errorMsg] = validateStageMovementParameters(axis, microns)
            % Static validation method for external use
            valid = true;
            errorMsg = '';
            
            % Validate axis
            if ~ischar(axis) || ~ismember(upper(axis), {'X', 'Y', 'Z'})
                valid = false;
                errorMsg = 'Invalid axis. Must be X, Y, or Z';
                return;
            end
            
            % Validate movement distance
            if ~isnumeric(microns) || ~isscalar(microns)
                valid = false;
                errorMsg = 'Movement distance must be a numeric scalar';
                return;
            end
            
            if abs(microns) > StageControlService.MAX_STEP_SIZE
                valid = false;
                errorMsg = sprintf('Movement distance exceeds maximum (%.1f μm)', StageControlService.MAX_STEP_SIZE);
                return;
            end
            
            if abs(microns) < StageControlService.MIN_STEP_SIZE && microns ~= 0
                valid = false;
                errorMsg = sprintf('Movement distance below minimum (%.2f μm)', StageControlService.MIN_STEP_SIZE);
                return;
            end
        end
        
        function [valid, errorMsg] = validateAbsolutePosition(position)
            % Static validation method for absolute positions
            valid = true;
            errorMsg = '';
            
            if ~isnumeric(position) || ~isscalar(position)
                valid = false;
                errorMsg = 'Position must be a numeric scalar';
                return;
            end
            
            % No min/max position check
        end
        
        function stepSizes = getAvailableStepSizes()
            % Get array of available step sizes
            stepSizes = StageControlService.STEP_SIZES;
        end
        
        function stepSize = getDefaultStepSize()
            % Get default step size
            stepSize = StageControlService.DEFAULT_STEP_SIZE;
        end
    end
end