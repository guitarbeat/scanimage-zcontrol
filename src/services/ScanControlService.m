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

        function executionPlan = createAutoStepExecutionPlan(stepSize, numSteps, direction)
            % Create execution plan for auto-stepping sequence
            executionPlan = struct();
            executionPlan.steps = [];
            executionPlan.totalDistance = 0;
            executionPlan.estimatedDuration = 0;

            % Validate inputs first
            [valid, errorMsg] = ScanControlService.validateAutoStepParameters(stepSize, numSteps, 0.5);
            if ~valid
                executionPlan.isValid = false;
                executionPlan.errorMessage = errorMsg;
                return;
            end

            % Parse direction
            parsedDirection = ScanControlService.parseDirection(direction);

            % Calculate step sequence
            actualStepSize = stepSize * parsedDirection;
            executionPlan.steps = (1:numSteps) * actualStepSize;
            executionPlan.totalDistance = numSteps * stepSize;
            executionPlan.direction = parsedDirection;
            executionPlan.isValid = true;
        end

        function metrics = initializeMetricsCollection()
            % Initialize structure for collecting auto-step metrics
            metrics = struct();
            metrics.Positions = [];
            metrics.Values = struct();
            metrics.StartTime = datetime('now');
            metrics.StepCount = 0;
        end

        function metrics = recordMetricStep(metrics, position, metricValues)
            % Record a single step's metrics
            if nargin < 3
                metricValues = struct();
            end

            % Record position
            metrics.Positions(end+1) = position;
            metrics.StepCount = metrics.StepCount + 1;

            % Record metric values
            metricFields = fieldnames(metricValues);
            for i = 1:length(metricFields)
                fieldName = metricFields{i};
                if ~isfield(metrics.Values, fieldName)
                    metrics.Values.(fieldName) = [];
                end
                metrics.Values.(fieldName)(end+1) = metricValues.(fieldName);
            end
        end

        function summary = summarizeAutoStepSession(metrics, params)
            % Create summary of completed auto-step session
            summary = struct();
            summary.TotalSteps = length(metrics.Positions);
            summary.Duration = seconds(datetime('now') - metrics.StartTime);
            summary.AverageStepRate = summary.TotalSteps / max(summary.Duration, 0.1);

            if ~isempty(metrics.Positions)
                summary.StartPosition = metrics.Positions(1);
                summary.EndPosition = metrics.Positions(end);
                summary.TotalDistance = abs(summary.EndPosition - summary.StartPosition);
                summary.ActualStepSize = summary.TotalDistance / max(summary.TotalSteps - 1, 1);
            else
                summary.StartPosition = 0;
                summary.EndPosition = 0;
                summary.TotalDistance = 0;
                summary.ActualStepSize = 0;
            end

            % Include original parameters
            if nargin > 1
                summary.RequestedStepSize = params.stepSize;
                summary.RequestedSteps = params.numSteps;
                summary.Direction = params.direction;
            end
        end
    end
end