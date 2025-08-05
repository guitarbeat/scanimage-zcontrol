%==============================================================================
% INSTALL_MJC3.M
%==============================================================================
% Complete installation script for MJC3 MEX controller system.
%
% This script provides a comprehensive installation process for the high-performance
% MJC3 joystick controller, including compiler setup, library installation,
% MEX function building, and system testing. It automates the entire setup
% process to ensure the MJC3 controller is ready for use.
%
% Installation Steps:
%   1. Check MATLAB C++ compiler configuration
%   2. Verify hidapi library availability
%   3. Build MEX function with hidapi
%   4. Test installation and functionality
%   5. Clean up deprecated files
%   6. Display usage instructions
%
% Key Features:
%   - Automated dependency checking
%   - Cross-platform support (Windows/Linux/Mac)
%   - Comprehensive error reporting
%   - Installation verification
%   - User-friendly progress reporting
%
% Prerequisites:
%   - MATLAB with C++ compiler support
%   - hidapi library (installed via vcpkg or system package manager)
%   - Visual Studio (Windows) or GCC/Clang (Linux/Mac)
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   install_mjc3();  % Run complete installation
%
%==============================================================================

function install_mjc3()
    % install_mjc3 - Complete installation script for MJC3 MEX controller
    % 
    % This script handles the complete setup process for the high-performance
    % MJC3 joystick controller system.
    
    % Initialize logger
    logger = LoggingService('MJC3Installer');
    
    logger.info('=== MJC3 MEX Controller Installation ===');
    
    % Step 1: Check MATLAB compiler
    logger.info('Step 1: Checking MATLAB C++ compiler...');
    if ~check_compiler(logger)
        logger.error('Installation failed: C++ compiler not configured');
        return;
    end
    logger.info('✅ C++ compiler ready');
    
    % Step 2: Check/install hidapi
    logger.info('Step 2: Checking hidapi library...');
    if ~check_hidapi(logger)
        logger.error('Installation failed: hidapi not found');
        show_hidapi_install_instructions(logger);
        return;
    end
    logger.info('✅ hidapi library found');
    
    % Step 3: Build MEX function
    logger.info('Step 3: Building MEX function...');
    try
        % Change to the mjc3 directory for building
        currentDir = pwd;
        cd(fileparts(mfilename('fullpath')));
        build_mjc3_mex();
        cd(currentDir);
        logger.info('✅ MEX function built successfully');
    catch ME
        logger.error('MEX build failed: %s', ME.message);
        logger.debug('Build error details: %s', ME.getReport());
        return;
    end
    
    % Step 4: Test installation
    logger.info('Step 4: Testing installation...');
    if test_installation(logger)
        logger.info('✅ Installation test passed');
    else
        logger.warning('⚠️ Installation completed but tests failed');
        logger.info('This may be normal if MJC3 hardware is not connected');
    end
    
    % Step 5: Clean up deprecated files
    logger.info('Step 5: Cleaning up deprecated files...');
    cleanup_deprecated_files(logger);
    logger.info('✅ Cleanup completed');
    
    % Step 6: Show usage instructions
    show_usage_instructions(logger);
    
    logger.info('🎉 MJC3 MEX Controller installation complete!');
    logger.info('You can now use the high-performance MEX controller.');
end

function success = check_compiler(logger)
    % Check if MATLAB C++ compiler is configured
    try
        cc = mex.getCompilerConfigurations('C++', 'Selected');
        success = ~isempty(cc);
        if success
            logger.info('Using C++ compiler: %s', cc.Name);
            logger.debug('Compiler details: %s', jsonencode(cc));
        end
    catch ME
        success = false;
        logger.error('Compiler check failed: %s', ME.message);
    end
    
    if ~success
        logger.warning('C++ compiler not configured');
        logger.info('Please run: mex -setup');
        logger.info('On Windows: Install Visual Studio Community (free)');
        logger.info('On Linux: Install gcc/g++');
        logger.info('On macOS: Install Xcode Command Line Tools');
    end
end

function success = check_hidapi(logger)
    % Check if hidapi is available
    success = false;
    
    logger.debug('Searching for hidapi library...');
    
    % Check vcpkg installation (Windows)
    if ispc
        vcpkg_paths = {
            'C:\vcpkg\installed\x64-windows',
            'C:\vcpkg\installed\x86-windows'
        };
        
        for i = 1:length(vcpkg_paths)
            include_path = fullfile(vcpkg_paths{i}, 'include');
            if exist(include_path, 'dir') && exist(fullfile(include_path, 'hidapi'), 'dir')
                logger.info('Found hidapi via vcpkg: %s', vcpkg_paths{i});
                logger.debug('hidapi include path: %s', include_path);
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
                logger.info('Found hidapi at: %s', system_paths{i});
                logger.debug('hidapi system path: %s', system_paths{i});
                success = true;
                return;
            end
        end
    end
    
    % Check local installation
    local_paths = {'external/hidapi', '../external/hidapi', 'C:/hidapi'};
    for i = 1:length(local_paths)
        if exist(fullfile(local_paths{i}, 'include'), 'dir')
            logger.info('Found hidapi at: %s', local_paths{i});
            logger.debug('hidapi local path: %s', local_paths{i});
            success = true;
            return;
        end
    end
    
    if ~success
        logger.warning('hidapi library not found in any standard location');
    end
