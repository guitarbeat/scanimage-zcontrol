# MJC3 Joystick Controller System

High-performance MEX-based controller for Thorlabs MJC3 USB joystick integration with ScanImage Z-axis control.

## Features

- **50Hz polling rate** (2.5x faster than PsychHID-based solutions)
- **No external dependencies** (no PsychHID or Psychtoolbox required)
- **Cross-platform support** (Windows, Linux, macOS)
- **Direct HID access** via hidapi library
- **Robust error handling** with automatic reconnection
- **Real-time joystick visualization**

## Quick Start

### 1. Installation
```matlab
% Run automated installation
install_mjc3()
```

### 2. Basic Usage
```matlab
% Add paths
addpath('controllers/mjc3');
addpath('controllers');
addpath('views');

% Create controller
zController = ScanImageZController(hSI.hMotors);
controller = MJC3ControllerFactory.createController(zController);

% Start joystick control
controller.start();
```

### 3. UI Integration
```matlab
% Use with existing HIDController
hidController = HIDController(uiComponents, zController);
hidController.enable();  % Automatically uses MEX controller
```

## Architecture

### Core Components

- **`mjc3_joystick_mex.cpp`** - High-performance C++ MEX function
- **`MJC3_MEX_Controller.m`** - MATLAB controller wrapper
- **`MJC3ControllerFactory.m`** - Automatic controller selection
- **`HIDController.m`** - UI integration bridge
- **`MJC3View.m`** - Dedicated joystick control window

### File Structure
```
src/
├── mjc3_joystick_mex.cpp          # C++ MEX source
├── mjc3_joystick_mex.mexw64       # Compiled MEX function
├── hidapi.dll                    # Required DLL
├── install_mjc3.m                # Automated setup
├── build_mjc3_mex.m              # Manual build script
├── controllers/
│   ├── HIDController.m           # UI integration
│   ├── ScanImageZController.m    # ScanImage interface
│   └── mjc3/
│       ├── MJC3_MEX_Controller.m      # Primary controller
│       ├── MJC3ControllerFactory.m    # Factory pattern
│       ├── BaseMJC3Controller.m       # Base class
│       ├── MJC3_Simulation_Controller.m # Testing fallback
│       └── README.md                  # Detailed documentation
└── views/
    └── MJC3View.m                # Joystick control UI
```

## Hardware Requirements

- **Thorlabs MJC3 USB Joystick** (VID: 0x1313, PID: 0x9000)
- **USB connection** to computer
- **MATLAB with C++ compiler** configured (`mex -setup`)

## Installation Requirements

### Windows
- **Visual Studio** or **MinGW64** compiler
- **hidapi library** (automatically handled by installer)

### Linux
```bash
sudo apt-get install libhidapi-dev  # Ubuntu/Debian
# or
sudo yum install hidapi-devel       # CentOS/RHEL
```

### macOS
```bash
brew install hidapi
```

## Troubleshooting

### "MEX function not found"
- Run `install_mjc3()` to build the MEX function
- Ensure `mjc3_joystick_mex.mexw64` exists in src directory
- Check that `hidapi.dll` is present

### "Hardware not detected"
- Verify USB connection
- Check Device Manager (Windows) for MJC3 device
- Try unplugging/reconnecting joystick

### "Compiler not configured"
```matlab
mex -setup  % Configure C++ compiler
```

## Performance

| Metric | Value |
|--------|-------|
| **Polling Rate** | 50 Hz |
| **Average Read Time** | ~11ms |
| **Hardware Detection** | Automatic |
| **Reconnection** | Automatic |

## Integration Examples

### Replace Old PsychHID Controller
```matlab
% OLD (PsychHID-based):
% controller = MJC3_HID_Controller(zController, stepFactor);

% NEW (MEX-based):
controller = MJC3ControllerFactory.createController(zController, stepFactor);
```

### With Error Handling
```matlab
try
    controller = MJC3ControllerFactory.createController(zController);
    controller.start();
    fprintf('MJC3 controller started successfully\n');
catch ME
    fprintf('Failed to start MJC3 controller: %s\n', ME.message);
    % Fallback to simulation or manual control
end
```

### Manual Hardware Testing
```matlab
% Test hardware connection
info = mjc3_joystick_mex('info');
fprintf('Connected: %s\n', mat2str(info.connected));

% Read joystick data
data = mjc3_joystick_mex('read', 100);
if ~isempty(data)
    fprintf('X=%d Y=%d Z=%d Btn=%d Spd=%d\n', data);
end
```

## Support

For detailed setup instructions, see `controllers/mjc3/README.md` and `controllers/mjc3/MEX_SETUP.md`.

The system automatically detects available capabilities and selects the best controller implementation.