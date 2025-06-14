# FocalSweep Z-Control Tool

A MATLAB tool for Z-focus control in ScanImage microscopy systems. Provides automated Z-scanning and focus optimization.

## Key Features

- Z-position control with up/down movement
- Automatic Z-scanning with focus quality detection
- Integration with ScanImage microscopy software
- Live focus quality monitoring
- Modern GUI with App Designer components 

## Installation

1. Clone or download this repository
2. Add the `src` directory to your MATLAB path
3. Run `fsweep` in the MATLAB command window

## Requirements

- MATLAB R2019b or newer (for full functionality)
- ScanImage must be running with `hSI` available in the base workspace
- Access to ScanImage Motor Controls

## Basic Usage

```matlab
% Launch with default settings
fsweep

% Launch with specific parameters
fsweep('verbosity', 1)

% Force creation of a new instance
fsweep('forceNew', true)

% Get a handle to the FocalSweep object
fs = fsweep();

% Show version information
fsweep('version')

% Close all instances
fsweep('close')
```

## Code Organization

The codebase is organized into several modules:

### Core Module
- `AppConfig` - Centralized configuration settings
- `CoreUtils` - Utility functions for error handling and validation
- `FocalParameters` - Parameter management for Z-scanning
- `FocalSweep` - Main controller class
- `FocalSweepFactory` - Factory for creating instances
- `Initializer` - Handles ScanImage initialization
- `MotorGUI_ZControl` - Interface to ScanImage motor controls

### GUI Module
- `FocusGUI` - Main GUI controller
- `GUIUtils` - GUI utility functions
- `components.UIComponentFactory` - Factory for creating UI components
- `interfaces.ControllerInterface` - Interface for controllers
- `interfaces.ControllerAdapter` - Adapter for legacy controllers

### Scan Module
- `ZScanner` - Handles Z-scanning and movement

## Recent Improvements

1. **Centralized Configuration**
   - Created `AppConfig` for application-wide settings
   - Consolidated color and style definitions
   - Standardized default parameter values

2. **Enhanced Error Handling**
   - Improved parameter validation
   - Standardized error reporting
   - Added robust error recovery

3. **Modernized GUI Components**
   - Added compatibility with latest App Designer components
   - Added fallback for older MATLAB versions
   - Improved component styling and layout

4. **Reduced Code Duplication**
   - Created utility classes for common operations
   - Standardized validation methods
   - Unified error handling approach

5. **Improved Architecture**
   - Better separation of concerns
   - More consistent interfaces
   - Enhanced code organization

## Feature Compatibility

| Feature | Required MATLAB Version |
|---------|--------------------------|
| Basic functionality | R2018b or newer |
| RangeSlider | R2020b or newer |
| StateButton | R2019b or newer |
| ButtonGroup | R2019a or newer |
| TreeView | R2020a or newer |

## License

See the LICENSE file for details.
