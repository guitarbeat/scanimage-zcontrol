# ScanImage Z Control - MJC3 Joystick Integration System

A high-performance MATLAB application for integrating Thorlabs MJC3 USB joystick with ScanImage microscopy systems, providing real-time Z-axis (and X/Y) control with enhanced UI and automation capabilities.

## 🎯 Overview

This repository contains a complete MATLAB-based control system that bridges Thorlabs MJC3 USB joystick hardware with ScanImage microscopy software. The system provides:

- **High-performance joystick control** (50Hz polling rate)
- **Real-time Z-axis positioning** for microscopy applications
- **Multi-axis support** (X, Y, Z) with calibration
- **Automated metadata tracking** and bookmarking
- **Comprehensive UI** with visualization and control panels
- **Robust error handling** and automatic reconnection

## 🏗️ Architecture

### Core Components

```
scanimage-zcontrol/
├── src/                          # Main source code
│   ├── foilview.m               # Primary MATLAB App Designer application
│   ├── controllers/              # Control logic and hardware interfaces
│   │   ├── FoilviewController.m  # Main application controller
│   │   ├── ScanImageController.m # ScanImage integration
│   │   ├── HIDController.m       # Human Interface Device management
│   │   ├── UIController.m        # UI state management
│   │   └── mjc3/                # MJC3 joystick specific controllers
│   │       ├── MJC3_MEX_Controller.m      # High-performance MEX controller
│   │       ├── MJC3ControllerFactory.m    # Controller factory pattern
│   │       ├── BaseMJC3Controller.m       # Base controller class
│   │       └── MJC3_Simulation_Controller.m # Testing fallback
│   ├── views/                    # User interface components
│   │   ├── MJC3View.m           # Joystick control window
│   │   ├── StageView.m          # Stage position visualization
│   │   ├── BookmarksView.m      # Bookmark management UI
│   │   ├── ToolsWindow.m        # Utility tools window
│   │   ├── UiBuilder.m          # UI construction utilities
│   │   ├── UiComponents.m       # Reusable UI components
│   │   └── PlotManager.m        # Plotting and visualization
│   ├── services/                 # Business logic and data services
│   │   ├── ApplicationInitializer.m    # App startup and configuration
│   │   ├── MetadataService.m           # Metadata file management
│   │   ├── StageControlService.m      # Stage movement coordination
│   │   ├── UserNotificationService.m  # User feedback and alerts
│   │   ├── ErrorHandlerService.m      # Error management
│   │   ├── MetricCalculationService.m # Performance metrics
│   │   ├── ScanControlService.m       # Scan coordination
│   │   └── MetricsPlotService.m       # Data visualization
│   ├── managers/                 # High-level system management
│   │   ├── ScanImageManager.m    # ScanImage integration manager
│   │   └── BookmarkManager.m     # Bookmark data management
│   ├── utils/                    # Utility functions and helpers
│   │   ├── FoilviewUtils.m      # General application utilities
│   │   ├── MetadataWriter.m      # Metadata file operations
│   │   ├── NumericUtils.m       # Mathematical utilities
│   │   ├── FilePathUtils.m      # File path management
│   │   └── ConfigUtils.m        # Configuration management
│   ├── controllers/mjc3/
│   │   ├── build_mjc3_mex.m         # MEX compilation script
│   │   ├── mjc3_joystick_mex.cpp    # C++ MEX source for joystick control
│   │   ├── mjc3_joystick_mex.mexw64 # Compiled MEX function
│   │   ├── hidapi.dll               # Required runtime dependency
│   │   └── install_mjc3.m           # Automated installation script
├── dev-tools/                    # Development and testing tools
│   └── logs/                    # Application logs
├── vcpkg/                        # Package management (if used)
├── .vscode/                      # VS Code configuration
├── .kiro/                        # Kiro IDE configuration
├── .cursor/                      # Cursor IDE configuration
└── hidapi-win.zip               # Windows HID library package
```

## 🚀 Quick Start

### Prerequisites

