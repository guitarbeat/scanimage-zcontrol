# ScanImage Z-Control

A MATLAB-based tool for controlling Z-axis focus in ScanImage microscopy applications.

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

## Requirements

- MATLAB (tested with R2019b or newer)
- ScanImage (must be running with `hSI` in base workspace)
- Access to Motor Controls in ScanImage

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
