# Auto Step Control Code Map

This document maps out all the auto step related code locations in the foilview application.

## 🎯 Core Controller Logic

### `src/controllers/FoilviewController.m`
**Main auto step controller logic**

**Constants (lines 9-15):**
```matlab
DEFAULT_AUTO_STEP = 10      % Default step size (μm)
DEFAULT_AUTO_STEPS = 10     % Default number of steps
DEFAULT_AUTO_DELAY = 0.5    % Default delay between steps (seconds)
MIN_AUTO_STEPS = 1          % Minimum steps allowed
MAX_AUTO_STEPS = 1000       % Maximum steps allowed
MIN_AUTO_DELAY = 0.1        % Minimum delay (seconds)
MAX_AUTO_DELAY = 10.0       % Maximum delay (seconds)
```

**Properties (lines 53-56):**
```matlab
IsAutoRunning (1,1) logical = false    % Auto-stepping active flag
CurrentStep (1,1) double = 0           % Current step number
TotalSteps (1,1) double = 0            % Total steps to execute
AutoDirection (1,1) double = 1         % Direction: 1=up, -1=down
```

**Key Methods:**
- `startAutoStepping(stepSize, numSteps, delay, direction, recordMetrics)` (line 220)
- `stopAutoStepping()` (line 271)
- `startAutoSteppingWithValidation(app, autoControls, plotManager)` (line 342)
- `setAutoDirectionWithValidation(autoControls, direction)` (line 581)
- `executeAutoStep(stepSize)` (line 635) - Timer callback for each step

## 🎨 UI Components & Layout

### `src/views/components/UiBuilder.m`
**Auto controls UI creation**

**Main Function:**
- `createAutoStepContainer(mainLayout)` (line 261) - Creates the entire auto controls panel

**Layout Structure:**
- Panel assigned to row 4 of main layout (line 267)
- Internal 2x5 grid: `{'1x', 40}` row heights (line 275)
- Row 1: Main controls (START button, input fields, direction switch)
- Row 2: Status display (40px fixed height)

**Controls Created:**
- `StartStopButton` - START/STOP button (line 282)
- `StepField` - Step size input (line 287)
- `StepsField` - Number of steps input (line 295)
- `DelayField` - Delay between steps input (line 303)
- `DirectionSwitch` - Up/Down toggle (line 332)
- `StatusDisplay` - Status text label (line 360)

### `src/views/UiComponents.m`
**UI update and styling logic**

**Key Functions:**
- `updateControlStates(manualControls, autoControls, controller)` (line 237)
- `updateAutoStepButton(autoControls, isRunning)` (line 280)
- `updateDirectionButtonStyling(autoControls, direction)` (line 300)
- `updateDirectionButtons(app)` (line 346)
- `updateAutoStepStatusDisplay(app)` (line 396)

**Styling Logic:**
- Disables input fields during auto-stepping
- Changes START button to STOP when running
- Updates button colors based on direction and state
- Shows progress in status display

## 📱 Main Application

### `src/app/foilview.m`
**Main app with auto step callbacks**

**Callback Methods:**
- `onStartStopButtonPushed()` (line 158) - Start/stop auto-stepping
- `onAutoDirectionSwitchChanged()` (line 129) - Direction toggle callback
- `onAutoDirectionToggled()` (line 142) - Direction button callback
- `onAutoStepSizeChanged()` (line 150) - Step size change callback
- `onAutoStepsChanged()` (line 156) - Number of steps change callback
- `onAutoDelayChanged()` (line 126) - Delay change callback

**Status Update:**
- `updateAutoStepStatus()` (line 334) - Updates all auto control states

**Callback Registration (lines 508-514):**
```matlab
app.AutoControls.StepField.ValueChangedFcn = @app.onAutoStepSizeChanged;
app.AutoControls.StepsField.ValueChangedFcn = @app.onAutoStepsChanged;
app.AutoControls.DelayField.ValueChangedFcn = @app.onAutoDelayChanged;
app.AutoControls.DirectionSwitch.ValueChangedFcn = @app.onAutoDirectionSwitchChanged;
app.AutoControls.DirectionButton.ButtonPushedFcn = @app.onAutoDirectionToggled;
app.AutoControls.StartStopButton.ButtonPushedFcn = @app.onStartStopButtonPushed;
```

## 🔧 Services & Validation

