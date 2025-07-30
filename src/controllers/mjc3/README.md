# MJC3 Controller Organization

This directory contains a well-organized set of MJC3 joystick controllers for ScanImage Z-axis control. The controllers are designed with a common interface and automatic fallback system.

## Architecture

### Base Class
- **`BaseMJC3Controller`** - Abstract base class defining the common interface
  - Standardized constructor with Z-controller and step factor
  - Common methods: `start()`, `stop()`, `connectToMJC3()`, `moveUp()`, `moveDown()`
  - Automatic resource cleanup

### Controller Implementations

1. **`MJC3_HID_Controller`** (Recommended)
   - Direct HID access via PsychHID
   - Full joystick functionality
   - Requires Psychtoolbox license

2. **`MJC3_Native_Controller`**
   - Windows native joystick API
   - Bypasses PsychHID licensing requirements
   - Windows-only implementation

3. **`MJC3_Windows_HID_Controller`**
   - Simplified Windows HID access
   - Fallback for when full HID access isn't available

4. **`MJC3_Keyboard_Controller`**
   - Keyboard shortcuts as joystick alternative
   - Always available, no hardware dependencies

5. **`MJC3_Simulation_Controller`**
   - Simulated joystick for testing
   - Keyboard-based simulation with visual feedback

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

| Controller | PsychHID Required | Windows Only | Hardware Required | Fallback Level |
|------------|-------------------|--------------|-------------------|----------------|
| HID        | Yes               | No           | Yes               | 1 (Best)       |
| Native     | No                | Yes          | Yes               | 2              |
| Windows_HID| No                | Yes          | Yes               | 3              |
| Keyboard   | No                | No           | No                | 4              |
| Simulation | No                | No           | No                | 5 (Last)       |

## Migration from Old Controllers

The old controllers in the main `controllers/` directory are now deprecated. To migrate:

1. **Replace direct instantiation:**
   ```matlab
   % Old way
   controller = MJC3_HID_Controller(stageService, stepFactor);
   
   % New way
   zController = ScanImageZController(hSI.hMotors);
   controller = MJC3_HID_Controller(zController, stepFactor);
   ```

2. **Use factory for automatic selection:**
   ```matlab
   % Automatic best available controller
   controller = MJC3ControllerFactory.createController(zController);
   ```

3. **Update HIDController integration:**
   ```matlab
   % In HIDController.m, replace:
   obj.hidController = MJC3_HID_Controller(obj.zController, obj.stepFactor);
   
   % With:
   obj.hidController = MJC3ControllerFactory.createController(obj.zController, obj.stepFactor);
   ```

## Benefits of New Organization

1. **Standardized Interface** - All controllers implement the same methods
2. **Automatic Fallback** - Factory selects best available controller
3. **Better Error Handling** - Consistent error handling across all controllers
4. **Easier Testing** - Factory provides testing utilities
5. **Cleaner Code** - Common functionality in base class
6. **Future Extensibility** - Easy to add new controller types

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