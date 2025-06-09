# GUI Module for ScanImage Z-Control

This module contains the GUI components for the ScanImage Z-Control system.

## Refactored Structure

The FocusGUI has been refactored into a modular structure:

### Main Classes
- `FocusGUI.m` - Main class that coordinates the GUI creation and manages callbacks

### Components Module
- `+components/UIComponentFactory.m` - Factory class for creating UI components with consistent styling

### Handlers Module
- `+handlers/UIEventHandlers.m` - Event handler class for handling UI events and updates

## Design Patterns Used

1. **Factory Pattern** - The UIComponentFactory class creates UI components with consistent styling
2. **Facade Pattern** - The main GUI class provides a simplified interface to the complex UI subsystem
3. **Observer Pattern** - The event handlers respond to UI events and update the UI accordingly

## Usage

To use the refactored GUI:

```matlab
% Create a controller
controller = YourControllerClass();

% Create the GUI
gui = gui.FocusGUI(controller);

% Initialize the GUI
gui.create();
```

## Benefits of Refactoring

1. **Improved Maintainability** - Separating UI creation from event handling makes the code easier to maintain
2. **Better Code Organization** - The code is now organized into logical modules
3. **Reduced Duplication** - Common UI creation code is now centralized in the factory class
4. **Easier Testing** - Components can be tested independently
5. **Enhanced Flexibility** - New UI components can be added to the factory without modifying the main GUI class 