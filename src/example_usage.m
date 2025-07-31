function example_usage()
    % example_usage - Simple example of using the MJC3 MEX controller
    
    fprintf('=== MJC3 MEX Controller Example ===\n\n');
    
    % Add required paths
    addpath('controllers/mjc3');
    addpath('controllers');
    addpath('views');
    
    % Test hardware connection
    fprintf('1. Testing hardware connection...\n');
    try
        info = mjc3_joystick_mex('info');
        if info.connected
            fprintf('✅ MJC3 joystick connected (VID:0x%04X, PID:0x%04X)\n', info.vendor_id, info.product_id);
        else
            fprintf('❌ MJC3 joystick not connected\n');
            return;
        end
    catch ME
        fprintf('❌ Error: %s\n', ME.message);
        fprintf('Run install_mjc3() to set up the MEX controller\n');
        return;
    end
    
    % Create Z-controller (replace with your actual implementation)
    fprintf('\n2. Creating Z-controller...\n');
    if exist('hSI', 'var') && ~isempty(hSI) && isfield(hSI, 'hMotors')
        % Use real ScanImage Z-controller
        zController = ScanImageZController(hSI.hMotors);
        fprintf('✅ Using ScanImage Z-controller\n');
    else
        % Use simulation for demo
        zController = SimulationZController();
        fprintf('ℹ️  Using simulation Z-controller (ScanImage not available)\n');
    end
    
    % Create MJC3 controller
    fprintf('\n3. Creating MJC3 controller...\n');
    try
        controller = MJC3ControllerFactory.createController(zController, 5); % 5 μm/unit
        fprintf('✅ Controller created: %s\n', class(controller));
    catch ME
        fprintf('❌ Controller creation failed: %s\n', ME.message);
        return;
    end
    
    % Start the controller
    fprintf('\n4. Starting joystick control...\n');
    try
        controller.start();
        fprintf('✅ MJC3 controller started - move your joystick!\n');
        fprintf('   Z-axis movement will be printed below:\n\n');
        
        % Run for 10 seconds
        for i = 1:10
            pause(1);
            fprintf('   Running... %d/10 seconds\n', i);
        end
        
    catch ME
        fprintf('❌ Error during operation: %s\n', ME.message);
    end
    
    % Stop the controller
    fprintf('\n5. Stopping controller...\n');
    try
        controller.stop();
        fprintf('✅ Controller stopped\n');
    catch ME
        fprintf('❌ Error stopping: %s\n', ME.message);
    end
    
    % Cleanup
    delete(controller);
    fprintf('\n✅ Example completed successfully!\n');
    
    % Show integration instructions
    fprintf('\n=== Integration Instructions ===\n');
    fprintf('To use in your application:\n\n');
    fprintf('1. Add paths:\n');
    fprintf('   addpath(''controllers/mjc3'');\n');
    fprintf('   addpath(''controllers'');\n');
    fprintf('   addpath(''views'');\n\n');
    fprintf('2. Create controller:\n');
    fprintf('   zController = ScanImageZController(hSI.hMotors);\n');
    fprintf('   controller = MJC3ControllerFactory.createController(zController);\n\n');
    fprintf('3. Start/stop:\n');
    fprintf('   controller.start();\n');
    fprintf('   %% ... your application runs ...\n');
    fprintf('   controller.stop();\n\n');
end

% Simple simulation Z-controller for demo purposes
classdef SimulationZController < handle
    methods
        function success = relativeMove(~, dz)
            fprintf('   → Z-axis move: %.2f μm\n', dz);
            success = true;
        end
    end
end