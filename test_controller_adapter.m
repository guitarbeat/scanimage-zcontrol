% Test script to validate the ControllerAdapter property forwarding
% This script tests whether the adapter correctly forwards property access

% Mock controller with params property
MockController = struct(...
    'params', struct('initialStepSize', 10), ...
    'hSI', struct('version', '2023.1'), ...
    'scanner', struct('isRunning', false), ...
    'getZ', @() 50, ...
    'moveZUp', @() disp('Moving Z up'), ...
    'moveZDown', @() disp('Moving Z down'), ...
    'toggleMonitor', @(b) disp(['Monitor toggled: ' num2str(b)]), ...
    'moveToMaxBrightness', @() disp('Moving to max brightness'), ...
    'toggleZScan', @(b) disp(['ZScan toggled: ' num2str(b)]), ...
    'getZLimit', @(which) 100 * (strcmp(which, 'max') - strcmp(which, 'min')), ...
    'setMinZLimit', @(v) disp(['Min Z limit set to: ' num2str(v)]), ...
    'setMaxZLimit', @(v) disp(['Max Z limit set to: ' num2str(v)]), ...
    'updateStepSizeImmediate', @(v) disp(['Step size updated to: ' num2str(v)]), ...
    'abortAllOperations', @() disp('All operations aborted') ...
);

% Create the adapter
adapter = gui.interfaces.ControllerAdapter(MockController);

% Test property access
try
    disp('Testing adapter direct property access:');
    disp(['  initialStepSize = ' num2str(adapter.params.initialStepSize)]);
    disp(['  hSI.version = ' adapter.hSI.version]);
    disp(['  scanner.isRunning = ' num2str(adapter.scanner.isRunning)]);
    disp('Property access working!');
catch ME
    disp(['ERROR: Property access failed: ' ME.message]);
end

% Test method calls
try
    disp('Testing adapter method calls:');
    disp(['  getZ() = ' num2str(adapter.getZ())]);
    adapter.moveZUp();
    adapter.toggleMonitor(true);
    disp('Method calls working!');
catch ME
    disp(['ERROR: Method call failed: ' ME.message]);
end

% Test dynamic property access
try
    disp('Testing adapter dynamic property access:');
    adapter.scanner.isRunning = true;
    disp(['  scanner.isRunning after change = ' num2str(adapter.scanner.isRunning)]);
    disp('Dynamic property access working!');
catch ME
    disp(['ERROR: Dynamic property access failed: ' ME.message]);
end

disp('All tests completed!'); 