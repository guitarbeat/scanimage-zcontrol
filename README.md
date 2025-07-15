# FoilView - Z-Control Application

A MATLAB application for controlling Z-stage positioning with ScanImage integration.

## Recent Fix

**Issue**: The application was failing to start with the error:
```
Functionality not supported with figures created with the uifigure function.
Error in UiBuilder/createManualControlContainer (line 187)
    stepSizePanel.BorderWidth = 1;
```

**Solution**: Removed unsupported properties from uifigure-based components:
- Removed `BorderWidth = 1` from stepSizePanel
- Removed `HighlightColor = [0.8 0.8 0.8]` from stepSizePanel

These properties are not supported in uifigure-based applications and were causing the initialization to fail.

## Running the Application

### Method 1: Using the startup script (Recommended)
```matlab
startup;  % Add all necessary paths
foilview; % Start the application
```

### Method 2: Manual path setup
```matlab
addpath('src');
addpath('src/app');
addpath('src/views');
addpath('src/views/components');
addpath('src/controllers');
addpath('src/utils');
addpath('src/managers');
foilview;
```

### Method 3: Command line
```bash
matlab -batch "startup; foilview"
```

## Expected Behavior

When running outside of ScanImage, you may see warnings like:
```
ScanImageManager: Connection failed: Unrecognized function or variable 'hSI'.
```

This is normal and expected - the application will run in simulation mode when ScanImage is not available.

## Features

- Manual Z-stage control with adjustable step sizes
- Automatic stepping with configurable parameters
- Real-time position and metric display
- Integration with ScanImage for live imaging
- Bookmarks and stage view windows
- Metrics plotting and export functionality
- **Metadata logging with bookmark integration** - Bookmarks are automatically saved to the imaging metadata CSV file

## Requirements

- MATLAB R2019b or later (for uifigure support)
- ScanImage (optional, for live imaging integration)

## Bookmark Metadata Integration

Bookmarks created in the application are now automatically saved to the imaging metadata CSV file. The metadata file includes three new columns:

- **BookmarkLabel**: The label/name of the bookmark
- **BookmarkMetricType**: The type of metric associated with the bookmark (e.g., "Std Dev", "Mean", "Max")
- **BookmarkMetricValue**: The value of the metric at the bookmark position

### How it works:

1. **Regular metadata entries**: When imaging frames are captured, these fields are empty
2. **Bookmark entries**: When bookmarks are created, these fields contain the bookmark information
3. **Automatic integration**: No manual intervention required - bookmarks are automatically logged

### Testing the feature:

Run the test script to see the bookmark metadata integration in action:
```matlab
test_bookmark_metadata
```

This will create several test bookmarks and demonstrate how they appear in the metadata file. 