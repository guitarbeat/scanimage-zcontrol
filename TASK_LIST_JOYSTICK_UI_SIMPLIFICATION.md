# Task List: Simplify Joystick UI and Implement Z/Y/X Controls

## Overview
This task list outlines the steps to simplify the current MJC3 joystick user interface and implement the specific Z, Y, and X axis controls shown in the reference image.

## Phase 1: Simplify Current UI Structure

### Task 1.1: Remove Complex Sections
- [x] Remove the visualizer section (joystick position plot)
- [x] Remove the movement monitoring section  
- [x] Remove the calibration section
- [x] Remove the logging section
- [x] Keep only essential controls

### Task 1.2: Streamline Control Section
- [x] Simplify to just Enable/Disable button
- [x] Keep step factor control
- [x] Add simple status display
- [x] Remove settings button

## Phase 2: Implement Z/Y/X Controls Based on Image

### Task 2.1: Create Analog Controls Section
- [x] Add "Analog Controls" panel similar to image
- [x] Implement controls for:
  - **Analog Z** (Z-axis movement)
  - **Analog X** (X-axis movement) 
  - **Analog Y** (Y-axis movement)
- [x] Each control should have:
  - Current value display
  - Numerical input field for sensitivity
  - Action dropdown (Move Continuous, Delta 1, etc.)
  - Calibrate button

### Task 2.2: Implement Button Controls
- [x] Add "Buttons" section
- [x] Configure Button 1 with:
  - State indicator (green circle when active)
  - Target dropdown (Selected)
  - Action dropdown (Fire 1)
- [x] Add support for additional buttons if needed

### Task 2.3: Add Mapping Controls
- [x] Add "Mapping" section with:
  - Mapping file dropdown
  - New/Save/Remove buttons
- [x] Implement mapping file management

## Phase 3: Core Functionality Implementation

### Task 3.1: Extend MEX Controller for X/Y Movement
- [x] Modify `MJC3_MEX_Controller.m` to support X and Y axis movement
- [x] Add separate step factors for X, Y, and Z axes
- [x] Implement movement logic for all three axes

### Task 3.2: Update ScanImageZController
- [x] Rename to `ScanImageController` to handle X, Y, Z
- [x] Add methods for X and Y movement
- [x] Maintain backward compatibility with Z-only mode

### Task 3.3: Implement Calibration System
- [ ] Add calibration logic for each axis
- [ ] Store calibration data persistently
- [ ] Provide calibration UI similar to image

## Phase 4: UI Integration

### Task 4.1: Create Simplified MJC3View
- [ ] Replace current complex UI with simplified version
- [ ] Focus on essential controls only
- [ ] Implement the exact layout from the image

### Task 4.2: Add Real-time Value Display
- [ ] Show current analog values (0 for all axes initially)
- [ ] Update values in real-time as joystick moves
- [ ] Color-code active vs inactive states

## Phase 5: Testing and Validation

### Task 5.1: Test Multi-axis Movement
- [ ] Verify X, Y, Z movement works independently
- [ ] Test calibration functionality
- [ ] Validate mapping system

### Task 5.2: Integration Testing
- [ ] Test with ScanImage integration
- [ ] Verify simulation mode still works
- [ ] Test error handling and recovery

## Phase 6: Documentation and Polish

### Task 6.1: Update Documentation
- [ ] Update README with new multi-axis capabilities
- [ ] Document calibration procedures
- [ ] Add usage examples

### Task 6.2: Final UI Polish
- [ ] Ensure consistent styling
- [ ] Add tooltips and help text
- [ ] Optimize layout for different screen sizes

## Implementation Priority

### High Priority (Phase 1-2)
1. Simplify current UI structure
2. Implement basic Z/Y/X controls
3. Create analog controls section

### Medium Priority (Phase 3-4)
4. Extend MEX controller functionality
5. Update core controllers
6. Integrate new UI

### Low Priority (Phase 5-6)
7. Comprehensive testing
8. Documentation updates
9. Final polish

## Success Criteria

- [ ] Simplified UI with only essential controls
- [ ] Z, Y, X axis controls matching reference image
- [ ] Real-time value display for all axes
- [ ] Calibration functionality for each axis
- [ ] Mapping system for controller profiles
- [ ] Backward compatibility with existing Z-only functionality
- [ ] Proper error handling and recovery
- [ ] Updated documentation

## Notes

- The reference image shows a Windows-style input device configuration interface
- Current implementation focuses only on Z-axis movement
- New implementation should support full 3-axis control
- Maintain compatibility with existing ScanImage integration
- Consider performance implications of multi-axis polling

## Recent Improvements (2025-07-30)

### ✅ Cleanup Improvements
- **Enhanced MJC3View cleanup**: Added proper controller stopping and disconnection
- **Improved MJC3_MEX_Controller cleanup**: Added robust timer cleanup and MEX connection closing
- **Window close handling**: Added `onWindowClose` method to ensure proper cleanup when window is closed
- **Main application cleanup**: Enhanced foilview cleanup to properly handle MJC3View disposal

### ✅ UI Simplification Completed
- **Removed complex sections**: Visualizer, monitoring, calibration, logging sections removed
- **Streamlined controls**: Simplified to essential Enable/Disable, step factor, and status
- **Analog controls implemented**: Z, Y, X axis controls with real-time value display
- **Calibration system**: Basic calibration dialog for each axis 