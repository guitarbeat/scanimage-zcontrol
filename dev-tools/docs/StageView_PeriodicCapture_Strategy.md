# StageView Periodic Capture Strategy

## Overview
This document outlines a strategy to enable multiple camera monitoring in StageView using periodic capture instead of continuous live feeds. This approach works around hardware bandwidth limitations by cycling through cameras, taking snapshots in sequence, and displaying them in a rotating fashion.

## Core Concept
Instead of maintaining continuous live feeds (which consume too much bandwidth), we implement a "round-robin" capture system:

1. **Open Camera A** → **Take Snapshot** → **Close Camera A**
2. **Open Camera B** → **Take Snapshot** → **Close Camera B** 
3. **Open Camera C** → **Take Snapshot** → **Close Camera C**
4. **Return to Camera A** → **Repeat Cycle**

Each camera gets exclusive hardware access for a brief moment, then releases it completely before the next camera opens.

## Architecture Changes

### New Properties
```matlab
properties (Access = private)
    % Periodic Capture System
    SelectedCameras = {}           % Cell array of selected camera names
    CaptureTimer = []              % Timer for periodic capture cycle
    CurrentCameraIndex = 1         % Index of current camera in cycle
    CaptureInterval = 1.0          % Seconds between captures (configurable)
    
    % Display Management
    CameraDisplays = containers.Map() % Camera name -> display data struct
    DisplayFigure = []             % Single figure for all camera displays
    DisplayLayout = []             % Tiled layout for multiple camera views
    
    % Capture State
    IsPeriodicCaptureActive = false
    LastCaptureTime = datetime.empty
    CaptureErrors = containers.Map() % Track errors per camera
end
```

### Display Data Structure
```matlab
% Each entry in CameraDisplays contains:
displayData = struct(...
    'name', cameraName, ...
    'axes', axesHandle, ...
    'image', imageHandle, ...
    'lastUpdate', datetime('now'), ...
    'isActive', true, ...
    'errorCount', 0 ...
);
```

## Implementation Strategy

### Phase 1: Multi-Select Camera Interface

#### UI Changes
```matlab
% Modify camera listbox to support multi-select
obj.CameraListBox.Multiselect = 'on';

% Add new buttons
obj.StartPeriodicButton = uibutton(controlLayout, 'push');
obj.StartPeriodicButton.Text = 'Start Periodic Capture';
obj.StartPeriodicButton.BackgroundColor = [0.2 0.8 0.4];

obj.StopPeriodicButton = uibutton(controlLayout, 'push');
obj.StopPeriodicButton.Text = 'Stop Periodic Capture';
obj.StopPeriodicButton.BackgroundColor = [0.8 0.2 0.2];

% Add interval control
obj.IntervalSpinner = uispinner(controlLayout);
obj.IntervalSpinner.Limits = [0.5 10];
obj.IntervalSpinner.Value = 1.0;
obj.IntervalSpinner.Step = 0.1;
```

#### Camera Selection Logic
```matlab
function updateSelectedCameras(obj)
    % Get selected cameras from listbox
    selectedItems = obj.CameraListBox.Value;
    
    % Handle single vs multiple selection
    if ischar(selectedItems)
        obj.SelectedCameras = {selectedItems};
    else
        obj.SelectedCameras = selectedItems;
    end
    
    % Filter out invalid selections
    obj.SelectedCameras = obj.SelectedCameras(...
        ~strcmp(obj.SelectedCameras, 'No cameras detected'));
    
    obj.updateUI();
end
```

### Phase 2: Periodic Capture Engine

