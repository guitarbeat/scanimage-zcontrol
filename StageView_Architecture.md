# StageView Architecture and Relationships

## Overview
The StageView is a standalone camera management window within the Foilview microscopy application. It provides live camera feed capabilities, video recording, and snapshot functionality to complement the main stage positioning interface.

## Core Architecture

### Class Structure
```
StageView (handle class)
├── UI Components (Public Properties)
│   ├── UIFigure - Main window
│   ├── MainLayout - Grid layout container
│   ├── ControlPanel - Camera controls panel
│   ├── StatusLabel - Camera status display
│   ├── CameraListBox - Available cameras list
│   └── Control Buttons (Refresh, Start, Stop, Snapshot, Recording)
├── Camera State (Private Properties)
│   ├── ActivePreviews - Cell array of active camera feeds
│   ├── AvailableCameras - List of detected cameras
│   └── IsPreviewActive - Boolean state flag
└── Recording State (Private Properties)
    ├── IsRecording - Recording status
    ├── VideoWriterObj - Video file writer
    ├── VideoRecordTimer - Frame capture timer
    └── RecordingFileName - Output file path
```

### Key Design Patterns

#### 1. Handle Class Pattern
- StageView extends `handle` class for reference semantics
- Enables proper cleanup and resource management
- Allows multiple references to the same instance

#### 2. Resource Management Pattern
- Explicit cleanup in destructor (`delete` method)
- Safe resource release for cameras and video writers
- Timer management with proper stop/delete sequences

#### 3. State Management Pattern
- Clear separation between UI state and camera state
- Centralized state updates through `updateUI()` method
- Status synchronization between UI elements and internal state

## Integration with Main Application

### Parent-Child Relationship
```
foilview (Main App)
├── StageViewApp (Property)
│   └── StageView instance
├── Controller Integration
│   └── Independent operation (no direct controller dependency)
└── UI Integration
    ├── StatusControls.StageViewButton
    └── Window management callbacks
```

### Lifecycle Management

#### Creation Flow
1. User clicks StageView button in main app
2. `onStageViewButtonPushed()` callback triggered
3. `launchStageView()` method called
4. New `StageView()` instance created
5. UI components initialized and displayed

#### Destruction Flow
1. User closes StageView window OR clicks button again
2. `delete(app.StageViewApp)` called
3. StageView destructor executes
4. All camera resources released
5. UI figure deleted
6. Reference set to `[]` in main app

### Button State Management
The main application tracks StageView state through `updateWindowStatusButtons()`:
```matlab
isStageViewOpen = ~isempty(app.StageViewApp) && 
                  isvalid(app.StageViewApp) && 
                  isvalid(app.StageViewApp.UIFigure);
```

## Camera Management Architecture

### Camera Detection
- Uses MATLAB's `webcamlist` function
- Populates `AvailableCameras` property
- Updates UI listbox with available devices
- Handles detection failures gracefully

### Preview Management
```
ActivePreviews Structure:
{
  name: 'Camera Name',
  camera: webcam object,
  figure: MATLAB figure handle
}
```

#### Single Camera Constraint
- Only one camera preview active at a time
- New camera start stops existing previews
- Hardware resource management through exclusive access

#### Preview Lifecycle
1. **Start**: Create webcam object → Call `preview()` → Store handles
2. **Display**: MATLAB creates figure automatically → Custom close callback
3. **Stop**: Close preview → Clear camera object → Delete figure

### Video Recording System

#### Recording Architecture
- Uses MATLAB's `VideoWriter` class
- Motion JPEG AVI format (configurable)
- Timer-based frame capture at 15 FPS
- Asynchronous recording with error handling

#### Recording Flow
1. User selects output file via dialog
2. VideoWriter object created and opened
3. Timer started for periodic frame capture
4. Each timer tick captures and writes frame
5. Stop button or error triggers cleanup

## UI Component Architecture

