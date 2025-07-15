% Test script to debug auto-step direction issue
% This script will help identify where the direction problem occurs

fprintf('=== Auto-Step Direction Debug Test ===\n');

% Initialize the controller
controller = FoilviewController();

% Test 1: Check initial direction
fprintf('\nTest 1: Initial direction\n');
fprintf('Initial AutoDirection: %d\n', controller.AutoDirection);

% Test 2: Change direction to down
fprintf('\nTest 2: Change direction to down\n');
controller.AutoDirection = -1;
fprintf('AutoDirection after setting to -1: %d\n', controller.AutoDirection);

% Test 3: Change direction to up
fprintf('\nTest 3: Change direction to up\n');
controller.AutoDirection = 1;
fprintf('AutoDirection after setting to 1: %d\n', controller.AutoDirection);

% Test 4: Test manual movement with different directions
fprintf('\nTest 4: Manual movement test\n');
fprintf('Moving +5 μm (should use increment button)\n');
controller.moveStage(5);

fprintf('Moving -5 μm (should use decrement button)\n');
controller.moveStage(-5);

% Test 5: Test auto-step with different directions
fprintf('\nTest 5: Auto-step direction test\n');
fprintf('Starting auto-step with direction 1 (up)\n');
controller.startAutoStepping(1, 2, 1, 1, false);  % 2 steps, 1 second delay, up direction
pause(3);  % Wait for auto-step to complete

fprintf('Starting auto-step with direction -1 (down)\n');
controller.startAutoStepping(1, 2, 1, -1, false);  % 2 steps, 1 second delay, down direction
pause(3);  % Wait for auto-step to complete

fprintf('\n=== Debug Test Complete ===\n'); 