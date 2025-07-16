# Services Layer

This directory contains the business logic services for the FoilView application. Services are pure business logic components with no UI dependencies, designed to be testable, reusable, and maintainable.

## Service Architecture Principles

### 1. Single Responsibility
Each service handles one specific domain of business logic:
- `StageControlService` - Stage movement and positioning
- `MetricCalculationService` - Metric calculations and caching
- `ScanControlService` - Scan parameter validation and control
- `MetadataService` - Metadata logging and session statistics
- `MetricsPlotService` - Plot data management and visualization logic

### 2. No UI Dependencies
Services contain no direct references to UI components. They communicate with the UI layer through:
- Return values from method calls
- Event notifications using MATLAB's event system
- Data structures passed to controllers

### 3. Dependency Injection
Services receive their dependencies through constructor injection:
```matlab
% Example: StageControlService requires ScanImageManager
obj.StageControlService = StageControlService(obj.ScanImageManager);
```

### 4. Event-Driven Communication
Services use MATLAB events to notify other components of state changes:
```matlab
% Services define events
events
    PositionChanged
    MetricCalculated
end

% Controllers listen to service events
addlistener(obj.StageControlService, 'PositionChanged', @obj.onPositionChanged);
```

## Service Interfaces

### StageControlService
**Purpose**: Manages all stage movement operations and position tracking.

**Key Methods**:
- `moveStage(axis, microns)` - Move stage along specified axis
- `setAbsolutePosition(axis, position)` - Set absolute position
- `getCurrentPositions()` - Get current X, Y, Z positions
- `resetPosition(axis)` - Reset position to zero

**Events**:
- `PositionChanged` - Fired when stage position changes

**Dependencies**: `ScanImageManager`

### MetricCalculationService
**Purpose**: Handles all metric calculations with caching and optimization.

**Key Methods**:
- `calculateAllMetrics(position)` - Calculate all available metrics
- `getCurrentMetric(position)` - Get current selected metric value
- `setMetricType(metricType)` - Set the active metric type
- `clearCache()` - Clear metric calculation cache

**Events**:
- `MetricCalculated` - Fired when metrics are calculated
- `MetricTypeChanged` - Fired when metric type changes

**Dependencies**: `ScanImageManager`

### ScanControlService
**Purpose**: Validates scan parameters and manages scan operations.

**Key Methods**:
- `validateAutoStepParameters(stepSize, numSteps, delay)` - Validate parameters
- `startAutoStepping(params)` - Start automated stepping sequence
- `stopAutoStepping()` - Stop current auto-stepping

**Dependencies**: `ScanImageManager`

### MetadataService
**Purpose**: Manages metadata logging and session statistics.

**Key Methods**:
- `logBookmark(label, position, metric)` - Log bookmark metadata
- `logSession(sessionData)` - Log session information
- `getSessionStatistics()` - Get current session stats

**Dependencies**: None (file system only)

### MetricsPlotService
**Purpose**: Manages plot data and visualization logic.

**Key Methods**:
- `updatePlot(axes, data)` - Update plot with new data
- `clearPlot(axes)` - Clear plot data
- `configureAxes(axes, config)` - Configure plot appearance

**Dependencies**: None (MATLAB plotting functions only)

## Usage Patterns

### 1. Service Initialization
Services are typically initialized in the main controller:

```matlab
function obj = FoilviewController()
    obj.ScanImageManager = ScanImageManager();
    obj.StageControlService = StageControlService(obj.ScanImageManager);
    obj.MetricCalculationService = MetricCalculationService(obj.ScanImageManager);
    
    % Set up event listeners
    addlistener(obj.StageControlService, 'PositionChanged', @obj.onPositionChanged);
    addlistener(obj.MetricCalculationService, 'MetricCalculated', @obj.onMetricCalculated);
end
```

### 2. Service Method Calls
Controllers delegate business logic to services:

```matlab
% Instead of implementing movement logic in controller
function moveStage(obj, microns)
    success = obj.StageControlService.moveStage('Z', microns);
    if success
        obj.syncPositionsFromService();
    end
end
```

### 3. Event Handling
Controllers respond to service events to update UI:

```matlab
function onPositionChanged(obj, ~, eventData)
    obj.syncPositionsFromService();
    obj.notifyPositionChanged(); % Notify UI layer
end
```

## Testing Services

Services are designed to be easily unit tested:

```matlab
function tests = test_StageControlService
    tests = functiontests(localfunctions);
end

function test_moveStage(testCase)
    mockScanImageManager = MockScanImageManager();
    service = StageControlService(mockScanImageManager);
    
    success = service.moveStage('Z', 10.0);
    verifyTrue(testCase, success);
    
    positions = service.getCurrentPositions();
    verifyEqual(testCase, positions.z, 10.0, 'AbsTol', 0.01);
end
```

## Error Handling

Services use consistent error handling patterns:

```matlab
function success = moveStage(obj, axis, microns)
    success = false;
    
    try
        % Validate inputs
        if ~obj.validateMovement(microns)
            return;
        end
        
        % Perform operation
        newPos = obj.ScanImageManager.moveStage(axis, microns);
        obj.updatePosition(axis, newPos);
        
        success = true;
        
    catch ME
        FoilviewUtils.logException('StageControlService.moveStage', ME);
    end
end
```

## Performance Considerations

### Caching
Services implement caching where appropriate:
- `MetricCalculationService` caches expensive metric calculations
- Cache invalidation based on position changes and time limits

### Throttling
Services avoid excessive operations:
- Position updates are throttled to prevent UI flooding
- Metric calculations are debounced during rapid position changes

### Memory Management
Services properly clean up resources:
- Event listeners are removed in destructors
- Timers are properly stopped and deleted
- Large data structures are cleared when no longer needed

## Migration Notes

During the refactoring process, business logic was extracted from:
- `FoilviewController.m` - Stage control and metric calculation logic moved to services
- `foilview.m` - Metadata logging moved to `MetadataService`
- `PlotManager.m` - Plot logic moved to `MetricsPlotService`

This separation provides:
- **Better testability** - Services can be unit tested in isolation
- **Improved maintainability** - Each service has a single, clear responsibility
- **Enhanced reusability** - Services can be used by multiple controllers or applications
- **Cleaner architecture** - Clear separation between business logic and UI concerns

## Future Enhancements

Potential service improvements:
- **Configuration Service** - Centralized configuration management
- **Logging Service** - Structured logging with different levels
- **Validation Service** - Centralized input validation
- **State Management Service** - Application state persistence and restoration