### Layout Hierarchy
```
UIFigure (280x420)
└── MainLayout (GridLayout)
    └── ControlPanel (Panel)
        └── controlLayout (GridLayout)
            ├── StatusLabel (Row 1)
            ├── CameraListBox (Row 2)
            ├── RefreshButton (Row 3)
            ├── StartAllButton (Row 4)
            ├── StopAllButton (Row 5)
            ├── SnapshotAllButton (Row 6)
            ├── StartRecordingButton (Row 7)
            ├── StopRecordingButton (Row 8)
            ├── RecordingStatusLabel (Row 9)
            └── InstructionLabel (Row 10)
```

### Button State Logic
- **Start Button**: Enabled when cameras available
- **Stop Button**: Enabled when cameras active
- **Snapshot Button**: Enabled when cameras active
- **Record Start**: Enabled when preview active AND not recording
- **Record Stop**: Enabled only when recording

## Error Handling and Logging

### Exception Management
- All camera operations wrapped in try-catch blocks
- Uses `FoilviewUtils.logException()` for consistent logging
- User-friendly error dialogs via `uialert()`
- Graceful degradation on hardware failures

### Resource Cleanup
- Automatic cleanup on window close
- Manual cleanup methods for cameras and recording
- Timer management with safe stop procedures
- Memory leak prevention through proper handle management

## Key Features and Capabilities

### Camera Operations
- **Detection**: Automatic camera discovery and listing
- **Preview**: Live camera feed in separate window
- **Snapshot**: Single frame capture with timestamp
- **Recording**: Continuous video recording to file

### User Interface
- **Responsive Design**: Grid-based layout with proper sizing
- **Status Feedback**: Real-time status updates and color coding
- **Error Handling**: User-friendly error messages and recovery
- **Resource Management**: Proper cleanup and resource release

### Integration Points
- **Independent Operation**: No dependency on main app controller
- **Window Management**: Integrated with main app window tracking
- **Resource Sharing**: Exclusive camera access management
- **Event Handling**: Proper callback management and cleanup

## Technical Considerations

### Performance
- Single camera constraint prevents resource conflicts
- Timer-based recording for consistent frame rates
- Efficient memory management through proper cleanup
- Minimal UI updates to prevent performance issues

### Reliability
- Comprehensive error handling for hardware failures
- Resource cleanup on all exit paths
- State validation before operations
- Graceful degradation when cameras unavailable

### Maintainability
- Clear separation of concerns (UI, camera, recording)
- Consistent naming conventions and code structure
- Comprehensive logging for debugging
- Modular design for easy extension

## Multiple Live Feed Strategies

The current StageView implementation uses a single camera constraint for resource management. However, there are several strategies to enable multiple simultaneous live feeds:

### Strategy 1: Independent Webcam Objects (Recommended)
**Approach**: Create separate webcam objects for each camera
```matlab
% Multiple independent webcam objects
cam1 = webcam('Camera 1');
cam2 = webcam('Camera 2');
cam3 = webcam('Camera 3');

% Each with independent preview
preview(cam1);
preview(cam2);
preview(cam3);
```

**Advantages**:
- Simple implementation following MATLAB's standard pattern
- Each camera operates independently
- Natural resource isolation
- Easy error handling per camera

**Considerations**:
- Requires sufficient system resources (CPU, memory, USB bandwidth)
- Each preview creates its own figure window
- Manual window management needed

### Strategy 2: Parallel Computing Toolbox Integration
**Approach**: Use `parfor` loops for simultaneous camera operations
```matlab
% Parallel camera initialization
cameraNames = webcamlist;
numCameras = length(cameraNames);
cameras = cell(numCameras, 1);

parfor i = 1:numCameras
    cameras{i} = webcam(cameraNames{i});
    % Configure camera properties in parallel
end

% Parallel frame capture
frames = cell(numCameras, 1);
parfor i = 1:numCameras
    frames{i} = snapshot(cameras{i});
end
```

**Advantages**:
- Leverages parallel processing capabilities
- Reduced latency for simultaneous operations
- Efficient resource utilization on multi-core systems

**Considerations**:
- Requires Parallel Computing Toolbox license
- Preview operations may not work within parfor loops
- Complex error handling across parallel workers

