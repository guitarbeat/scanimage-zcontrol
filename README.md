# FocalSweep - Focus Finding for ScanImage

This MATLAB package provides tools for controlling Z-position in ScanImage while monitoring image brightness to help find optimal focal points.

## Features

- Real-time brightness monitoring from ScanImage display channel
- Automated Z-position scanning with adaptive step sizing
- Automatic detection of maximum brightness position
- Interactive GUI for parameter control and visualization
- Integration with ScanImage's motor control system

## Requirements

- MATLAB R2019b or later
- ScanImage 2021 or later
- Active ScanImage session with motor control enabled

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/scanimage-zcontrol.git
cd scanimage-zcontrol
```

2. Add the `src` directory to your MATLAB path:
```matlab
addpath('src');
```

## Usage

### Basic Usage

1. Start ScanImage and ensure motor control is enabled
2. Create the control object:
```matlab
control = FocalSweep();
```
   
   Alternatively, use the quick launcher function:
```matlab
control = fsweep();
```

3. The GUI will appear with the following components:
   - Brightness vs Z-position plot
   - Parameter inputs
   - Control buttons
   - Status display
   - Usage guide

### Finding the Focal Point

1. Set the parameters in the GUI:
   - **Initial Step Size**: Start with 20 for coarse scanning
   - **Scan Range**: Distance to scan (e.g., 100)
   - **Pause Time**: Time between steps (e.g., 0.5s)

2. Click "Start Monitoring" to begin brightness tracking

3. Click "Start Z-Scan" to begin automated scanning:
   - The system will start with larger steps
   - Step size automatically reduces when approaching the focal point
   - Watch the plot to see brightness changes

4. Use "Stop Z-Scan" to pause at any time

5. Click "Move to Max" to automatically move to the position of maximum brightness

### Adaptive Step Sizing

The system uses an adaptive step size algorithm:
- Starts with the initial step size (default: 20)
- Monitors brightness changes
- Reduces step size by half when:
  - Brightness decreases by more than 10%
  - This occurs for 3 consecutive steps
- Continues until minimum step size (1) is reached

### Manual Control

You can also use manual control methods:
```matlab
% Get current Z position
z = control.getZ();

% Set step size
control.setStepSize(5);

% Move up/down
control.moveUp();
control.moveDown();

% Move by relative distance
control.relativeMove(10);  % Move up 10 units
control.relativeMove(-10); % Move down 10 units

% Move to absolute position
control.absoluteMove(12000);
```

## Code Structure

### Main Components

#### `FocalSweep.m`
The main class that combines Z-position control with brightness monitoring, providing:
- Real-time brightness monitoring
- Automated Z-scanning with adaptive step sizing
- Interactive GUI for control and visualization
- Automatic focal point detection

#### `fsweep.m`
Quick launcher function that creates and returns a FocalSweep object instance.

### GUI Module

The GUI system is built with a modular structure:

#### Main Classes
- `FocusGUI.m` - Main class that coordinates the GUI creation and manages callbacks

#### Components Module
- `UIComponentFactory.m` - Factory class for creating UI components with consistent styling

#### Handlers Module
- `UIEventHandlers.m` - Event handler class for handling UI events and updates

### Design Patterns Used

1. **Factory Pattern** - The UIComponentFactory class creates UI components with consistent styling
2. **Facade Pattern** - The main GUI class provides a simplified interface to the complex UI subsystem
3. **Observer Pattern** - The event handlers respond to UI events and update the UI accordingly

## Troubleshooting

1. **No motor control found**:
   - Ensure ScanImage is running
   - Verify motor control is enabled in ScanImage
   - Check that the Motor Controls window is open

2. **No brightness data**:
   - Ensure an acquisition is active in ScanImage
   - Verify the correct display channel is selected
   - Check that the data scope is active

3. **Step size issues**:
   - If steps are too large, reduce the initial step size
   - If steps are too small, increase the initial step size
   - Adjust the pause time if steps are too fast/slow

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
