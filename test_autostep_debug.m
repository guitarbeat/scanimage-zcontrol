% Test script to debug auto-step start/stop functionality
% This script will help identify where the start/stop problem occurs

fprintf('=== Auto-Step Start/Stop Debug Test ===\n');

% Initialize the controller
fprintf('\n1. Initializing FoilviewController...\n');
controller = FoilviewController();

% Test 2: Check initial state
fprintf('\n2. Checking initial state...\n');
timerState = controller.getTimerState();
fprintf('Initial IsAutoRunning: %d\n', timerState.IsAutoRunning);
fprintf('Initial HasTimer: %d\n', timerState.HasTimer);
fprintf('Initial TimerValid: %d\n', timerState.TimerValid);

% Test 3: Try to start auto-stepping
fprintf('\n3. Testing auto-step start...\n');
try
    controller.startAutoStepping(1, 3, 1, 1, false);  % 3 steps, 1 second delay, up direction
    fprintf('Auto-step start successful\n');
    timerState = controller.getTimerState();
    fprintf('IsAutoRunning after start: %d\n', timerState.IsAutoRunning);
    fprintf('HasTimer after start: %d\n', timerState.HasTimer);
    fprintf('TimerValid after start: %d\n', timerState.TimerValid);
catch ME
    fprintf('ERROR: Failed to start auto-stepping: %s\n', ME.message);
end

% Test 4: Wait a moment and check state
fprintf('\n4. Waiting 2 seconds and checking state...\n');
pause(2);
timerState = controller.getTimerState();
fprintf('IsAutoRunning after 2s: %d\n', timerState.IsAutoRunning);
fprintf('CurrentStep: %d/%d\n', timerState.CurrentStep, timerState.TotalSteps);

% Test 5: Try to stop auto-stepping
fprintf('\n5. Testing auto-step stop...\n');
try
    controller.stopAutoStepping();
    fprintf('Auto-step stop successful\n');
    timerState = controller.getTimerState();
    fprintf('IsAutoRunning after stop: %d\n', timerState.IsAutoRunning);
    fprintf('HasTimer after stop: %d\n', timerState.HasTimer);
    fprintf('TimerValid after stop: %d\n', timerState.TimerValid);
catch ME
    fprintf('ERROR: Failed to stop auto-stepping: %s\n', ME.message);
end

% Test 6: Try to start again
fprintf('\n6. Testing auto-step restart...\n');
try
    controller.startAutoStepping(1, 2, 1, -1, false);  % 2 steps, 1 second delay, down direction
    fprintf('Auto-step restart successful\n');
    timerState = controller.getTimerState();
    fprintf('IsAutoRunning after restart: %d\n', timerState.IsAutoRunning);
catch ME
    fprintf('ERROR: Failed to restart auto-stepping: %s\n', ME.message);
end

% Test 7: Wait for completion
fprintf('\n7. Waiting for auto-step completion...\n');
pause(3);
timerState = controller.getTimerState();
fprintf('Final IsAutoRunning: %d\n', timerState.IsAutoRunning);
fprintf('Final CurrentStep: %d/%d\n', timerState.CurrentStep, timerState.TotalSteps);
fprintf('Final HasTimer: %d\n', timerState.HasTimer);
fprintf('Final TimerValid: %d\n', timerState.TimerValid);

% Test 8: Test rapid start/stop
fprintf('\n8. Testing rapid start/stop...\n');
try
    controller.startAutoStepping(1, 5, 0.5, 1, false);
    fprintf('Rapid start successful\n');
    pause(0.1);  % Very short wait
    controller.stopAutoStepping();
    fprintf('Rapid stop successful\n');
catch ME
    fprintf('ERROR: Rapid start/stop failed: %s\n', ME.message);
end

fprintf('\n=== Debug Test Complete ===\n');
fprintf('Check the console output above for any error messages or unexpected behavior.\n'); 