# Source Code Documentation

This directory contains the source code for the FocalSweep focus finding system.

## Main Components

### `FocalSweep.m`
The main class that combines Z-position control with brightness monitoring. This is the primary interface for users, providing:
- Real-time brightness monitoring
- Automated Z-scanning with adaptive step sizing
- Interactive GUI for control and visualization
- Automatic focal point detection

### `fsweep.m`
Quick launcher function that creates and returns a FocalSweep object instance. This provides an easy way to start the tool.

### Core Components
Base classes and core functionality for Z-position control and ScanImage integration.

## Development and Testing Files

## Usage

For normal usage, you only need to use `FocalSweep.m` or the launcher function `fsweep.m`. The GUI is compact, uses available space efficiently, and is focused on Z control and brightness monitoring only. All development tools have been removed from the main interface for clarity and usability.

See the main README.md for usage instructions. 