#### Core Capture Cycle
```matlab
function startPeriodicCapture(obj)
    % Initialize periodic capture system
    
    if obj.IsPeriodicCaptureActive
        return; % Already running
    end
    
    if isempty(obj.SelectedCameras)
        uialert(obj.UIFigure, 'Please select cameras for periodic capture.', 'No Selection');
        return;
    end
    
    % Stop any existing live previews
    obj.stopAllCameras();
    
    % Initialize display system
    obj.createMultiCameraDisplay();
    
    % Reset capture state
    obj.CurrentCameraIndex = 1;
    obj.CaptureErrors.remove(obj.CaptureErrors.keys);
    
    % Create and start capture timer
    obj.CaptureInterval = obj.IntervalSpinner.Value;
    obj.CaptureTimer = timer(...
        'ExecutionMode', 'fixedRate', ...
        'Period', obj.CaptureInterval, ...
        'TimerFcn', @(~,~) obj.captureNextCamera(), ...
        'ErrorFcn', @(~,e) obj.handleCaptureError(e));
    
    obj.IsPeriodicCaptureActive = true;
    start(obj.CaptureTimer);
    
    obj.updateStatusLabel();
    obj.updateUI();
end
```

#### Single Camera Capture Cycle
```matlab
function captureNextCamera(obj)
    % Capture from the next camera in the rotation
    
    if isempty(obj.SelectedCameras)
        obj.stopPeriodicCapture();
        return;
    end
    
    % Get current camera name
    cameraName = obj.SelectedCameras{obj.CurrentCameraIndex};
    
    % Update status
    obj.StatusLabel.Text = sprintf('Capturing from %s...', cameraName);
    drawnow;
    
    success = false;
    cam = [];
    
    try
        % CRITICAL: Open camera exclusively
        cam = webcam(cameraName);
        
        % Brief pause to ensure camera is ready
        pause(0.1);
        
        % Capture snapshot
        img = snapshot(cam);
        
        % Update display immediately
        obj.updateCameraDisplay(cameraName, img);
        
        success = true;
        
    catch ME
        % Log error but continue with next camera
        obj.handleCameraError(cameraName, ME);
        
    end
    
    % CRITICAL: Always close camera to free hardware
    try
        if ~isempty(cam)
            clear cam; % This releases the webcam object
        end
    catch
        % Ignore cleanup errors
    end
    
    % Update error tracking
    if success
        obj.CaptureErrors(cameraName) = 0; % Reset error count
    else
        currentErrors = 0;
        if obj.CaptureErrors.isKey(cameraName)
            currentErrors = obj.CaptureErrors(cameraName);
        end
        obj.CaptureErrors(cameraName) = currentErrors + 1;
    end
    
    % Move to next camera
    obj.CurrentCameraIndex = obj.CurrentCameraIndex + 1;
    if obj.CurrentCameraIndex > length(obj.SelectedCameras)
        obj.CurrentCameraIndex = 1; % Wrap around
    end
    
    % Update status
    obj.updatePeriodicStatus();
end
```

### Phase 3: Multi-Camera Display System

#### Display Creation
```matlab
function createMultiCameraDisplay(obj)
    % Create a single figure with tiled layout for all selected cameras
    
    numCameras = length(obj.SelectedCameras);
    if numCameras == 0
        return;
    end
    
    % Calculate grid dimensions (prefer wider layouts)
    if numCameras <= 2
        rows = 1; cols = numCameras;
    elseif numCameras <= 4
        rows = 2; cols = 2;
    elseif numCameras <= 6
        rows = 2; cols = 3;
    else
        rows = ceil(sqrt(numCameras));
        cols = ceil(numCameras / rows);
    end
    
    % Create display figure
    obj.DisplayFigure = figure(...
        'Name', 'Multi-Camera Periodic View', ...
        'NumberTitle', 'off', ...
        'Position', [300, 200, 800, 600], ...
        'CloseRequestFcn', @(~,~) obj.onDisplayFigureClose());
    
    % Create tiled layout
    obj.DisplayLayout = tiledlayout(obj.DisplayFigure, rows, cols);
    obj.DisplayLayout.TileSpacing = 'compact';
    obj.DisplayLayout.Padding = 'compact';
    
    % Create axes for each camera
    obj.CameraDisplays = containers.Map();
    
    for i = 1:numCameras
        cameraName = obj.SelectedCameras{i};
        
        % Create axes in next tile
        ax = nexttile(obj.DisplayLayout);
        
        % Create placeholder image
        placeholderImg = zeros(240, 320, 3, 'uint8'); % Default size
        imgHandle = imshow(placeholderImg, 'Parent', ax);
        
        % Set title
        title(ax, sprintf('%s (Waiting...)', cameraName), ...
            'FontSize', 10, 'Interpreter', 'none');
        
        % Store display data
        displayData = struct(...
            'name', cameraName, ...
            'axes', ax, ...
            'image', imgHandle, ...
            'lastUpdate', datetime.empty, ...
            'isActive', true, ...
            'errorCount', 0);
        
        obj.CameraDisplays(cameraName) = displayData;
    end
end
```

