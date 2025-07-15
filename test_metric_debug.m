% Test script to debug the updateMetric error
% This script will help identify the exact cause of the "Unknown error" in updateMetric

fprintf('=== Metric Update Debug Test ===\n');

% Initialize the controller
fprintf('\n1. Initializing FoilviewController...\n');
controller = FoilviewController();

% Test 2: Check initial state
fprintf('\n2. Checking initial state...\n');
fprintf('SimulationMode: %d\n', controller.SimulationMode);
fprintf('CurrentMetricType: %s\n', controller.CurrentMetricType);
fprintf('CurrentPosition: %.1f\n', controller.CurrentPosition);

% Test 3: Try to update metric
fprintf('\n3. Testing updateMetric...\n');
try
    controller.updateMetric();
    fprintf('updateMetric completed successfully\n');
catch ME
    fprintf('ERROR: updateMetric failed: %s\n', ME.message);
    fprintf('Error identifier: %s\n', ME.identifier);
    fprintf('Error stack:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end

% Test 4: Check metric state after update
fprintf('\n4. Checking metric state after update...\n');
fprintf('CurrentMetric: %.2f\n', controller.CurrentMetric);
fprintf('AllMetrics fields: %s\n', strjoin(fieldnames(controller.AllMetrics), ', '));

% Test 5: Try to update metric again
fprintf('\n5. Testing updateMetric again...\n');
try
    controller.updateMetric();
    fprintf('Second updateMetric completed successfully\n');
catch ME
    fprintf('ERROR: Second updateMetric failed: %s\n', ME.message);
end

fprintf('\n=== Metric Debug Test Complete ===\n'); 