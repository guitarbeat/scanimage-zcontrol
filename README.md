# ScanImage Z-Control

A tool for automated Z-focus finding in microscopy applications using ScanImage.

## Overview

This software provides Z-focus control for microscopes running ScanImage, with automated focus finding based on image brightness. The system includes:

- Real-time brightness monitoring
- Automated Z-scanning
- Focus optimization
- Interactive GUI

## Recent Simplifications (MVP Version)

The software has been simplified to a Minimum Viable Product (MVP) version to address stability issues. The following changes were made:

1. **Removed channelSettings dependency** - The code no longer requires access to ScanImage's channel settings, which was causing errors.
2. **Made display settings optional** - The software now gracefully handles missing display settings.
3. **Added error resilience** - Added try-catch blocks around critical components to prevent crashes.
4. **Improved GUI robustness** - The UI creation is now wrapped in try-catch to handle initialization failures.
5. **Better status reporting** - Status updates now work even if UI components aren't fully initialized.

## Requirements

- MATLAB R2018b or later
- ScanImage 2020 or later
- Access to ScanImage motor controls

## Usage

```matlab
% Launch the Z-control tool
fsweep

% Launch with debug messages
fsweep('verbosity', 2)

% Close the tool
fsweep('close')

% Display version information
fsweep('version')
```

## Troubleshooting

If you encounter issues:

1. Make sure ScanImage is running with `hSI` in the base workspace
2. Check if your ScanImage version is compatible
3. Verify that motor controls are accessible

## License

See LICENSE file for details.

## Structure

The application is organized into the following package structure:

```
src/
  +core/              # Core functionality and classes
    FocalParameters.m    # Parameter management for focusing
    FocalSweep.m         # Main application class
    FocalSweepFactory.m  # Factory for creating FocalSweep instances
    Initializer.m        # System initialization logic
    MotorGUI_ZControl.m  # Base class for Z-motor control

  +gui/               # GUI components
    FocusGUI.m           # Main GUI class
    +components/         # Reusable UI components
    +handlers/           # Event handling logic

  +monitoring/        # Image monitoring functionality
    BrightnessMonitor.m  # Real-time brightness monitoring

  +scan/              # Z-scanning functionality
    ZScanner.m           # Z-axis scanning control

  fsweep.m            # Main launcher function
```

## Usage

To launch the application, simply run:

```matlab
% In MATLAB command window
fsweep
```

Or with custom parameters:

```matlab
% With parameters
fsweep('verbosity', 2)          % Enable more verbose output
fsweep('forceNew', true)        % Force creation of a new instance

% Get the instance handle
zController = fsweep();

% Close any existing instances
fsweep('close')
```

## Development

For development, use the core package directly:

```matlab
% Create an instance directly
zController = core.FocalSweep();

% Use the factory
zController = core.FocalSweepFactory.launch();
```

## Design Architecture

The application follows a modular design with several key components:

1. **Core System** - Provides the fundamental functionality
   - `core.FocalSweep` - Main controller class
   - `core.FocalParameters` - Parameter management
   - `core.MotorGUI_ZControl` - Z-position motor interface

2. **GUI System** - Handles the user interface
   - `gui.FocusGUI` - Main GUI controller
   - `gui.components.UIComponentFactory` - Creates UI elements with consistent styling
   - `gui.handlers.UIEventHandlers` - Manages UI events and updates

3. **Monitoring System** - Handles image monitoring
   - `monitoring.BrightnessMonitor` - Monitors image brightness in real-time

4. **Scanning System** - Controls Z-scanning operations
   - `scan.ZScanner` - Manages automated Z-position scanning

This modular architecture makes the system extensible and maintainable, with clear separation of concerns between components.
