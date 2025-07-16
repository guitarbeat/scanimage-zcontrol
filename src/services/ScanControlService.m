classdef ScanControlService < handle
    % ScanControlService - Pure business logic for scan control operations
    % No UI dependencies, focused on scan parameter validation and execution
    
    properties (Constant)
        MIN_STEP_SIZE = 0.01
        MAX_STEP_SIZE = 1000
        MIN_AUTO_STEPS = 1
        MAX_AUTO_STEPS = 1000
        MIN_AUTO_DELAY = 0.1
        MAX_AUTO_DELAY = 10.0
    end
    
    methods (Static)
        function [valid, errorMsg] = validateAutoStepParameters(stepSize, numSteps, delay)
            % Centralized validation for auto-stepping parameters
            valid = true;
            errorMsg = '';
            
            if ~ScanControlService.isValidStepSize(stepSize)
                valid = false;
                errorMsg = sprintf('Step size must be between %.2f and %.0f μm', ...
                    ScanControlService.MIN_STEP_SIZE, ScanControlService.MAX_STEP_SIZE);
                return;
            end
            
            if ~ScanControlService.isValidStepCount(numSteps)
                valid = false;
                errorMsg = sprintf('Number of steps must be between %d and %d', ...
                    ScanControlService.MIN_AUTO_STEPS, ScanControlService.MAX_AUTO_STEPS);
                return;
            end
            
            if ~ScanControlService.isValidDelay(delay)
                valid = false;
                errorMsg = sprintf('Delay must be between %.1f and %.1f seconds', ...
                    ScanControlService.MIN_AUTO_DELAY, ScanControlService.MAX_AUTO_DELAY);
                return;
            end
        end
        
        function valid = isValidStepSize(stepSize)
            valid = isnumeric(stepSize) && isscalar(stepSize) && ...
                   stepSize >= ScanControlService.MIN_STEP_SIZE && ...
                   stepSize <= ScanControlService.MAX_STEP_SIZE;
        end
        
        function valid = isValidStepCount(numSteps)
            valid = isnumeric(numSteps) && isscalar(numSteps) && ...
                   mod(numSteps, 1) == 0 && ...
                   numSteps >= ScanControlService.MIN_AUTO_STEPS && ...
                   numSteps <= ScanControlService.MAX_AUTO_STEPS;
        end
        
        function valid = isValidDelay(delay)
            valid = isnumeric(delay) && isscalar(delay) && ...
                   delay >= ScanControlService.MIN_AUTO_DELAY && ...
                   delay <= ScanControlService.MAX_AUTO_DELAY;
        end
        
        function direction = parseDirection(directionValue)
            % Convert UI direction value to numeric direction
            if ischar(directionValue) || isstring(directionValue)
                if strcmpi(directionValue, 'Up')
                    direction = 1;
                elseif strcmpi(directionValue, 'Down')
                    direction = -1;
                else
                    direction = 1; % Default to up
                end
            elseif isnumeric(directionValue)
                direction = sign(directionValue);
                if direction == 0
                    direction = 1;
                end
            else
                direction = 1; % Default
            end
        end
        
        function params = createAutoStepParams(stepSize, numSteps, delay, direction, recordMetrics)
            % Create validated parameter structure for auto-stepping
            if nargin < 5
                recordMetrics = true;
            end
            
            params = struct();
            params.stepSize = stepSize;
            params.numSteps = numSteps;
            params.delay = delay;
            params.direction = ScanControlService.parseDirection(direction);
            params.recordMetrics = logical(recordMetrics);
            params.isValid = true;
            
            [valid, errorMsg] = ScanControlService.validateAutoStepParameters(stepSize, numSteps, delay);
            if ~valid
                params.isValid = false;
                params.errorMessage = errorMsg;
            end
        end
    end
end