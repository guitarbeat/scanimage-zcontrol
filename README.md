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
│   ├── app/                      # Main application
│   │   └── foilview.m           # Primary MATLAB App Designer application
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

- **[MJC3 Controller Documentation](src/controllers/mjc3/README.md)** - Detailed joystick controller setup
- **[MEX Setup Guide](src/controllers/mjc3/MEX_SETUP.md)** - Manual MEX compilation instructions
- **[Services Documentation](src/services/README.md)** - Service layer architecture
- **[Task List](TASK_LIST_JOYSTICK_UI_SIMPLIFICATION.md)** - Development roadmap and progress

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