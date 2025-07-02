# FoilView - Z-Stage Control Application

A modern MATLAB GUI for microscope Z-stage positioning control optimized for foil analysis workflows.

## Directory Structure

```
src/
├── setup_foilview.m     # Setup script (run this first)
├── README.md            # This documentation
│
├── app/                 # Main Application Entry Point
│   └── foilview.m       # Main application class
│
├── core/                # Core Controllers & Business Logic
│   ├── foilview_controller.m  # Z-stage positioning and metrics
│   └── foilview_logic.m       # Business logic and validation
│
├── ui/                  # User Interface Components
│   ├── foilview_ui.m         # UI component creation
│   ├── foilview_updater.m    # UI state management
│   └── foilview_plot.m       # Metrics plotting functionality
│
└── utils/               # Utilities & Helper Functions
    ├── foilview_constants.m  # Centralized constants and configuration
    ├── foilview_utils.m      # Common utilities and error handling
    └── foilview_manager.m    # Consolidated management (callbacks, initialization, windows)
```

## Quick Start

1. **Setup and verify the environment:**
   ```matlab
   cd('path/to/scanimage-zcontrol/src')
   setup_foilview()  % This also verifies the refactoring was successful
   ```

2. **Launch the application:**
   ```matlab
   app = foilview();
   ```

3. **Clean shutdown:**
   ```matlab
   delete(app);
   ```

## Architecture Overview

### Core Components

- **`foilview`** - Main application class that orchestrates all components
- **`foilview_controller`** - Handles Z-stage hardware control and metrics calculation
- **`foilview_logic`** - Contains business logic, validation, and workflow management

### User Interface

- **`foilview_ui`** - Creates all UI components (tabs, buttons, controls)
- **`foilview_updater`** - Manages UI state updates and display refresh
- **`foilview_plot`** - Handles metrics plotting and GUI expansion/collapse

### Utilities

- **`foilview_constants`** - Centralized constants and configuration values
- **`foilview_utils`** - Common utility functions for error handling, validation, and formatting  
- **`foilview_manager`** - Consolidated management for callbacks, initialization, and window management

## Key Features

- **Tabbed Interface**: Manual Control, Auto Step, and Bookmarks
- **Real-time Metrics**: Position tracking and focus metrics display
- **Expandable Plotting**: Side-by-side metrics visualization
- **Position Bookmarks**: Save and navigate to important Z locations
- **Automated Sequences**: Configurable stepping with data collection
- **ScanImage Integration**: Automatic hardware detection with simulation fallback

## Dependencies

- MATLAB R2019b or later
- MATLAB App Designer
- ScanImage (optional - runs in simulation mode without it)

## Development Notes

The codebase follows these design principles:

1. **Separation of Concerns** - Each class has a specific responsibility
2. **DRY Principle** - Common functionality consolidated in utilities
3. **Event-driven Architecture** - Loose coupling between components
4. **Defensive Programming** - Comprehensive error handling and validation
5. **Performance Optimization** - Throttled updates and efficient data handling
6. **Code Quality** - Automated verification through enhanced setup script

### Refactoring Verification

The `setup_foilview()` script now includes comprehensive refactoring verification:
- Validates that old manager files have been removed
- Confirms new consolidated manager exists and works
- Tests basic instantiation and functionality
- Provides detailed feedback on the consolidation process

## Troubleshooting

If you encounter issues:

1. **Classes not found**: Re-run `setup_foilview()` to ensure paths are correct
2. **ScanImage errors**: The app will automatically switch to simulation mode
3. **UI not responding**: Check MATLAB command window for error messages
4. **Timer errors**: Use `delete(app)` for proper cleanup

## Support

For issues or questions, check the error messages in the MATLAB command window. The application includes comprehensive error logging and user-friendly alerts. 