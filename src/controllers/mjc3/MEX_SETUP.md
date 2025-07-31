# MJC3 MEX Controller Setup Guide

This guide walks you through setting up the high-performance MEX-based MJC3 controller that provides direct HID access without PsychHID dependencies.

## Benefits of MEX Controller

- **No PsychHID dependency** - Works with any MATLAB installation
- **Better performance** - 50Hz polling vs 20Hz, native C++ speed
- **Cross-platform** - Windows, Linux, macOS support
- **Simplified architecture** - Single robust implementation
- **Direct HID access** - No licensing or driver issues

## Prerequisites

### 1. MATLAB C++ Compiler
```matlab
% Check if compiler is configured
mex -setup

% If not configured, MATLAB will guide you through setup
% On Windows: Install Visual Studio Community (free)
% On Linux: Install gcc/g++
% On macOS: Install Xcode Command Line Tools
```

### 2. hidapi Library

#### Windows (Recommended: vcpkg)
```cmd
# Install vcpkg if not already installed
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat

# Install hidapi
.\vcpkg install hidapi:x64-windows
```

#### Windows (Alternative: Manual)
1. Download hidapi from: https://github.com/libusb/hidapi/releases
2. Extract to `C:\hidapi\`
3. Ensure you have both include and lib directories

#### Linux (Ubuntu/Debian)
```bash
sudo apt-get install libhidapi-dev
```

#### Linux (CentOS/RHEL)
```bash
sudo yum install hidapi-devel
```

#### macOS
```bash
# Using Homebrew
brew install hidapi

# Using MacPorts
sudo port install hidapi
```

## Installation Steps

### 1. Build the MEX Function
```matlab
% Navigate to your source directory
cd src

% Run the build script
build_mjc3_mex()
```

The build script will:
- Detect your compiler configuration
- Find hidapi installation
- Compile the MEX function
- Test the compiled function
- Verify MJC3 device connection

### 2. Verify Installation
```matlab
% Test MEX function directly
result = mjc3_joystick_mex('test')  % Should return true

% Get device info
info = mjc3_joystick_mex('info')
disp(info)

% Test controller creation
zController = ScanImageZController(hSI.hMotors);  % Your Z-controller
controller = MJC3_MEX_Controller(zController, 5);

% Check if MEX is preferred controller
MJC3ControllerFactory.listAvailableTypes()
```

### 3. Integration with Existing System
The MEX controller integrates seamlessly with your existing architecture:

```matlab
% Factory automatically selects MEX controller if available
controller = MJC3ControllerFactory.createController(zController);

% Or force MEX controller specifically
controller = MJC3ControllerFactory.createController(zController, 5, 'MEX');

% Use with existing HIDController
hidController = HIDController(uiComponents, zController);
hidController.enable();  % Will use MEX controller automatically
```

## Troubleshooting

### Build Issues

#### "No C++ compiler configured"
```matlab
mex -setup
% Follow MATLAB's instructions to install/configure compiler
```

#### "hidapi not found"
1. Verify hidapi installation
2. Update paths in `build_mjc3_mex.m`
3. Check library naming (hidapi vs hidapi_ms vs hid)

#### Windows: "LNK2019: unresolved external symbol"
- Ensure correct library architecture (x64 vs x86)
- Try different library names: hidapi, hidapi_ms, hid
- Check Visual Studio installation

#### Linux: "cannot find -lhidapi"
```bash
# Install development packages
sudo apt-get install libhidapi-dev pkg-config

# Check library location
pkg-config --libs hidapi-libusb
```

### Runtime Issues

#### "MEX function not found"
- Ensure MEX file compiled successfully
- Check MATLAB path includes MEX file location
- Verify file permissions

#### "Cannot open MJC3 joystick"
- Check USB connection
- Verify device VID:1313, PID:9000
- On Linux: Check udev rules for HID access
- Try running MATLAB as administrator (Windows)

#### "HID read error"
- Device may be in use by another application
- Try unplugging/reconnecting USB
- Check device manager (Windows)

### Linux-Specific Setup

#### udev Rules for Non-Root Access
Create `/etc/udev/rules.d/99-mjc3.rules`:
```
# Thorlabs MJC3 Joystick
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1313", ATTRS{idProduct}=="9000", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1313", ATTRS{idProduct}=="9000", MODE="0666"
```

Then reload udev rules:
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Performance Comparison

| Controller Type | Poll Rate | Dependencies | Licensing | Performance |
|----------------|-----------|--------------|-----------|-------------|
| MEX            | 50 Hz     | hidapi only  | None      | Excellent   |
| HID (PsychHID) | 20 Hz     | Psychtoolbox | Required  | Good        |
| Native         | 20 Hz     | Windows API  | None      | Fair        |
| Windows_HID    | 10 Hz     | PowerShell   | None      | Poor        |

## Advanced Configuration

### Custom Polling Rate
```matlab
% Modify MJC3_MEX_Controller.m
properties (Constant)
    POLL_RATE = 0.01;  % 100Hz polling (very fast)
end
```

### Timeout Adjustment
```matlab
% In readJoystick method
data = feval(obj.mexFunction, 'read', 25); % 25ms timeout
```

### Debug Mode
```matlab
% Enable verbose output in MEX controller
controller.setDebugMode(true);
```

## Testing and Validation

### Basic Functionality Test
```matlab
% Test MEX function
data = mjc3_joystick_mex('read', 100);
fprintf('Joystick data: X=%d Y=%d Z=%d Btn=%d Spd=%d\n', data);
```

### Performance Test
```matlab
% Measure polling performance
tic;
for i = 1:1000
    data = mjc3_joystick_mex('read', 10);
end
elapsed = toc;
fprintf('Average read time: %.2f ms\n', elapsed);
```

### Integration Test
```matlab
% Full system test
controller = MJC3ControllerFactory.createController(zController);
controller.start();
pause(5);  % Let it run for 5 seconds
controller.stop();
```

## Support and Updates

For issues or improvements:
1. Check this troubleshooting guide
2. Verify hidapi and compiler setup
3. Test with simulation controller first
4. Check MATLAB and system compatibility

The MEX controller represents the optimal solution for MJC3 joystick control, providing the best performance and reliability while eliminating external dependencies.