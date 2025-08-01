function install_mjc3()
    % install_mjc3 - Complete installation script for MJC3 MEX controller
    % 
    % This script handles the complete setup process for the high-performance
    % MJC3 joystick controller system.
    
    fprintf('=== MJC3 MEX Controller Installation ===\n\n');
    
    % Step 1: Check MATLAB compiler
    fprintf('Step 1: Checking MATLAB C++ compiler...\n');
    if ~check_compiler()
        fprintf('❌ Installation failed: C++ compiler not configured\n');
        return;
    end
    fprintf('✅ C++ compiler ready\n\n');
    
    % Step 2: Check/install hidapi
    fprintf('Step 2: Checking hidapi library...\n');
    if ~check_hidapi()
        fprintf('❌ Installation failed: hidapi not found\n');
        show_hidapi_install_instructions();
        return;
    end
    fprintf('✅ hidapi library found\n\n');
    
    % Step 3: Build MEX function
    fprintf('Step 3: Building MEX function...\n');
    try
        % Change to the mjc3 directory for building
        currentDir = pwd;
        cd(fileparts(mfilename('fullpath')));
        build_mjc3_mex();
        cd(currentDir);
        fprintf('✅ MEX function built successfully\n\n');
    catch ME
        fprintf('❌ MEX build failed: %s\n', ME.message);
        return;
    end
    
    % Step 4: Test installation
    fprintf('Step 4: Testing installation...\n');
    if test_installation()
        fprintf('✅ Installation test passed\n\n');
    else
        fprintf('⚠️  Installation completed but tests failed\n');
        fprintf('   This may be normal if MJC3 hardware is not connected\n\n');
    end
    
    % Step 5: Clean up deprecated files
    fprintf('Step 5: Cleaning up deprecated files...\n');
    cleanup_deprecated_files();
    fprintf('✅ Cleanup completed\n\n');
    
    % Step 6: Show usage instructions
    show_usage_instructions();
    
    fprintf('🎉 MJC3 MEX Controller installation complete!\n');
    fprintf('You can now use the high-performance MEX controller.\n\n');
end

function success = check_compiler()
    % Check if MATLAB C++ compiler is configured
    try
        cc = mex.getCompilerConfigurations('C++', 'Selected');
        success = ~isempty(cc);
        if success
            fprintf('   Using: %s\n', cc.Name);
        end
    catch
        success = false;
    end
    
    if ~success
        fprintf('   Please run: mex -setup\n');
        fprintf('   On Windows: Install Visual Studio Community (free)\n');
        fprintf('   On Linux: Install gcc/g++\n');
        fprintf('   On macOS: Install Xcode Command Line Tools\n');
    end
end

function success = check_hidapi()
    % Check if hidapi is available
    success = false;
    
    % Check vcpkg installation (Windows)
    if ispc
        vcpkg_paths = {
            'C:\vcpkg\installed\x64-windows',
            'C:\vcpkg\installed\x86-windows'
        };
        
        for i = 1:length(vcpkg_paths)
            include_path = fullfile(vcpkg_paths{i}, 'include');
            if exist(include_path, 'dir') && exist(fullfile(include_path, 'hidapi'), 'dir')
                fprintf('   Found hidapi via vcpkg: %s\n', vcpkg_paths{i});
                success = true;
                return;
            end
        end
    end
    
    % Check system installation (Linux/macOS)
    if isunix
        system_paths = {'/usr/include', '/usr/local/include', '/opt/homebrew/include'};
        for i = 1:length(system_paths)
            if exist(fullfile(system_paths{i}, 'hidapi'), 'dir')
                fprintf('   Found hidapi at: %s\n', system_paths{i});
                success = true;
                return;
            end
        end
    end
    
    % Check local installation
    local_paths = {'external/hidapi', '../external/hidapi', 'C:/hidapi'};
    for i = 1:length(local_paths)
        if exist(fullfile(local_paths{i}, 'include'), 'dir')
            fprintf('   Found hidapi at: %s\n', local_paths{i});
            success = true;
            return;
        end
    end
