%==============================================================================
% BUILD_MJC3_MEX.M
%==============================================================================
% Build script for the MJC3 MEX function.
%
% This script compiles the mjc3_joystick_mex.cpp file with the hidapi library
% to create a high-performance MEX function for MJC3 joystick communication.
% The resulting MEX function provides direct hardware access to the MJC3 device
% for real-time joystick polling.
%
% Prerequisites:
%   1. MATLAB C++ compiler configured (run: mex -setup)
%   2. hidapi library installed and accessible
%   3. Visual Studio or compatible compiler (Windows)
%   4. GCC or Clang (Linux/Mac)
%
% Key Features:
%   - Automatic hidapi library detection
%   - Cross-platform build support (Windows/Linux/Mac)
%   - Multiple library name attempts for compatibility
%   - Build verification and testing
%   - Comprehensive error reporting and troubleshooting
%
% Dependencies:
%   - mjc3_joystick_mex.cpp: Source file to compile
%   - hidapi library: USB HID communication library
%   - MATLAB MEX compiler: C++ compilation tools
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   build_mjc3_mex();  % Build the MEX function
%
%==============================================================================

function build_mjc3_mex()
    % build_mjc3_mex - Build the MJC3 MEX function
    % 
    % This script compiles the mjc3_joystick_mex.cpp file with hidapi library
    % 
    % Prerequisites:
    %   1. MATLAB C++ compiler configured (run: mex -setup)
    %   2. hidapi library installed and accessible
    %   3. Visual Studio or compatible compiler
    
    % Initialize logger
    logger = LoggingService('MJC3Builder');
    
    logger.info('Building MJC3 MEX function...');
    
    % Check if MEX compiler is configured
    try
        cc = mex.getCompilerConfigurations('C++', 'Selected');
        if isempty(cc)
            error('No C++ compiler configured');
        end
        logger.info('Using C++ compiler: %s', cc.Name);
        logger.debug('Compiler details: %s', jsonencode(cc));
    catch ME
        logger.error('C++ compiler not configured: %s', ME.message);
        logger.info('Please run: mex -setup');
        error('MEX compiler not available');
    end
    
    % Define paths (adjust these for your system)
    hidapi_include = 'C:\hidapi\include';  % Adjust path
    hidapi_lib = 'C:\hidapi\lib';          % Adjust path
    
    % Check for common hidapi locations
    possible_paths = {
        'C:\vcpkg\installed\x64-windows',
        'C:\vcpkg\installed\x86-windows', 
        'C:\hidapi',
        'C:\Program Files\hidapi',
        'C:\Program Files (x86)\hidapi',
        fullfile(pwd, 'external', 'hidapi'),
        fullfile(pwd, '..', 'external', 'hidapi')
    };
    
    hidapi_found = false;
    logger.debug('Searching for hidapi library in common locations...');
    
    for i = 1:length(possible_paths)
        include_path = fullfile(possible_paths{i}, 'include');
        lib_path = fullfile(possible_paths{i}, 'lib');
        
        if exist(include_path, 'dir') && exist(lib_path, 'dir')
            hidapi_include = include_path;
            hidapi_lib = lib_path;
            hidapi_found = true;
            logger.info('Found hidapi at: %s', possible_paths{i});
            logger.debug('hidapi include path: %s', include_path);
            logger.debug('hidapi lib path: %s', lib_path);
            break;
        end
    end
    
    if ~hidapi_found
        logger.warning('hidapi not found in common locations');
        logger.info('Installing hidapi via vcpkg (recommended):');
        logger.info('  1. Install vcpkg: https://github.com/Microsoft/vcpkg');
        logger.info('  2. Run: vcpkg install hidapi:x64-windows');
        logger.info('  3. Re-run this build script');
        logger.info('Alternative: Download from https://github.com/libusb/hidapi');
        
        % Try to continue with default paths
        logger.info('Attempting build with default paths...');
    end
    
    % Source file
    source_file = 'mjc3_joystick_mex.cpp';
    if ~exist(source_file, 'file')
        logger.error('Source file %s not found in current directory', source_file);
        error('Source file %s not found in current directory', source_file);
    end
    
    logger.debug('Source file found: %s', source_file);
    
    % Build command
    try
        if ispc
            % Windows build
            logger.info('Building for Windows...');
            
            % Try different library names
            lib_names = {'hidapi', 'hidapi_ms', 'hid'};
            build_success = false;
            
            for i = 1:length(lib_names)
                try
                    logger.debug('Trying library: %s', lib_names{i});
                    
                    mex_cmd = sprintf('mex -I"%s" -L"%s" -l%s "%s"', ...
                        hidapi_include, hidapi_lib, lib_names{i}, source_file);
                    
                    logger.debug('MEX command: %s', mex_cmd);
                    eval(mex_cmd);
                    
                    build_success = true;
                    logger.info('✓ Build successful with library: %s', lib_names{i});
                    break;
                    
                catch ME
                    logger.debug('✗ Build failed with %s: %s', lib_names{i}, ME.message);
                end
            end
            
            if ~build_success
                logger.error('All build attempts failed');
                error('All build attempts failed');
            end
            
        else
            % Linux/Mac build
            logger.info('Building for Unix/Linux/Mac...');
            mex_cmd = sprintf('mex -I"%s" -L"%s" -lhidapi "%s"', ...
                hidapi_include, hidapi_lib, source_file);
            
            logger.debug('MEX command: %s', mex_cmd);
            eval(mex_cmd);
        end
        
        logger.info('✓ MEX build completed successfully!');
        
        % Test the MEX function
        logger.info('Testing MEX function...');
        try
            result = mjc3_joystick_mex('test');
            if result
                logger.info('✓ MEX function test passed');
            else
                logger.error('✗ MEX function test failed');
            end
            
            % Try to get device info
            info = mjc3_joystick_mex('info');
            logger.debug('Device info: %s', jsonencode(info));
            
            if info.connected
                logger.info('✓ MJC3 device detected and connected');
            else
                logger.info('ℹ MEX function works, but MJC3 device not connected');
                logger.debug('This is normal if MJC3 hardware is not plugged in');
            end
            
        catch ME
            logger.error('✗ MEX function test error: %s', ME.message);
            logger.debug('Test error details: %s', ME.getReport());
        end
        
    catch ME
        logger.error('✗ Build failed: %s', ME.message);
        logger.debug('Build error details: %s', ME.getReport());
        logger.info('Troubleshooting:');
        logger.info('1. Ensure hidapi is installed');
        logger.info('2. Update paths in this script');
        logger.info('3. Check C++ compiler configuration: mex -setup');
        logger.info('4. On Windows, ensure Visual Studio is installed');
        rethrow(ME);
    end
    
    logger.info('Build complete! You can now use MJC3_MEX_Controller.');
end

% Helper function to detect hidapi installation
function path = detect_hidapi()
    path = '';
    
    % Check vcpkg installation
    if ispc
        vcpkg_paths = {
            'C:\vcpkg\installed\x64-windows',
            'C:\tools\vcpkg\installed\x64-windows'
        };
        
        for i = 1:length(vcpkg_paths)
            if exist(fullfile(vcpkg_paths{i}, 'include', 'hidapi'), 'dir')
                path = vcpkg_paths{i};
                return;
            end
        end
    end
    
    % Check system paths
    if isunix
        if exist('/usr/include/hidapi', 'dir')
            path = '/usr';
        elseif exist('/usr/local/include/hidapi', 'dir')
            path = '/usr/local';
        end
    end
end