#### Display Updates
```matlab
function updateCameraDisplay(obj, cameraName, img)
    % Update the display for a specific camera
    
    if ~obj.CameraDisplays.isKey(cameraName)
        return;
    end
    
    displayData = obj.CameraDisplays(cameraName);
    
    try
        % Update image data
        set(displayData.image, 'CData', img);
        
        % Update title with timestamp
        timeStr = char(datetime('now', 'Format', 'HH:mm:ss'));
        title(displayData.axes, sprintf('%s (%s)', cameraName, timeStr), ...
            'FontSize', 10, 'Interpreter', 'none', 'Color', [0.2 0.6 0.2]);
        
        % Update last update time
        displayData.lastUpdate = datetime('now');
        displayData.errorCount = 0;
        
        obj.CameraDisplays(cameraName) = displayData;
        
    catch ME
        FoilviewUtils.logException('StageView', ME, ...
            sprintf('Failed to update display for %s', cameraName));
    end
end
```

### Phase 4: Error Handling and Recovery

#### Camera Error Management
```matlab
function handleCameraError(obj, cameraName, ME)
    % Handle errors for specific cameras
    
    FoilviewUtils.logException('StageView', ME, ...
        sprintf('Periodic capture error for %s', cameraName));
    
    % Update display to show error
    if obj.CameraDisplays.isKey(cameraName)
        displayData = obj.CameraDisplays(cameraName);
        
        % Update title to show error
        title(displayData.axes, sprintf('%s (ERROR)', cameraName), ...
            'FontSize', 10, 'Interpreter', 'none', 'Color', [0.8 0.2 0.2]);
        
        displayData.errorCount = displayData.errorCount + 1;
        obj.CameraDisplays(cameraName) = displayData;
    end
    
    % If too many consecutive errors, consider removing camera
    if obj.CaptureErrors.isKey(cameraName) && obj.CaptureErrors(cameraName) > 5
        obj.disableCamera(cameraName);
    end
end

function disableCamera(obj, cameraName)
    % Temporarily disable a problematic camera
    
    % Remove from selected cameras
    obj.SelectedCameras = obj.SelectedCameras(...
        ~strcmp(obj.SelectedCameras, cameraName));
    
    % Update display
    if obj.CameraDisplays.isKey(cameraName)
        displayData = obj.CameraDisplays(cameraName);
        title(displayData.axes, sprintf('%s (DISABLED)', cameraName), ...
            'FontSize', 10, 'Interpreter', 'none', 'Color', [0.5 0.5 0.5]);
    end
    
    % Adjust current index if needed
    if obj.CurrentCameraIndex > length(obj.SelectedCameras)
        obj.CurrentCameraIndex = 1;
    end
    
    % Stop if no cameras left
    if isempty(obj.SelectedCameras)
        obj.stopPeriodicCapture();
    end
end
```

### Phase 5: User Controls and Configuration

#### Interval Control
```matlab
function onIntervalChanged(obj)
    % Update capture interval while running
    
    newInterval = obj.IntervalSpinner.Value;
    
    if obj.IsPeriodicCaptureActive && ~isempty(obj.CaptureTimer)
        % Stop current timer
        stop(obj.CaptureTimer);
        
        % Update period
        obj.CaptureTimer.Period = newInterval;
        obj.CaptureInterval = newInterval;
        
        % Restart timer
        start(obj.CaptureTimer);
        
        obj.StatusLabel.Text = sprintf('Interval updated to %.1fs', newInterval);
    end
end
```

