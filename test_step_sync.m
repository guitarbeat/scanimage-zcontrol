% Test script for step size sync functionality
% This script tests the two-way sync between manual and auto step controls

fprintf('Testing step size sync functionality...\n');

% Add src to path
addpath('src');

try
    % Create the app
    app = foilview();
    
    % Wait for app to initialize
    pause(1);
    
    fprintf('Initial state:\n');
    fprintf('  Manual step size: %.1f μm\n', app.ManualControls.StepSizeField.Value);
    fprintf('  Auto step size: %.1f μm\n', app.AutoControls.StepField.Value);
    fprintf('  Auto direction: %s\n', app.Controller.AutoDirection > 0 ? 'UP' : 'DOWN');
    
    % Test the new editable manual step size field
    fprintf('\n=== Testing editable manual step size field ===\n');
    originalManual = app.ManualControls.StepSizeField.Value;
    originalAuto = app.AutoControls.StepField.Value;
    
    fprintf('Before change:\n');
    fprintf('  Manual: %.1f μm\n', originalManual);
    fprintf('  Auto: %.1f μm\n', originalAuto);
    
    % Set manual field to 12
    fprintf('\nSetting manual field to 12...\n');
    app.ManualControls.StepSizeField.Value = 12;
    pause(0.5);
    
    fprintf('After setting manual field to 12:\n');
    fprintf('  Manual: %.1f μm\n', app.ManualControls.StepSizeField.Value);
    fprintf('  Auto: %.1f μm\n', app.AutoControls.StepField.Value);
    
    % Check if sync works correctly
    if app.AutoControls.StepField.Value == 12
        fprintf('✓ Manual to Auto sync working correctly!\n');
    else
        fprintf('✗ Manual to Auto sync not working\n');
    end
    
    % Test auto field change to custom value
    fprintf('\n=== Testing auto field change to 7.3 ===\n');
    originalManual = app.ManualControls.StepSizeField.Value;
    originalAuto = app.AutoControls.StepField.Value;
    
    % Set auto field to 7.3
    app.AutoControls.StepField.Value = 7.3;
    pause(0.5);
    
    fprintf('After setting auto field to 7.3:\n');
    fprintf('  Manual: %.1f μm\n', app.ManualControls.StepSizeField.Value);
    fprintf('  Auto: %.1f μm\n', app.AutoControls.StepField.Value);
    
    % Check if sync works correctly
    if app.ManualControls.StepSizeField.Value == 7.3
        fprintf('✓ Auto to Manual sync working correctly!\n');
    else
        fprintf('✗ Auto to Manual sync not working\n');
    end
    
    % Test quick preset buttons
    fprintf('\n=== Testing quick preset buttons ===\n');
    
    % Test step down button (should set to 0.5)
    app.onStepDownButtonPushed();
    pause(0.5);
    fprintf('After step down button: %.1f μm\n', app.ManualControls.StepSizeField.Value);
    
    % Test step up button (should set to 5.0)
    app.onStepUpButtonPushed();
    pause(0.5);
    fprintf('After step up button: %.1f μm\n', app.ManualControls.StepSizeField.Value);
    
    % Test direction toggle functionality
    fprintf('\n=== Testing direction toggle ===\n');
    originalDirection = app.Controller.AutoDirection;
    fprintf('Initial direction: %s\n', originalDirection > 0 ? 'UP' : 'DOWN');
    
    % Toggle direction
    app.onAutoDirectionToggled();
    pause(0.5);
    
    newDirection = app.Controller.AutoDirection;
    fprintf('After toggle: %s\n', newDirection > 0 ? 'UP' : 'DOWN');
    
    if newDirection == -originalDirection
        fprintf('✓ Direction toggle working correctly!\n');
    else
        fprintf('✗ Direction toggle not working correctly!\n');
    end
    
    fprintf('\nAll tests completed!\n');
    
    % Clean up
    delete(app);
    
catch ME
    fprintf('Error during test: %s\n', ME.message);
    if exist('app', 'var') && isvalid(app)
        delete(app);
    end
end 