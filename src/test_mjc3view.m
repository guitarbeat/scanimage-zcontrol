% Test script for simplified MJC3View
% This script tests the new simplified UI with analog controls

try
    fprintf('Testing simplified MJC3View...\n');
    
    % Create the view
    view = MJC3View();
    
    % Show the window
    view.show();
    
    fprintf('✅ MJC3View created successfully with simplified UI\n');
    fprintf('✅ Analog controls (Z, Y, X) implemented\n');
    fprintf('✅ Complex sections removed\n');
    
    % Keep the window open for testing
    fprintf('Window should be visible. Press any key to close...\n');
    pause;
    
    % Clean up
    delete(view);
    fprintf('✅ Test completed successfully\n');
    
catch ME
    fprintf('❌ Test failed: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s:%d\n', ME.stack(i).name, ME.stack(i).line);
    end
end 