#### Status Updates
```matlab
function updatePeriodicStatus(obj)
    % Update status label for periodic capture
    
    if ~obj.IsPeriodicCaptureActive
        return;
    end
    
    numCameras = length(obj.SelectedCameras);
    currentCamera = '';
    if numCameras > 0
        currentCamera = obj.SelectedCameras{obj.CurrentCameraIndex};
    end
    
    % Count active cameras (those without too many errors)
    activeCameras = 0;
    for i = 1:numCameras
        cameraName = obj.SelectedCameras{i};
        errorCount = 0;
        if obj.CaptureErrors.isKey(cameraName)
            errorCount = obj.CaptureErrors(cameraName);
        end
        if errorCount < 5
            activeCameras = activeCameras + 1;
        end
    end
    
    obj.StatusLabel.Text = sprintf('Periodic: %d/%d active (Next: %s)', ...
        activeCameras, numCameras, currentCamera);
    obj.StatusLabel.FontColor = [0.2 0.6 0.8];
end
```

## Integration with Existing Features

### Recording Integration
The periodic capture system can be extended to support recording:

```matlab
function recordPeriodicFrames(obj)
    % Record frames from periodic capture
    
    if ~obj.IsRecording || isempty(obj.SelectedCameras)
        return;
    end
    
    % Record the most recent frame from each camera
    for i = 1:length(obj.SelectedCameras)
        cameraName = obj.SelectedCameras{i};
        if obj.CameraDisplays.isKey(cameraName)
            displayData = obj.CameraDisplays(cameraName);
            if ~isempty(displayData.lastUpdate)
                % Get current image data
                img = get(displayData.image, 'CData');
                
                % Write to video (could create separate files per camera)
                writeVideo(obj.VideoWriterObj, img);
            end
        end
    end
end
```

### Snapshot Integration
```matlab
function capturePeriodicSnapshots(obj)
    % Capture snapshots from all active cameras
    
    if isempty(obj.SelectedCameras)
        uialert(obj.UIFigure, 'No cameras selected for periodic capture.', 'No Cameras');
        return;
    end
    
    timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd_HH-mm-ss'));
    
    for i = 1:length(obj.SelectedCameras)
        cameraName = obj.SelectedCameras{i};
        
        try
            % Temporarily capture from this camera
            cam = webcam(cameraName);
            img = snapshot(cam);
            clear cam;
            
            % Save snapshot
            filename = sprintf('Snapshot_%s_%s.png', ...
                strrep(cameraName, ' ', '_'), timestamp);
            imwrite(img, filename);
            
        catch ME
            FoilviewUtils.logException('StageView', ME, ...
                sprintf('Failed to capture snapshot from %s', cameraName));
        end
    end
    
    obj.StatusLabel.Text = sprintf('Snapshots saved for %d cameras', ...
        length(obj.SelectedCameras));
end
```

## Performance Considerations

### Timing Optimization
- **Minimum Interval**: 0.5 seconds (allows hardware to settle)
- **Default Interval**: 1.0 seconds (good balance of responsiveness and resource usage)
- **Maximum Interval**: 10 seconds (for very slow monitoring)

### Memory Management
- Reuse image handles instead of creating new ones
- Clear webcam objects immediately after use
- Limit image resolution if needed for performance

### Error Recovery
- Automatic retry with exponential backoff
- Camera disable after consecutive failures
- Graceful degradation when cameras become unavailable

## Benefits of This Approach

1. **Hardware Compatibility**: Works with bandwidth-limited USB hubs
2. **Resource Efficiency**: Minimal memory and CPU usage
3. **Scalability**: Can handle many cameras (limited by capture interval)
4. **Reliability**: Robust error handling and recovery
5. **User Control**: Configurable update intervals
6. **Visual Feedback**: Clear status indication for each camera

## Implementation Priority

1. **Phase 1**: Multi-select UI and basic periodic capture
2. **Phase 2**: Multi-camera display system
3. **Phase 3**: Error handling and recovery
4. **Phase 4**: Integration with recording and snapshots
5. **Phase 5**: Performance optimization and user preferences

This strategy provides a practical solution for multi-camera monitoring while respecting hardware limitations and maintaining system stability.