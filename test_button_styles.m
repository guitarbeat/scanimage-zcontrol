% Test script to verify button style fix
% This script tests the UiComponents.applyButtonStyle method with various style names

% Add src to path
addpath('src');

% Create a test figure and button
fig = figure('Visible', 'off');
button = uibutton(fig, 'Text', 'Test Button');

% Test different style names (both lowercase and mixed case)
testStyles = {'primary', 'success', 'warning', 'info', 'muted', 'danger'};

fprintf('Testing button styles...\n');

for i = 1:length(testStyles)
    style = testStyles{i};
    fprintf('Testing style: %s\n', style);
    
    try
        UiComponents.applyButtonStyle(button, style);
        fprintf('  ✅ Success: %s\n', style);
    catch ME
        fprintf('  ❌ Error: %s - %s\n', style, ME.message);
    end
end

% Clean up
delete(fig);
fprintf('\nButton style test completed!\n'); 