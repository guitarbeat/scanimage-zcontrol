# Z-Stage Control Application Documentation

## Overview

The Z-Stage Control application is a MATLAB-based tool designed for precise microscope Z-axis positioning and focus optimization. It integrates with ScanImage microscopy software to provide real-time metrics-based focus control, automated stepping sequences, and position management.

## Architecture

The application follows a Model-View-Controller (MVC) pattern with two main components:

### 1. **ZStageController.m** - Core Controller/Model
- **Purpose**: Handles all business logic, ScanImage integration, and data management
- **Type**: MATLAB handle class with event notifications
- **Key Responsibilities**:
  - ScanImage hardware communication
  - Z-stage position control
  - Real-time image metrics calculation
  - Automated stepping sequences
  - Position bookmarking system
  - Event-driven architecture for UI updates

### 2. **ZStageControlApp.m** - GUI Interface/View
- **Purpose**: Provides user interface and handles user interactions
- **Type**: MATLAB App Designer application
- **Key Responsibilities**:
  - Tabbed user interface design
  - Real-time position and metrics display
  - Expandable plotting functionality
  - User input validation and feedback
  - Controller event handling and UI synchronization

---

## ZStageController.m - Detailed Analysis

### **Core Features**

#### **1. ScanImage Integration**
```matlab
% Automatic detection and connection to ScanImage
connectToScanImage()
```
- Detects running ScanImage instances
- Finds and connects to Motor Controls window
- Extracts UI elements for position control
- Handles connection loss gracefully with simulation mode

#### **2. Position Control**
```matlab
% Manual positioning
moveStage(microns)           % Relative movement
setPosition(position)        % Absolute positioning
resetPosition()              % Zero the position
```
- Supports both relative and absolute positioning
- Real-time position feedback from hardware
- Position validation and error handling

#### **3. Metrics System**
```matlab
% Available metrics (optimized based on testing)
METRIC_TYPES = {'Std Dev', 'Mean', 'Max'}
DEFAULT_METRIC = 'Std Dev'   % Best for focus detection
```

**Metric Calculations**:
- **Standard Deviation**: Primary focus metric - measures image contrast/sharpness
- **Mean**: Average pixel intensity - useful for exposure monitoring
- **Max**: Peak pixel intensity - useful for saturation detection

#### **4. Automated Stepping**
```matlab
startAutoStepping(stepSize, numSteps, delay, direction, recordMetrics)
```
- Configurable step size, count, and timing
- Bidirectional movement (up/down)
- Optional metrics recording during sequence
- Real-time progress tracking and control

#### **5. Position Bookmarking**
```matlab
markCurrentPosition(label)      % Save current position
goToMarkedPosition(index)       % Navigate to saved position
deleteMarkedPosition(index)     % Remove bookmark
```
- Named position storage with associated metrics
- Automatic "maximum metric" bookmarks during auto-stepping
- Persistent bookmark management

### **Event System**
```matlab
% Controller events for UI synchronization
events
    StatusChanged       % Connection status updates
    PositionChanged     % Position updates
    MetricChanged       % Metric value updates
    AutoStepComplete    % Auto-stepping completion
end
```

### **Configuration Constants**
```matlab
% Step size options (microns)
STEP_SIZES = [0.1, 0.5, 1, 5, 10, 50]

% Timing configuration
POSITION_REFRESH_PERIOD = 0.5   % Position update rate
METRIC_REFRESH_PERIOD = 1.0     % Metrics calculation rate
```

---

## ZStageControlApp.m - Detailed Analysis

### **User Interface Design**

#### **1. Main Window Layout**
- **Fixed-width design**: 320px base width with expandable plot area
- **Hierarchical structure**: Grid layout with fixed positioning
- **Real-time displays**: Large position readout and current metric value
- **Status integration**: Connection status and operation feedback

#### **2. Tabbed Interface**

##### **Manual Control Tab**
```matlab
% Direct positioning controls
Step Size Dropdown    % Predefined step sizes
▲ ▼ Buttons          % Up/down movement
ZERO Button          % Reset position to zero
```

##### **Auto Step Tab**
```matlab
% Automated sequence controls
Step Size Field       % Custom step size input
Steps Count Field     % Number of steps to execute
Delay Field          % Time between steps
Direction Buttons    % Up/down sequence direction
Record Metrics ☑     % Enable metrics collection
START/STOP Button    % Sequence control
```

##### **Bookmarks Tab**
```matlab
% Position management
Label Field + MARK   % Save current position
Position List        % Saved positions display
GO TO / DELETE       % Navigation and management
```

#### **3. Expandable Plotting System**
- **Integrated design**: Plot expands horizontally within main window
- **Real-time updates**: Automatic plot updates during auto-stepping
- **Multi-metric display**: All metrics plotted simultaneously with normalization
- **Export functionality**: Save metrics data to .mat files
- **Plot controls**: Clear data and export options

### **Key UI Features**

