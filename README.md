# Z-Stage Control for ScanImage

A MATLAB tool for precise Z-stage positioning and focus optimization in ScanImage microscopy systems. Provides manual control, automated Z-scanning, and metrics-based focus optimization with a modern GUI interface.

## Key Features

- **Manual Z-position control** with configurable step sizes (0.1-50 μm)
- **Automated Z-scanning** with real-time focus quality metrics
- **Position bookmarking system** for saving and returning to important positions
- **Real-time metrics plotting** with normalized visualization
- **ScanImage integration** via Motor Controls GUI interface
- **Simulation mode** for testing without hardware
- **Modern tabbed GUI** built with MATLAB App Designer

## Installation

1. Clone or download this repository
2. Add the `src` directory to your MATLAB path:
   ```matlab
   addpath('path/to/scanimage-zcontrol/src')
   ```
3. Ensure ScanImage is running with Motor Controls window open (for hardware control)

## Requirements

- **MATLAB R2019b or newer** (for App Designer components)
- **ScanImage** must be running with `hSI` available in base workspace
- **Motor Controls window** must be open in ScanImage for hardware control

## Basic Usage

### Launch the Application

```matlab
% Create and launch the Z-Stage Control application
app = ZStageControlApp();
```

### Manual Control
- Use the **Manual Control** tab for direct positioning
- Select step size from dropdown (0.1, 0.5, 1, 5, 10, 50 μm)
- Click ▲/▼ buttons to move up/down by selected step
- Click **ZERO** to reset current position to 0 μm

### Automated Scanning
- Switch to the **Auto Step** tab
- Configure parameters:
  - **Step Size**: Custom step size in microns
  - **Steps**: Number of steps to execute
  - **Delay**: Time between steps (seconds)
  - **Direction**: Up (▲) or Down (▼)
  - **Record Metrics**: Enable to collect focus data
- Click **START** to begin automated sequence

### Position Bookmarks
- Use the **Bookmarks** tab to save important positions
- Enter a label and click **MARK** to save current position
- Select saved positions and click **GO TO** to return
- Click **DELETE** to remove unwanted bookmarks

### Focus Metrics
- Real-time focus metrics displayed in main window
- Choose metric type: Standard Deviation (best for focus), Mean, or Max
- Metrics are plotted during automated scanning
- Export metrics data for analysis

## ScanImage Integration

The application automatically integrates with ScanImage through a robust connection system:

### Connection Process
1. **Detection**: Checks for `hSI` variable in MATLAB base workspace
2. **Motor Controls**: Locates Motor Controls window by Tag='MotorControls'
3. **UI Elements**: Connects to position display (`etZPos`), step control (`Zstep`), and movement buttons (`Zdec`/`Zinc`)
4. **Fallback**: Automatically switches to simulation mode if any component is missing

### Hardware Control
- All movements are executed through ScanImage's own GUI controls
- Ensures proper synchronization with ScanImage's internal state
- Avoids hardware conflicts by using existing motor interfaces
- Position feedback comes directly from ScanImage hardware

### Simulation Mode
- Automatically activated when ScanImage is not available
- Allows testing and development without hardware
- Simulates realistic focus metrics for algorithm development
- All operations logged but don't affect physical hardware

## API Reference

### ZStageController Class

#### Core Methods
```matlab
% Position Control
moveStage(microns)              % Move relative distance
setPosition(position)           % Move to absolute position  
resetPosition()                 % Reset position to zero

% Automated Control
startAutoStepping(stepSize, numSteps, delay, direction, recordMetrics)
stopAutoStepping()             % Stop current sequence

% Position Management
markCurrentPosition(label)      % Save position with label
goToMarkedPosition(index)      % Go to saved position
deleteMarkedPosition(index)    % Remove saved position

% Metrics
updateMetric()                 % Calculate current metrics
setMetricType(metricType)      % Change active metric type
getAutoStepMetrics()           % Get collected scan data
```

#### Properties
```matlab
% Position State
CurrentPosition                % Current Z position (μm)
MarkedPositions               % Saved positions structure

% Metrics
CurrentMetric                 % Current metric value
CurrentMetricType            % Active metric ('Std Dev', 'Mean', 'Max')
AllMetrics                   % All calculated metrics

% Auto-stepping State  
IsAutoRunning                % True during automated sequences
RecordMetrics               % Enable metrics collection
```

### ZStageControlApp Class

#### Usage
```matlab
% Create application
app = ZStageControlApp();

% Access controller
controller = app.Controller;

% Cleanup when done
delete(app);
```

## Metrics Information

### Available Metrics
- **Standard Deviation**: Primary focus metric measuring image sharpness/contrast
- **Mean**: Average pixel intensity for exposure monitoring  
- **Max**: Peak pixel intensity for saturation detection

### Focus Detection
Standard Deviation is typically the best metric for focus optimization as it increases when image features are sharp and decreases when blurred.

## File Organization

```
src/
├── ZStageControlApp.m     # Main GUI application (1223 lines)
└── ZStageController.m     # Core controller logic (573 lines)
```

## Configuration

### Default Settings
- **Step sizes**: 0.1, 0.5, 1, 5, 10, 50 μm (1 μm default)
- **Auto-step defaults**: 10 steps of 10 μm with 0.5s delay
- **Position refresh**: 0.5 seconds
- **Metrics refresh**: 1.0 seconds
- **Default metric**: Standard Deviation

### Customization
Modify constants in `ZStageController.m`:
```matlab
STEP_SIZES = [0.1, 0.5, 1, 5, 10, 50]  % Available step sizes
DEFAULT_STEP_SIZE = 1.0                  % Default step
METRIC_REFRESH_PERIOD = 1.0             % Metrics update rate
```

## Troubleshooting

### Connection Issues
- Ensure ScanImage is running with `hSI` in base workspace
- Verify Motor Controls window is open (Window → Motor Controls)
- Check for ScanImage UI component changes (restart ScanImage if needed)

### Performance
- Increase refresh periods for slower computers
- Disable metrics recording for faster stepping
- Use larger step sizes for quick positioning

### Common Errors
- **"Motor Controls window not found"**: Open Motor Controls in ScanImage
- **"Missing UI elements"**: Restart ScanImage Motor Controls window
- **Movement not working**: Check ScanImage is not busy/acquiring

## Examples

### Automated Focus Search
```matlab
app = ZStageControlApp();

% Move to starting position
app.Controller.setPosition(1000);  % 1000 μm

% Run automated scan with metrics
app.Controller.startAutoStepping(2, 50, 0.3, 1, true);  % 2μm steps, 50 steps, 0.3s delay, up, record metrics

% Wait for completion, then find best focus
metrics = app.Controller.getAutoStepMetrics();
[~, bestIdx] = max(metrics.Values.Std_Dev);
bestPosition = metrics.Positions(bestIdx);
app.Controller.setPosition(bestPosition);
```

### Position Mapping
```matlab
app = ZStageControlApp();

% Save multiple positions of interest
app.Controller.setPosition(500);
app.Controller.markCurrentPosition('Sample Surface');

app.Controller.setPosition(750);  
app.Controller.markCurrentPosition('Mid Section');

app.Controller.setPosition(1000);
app.Controller.markCurrentPosition('Deep Focus');

% Return to saved position
app.Controller.goToMarkedPosition(1);  % Go to first saved position
```

## License

See the LICENSE file for details.

## Support

For issues or customization requests:
1. Check troubleshooting section above
2. Verify ScanImage version compatibility
3. Provide specific error messages and screenshots
4. Include Motor Controls GUI configuration details
