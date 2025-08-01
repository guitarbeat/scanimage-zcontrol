function build_mjc3_mex()
    % build_mjc3_mex - Build the MJC3 MEX function
    % 
    % This script compiles the mjc3_joystick_mex.cpp file with hidapi library
    % 
    % Prerequisites:
    %   1. MATLAB C++ compiler configured (run: mex -setup)
    %   2. hidapi library installed and accessible
    %   3. Visual Studio or compatible compiler
    
    fprintf('Building MJC3 MEX function...\n');
    
    % Check if MEX compiler is configured
    try
        cc = mex.getCompilerConfigurations('C++', 'Selected');
        if isempty(cc)
            error('No C++ compiler configured');
        end
        fprintf('Using C++ compiler: %s\n', cc.Name);
    catch ME
        fprintf('Error: C++ compiler not configured.\n');
        fprintf('Please run: mex -setup\n');
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
    for i = 1:length(possible_paths)
        include_path = fullfile(possible_paths{i}, 'include');
        lib_path = fullfile(possible_paths{i}, 'lib');
        
        if exist(include_path, 'dir') && exist(lib_path, 'dir')
            hidapi_include = include_path;
            hidapi_lib = lib_path;
            hidapi_found = true;
            fprintf('Found hidapi at: %s\n', possible_paths{i});
            break;
        end
    end
    
    if ~hidapi_found
        fprintf('Warning: hidapi not found in common locations.\n');
        fprintf('Installing hidapi via vcpkg (recommended):\n');
        fprintf('  1. Install vcpkg: https://github.com/Microsoft/vcpkg\n');
        fprintf('  2. Run: vcpkg install hidapi:x64-windows\n');
        fprintf('  3. Re-run this build script\n\n');
        fprintf('Alternative: Download from https://github.com/libusb/hidapi\n');
        
        % Try to continue with default paths
        fprintf('Attempting build with default paths...\n');
    end
    
    % Source file
    source_file = 'mjc3_joystick_mex.cpp';
    if ~exist(source_file, 'file')
        error('Source file %s not found in current directory', source_file);
    end
    
    % Build command
    try
        if ispc
            % Windows build
            fprintf('Building for Windows...\n');
            
            % Try different library names
            lib_names = {'hidapi', 'hidapi_ms', 'hid'};
            build_success = false;
            
            for i = 1:length(lib_names)
                try
                    fprintf('Trying library: %s\n', lib_names{i});
                    
                    mex_cmd = sprintf('mex -I"%s" -L"%s" -l%s "%s"', ...
                        hidapi_include, hidapi_lib, lib_names{i}, source_file);
                    
                    fprintf('MEX command: %s\n', mex_cmd);
                    eval(mex_cmd);
                    
                    build_success = true;
                    fprintf('✓ Build successful with library: %s\n', lib_names{i});
                    break;
                    
                catch ME
                    fprintf('✗ Build failed with %s: %s\n', lib_names{i}, ME.message);
                end
            end
            
            if ~build_success
                error('All build attempts failed');
            end
            
        else
            % Linux/Mac build
            fprintf('Building for Unix/Linux/Mac...\n');
            mex_cmd = sprintf('mex -I"%s" -L"%s" -lhidapi "%s"', ...
                hidapi_include, hidapi_lib, source_file);
            
            fprintf('MEX command: %s\n', mex_cmd);
            eval(mex_cmd);
        end
        
        fprintf('✓ MEX build completed successfully!\n');
        
        % Test the MEX function
        fprintf('Testing MEX function...\n');
        try
            result = mjc3_joystick_mex('test');
            if result
                fprintf('✓ MEX function test passed\n');
            else
                fprintf('✗ MEX function test failed\n');
            end
            
            % Try to get device info
            info = mjc3_joystick_mex('info');
            if info.connected
                fprintf('✓ MJC3 device detected and connected\n');
            else
                fprintf('ℹ MEX function works, but MJC3 device not connected\n');
            end
            
        catch ME
            fprintf('✗ MEX function test error: %s\n', ME.message);
        end
        
    catch ME
        fprintf('✗ Build failed: %s\n', ME.message);
        fprintf('\nTroubleshooting:\n');
        fprintf('1. Ensure hidapi is installed\n');
        fprintf('2. Update paths in this script\n');
        fprintf('3. Check C++ compiler configuration: mex -setup\n');
        fprintf('4. On Windows, ensure Visual Studio is installed\n');
        rethrow(ME);
    end
    
    fprintf('\nBuild complete! You can now use MJC3_MEX_Controller.\n');
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