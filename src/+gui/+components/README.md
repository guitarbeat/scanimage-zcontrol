# App Designer Component Integration

This document describes the integration of MATLAB App Designer components in the GUI module and provides important compatibility notes.

## Implemented Components

### 1. RangeSlider

The RangeSlider component (introduced in MATLAB R2020b) provides a dual-handle slider for setting minimum and maximum Z positions in a single control. This replaces the separate min/max Z position controls with a more intuitive interface.

**Implementation Details:**
- Located in `UIComponentFactory.createZRangeSlider`
- Connected to existing controller methods for compatibility
- Maintains backward compatibility through property mapping

**Compatibility Notes:**
- Requires MATLAB R2020b or newer
- Falls back to separate controls if RangeSlider is not available

### 2. StateButton

StateButton components (introduced in MATLAB R2019b) are used for Focus and Grab buttons to provide clear visual state feedback.

**Implementation Details:**
- Implemented in `UIComponentFactory.createScanImageControls`
- State is properly managed through callbacks
- Auto-resets state for momentary actions (like Grab Frame)

**Compatibility Notes:**
- State buttons use different callback properties (ValueChangedFcn instead of ButtonPushedFcn)
- Compatible with MATLAB R2019b and newer

## Known Limitations

1. **uistack Limitations**: The `uistack` function is not supported with uifigure. Any attempts to use it (such as in status bar positioning) will result in errors.

2. **Layout Properties**: Some layout properties like 'Width' are not supported in GridLayoutOptions. Use alternate approaches for controlling component sizes:
   - Adjust grid column widths
   - Use nested layout containers
   - Set component properties after creation

3. **App Designer vs. GUIDE Compatibility**: Be cautious when mixing App Designer components with traditional GUIDE components, as some functionality may not be compatible.

## Best Practices

1. **Version Checks**: Always check MATLAB version before using newer components:
   ```matlab
   hasNewUIControls = ~verLessThan('matlab', '9.8'); % R2020a or newer
   ```

2. **Graceful Degradation**: Provide fallbacks for newer components:
   ```matlab
   if hasNewUIControls
       % Use App Designer component
   else
       % Use traditional component
   end
   ```

3. **Error Handling**: Wrap component creation in try-catch blocks to handle compatibility issues:
   ```matlab
   try
       % Create App Designer component
   catch ME
       warning('Error creating component: %s', ME.message);
       % Create alternative component
   end
   ```

## Future Improvements

1. Add ButtonGroup components for better visual organization
2. Implement TabGroup for advanced interface organization
3. Use more ToggleButtons for binary state controls
4. Explore Tree component for structured data display
5. Consider Spinner component for numeric input 