end

function show_hidapi_install_instructions(logger)
    logger.info('To install hidapi:');
    
    if ispc
        logger.info('Windows (Recommended - vcpkg):');
        logger.info('  1. Install vcpkg:');
        logger.info('     git clone https://github.com/Microsoft/vcpkg.git');
        logger.info('     cd vcpkg && .\\bootstrap-vcpkg.bat');
        logger.info('  2. Install hidapi:');
        logger.info('     .\\vcpkg install hidapi:x64-windows');
        
        logger.info('Windows (Alternative - Manual):');
        logger.info('  1. Download from: https://github.com/libusb/hidapi/releases');
        logger.info('  2. Extract to C:\\hidapi\\');
        logger.info('  3. Ensure include/ and lib/ directories exist');
        
    elseif ismac
        logger.info('macOS:');
        logger.info('  brew install hidapi');
        logger.info('  # or');
        logger.info('  sudo port install hidapi');
        
    else % Linux
        logger.info('Linux (Ubuntu/Debian):');
        logger.info('  sudo apt-get install libhidapi-dev');
        
        logger.info('Linux (CentOS/RHEL):');
        logger.info('  sudo yum install hidapi-devel');
    end
    
    logger.info('After installing hidapi, re-run this installation script.');
end

function success = test_installation(logger)
    % Test the installed MEX function
    success = false;
    
    try
        logger.debug('Testing MEX function installation...');
        
        % Test MEX function exists and works
        if exist('mjc3_joystick_mex', 'file') ~= 3
            logger.error('MEX file not found');
            return;
        end
        
        logger.debug('MEX file found, testing basic functionality...');
        
        % Test basic functionality
        result = mjc3_joystick_mex('test');
        if ~result
            logger.error('MEX function test failed');
            return;
        end
        
        logger.debug('MEX function test passed, checking device connection...');
        
        % Test device info (may fail if no hardware)
        info = mjc3_joystick_mex('info');
        logger.debug('Device info: %s', jsonencode(info));
        
        if info.connected
            logger.info('✅ MJC3 device connected and ready');
        else
            logger.info('ℹ️ MEX function works (MJC3 hardware not connected)');
        end
        
        logger.debug('Testing controller creation...');
        
        % Test controller creation
        mockZController = MockZController();
        controller = MJC3_MEX_Controller(mockZController, 5);
        delete(controller);
        
        logger.debug('Controller creation test passed');
        success = true;
        
    catch ME
        logger.error('Test error: %s', ME.message);
        logger.debug('Test error details: %s', ME.getReport());
    end
end

function cleanup_deprecated_files(logger)
    % Remove old controller files that are no longer needed
    deprecated_files = {
        'controllers/mjc3/MJC3_HID_Controller.m',
        'controllers/mjc3/MJC3_Native_Controller.m', 
        'controllers/mjc3/MJC3_Windows_HID_Controller.m',
        'controllers/mjc3/MJC3_Keyboard_Controller.m',
        'controllers/WindowsJoystickReader.m'
    };
    
    logger.debug('Checking for deprecated files...');
    
    for i = 1:length(deprecated_files)
        if exist(deprecated_files{i}, 'file')
            try
                delete(deprecated_files{i});
                logger.info('Removed deprecated file: %s', deprecated_files{i});
            catch ME
                logger.warning('Could not remove deprecated file %s: %s', deprecated_files{i}, ME.message);
            end
        end
    end
end

function show_usage_instructions(logger)
    logger.info('Usage Instructions:');
    logger.info('==================');
    
    logger.info('1. Basic Usage:');
    logger.info('   zController = ScanImageZController(hSI.hMotors);');
    logger.info('   controller = MJC3ControllerFactory.createController(zController);');
    logger.info('   controller.start();');
    
    logger.info('2. With UI Integration:');
    logger.info('   hidController = HIDController(uiComponents, zController);');
    logger.info('   hidController.enable();');
    
    logger.info('3. Check Available Controllers:');
    logger.info('   MJC3ControllerFactory.listAvailableTypes();');
    
    logger.info('4. Test Hardware Connection:');
    logger.info('   data = mjc3_joystick_mex(''read'', 100);');
    logger.info('   info = mjc3_joystick_mex(''info'');');
    
    logger.info('5. Calibration:');
    logger.info('   controller.calibrateAxis(''Z'', 100);');
    logger.info('   status = controller.getCalibrationStatus();');
end