end

function show_hidapi_install_instructions()
    fprintf('\nTo install hidapi:\n\n');
    
    if ispc
        fprintf('Windows (Recommended - vcpkg):\n');
        fprintf('  1. Install vcpkg:\n');
        fprintf('     git clone https://github.com/Microsoft/vcpkg.git\n');
        fprintf('     cd vcpkg && .\\bootstrap-vcpkg.bat\n');
        fprintf('  2. Install hidapi:\n');
        fprintf('     .\\vcpkg install hidapi:x64-windows\n\n');
        
        fprintf('Windows (Alternative - Manual):\n');
        fprintf('  1. Download from: https://github.com/libusb/hidapi/releases\n');
        fprintf('  2. Extract to C:\\hidapi\\\n');
        fprintf('  3. Ensure include/ and lib/ directories exist\n\n');
        
    elseif ismac
        fprintf('macOS:\n');
        fprintf('  brew install hidapi\n');
        fprintf('  # or\n');
        fprintf('  sudo port install hidapi\n\n');
        
    else % Linux
        fprintf('Linux (Ubuntu/Debian):\n');
        fprintf('  sudo apt-get install libhidapi-dev\n\n');
        
        fprintf('Linux (CentOS/RHEL):\n');
        fprintf('  sudo yum install hidapi-devel\n\n');
    end
    
    fprintf('After installing hidapi, re-run this installation script.\n');
end

function success = test_installation()
    % Test the installed MEX function
    success = false;
    
    try
        % Test MEX function exists and works
        if exist('mjc3_joystick_mex', 'file') ~= 3
            fprintf('   MEX file not found\n');
            return;
        end
        
        % Test basic functionality
        result = mjc3_joystick_mex('test');
        if ~result
            fprintf('   MEX function test failed\n');
            return;
        end
        
        % Test device info (may fail if no hardware)
        info = mjc3_joystick_mex('info');
        if info.connected
            fprintf('   ✅ MJC3 device connected and ready\n');
        else
            fprintf('   ℹ️  MEX function works (MJC3 hardware not connected)\n');
        end
        
        % Test controller creation
        mockZController = MockZController();
        controller = MJC3_MEX_Controller(mockZController, 5);
        delete(controller);
        
        success = true;
        
    catch ME
        fprintf('   Test error: %s\n', ME.message);
    end
end

function cleanup_deprecated_files()
    % Remove old controller files that are no longer needed
    deprecated_files = {
        'controllers/mjc3/MJC3_HID_Controller.m',
        'controllers/mjc3/MJC3_Native_Controller.m', 
        'controllers/mjc3/MJC3_Windows_HID_Controller.m',
        'controllers/mjc3/MJC3_Keyboard_Controller.m',
        'controllers/WindowsJoystickReader.m'
    };
    
    for i = 1:length(deprecated_files)
        if exist(deprecated_files{i}, 'file')
            try
                delete(deprecated_files{i});
                fprintf('   Removed: %s\n', deprecated_files{i});
            catch
                fprintf('   Could not remove: %s\n', deprecated_files{i});
            end
        end
    end
end

function show_usage_instructions()
    fprintf('Usage Instructions:\n');
    fprintf('==================\n\n');
    
    fprintf('1. Basic Usage:\n');
    fprintf('   zController = ScanImageZController(hSI.hMotors);\n');
    fprintf('   controller = MJC3ControllerFactory.createController(zController);\n');
    fprintf('   controller.start();\n\n');
    
    fprintf('2. With UI Integration:\n');
    fprintf('   hidController = HIDController(uiComponents, zController);\n');
    fprintf('   hidController.enable();\n\n');
    
    fprintf('3. Check Available Controllers:\n');
    fprintf('   MJC3ControllerFactory.listAvailableTypes();\n\n');
    
    fprintf('4. Test Hardware Connection:\n');
    fprintf('   data = mjc3_joystick_mex(''read'', 100);\n');
    fprintf('   info = mjc3_joystick_mex(''info'');\n\n');
end

