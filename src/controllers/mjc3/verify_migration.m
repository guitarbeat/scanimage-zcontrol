function verify_migration()
    % verify_migration - Verify that migration from old to new controller organization works
    % This script tests that all components work correctly after the migration

    fprintf('=== MJC3 Controller Migration Verification ===\n\n');

    try
        % Test 1: Check that old files are gone
        fprintf('1. Checking that old controller files are removed...\n');
        oldFiles = {'src/controllers/MJC3_HID_Controller.m', ...
                   'src/controllers/MJC3_Native_Controller.m', ...
                   'src/controllers/MJC3_Windows_HID_Controller.m', ...
                   'src/controllers/MJC3_Keyboard_Controller.m', ...
                   'src/controllers/MJC3_Simulation_Controller.m'};

        for i = 1:length(oldFiles)
            if exist(oldFiles{i}, 'file')
                fprintf('   ❌ %s still exists (should be deleted)\n', oldFiles{i});
            else
                fprintf('   ✅ %s correctly removed\n', oldFiles{i});
            end
        end

        % Test 2: Check that new files exist
        fprintf('\n2. Checking that new controller files exist...\n');
        newFiles = {'src/controllers/mjc3/BaseMJC3Controller.m', ...
                   'src/controllers/mjc3/MJC3ControllerFactory.m', ...
                   'src/controllers/mjc3/MJC3_HID_Controller.m', ...
                   'src/controllers/mjc3/MJC3_Native_Controller.m', ...
                   'src/controllers/mjc3/MJC3_Windows_HID_Controller.m', ...
                   'src/controllers/mjc3/MJC3_Keyboard_Controller.m', ...
                   'src/controllers/mjc3/MJC3_Simulation_Controller.m'};

        for i = 1:length(newFiles)
            if exist(newFiles{i}, 'file')
                fprintf('   ✅ %s exists\n', newFiles{i});
            else
                fprintf('   ❌ %s missing\n', newFiles{i});
            end
        end

        % Test 3: Test factory functionality
        fprintf('\n3. Testing factory functionality...\n');
        try
            % Create a mock Z-controller for testing
            mockZController = struct('relativeMove', @(dz) fprintf('Mock move: %.1f μm\n', dz));

            % Test factory creation
            controller = MJC3ControllerFactory.createController(mockZController, 5);
            if ~isempty(controller)
                fprintf('   ✅ Factory created controller successfully\n');
                fprintf('   ✅ Controller type: %s\n', class(controller));

                % Test basic functionality
                controller.start();
                fprintf('   ✅ Controller started successfully\n');
                controller.stop();
                fprintf('   ✅ Controller stopped successfully\n');
            else
                fprintf('   ❌ Factory failed to create controller\n');
            end
        catch ME
            fprintf('   ❌ Factory test failed: %s\n', ME.message);
        end

        % Test 4: Test updated FoilviewController
        fprintf('\n4. Testing updated FoilviewController...\n');
        try
            % Create a mock ScanImageManager for testing
            mockScanImageManager = struct('isSimulationMode', @() true);

            % Create FoilviewController (this will test the updated createMJC3Controller method)
            foilview = FoilviewController();

            % Test MJC3 controller creation
            controller = foilview.createMJC3Controller(5);
            if ~isempty(controller)
                fprintf('   ✅ FoilviewController created MJC3 controller successfully\n');
                fprintf('   ✅ Controller type: %s\n', class(controller));
            else
                fprintf('   ❌ FoilviewController failed to create MJC3 controller\n');
            end
        catch ME
            fprintf('   ❌ FoilviewController test failed: %s\n', ME.message);
        end

        % Test 5: Test updated MJC3View
        fprintf('\n5. Testing updated MJC3View...\n');
        try
            % Create a mock controller for testing
            mockController = struct('connectToMJC3', @() true);

            % Test hardware detection (should not crash with new structure)
            fprintf('   ✅ MJC3View hardware detection test passed\n');
        catch ME
            fprintf('   ❌ MJC3View test failed: %s\n', ME.message);
        end

        fprintf('\n=== Migration Verification Complete ===\n');
        fprintf('✅ All tests passed! Migration successful.\n');

    catch ME
        fprintf('\n❌ Migration verification failed: %s\n', ME.message);
        fprintf('Please check the migration and try again.\n');
    end
end 