#### **1. Responsive Design**
```matlab
% Fixed panel positioning prevents layout issues
MainPanel.Position = [0, 0, WINDOW_WIDTH, WINDOW_HEIGHT]
MainPanel.AutoResizeChildren = 'off'
```

#### **2. Real-time Updates**
```matlab
% Automatic refresh timers
RefreshTimer = timer(Period=0.5s)  % Position updates
MetricTimer = timer(Period=1.0s)   % Metrics updates
```

#### **3. User Feedback System**
- **Visual status indicators**: Color-coded connection status
- **Progress tracking**: Auto-step progress display
- **Input validation**: Parameter checking with user alerts
- **Error handling**: Graceful degradation with informative messages

---

## Application Workflow

### **1. Startup Sequence**
1. Initialize UI components and controller
2. Attempt ScanImage connection
3. Start refresh timers for position and metrics
4. Set default metric to Standard Deviation
5. Display ready status

### **2. Manual Operation**
1. Select step size from dropdown
2. Use ▲/▼ buttons for positioning
3. Monitor real-time position and metric feedback
4. Save important positions as bookmarks

### **3. Automated Focus Finding**
1. Configure auto-stepping parameters
2. Enable "Record Metrics" checkbox
3. Choose direction and start sequence
4. Monitor real-time plot expansion
5. Review metrics plot for optimal focus position
6. Use automatically created "Max" bookmarks

### **4. Data Analysis**
1. Expand plot view to analyze metrics vs. position
2. Export metrics data for external analysis
3. Navigate to optimal positions using bookmarks
4. Clear plot data for new sequences

---

## Key Design Decisions

### **1. Metrics Optimization**
- **Reduced to 3 essential metrics** based on real-world testing
- **Standard Deviation as default** - proven most effective for focus detection
- **Removed redundant metrics** (Median, Focus Score) to simplify interface

### **2. Event-Driven Architecture**
- **Loose coupling** between controller and UI
- **Real-time responsiveness** through event notifications
- **Clean separation** of business logic and presentation

### **3. Robust ScanImage Integration**
- **Graceful degradation** to simulation mode when ScanImage unavailable
- **Automatic reconnection** capabilities
- **Error handling** for connection loss scenarios

### **4. User Experience Focus**
- **Immediate visual feedback** for all operations
- **Contextual controls** - manual and auto operations clearly separated
- **Intelligent defaults** - optimal settings pre-configured
- **Progressive disclosure** - expandable plot interface

---

## Technical Specifications

### **Dependencies**
- MATLAB R2019b or later (App Designer support)
- ScanImage software (optional - simulation mode available)
- Image Processing Toolbox (for gradient calculations)

### **Performance Characteristics**
- **Position refresh**: 2 Hz (500ms intervals)
- **Metrics calculation**: 1 Hz (1000ms intervals)
- **Auto-stepping timing**: User configurable (0-∞ seconds between steps)
- **Memory usage**: Minimal - metrics stored only during active recording

### **File Structure**
```
src/
├── ZStageController.m     # Core controller (573 lines)
├── ZStageControlApp.m     # GUI application (1223 lines)
└── README.md             # Basic usage instructions
```

---

## Usage Examples

### **Basic Focus Finding**
```matlab
% Launch application
app = ZStageControlApp();

% Manual approach:
% 1. Use ▲/▼ buttons to roughly position
% 2. Watch Std Dev metric increase near focus
% 3. Use smaller steps for fine positioning

% Automated approach:
% 1. Set step size (e.g., 1 μm)
% 2. Set steps count (e.g., 20)
% 3. Enable "Record Metrics"
% 4. Click START
% 5. Use plot to find maximum Std Dev position
```

### **Position Bookmarking Workflow**
```matlab
% Save optimal focus position
% 1. Navigate to best focus
% 2. Enter label "Best Focus"
% 3. Click MARK
% 4. Position saved with current metric value

% Return to saved position
% 1. Select "Best Focus" from list
% 2. Click GO TO
% 3. Stage moves to saved position
```

---

## Future Enhancement Opportunities

1. **Auto-focus algorithms** - Automated peak finding in metrics data
2. **Position history** - Undo/redo functionality for movements
3. **Custom protocols** - Programmable movement sequences
4. **Enhanced plotting** - Real-time metrics during manual operation
5. **Multi-position support** - Array scanning capabilities

---

## Conclusion

The Z-Stage Control application provides a robust, user-friendly interface for microscope focus control with the following key strengths:

- **Proven metrics system** optimized for real-world focus detection
- **Flexible operation modes** supporting both manual and automated workflows  
- **Professional UI design** with expandable plotting and comprehensive feedback
- **Reliable ScanImage integration** with graceful fallback capabilities
- **Extensible architecture** supporting future enhancements

The application successfully bridges the gap between ScanImage's motor controls and the specific needs of focus optimization workflows, providing a specialized tool that enhances microscopy productivity and precision. 