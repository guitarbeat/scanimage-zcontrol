% Test script to verify the initialization fix
fprintf('Testing initialization fix...\n');

% Add src to path
addpath('src');

try
    % Test that the app can be created without errors
    fprintf('Creating foilview app...\n');
    app = foilview();
    
    % Wait a moment for initialization
    pause(1);
    
    % Check that the manual controls are properly initialized
    fprintf('Checking manual controls initialization...\n');
    
    if isfield(app.ManualControls, 'StepSizes') && ~isempty(app.ManualControls.StepSizes)
        fprintf('✓ StepSizes initialized correctly\n');
    else
        fprintf('✗ StepSizes not initialized\n');
    end
    
    if isfield(app.ManualControls, 'CurrentStepIndex') && ~isempty(app.ManualControls.CurrentStepIndex)
        fprintf('✓ CurrentStepIndex initialized correctly\n');
    else
        fprintf('✗ CurrentStepIndex not initialized\n');
    end
    
    if isfield(app.ManualControls, 'StepSizeDisplay') && ~isempty(app.ManualControls.StepSizeDisplay.Text)
        fprintf('✓ StepSizeDisplay initialized correctly: %s\n', app.ManualControls.StepSizeDisplay.Text);
    else
        fprintf('✗ StepSizeDisplay not initialized\n');
    end
    
    % Check that auto controls are properly initialized
    fprintf('Checking auto controls initialization...\n');
    
    if isfield(app.AutoControls, 'StepField') && ~isempty(app.AutoControls.StepField.Value)
        fprintf('✓ Auto StepField initialized correctly: %.1f μm\n', app.AutoControls.StepField.Value);
    else
        fprintf('✗ Auto StepField not initialized\n');
    end
    
    if isfield(app.AutoControls, 'DirectionButton') && strcmp(app.AutoControls.DirectionButton.Visible, 'on')
        fprintf('✓ Direction button is visible\n');
    else
        fprintf('✗ Direction button not visible\n');
    end
    
    fprintf('\nInitialization test completed successfully!\n');
    
    % Clean up
    delete(app);
    
catch ME
    fprintf('Error during initialization test: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    if exist('app', 'var') && isvalid(app)
        delete(app);
    end
end 