### `src/services/ScanControlService.m`
**Parameter validation and session management**

**Constants (lines 8-11):**
```matlab
MIN_AUTO_STEPS = 1          % Minimum steps validation
MAX_AUTO_STEPS = 1000       % Maximum steps validation
MIN_AUTO_DELAY = 0.1        % Minimum delay validation
MAX_AUTO_DELAY = 10.0       % Maximum delay validation
```

**Key Methods:**
- `validateAutoStepParameters(stepSize, numSteps, delay)` (line 25)
- `isValidStepCount(numSteps)` (line 49)
- `isValidDelay(delay)` (line 56)
- `summarizeAutoStepSession(metrics, params)` (line 159)

### `src/controllers/UIController.m`
**UI state management during auto-stepping**

**Key Methods:**
- `updateControlStates(controller, manualControls, autoControls)` (line 82)
- `updateAutoStepProgress(controller, autoControls)` (line 141)

**Logic:**
- Disables manual controls during auto-stepping
- Disables auto input fields during operation
- Updates progress display
- Manages button states and colors

## ⌨️ Keyboard Integration

### `src/utils/KeyboardShortcuts.m`
**Keyboard shortcut handling**

**Auto Step Integration (lines 14-21):**
```matlab
case 'uparrow'
    if ~app.Controller.IsAutoRunning
        app.onUpButtonPushed();
    end
case 'downarrow'
    if ~app.Controller.IsAutoRunning
        app.onDownButtonPushed();
    end
```

Prevents manual movement during auto-stepping.

## 🛠️ Diagnostic Tools

### `dev-tools/` Directory
**Auto controls diagnostic and fix scripts**

**Diagnostic Scripts:**
- `diagnose_autocontrols_visibility.m` - Detailed visibility analysis
- `check_autocontrols_clipping.m` - Check what parts are clipped
- `autocontrols_solution_summary.m` - Solution summary

**Fix Scripts:**
- `fix_autocontrols_visibility.m` - Runtime visibility fix
- `fix_layout_proportions.m` - Runtime layout fix
- `comprehensive_autocontrols_fix.m` - Complete runtime solution
- `fix_uibuilder_proportions.m` - Permanent source code fix

## 📊 Data Flow

### Auto Step Execution Flow:
1. **UI Input** → `foilview.m` callbacks
2. **Validation** → `ScanControlService.validateAutoStepParameters()`
3. **Start** → `FoilviewController.startAutoStepping()`
4. **Timer Loop** → `FoilviewController.executeAutoStep()` (repeated)
5. **UI Updates** → `UiComponents.updateControlStates()`
6. **Completion** → `FoilviewController.stopAutoStepping()`

### UI Update Flow:
1. **State Change** → Controller properties updated
2. **Notification** → `updateAutoStepStatus()` called
3. **UI Refresh** → `UiComponents.updateControlStates()`
4. **Visual Updates** → Button colors, text, enabled states

## 🎛️ Control Structure

### Auto Controls Object Structure:
```matlab
AutoControls = struct(
    'StartStopButton',   % uibutton - START ▲ / STOP
    'StepField',         % uieditfield - Step size (μm)
    'StepsField',        % uieditfield - Number of steps
    'DelayField',        % uieditfield - Delay (seconds)
    'DirectionSwitch',   % uiswitch - Up/Down toggle
    'DirectionButton',   % uibutton - Direction indicator (hidden)
    'StatusDisplay'      % uilabel - Status text
);
```

### Layout Hierarchy:
```
MainLayout (6 rows)
├── Row 1: Metrics Display
├── Row 2: Position Display (1x)
├── Row 3: Manual Controls
├── Row 4: Auto Controls (2x) ← Largest allocation
│   ├── Internal Grid (2x5)
│   ├── Row 1 (1x): Main controls
│   └── Row 2 (40px): Status display
├── Row 5: Expand Button
└── Row 6: Status Bar
```

## 🔍 Key Integration Points

1. **Timer Management**: `FoilviewController.AutoTimer` handles step execution
2. **State Synchronization**: `IsAutoRunning` flag coordinates UI and logic
3. **Parameter Validation**: `ScanControlService` ensures safe operation
4. **UI Coordination**: `UIController` manages cross-component updates
5. **Metrics Recording**: Optional data collection during auto-stepping

This comprehensive map shows how auto step functionality is distributed across the application architecture, from low-level controller logic to high-level UI components.