- **MATLAB R2020b or later** with App Designer support
- **Thorlabs MJC3 USB Joystick** (VID: 0x1313, PID: 0x9000)
- **ScanImage** microscopy software (for full integration)
- **C++ compiler** configured in MATLAB (`mex -setup`)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/scanimage-zcontrol.git
   cd scanimage-zcontrol
   ```

2. **Run automated installation:**
   ```matlab
   % Add to MATLAB path and run installation
   addpath('src');
   install_mjc3();
   ```

3. **Launch the application:**
   ```matlab
   % Start the main application
   foilview();
   ```

### Basic Usage

```matlab
% Create and start joystick controller
zController = ScanImageController(hSI.hMotors);
controller = MJC3ControllerFactory.createController(zController);
controller.start();

% Enable joystick control
controller.enable();
```

## 🎮 Features

### High-Performance Joystick Control
- **50Hz polling rate** (2.5x faster than PsychHID solutions)
- **Direct HID access** via hidapi library
- **Cross-platform support** (Windows, Linux, macOS)
- **Automatic hardware detection** and reconnection

### Multi-Axis Support
- **Z-axis control** for focus adjustment
- **X/Y-axis support** for stage positioning
- **Individual calibration** for each axis with persistent storage
- **Configurable sensitivity** and step factors
- **Real-time calibrated value display** with color-coded activity indicators

### Advanced UI Features
- **Real-time position display** with visual feedback
- **Bookmark system** for saving positions
- **Metadata tracking** and automatic logging
- **Performance metrics** and monitoring
- **Error handling** with user notifications

### ScanImage Integration
- **Direct motor control** integration
- **Automatic metadata** capture
- **Bookmark-to-metadata** linking
- **Stage position** synchronization

## 🔧 Configuration

### Hardware Setup
1. Connect Thorlabs MJC3 USB joystick to computer
2. Verify device appears in Device Manager (Windows)
3. Run hardware test: `mjc3_joystick_mex('info')`

### ScanImage Integration
1. Start ScanImage and load your configuration
2. Launch foilview application
3. Configure motor axes in ScanImage settings
4. Enable joystick control through UI

### Calibration
1. Open MJC3View from main application
2. Click "Calibrate" button for any axis (X, Y, or Z)
3. Follow on-screen instructions to move joystick through full range
4. System automatically calculates and stores calibration parameters
5. Calibration data persists between sessions in `mjc3_calibration.mat`

**Calibration Process:**
- Move joystick through complete range of motion for each axis
- System collects 100 samples over ~1 second
- Calculates center point, range, dead zone, and sensitivity
- Applies calibration automatically to all future movements

## 🛠️ Development

### Building MEX Functions
```matlab
% Manual build (if automated install fails)
build_mjc3_mex();
```

### Testing
```matlab
% Test hardware connection
info = mjc3_joystick_mex('info');
fprintf('Connected: %s\n', mat2str(info.connected));

% Test joystick reading
data = mjc3_joystick_mex('read', 100);
if ~isempty(data)
    fprintf('X=%d Y=%d Z=%d Btn=%d Spd=%d\n', data);
end

