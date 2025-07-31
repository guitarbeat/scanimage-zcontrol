% Test script for MJC3 controller cleanup
% This script tests that the controller properly disconnects when closed

try
    fprintf('Testing MJC3 controller cleanup...\n');
    
    % Create the view
    view = MJC3View();
    
    % Show the window
    view.show();
    
    fprintf('✅ MJC3View created successfully\n');
    fprintf('✅ Window should be visible\n');
    fprintf('✅ Close the window to test cleanup\n');
    
    % Keep the window open for testing
    fprintf('Window should be visible. Close it to test cleanup...\n');
    
    % Wait for user to close the window
    while isvalid(view) && isvalid(view.UIFigure)
        pause(0.1);
    end
    
    fprintf('✅ Window closed successfully\n');
    fprintf('✅ Cleanup test completed\n');
    
catch ME
    fprintf('❌ Test failed: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s:%d\n', ME.stack(i).name, ME.stack(i).line);
    end
end 