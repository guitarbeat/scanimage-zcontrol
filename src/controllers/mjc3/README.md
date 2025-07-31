# MJC3 Controller Organization

This directory contains a well-organized set of MJC3 joystick controllers for ScanImage Z-axis control. The controllers are designed with a common interface and automatic fallback system.

## Architecture

### Base Class
- **`BaseMJC3Controller`** - Abstract base class defining the common interface
  - Standardized constructor with Z-controller and step factor
  - Common methods: `start()`, `stop()`, `connectToMJC3()`, `moveUp()`, `moveDown()`
  - Automatic resource cleanup

### Controller Implementations

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

### Factory Pattern
- **`MJC3ControllerFactory`** - Automatic controller selection
  - Detects available capabilities
  - Creates best available controller
  - Provides testing and diagnostics

## Usage

### Basic Usage
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

### Specific Controller Selection
```matlab
% Force specific controller type
controller = MJC3ControllerFactory.createController(zController, 5, 'HID');

% Or create directly
controller = MJC3_HID_Controller(zController, 5);
```

### Diagnostics
```matlab
% List available controller types
MJC3ControllerFactory.listAvailableTypes();

% Test specific controller
MJC3ControllerFactory.testController('HID', zController);
```

## Controller Capabilities

| Controller | Dependencies | Cross-Platform | Hardware Required | Performance |
|------------|--------------|----------------|-------------------|-------------|
| MEX        | hidapi only  | Yes            | Yes               | Excellent (50Hz) |
| Simulation | None         | Yes            | No                | N/A (Testing)    |

## Installation

The system now uses a streamlined MEX-based implementation:

1. **Quick Installation:**
   ```matlab
   install_mjc3()  % Handles everything automatically
   ```

2. **Manual Installation:**
   ```matlab
   % 1. Configure compiler
   mex -setup
   
   % 2. Install hidapi (see MEX_SETUP.md for details)
   
   % 3. Build MEX function
   build_mjc3_mex()
   ```

3. **Verify Installation:**
   ```matlab
   test_mjc3_improvements()
   ```

## Benefits of MEX Implementation

1. **High Performance** - 50Hz polling rate with native C++ speed
2. **No Dependencies** - Works with any MATLAB installation (no PsychHID)
3. **Cross-Platform** - Windows, Linux, macOS support via hidapi
4. **Robust Error Handling** - Direct hardware access with reconnection
5. **Simplified Architecture** - Single primary implementation
6. **Easy Installation** - Automated setup process

## Troubleshooting

### Controller Not Working
1. Check available types: `MJC3ControllerFactory.listAvailableTypes()`
2. Test specific controller: `MJC3ControllerFactory.testController('HID', zController)`
3. Verify Z-controller: Ensure `zController.relativeMove(dz)` works

### PsychHID Issues
- If PsychHID is not available, the factory will automatically fall back to Windows Native controller
- For testing without hardware, use Simulation controller

### Windows API Issues
- Ensure PowerShell execution policy allows script execution
- Check Windows joystick drivers are installed
- Try Keyboard controller as last resort

## File Structure
```
mjc3/
├── BaseMJC3Controller.m           # Abstract base class
├── MJC3ControllerFactory.m        # Factory for controller creation
├── MJC3_HID_Controller.m          # PsychHID-based controller
├── MJC3_Native_Controller.m       # Windows native API controller
├── MJC3_Windows_HID_Controller.m # Simplified Windows HID
├── MJC3_Keyboard_Controller.m     # Keyboard-based controller
├── MJC3_Simulation_Controller.m   # Simulation controller
└── README.md                      # This file
``` 