% Test multi-axis movement and calibration
test_multi_axis_movement();
test_integration();
```

### Adding New Features
1. **Controllers**: Extend base classes in `src/controllers/`
2. **Views**: Create new UI components in `src/views/`
3. **Services**: Add business logic in `src/services/`
4. **Utils**: Place helper functions in `src/utils/`

## 📊 Performance Metrics

| Metric | Value | Description |
|--------|-------|-------------|
| **Polling Rate** | 50 Hz | Joystick data refresh rate |
| **Average Read Time** | ~11ms | Single joystick read operation |
| **Hardware Detection** | Automatic | Device connection monitoring |
| **Reconnection** | Automatic | Lost connection recovery |
| **Memory Usage** | <50MB | Typical application footprint |

## 🔍 Troubleshooting

### Common Issues

**"MEX function not found"**
- Run `install_mjc3()` to build MEX function
- Ensure `mjc3_joystick_mex.mexw64` exists in src/controllers/mjc3/ directory
- Check that `hidapi.dll` is present

**"Hardware not detected"**
- Verify USB connection
- Check Device Manager (Windows) for MJC3 device
- Try unplugging/reconnecting joystick
- Run hardware test: `mjc3_joystick_mex('info')`

**"Compiler not configured"**
```matlab
mex -setup  % Configure C++ compiler
```

**"ScanImage integration issues"**
- Ensure ScanImage is running and `hSI` is available
- Check motor configuration in ScanImage
- Verify motor axes are properly configured

## 📚 Documentation

## 🎮 MJC3 Controller Architecture

The MJC3 joystick controllers are designed with a common interface and automatic fallback system.

### Controller Architecture

#### Base Class
- **`BaseMJC3Controller`** - Abstract base class defining the common interface
  - Standardized constructor with Z-controller and step factor
  - Common methods: `start()`, `stop()`, `connectToMJC3()`, `moveUp()`, `moveDown()`
  - Automatic resource cleanup

#### Controller Implementations

1. **`MJC3_MEX_Controller`** (Primary)
   - High-performance C++ MEX implementation
   - Direct HID access via hidapi library
   - 50Hz polling rate for responsive control
   - Cross-platform compatibility
   - No external licensing dependencies

2. **`MJC3_Simulation_Controller`** (Testing)
   - Simulated joystick for development and testing
   - Keyboard-based simulation with visual feedback
   - Always available as fallback

#### Factory Pattern
- **`MJC3ControllerFactory`** - Automatic controller selection
  - Detects available capabilities
  - Creates best available controller
  - Provides testing and diagnostics

### Controller Usage

#### Basic Usage
```matlab
% Create Z-controller
zController = ScanImageZController(hSI.hMotors);

% Let factory choose best available controller
controller = MJC3ControllerFactory.createController(zController);

% Start the controller
controller.start();

% Manual control
controller.moveUp(2);    % Move up 2 steps
controller.moveDown(1);  % Move down 1 step

% Stop when done
controller.stop();
```

#### Specific Controller Selection
```matlab
% Force specific controller type
controller = MJC3ControllerFactory.createController(zController, 5, 'MEX');

% Or create directly
controller = MJC3_MEX_Controller(zController, 5);
```

#### Diagnostics
```matlab
% List available controller types
MJC3ControllerFactory.listAvailableTypes();

% Test specific controller
MJC3ControllerFactory.testController('MEX', zController);
```

### Controller Capabilities

| Controller | Dependencies | Cross-Platform | Hardware Required | Performance |
|------------|--------------|----------------|-------------------|-------------|
| MEX        | hidapi only  | Yes            | Yes               | Excellent (50Hz) |
| Simulation | None         | Yes            | No                | N/A (Testing)    |

### Benefits of MEX Implementation

1. **High Performance** - 50Hz polling rate with native C++ speed
2. **No Dependencies** - Works with any MATLAB installation (no PsychHID)
3. **Cross-Platform** - Windows, Linux, macOS support via hidapi
4. **Robust Error Handling** - Direct hardware access with reconnection
5. **Simplified Architecture** - Single primary implementation
6. **Easy Installation** - Automated setup process

### MJC3 Troubleshooting

#### Controller Not Working
1. Check available types: `MJC3ControllerFactory.listAvailableTypes()`
2. Test specific controller: `MJC3ControllerFactory.testController('MEX', zController)`
3. Verify Z-controller: Ensure `zController.relativeMove(dz)` works

#### Hardware Issues
- If MEX controller is not available, the factory will automatically fall back to Simulation controller
- For testing without hardware, use Simulation controller
- Ensure hidapi library is properly installed

## 🔧 MEX Controller Setup

The high-performance MEX-based MJC3 controller provides direct HID access without PsychHID dependencies.

### Benefits of MEX Controller

- **No PsychHID dependency** - Works with any MATLAB installation
- **Better performance** - 50Hz polling vs 20Hz, native C++ speed
- **Cross-platform** - Windows, Linux, macOS support
- **Simplified architecture** - Single robust implementation
- **Direct HID access** - No licensing or driver issues

### Prerequisites

#### 1. MATLAB C++ Compiler
```matlab
% Check if compiler is configured
mex -setup

% If not configured, MATLAB will guide you through setup
% On Windows: Install Visual Studio Community (free)
% On Linux: Install gcc/g++
% On macOS: Install Xcode Command Line Tools
```

#### 2. hidapi Library

**Windows (Recommended: vcpkg)**
```cmd
# Install vcpkg if not already installed
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat

