# Source Code Documentation

This directory contains the source code for the ScanImage Z-Control with Brightness Monitoring system.

## Main Components

### `SI_BrightnessZControl.m`
The main class that combines Z-position control with brightness monitoring. This is the primary interface for users, providing:
- Real-time brightness monitoring
- Automated Z-scanning with adaptive step sizing
- Interactive GUI for control and visualization
- Automatic focal point detection

### `SI_MotorGUI_ZControl.m`
Base class for Z-position control through ScanImage's Motor Controls GUI. Provides:
- Basic Z-position control functions
- Integration with ScanImage's motor control system
- Step size management
- Relative and absolute movement capabilities

## Development and Testing Files


### `investigate_image_data.m`
Utility script for exploring image data access in ScanImage. Used during development to:
- Test different methods of accessing image data
- Verify channel configuration
- Debug data scope access

### `investigate_scanimage_vars.m`
Development tool for exploring ScanImage's internal variables and properties. Used to:
- Map ScanImage's object hierarchy
- Identify relevant properties and methods
- Debug integration points

## Usage

For normal usage, you only need to use `SI_BrightnessZControl.m`. The other files are either:
1. Supporting classes (`SI_MotorGUI_ZControl.m`)
2. Development tools (investigation scripts)

See the main README.md for usage instructions. 