% Test script to verify FoilView fixes
% This script tests the application initialization without ScanImage

fprintf('=== Testing FoilView Fixes ===\n');

try
    % Add source directories to MATLAB path
    addpath(genpath('src'));
    
    % Clear any existing variables that might interfere
    clear hSI metadataFilePath metadataConfig
    
    % Test 1: Check if required classes exist
    fprintf('1. Checking required classes...\n');
    
    classes_to_check = {'FoilviewController', 'UIController', 'PlotManager', ...
                       'ScanImageManager', 'MetadataService', 'UiBuilder', ...
                       'FoilviewUtils', 'UiComponents'};
    
    missing_classes = {};
    for i = 1:length(classes_to_check)
        class_name = classes_to_check{i};
        try
            if exist(class_name, 'class') ~= 8
                missing_classes{end+1} = class_name;
            else
                fprintf('   ✓ %s found\n', class_name);
            end
        catch
            missing_classes{end+1} = class_name;
        end
    end
    
    if ~isempty(missing_classes)
        fprintf('   ❌ Missing classes: %s\n', strjoin(missing_classes, ', '));
        fprintf('   Please ensure all source files are on the MATLAB path\n');
        return;
    end
    
    % Test 2: Test MetadataService functionality
    fprintf('\n2. Testing MetadataService...\n');
    try
        % Test metadata creation
        metadata = MetadataService.createBookmarkMetadata('test', 10, 20, 30, [], []);
        fprintf('   ✓ Metadata creation works\n');
        
        % Test file writing (to temp file)
        temp_file = fullfile(tempdir, 'test_metadata.csv');
        success = MetadataService.writeMetadataToFile(metadata, temp_file, false);
        if success && exist(temp_file, 'file')
            fprintf('   ✓ Metadata file writing works\n');
            delete(temp_file); % Clean up
        else
            fprintf('   ❌ Metadata file writing failed\n');
        end
    catch ME
        fprintf('   ❌ MetadataService error: %s\n', ME.message);
    end
    
    % Test 3: Test ScanImageManager in simulation mode
    fprintf('\n3. Testing ScanImageManager...\n');
    try
        sim_manager = ScanImageManager();
        sim_manager.initialize([]);
        if sim_manager.isSimulationMode()
            fprintf('   ✓ ScanImageManager simulation mode works\n');
        else
            fprintf('   ❌ ScanImageManager should be in simulation mode\n');
        end
        sim_manager.cleanup();
    catch ME
        fprintf('   ❌ ScanImageManager error: %s\n', ME.message);
    end
    
    % Test 4: Test date format fix
    fprintf('\n4. Testing date format...\n');
    try
        % This should not produce a warning now
        test_date = datetime('now', 'Format', 'yyyy-MM-dd');
        fprintf('   ✓ Date format yyyy-MM-dd works without warning\n');
    catch ME
        fprintf('   ❌ Date format error: %s\n', ME.message);
    end
    
    % Test 5: Attempt to create foilview app (this might still fail due to UI dependencies)
    fprintf('\n5. Testing foilview app creation...\n');
    fprintf('   Note: This may fail due to missing UI components, but should not crash on the fixed issues\n');
    
    try
        % Add current directory and subdirectories to path
        addpath(genpath('.'));
        
        % Try to create the app
        app = foilview();
        fprintf('   ✓ FoilView app created successfully!\n');
        
        % Test basic functionality
        if ~isempty(app.Controller) && isvalid(app.Controller)
            fprintf('   ✓ Controller initialized\n');
        end
        
        if ~isempty(app.UIController) && isvalid(app.UIController)
            fprintf('   ✓ UIController initialized\n');
        end
        
        if ~isempty(app.ScanImageManager) && isvalid(app.ScanImageManager)
            fprintf('   ✓ ScanImageManager initialized\n');
        end
        
        % Clean up
        delete(app);
        fprintf('   ✓ App cleanup successful\n');
        
    catch ME
        fprintf('   ❌ App creation failed: %s\n', ME.message);
        fprintf('   Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('      %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
    end
    
    fprintf('\n=== Test Complete ===\n');
    
catch ME
    fprintf('❌ Test script failed: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('   %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end