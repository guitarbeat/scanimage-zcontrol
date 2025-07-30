function migrate_to_new_organization()
    % migrate_to_new_organization - Migration script for MJC3 controller organization
    % This script helps users transition from the old controller structure to the new one
    
    fprintf('MJC3 Controller Migration Script\n');
    fprintf('================================\n\n');
    
    % Check if we're in the right directory
    if ~exist('BaseMJC3Controller.m', 'file')
        error('This script must be run from the mjc3/ directory');
    end
    
    fprintf('New MJC3 Controller Organization:\n');
    fprintf('1. BaseMJC3Controller - Abstract base class\n');
    fprintf('2. MJC3ControllerFactory - Automatic controller selection\n');
    fprintf('3. Standardized controllers with common interface\n');
    fprintf('4. Automatic fallback system\n\n');
    
    % Test factory functionality
    fprintf('Testing Factory Functionality:\n');
    fprintf('-----------------------------\n');
    
    try
        % List available types
        fprintf('Available controller types:\n');
        MJC3ControllerFactory.listAvailableTypes();
        
        % Test if we can create a simulation controller (always works)
        fprintf('\nTesting simulation controller creation...\n');
        
        % Create a mock Z-controller for testing
        mockZController = struct();
        mockZController.relativeMove = @(dz) fprintf('Mock Z move: %.1f μm\n', dz);
        
        controller = MJC3ControllerFactory.createController(mockZController, 5, 'Simulation');
        fprintf('✓ Simulation controller created successfully\n');
        
        % Test basic functionality
        if controller.connectToMJC3()
            fprintf('✓ Controller connection test passed\n');
        end
        
        % Test manual movement
        controller.moveUp(1);
        controller.moveDown(1);
        
        % Clean up
        delete(controller);
        fprintf('✓ Controller cleanup successful\n\n');
        
    catch ME
        fprintf('✗ Factory test failed: %s\n', ME.message);
        return;
    end
    
    % Show migration examples
    fprintf('Migration Examples:\n');
    fprintf('==================\n\n');
    
    fprintf('OLD CODE:\n');
    fprintf('--------\n');
    fprintf('%% Create with StageControlService\n');
    fprintf('stageService = StageControlService(scanImageManager);\n');
    fprintf('controller = MJC3_HID_Controller(stageService, stepFactor);\n');
    fprintf('controller.start();\n\n');
    
    fprintf('NEW CODE:\n');
    fprintf('--------\n');
    fprintf('%% Create with Z-controller\n');
    fprintf('zController = ScanImageZController(hSI.hMotors);\n');
    fprintf('controller = MJC3_HID_Controller(zController, stepFactor);\n');
    fprintf('controller.start();\n\n');
    
    fprintf('OR USE FACTORY (RECOMMENDED):\n');
    fprintf('-----------------------------\n');
    fprintf('zController = ScanImageZController(hSI.hMotors);\n');
    fprintf('controller = MJC3ControllerFactory.createController(zController);\n');
    fprintf('controller.start();\n\n');
    
    % Show benefits
    fprintf('Benefits of New Organization:\n');
    fprintf('============================\n');
    fprintf('✓ Standardized interface across all controllers\n');
    fprintf('✓ Automatic fallback to best available controller\n');
    fprintf('✓ Better error handling and diagnostics\n');
    fprintf('✓ Easier testing and debugging\n');
    fprintf('✓ Cleaner, more maintainable code\n');
    fprintf('✓ Future extensibility\n\n');
    
    % Check for old files
    fprintf('Checking for Old Controller Files:\n');
    fprintf('================================\n');
    
    oldFiles = {'../MJC3_HID_Controller.m', '../MJC3_Keyboard_Controller.m', ...
                '../MJC3_Native_Controller.m', '../MJC3_Windows_HID_Controller.m', ...
                '../MJC3_Simulation_Controller.m'};
    
    for i = 1:length(oldFiles)
        if exist(oldFiles{i}, 'file')
            fprintf('⚠ Found old file: %s\n', oldFiles{i});
            fprintf('  Consider removing after migration is complete\n');
        else
            fprintf('✓ No old file: %s\n', oldFiles{i});
        end
    end
    
    fprintf('\nMigration Complete!\n');
    fprintf('==================\n');
    fprintf('The new MJC3 controller organization is ready to use.\n');
    fprintf('See README.md for detailed documentation.\n\n');
    
    fprintf('Next Steps:\n');
    fprintf('1. Update your code to use the new factory pattern\n');
    fprintf('2. Test with your specific hardware setup\n');
    fprintf('3. Remove old controller files when no longer needed\n');
    fprintf('4. Report any issues or improvements needed\n\n');
end 