### Strategy 3: Custom Multi-Camera Manager
**Approach**: Extend StageView with multi-camera architecture
```matlab
properties (Access = private)
    ActiveCameras = containers.Map(); % Camera name -> camera object
    PreviewFigures = containers.Map(); % Camera name -> figure handle
    CameraTimers = containers.Map();   % Camera name -> update timer
end
```

**Implementation Pattern**:
- Use containers.Map for dynamic camera management
- Individual timers for each camera's frame updates
- Centralized control with distributed preview windows
- Grid or tabbed layout for organized display

**Advantages**:
- Maintains current UI paradigm
- Scalable to any number of cameras
- Centralized control and monitoring
- Custom layout and organization options

### Strategy 4: Tiled Preview Layout
**Approach**: Single figure with multiple subplot regions
```matlab
% Create tiled layout for multiple camera feeds
fig = uifigure('Name', 'Multi-Camera View');
tLayout = tiledlayout(fig, 2, 2); % 2x2 grid for 4 cameras

% Create axes for each camera
for i = 1:4
    ax(i) = nexttile(tLayout);
    % Display camera feed in specific tile
end
```

**Advantages**:
- Organized, compact display
- Single window management
- Easy comparison between feeds
- Reduced screen real estate usage

**Considerations**:
- Fixed layout constraints
- Potential performance impact with multiple updates
- Complex coordinate management for interactions

### Strategy 5: Asynchronous Frame Capture
**Approach**: Timer-based frame updates for smooth playback
```matlab
% Timer for each camera with different update rates
for i = 1:numCameras
    cameraTimers{i} = timer(...
        'ExecutionMode', 'fixedRate', ...
        'Period', 1/frameRates(i), ...
        'TimerFcn', @(~,~) updateCameraFeed(i));
    start(cameraTimers{i});
end
```

**Advantages**:
- Smooth, independent frame rates per camera
- Non-blocking operation
- Customizable update frequencies
- Efficient resource scheduling

**Considerations**:
- Timer management complexity
- Potential synchronization issues
- Memory management for frame buffers

### Strategy 6: Hybrid Approach (Recommended for Production)
**Approach**: Combine multiple strategies for optimal performance

**Architecture**:
1. **Detection Phase**: Use `webcamlist` to discover all cameras
2. **Initialization Phase**: Create webcam objects independently
3. **Preview Phase**: Use custom multi-camera manager with tiled layout
4. **Recording Phase**: Parallel capture using timer-based approach
5. **Cleanup Phase**: Systematic resource release

**Implementation Considerations**:
- **Resource Management**: Monitor system resources and adapt
- **Error Handling**: Graceful degradation when cameras fail
- **UI Responsiveness**: Separate UI thread from camera operations
- **Performance Optimization**: Dynamic frame rate adjustment
- **User Control**: Individual camera enable/disable controls

### Hardware and System Considerations

#### USB Bandwidth Limitations
- **USB 2.0**: ~480 Mbps shared across all devices on hub
- **USB 3.0**: ~5 Gbps with better power management
- **Recommendation**: Use USB 3.0 hubs for multiple high-resolution cameras

#### System Resource Requirements
- **CPU**: Multi-core recommended for parallel processing
- **Memory**: ~100-200 MB per active camera feed
- **Graphics**: Hardware acceleration for multiple video streams

#### Camera Compatibility
- **Driver Support**: Ensure all cameras use compatible drivers
- **Resolution Matching**: Consider standardizing resolutions
- **Frame Rate Balancing**: Adjust rates based on system capabilities

### Implementation Roadmap

#### Phase 1: Multi-Camera Detection
- Extend `refreshCameraList()` to handle multiple selections
- Add multi-select capability to camera listbox
- Update UI to show multiple camera status

#### Phase 2: Independent Preview Windows
- Modify `startSelectedCameras()` to handle multiple cameras
- Implement window management for multiple previews
- Add individual camera controls

#### Phase 3: Unified Multi-Camera Interface
- Implement tiled layout option
- Add camera grid management
- Integrate recording for multiple streams

#### Phase 4: Performance Optimization
- Add parallel processing support
- Implement adaptive frame rates
- Add system resource monitoring

This architecture provides a robust, user-friendly camera management system that integrates seamlessly with the main Foilview application while maintaining independence and proper resource management.