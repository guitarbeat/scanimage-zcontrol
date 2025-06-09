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

## Usage

For normal usage, you only need to use `SI_BrightnessZControl.m`. The GUI is now more compact, uses available space efficiently, and is focused on Z control and brightness monitoring only. All development tools have been removed from the main interface for clarity and usability.

See the main README.md for usage instructions. 