# Install hidapi
.\vcpkg install hidapi:x64-windows
```

**Windows (Alternative: Manual)**
1. Download hidapi from: https://github.com/libusb/hidapi/releases
2. Extract to `C:\hidapi\`
3. Ensure you have both include and lib directories

**Linux (Ubuntu/Debian)**
```bash
sudo apt-get install libhidapi-dev
```

**Linux (CentOS/RHEL)**
```bash
sudo yum install hidapi-devel
```

**macOS**
```bash
# Using Homebrew
brew install hidapi

# Using MacPorts
sudo port install hidapi
```

### Installation Steps

#### 1. Build the MEX Function
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

#### 2. Verify Installation
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

#### 3. Integration with Existing System
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

### Troubleshooting

#### Build Issues

**"No C++ compiler configured"**
```matlab
mex -setup
% Follow MATLAB's instructions to install/configure compiler
```

**"hidapi not found"**
1. Verify hidapi installation
2. Update paths in `build_mjc3_mex.m`
3. Check library naming (hidapi vs hidapi_ms vs hid)

**Windows: "LNK2019: unresolved external symbol"**
- Ensure correct library architecture (x64 vs x86)
- Try different library names: hidapi, hidapi_ms, hid
- Check Visual Studio installation

**Linux: "cannot find -lhidapi"**
```bash
# Install development packages
sudo apt-get install libhidapi-dev pkg-config

# Check library location
pkg-config --libs hidapi-libusb
```

#### Runtime Issues

**"MEX function not found"**
- Ensure MEX file compiled successfully
- Check MATLAB path includes MEX file location
- Verify file permissions

**"Cannot open MJC3 joystick"**
- Check USB connection
- Verify device VID:1313, PID:9000
- On Linux: Check udev rules for HID access
- Try running MATLAB as administrator (Windows)

**"HID read error"**
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

### Performance Comparison

| Controller Type | Poll Rate | Dependencies | Licensing | Performance |
|----------------|-----------|--------------|-----------|-------------|
| MEX            | 50 Hz     | hidapi only  | None      | Excellent   |
| HID (PsychHID) | 20 Hz     | Psychtoolbox | Required  | Good        |
| Native         | 20 Hz     | Windows API  | None      | Fair        |
| Windows_HID    | 10 Hz     | PowerShell   | None      | Poor        |

### Advanced Configuration

#### Custom Polling Rate
```matlab
% Modify MJC3_MEX_Controller.m
properties (Constant)
    POLL_RATE = 0.01;  % 100Hz polling (very fast)
end
```

#### Timeout Adjustment
```matlab
% In readJoystick method
data = feval(obj.mexFunction, 'read', 25); % 25ms timeout
```

#### Debug Mode
```matlab
% Enable verbose output in MEX controller
controller.setDebugMode(true);
```

### Testing and Validation

#### Basic Functionality Test
```matlab
% Test MEX function
data = mjc3_joystick_mex('read', 100);
fprintf('Joystick data: X=%d Y=%d Z=%d Btn=%d Spd=%d\n', data);
```

#### Performance Test
```matlab
% Measure polling performance
tic;
for i = 1:1000
    data = mjc3_joystick_mex('read', 10);
end
elapsed = toc;
fprintf('Average read time: %.2f ms\n', elapsed);
```

#### Integration Test
```matlab
% Full system test
controller = MJC3ControllerFactory.createController(zController);
controller.start();
pause(5);  % Let it run for 5 seconds
controller.stop();
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Make your changes following the existing code style
4. Add tests for new functionality
5. Submit a pull request with detailed description

### Code Style Guidelines
- Follow MATLAB naming conventions
- Use Google Style Docstrings for functions
- Include error handling for all external calls
- Add comments for complex logic using Better Comments style

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Thorlabs** for MJC3 joystick hardware
- **ScanImage** team for microscopy software integration
- **hidapi** library contributors for cross-platform HID support
- **MATLAB** community for App Designer framework

## 📞 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review the detailed documentation in `src/` subdirectories
3. Open an issue on GitHub with detailed error information
4. Include system information and MATLAB version

---

**Note**: This system is designed for research microscopy applications. Always verify motor movements and safety limits before use in critical experiments. 