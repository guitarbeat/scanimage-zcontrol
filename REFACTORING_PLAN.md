# FoilView Codebase Refactoring Plan

## Executive Summary

Based on the dependency analysis and code review, this document outlines a comprehensive refactoring plan to improve the FoilView MATLAB application's architecture, eliminate dead code, and enhance maintainability.

## Current Issues Identified

### 1. Architectural Problems
- **Monolithic Main App**: `foilview.m` (~1600+ lines) handles UI, business logic, metadata, and timers
- **Fat Controller**: `FoilviewController.m` (~983+ lines) mixes UI validation with business logic
- **Tight Coupling**: Direct dependencies between all layers
- **Mixed Concerns**: UI logic intertwined with business logic throughout

### 2. Code Quality Issues
- **Duplication**: Similar validation patterns repeated across files
- **Large Methods**: Many methods exceed 50 lines with multiple responsibilities
- **Inconsistent Error Handling**: Different error handling patterns throughout
- **Hard-coded Values**: Magic numbers and strings scattered throughout code

### 3. Performance Issues
- **Inefficient UI Updates**: Full UI refresh on every change
- **Unthrottled Operations**: No rate limiting on frequent operations
- **Memory Leaks**: Timer cleanup not always guaranteed

## Refactoring Strategy

### Phase 1: Service Layer Creation ✅ COMPLETED
- [x] Created `ScanControlService.m` - Parameter validation and scan logic
- [x] Created `MetadataService.m` - Metadata logging and session statistics
- [x] Created `MetricsPlotService.m` - Plot management (already existed)

### Phase 2: Utility Decomposition ✅ COMPLETED
- [x] Created `ConfigUtils.m` - Configuration management
- [x] Created `FilePathUtils.m` - File and path operations
- [x] Created `NumericUtils.m` - Numeric computations and validations
- [x] Created `UIController.m` - UI state management

### Phase 3: Controller Refactoring (NEXT)
1. **Slim Down FoilviewController**
   - Move UI update logic to `UIController`
   - Move validation logic to services
   - Keep only core business logic

2. **Extract Business Logic**
   - Move stage control logic to `StageControlService`
   - Move metric calculation to `MetricCalculationService`
   - Move bookmark logic to enhanced `BookmarkManager`

### Phase 4: Main App Simplification
1. **Reduce foilview.m Responsibilities**
   - Move timer management to `TimerManager`
   - Move metadata handling to `MetadataService`
   - Move UI building to `UIBuilder` (already exists)
   - Keep only app lifecycle and coordination

2. **Implement Event-Driven Architecture**
   - Use MATLAB events for loose coupling
   - Implement observer pattern for UI updates
   - Reduce direct method calls between layers

## Dead Code Identification

### Potential Dead Code Areas

1. **Unused Methods in FoilviewUtils**
   - Several utility methods may be unused after service extraction
   - Legacy error handling methods

2. **Redundant Validation Code**
   - Multiple similar validation patterns
   - Duplicate parameter checking

3. **Obsolete UI Update Methods**
   - Manual font sizing code (can be replaced with responsive design)
   - Redundant position formatting methods

4. **Legacy Timer Code**
   - Old timer creation patterns
   - Unused timer cleanup methods

### Dead Code Analysis Script

```matlab
% Run this in MATLAB to identify potentially unused functions
function analyzeDeadCode()
    % Get all .m files in src/
    files = dir(fullfile('src', '**', '*.m'));
    
    allFunctions = {};
    allCalls = {};
    
    for i = 1:length(files)
        filePath = fullfile(files(i).folder, files(i).name);
        [funcs, calls] = extractFunctionsAndCalls(filePath);
        allFunctions = [allFunctions, funcs];
        allCalls = [allCalls, calls];
    end
    
    % Find functions that are defined but never called
    unusedFunctions = setdiff(allFunctions, allCalls);
    
    fprintf('Potentially unused functions:\n');
    for i = 1:length(unusedFunctions)
        fprintf('  - %s\n', unusedFunctions{i});
    end
end
```

## Performance Improvements

### 1. UI Update Optimization
- **Throttled Updates**: Implement update throttling (already in UIController)
- **Batch Updates**: Group UI updates to reduce redraws
- **Selective Updates**: Only update changed components

### 2. Memory Management
- **Timer Cleanup**: Ensure all timers are properly cleaned up
- **Event Listener Cleanup**: Remove event listeners on destruction
- **Data Structure Optimization**: Use more efficient data structures

### 3. Computation Optimization
- **Metric Calculation Caching**: Cache expensive metric calculations
- **Data Limiting**: Limit plot data points for performance
- **Lazy Loading**: Load data only when needed

## Implementation Roadmap

### Week 1: Service Integration
1. Update `FoilviewController` to use new services
2. Update `BookmarkManager` to use `MetadataService`
3. Test service integration

### Week 2: Controller Refactoring
1. Extract remaining business logic from `FoilviewController`
2. Implement `UIController` integration
3. Create `StageControlService` and `MetricCalculationService`

### Week 3: Main App Simplification
1. Refactor `foilview.m` to use new architecture
2. Implement event-driven updates
3. Create `TimerManager` for centralized timer handling

### Week 4: Testing and Optimization
1. Comprehensive testing of refactored code
2. Performance optimization
3. Dead code removal
4. Documentation updates

## Expected Benefits

### 1. Maintainability
- **Smaller Files**: Each file has a single, clear responsibility
- **Easier Testing**: Services can be unit tested in isolation
- **Clearer Dependencies**: Well-defined interfaces between layers

### 2. Performance
- **Faster UI Updates**: Throttled and selective updates
- **Better Memory Usage**: Proper cleanup and efficient data structures
- **Reduced Coupling**: Less interdependent code execution

### 3. Extensibility
- **Plugin Architecture**: Services can be easily extended or replaced
- **New Features**: Easier to add new functionality without breaking existing code
- **Configuration**: Centralized configuration management

## Risk Mitigation

### 1. Backward Compatibility
- Keep old interfaces during transition
- Gradual migration with fallbacks
- Comprehensive testing at each step

### 2. Testing Strategy
- Unit tests for each service
- Integration tests for controller interactions
- End-to-end tests for complete workflows

### 3. Rollback Plan
- Git branching strategy for safe rollbacks
- Feature flags for gradual rollout
- Monitoring and logging for issue detection

## Success Metrics

1. **Code Quality**
   - Reduce average file size by 50%
   - Eliminate circular dependencies
   - Achieve 80%+ test coverage

2. **Performance**
   - Reduce UI update latency by 30%
   - Eliminate memory leaks
   - Improve startup time by 20%

3. **Maintainability**
   - Reduce time to implement new features by 40%
   - Decrease bug fix time by 50%
   - Improve code review efficiency

## Phase 3: Controller Refactoring (CURRENT PHASE)

### Step 1: Extract Stage Control Logic
Create `StageControlService.m` to handle all stage movement operations:

```matlab
% Move from FoilviewController to StageControlService:
- moveStage(), moveStageX(), moveStageY()
- setPosition(), setXYZPosition()
- resetPosition(), refreshPosition()
- Position validation and bounds checking
```

### Step 2: Extract Metric Calculation Logic
Create `MetricCalculationService.m` for all metric computations:

```matlab
% Move from FoilviewController to MetricCalculationService:
- updateMetric(), calculateMetric()
- setMetricType(), getCurrentMetric()
- Metric caching and optimization
- Auto-step metrics collection
```

### Step 3: Refactor FoilviewController
Slim down the controller to focus on coordination:

```matlab
% Keep in FoilviewController:
- Business logic coordination
- Service orchestration
- Event handling and notifications
- State management

% Remove from FoilviewController:
- Direct UI updates (move to UIController)
- Parameter validation (move to services)
- Complex calculations (move to services)
```

### Step 4: Integrate UIController
Update `foilview.m` to use the new `UIController`:

```matlab
% Replace direct UI updates with:
app.UIController.updateAllUI()
app.UIController.updatePositionDisplay()
app.UIController.updateControlStates()
```

## Phase 4: Main App Simplification

### Step 1: Create TimerManager
Centralize all timer operations:

```matlab
classdef TimerManager < handle
    methods
        function startPositionTimer(obj, callback, period)
        function startMetricTimer(obj, callback, period)
        function stopAllTimers(obj)
        function cleanup(obj)
    end
end
```

### Step 2: Refactor foilview.m Structure
Break down the monolithic app into focused sections:

```matlab
% New foilview.m structure:
classdef foilview < matlab.apps.AppBase
    properties (Access = private)
        % Core components
        Controller
        UIController
        TimerManager
        
        % UI Components (built by UiBuilder)
        UIComponents
    end
    
    methods
        function app = foilview()
            app.initializeServices()
            app.buildUI()
            app.setupEventHandlers()
            app.startApplication()
        end
    end
end
```

### Step 3: Implement Event-Driven Architecture
Replace direct method calls with events:

```matlab
% Instead of: app.updateAllUI()
% Use: notify(obj, 'StateChanged', EventData)

% Event listeners in foilview.m:
addlistener(obj.Controller, 'PositionChanged', @obj.onPositionChanged)
addlistener(obj.Controller, 'MetricChanged', @obj.onMetricChanged)
addlistener(obj.Controller, 'StatusChanged', @obj.onStatusChanged)
```

## Dead Code Removal Strategy

### Enhanced Dead Code Analysis Results
Based on the improved analyzer, we can now safely identify:

1. **Truly Unused Functions**: Functions with no direct or indirect calls
2. **Suspicious Functions**: Potential callbacks or dynamic calls (review needed)
3. **Protected Functions**: MATLAB special methods and constructors (keep)

### Safe Removal Process
1. **Run Enhanced Analyzer**: Use the improved `analyze_dead_code.m`
2. **Manual Verification**: Check each "unused" function individually
3. **Incremental Removal**: Remove 1-2 functions at a time
4. **Test After Each Removal**: Ensure application still works
5. **Commit Small Changes**: Easy rollback if issues arise

### Specific Dead Code Targets

#### 1. Redundant Validation Methods
```matlab
% In FoilviewUtils.m - after service extraction:
- validateNumericRange() → Move to NumericUtils
- validateStringInput() → Move to ConfigUtils  
- Multiple similar validation patterns → Consolidate
```

#### 2. Obsolete UI Methods
```matlab
% In foilview.m - after UIController integration:
- updateStepSizeDisplay() → Move to UIController
- updateAutoStepStatus() → Move to UIController
- Manual font sizing methods → Replace with responsive design
```

#### 3. Legacy Timer Code
```matlab
% After TimerManager implementation:
- Individual timer creation methods
- Scattered timer cleanup code
- Duplicate timer validation
```

## Testing Strategy

### Unit Testing Framework
Create focused unit tests for each service:

```matlab
% Example: test_ScanControlService.m
function tests = test_ScanControlService
    tests = functiontests(localfunctions);
end

function test_validateAutoStepParameters(testCase)
    [valid, msg] = ScanControlService.validateAutoStepParameters(1.0, 10, 0.5);
    verifyTrue(testCase, valid);
    verifyEmpty(testCase, msg);
end
```

### Integration Testing
Test service interactions:

```matlab
% Example: test_ControllerServiceIntegration.m
function test_controllerUsesServices(testCase)
    controller = FoilviewController();
    % Verify controller delegates to services
    % Test event propagation
    % Verify state consistency
end
```

### Regression Testing
Ensure existing functionality works:

```matlab
% test_ApplicationWorkflow.m
function test_completeAutoStepWorkflow(testCase)
    % Test complete auto-stepping workflow
    % Verify UI updates correctly
    % Check data collection and plotting
end
```

## Performance Optimization Targets

### 1. UI Update Performance
**Current Issue**: Full UI refresh on every change
**Solution**: Selective updates with change detection

```matlab
% Before:
function updateAllUI(app)
    updatePositionDisplay(app);
    updateMetricDisplay(app);
    updateControlStates(app);
    updateStatusDisplay(app);
end

% After:
function updateAllUI(app)
    changes = app.UIController.detectChanges();
    if changes.position
        app.UIController.updatePositionDisplay();
    end
    if changes.metric
        app.UIController.updateMetricDisplay();
    end
    % ... selective updates only
end
```

### 2. Memory Usage Optimization
**Target**: Reduce memory footprint by 30%

- **Data Structure Optimization**: Use more efficient containers
- **Event Listener Cleanup**: Proper cleanup prevents memory leaks
- **Timer Management**: Centralized cleanup ensures no orphaned timers
- **Plot Data Limiting**: Limit stored plot points to prevent memory growth

### 3. Startup Performance
**Target**: Reduce startup time by 20%

- **Lazy Loading**: Load services only when needed
- **UI Building Optimization**: Streamline component creation
- **Reduced Dependencies**: Fewer file loads at startup

## Migration Checklist

### Phase 3 Tasks (Current)
- [ ] Create `StageControlService.m`
- [ ] Create `MetricCalculationService.m`
- [ ] Refactor `FoilviewController.m` to use services
- [ ] Update `foilview.m` to use `UIController`
- [ ] Test service integration thoroughly
- [ ] Update documentation for new architecture

### Phase 4 Tasks (Next)
- [ ] Create `TimerManager.m`
- [ ] Refactor `foilview.m` structure
- [ ] Implement event-driven architecture
- [ ] Replace direct method calls with events
- [ ] Test event propagation and handling
- [ ] Performance testing and optimization

### Dead Code Removal Tasks
- [ ] Run enhanced dead code analyzer
- [ ] Manual review of "unused" functions
- [ ] Remove confirmed dead code (incremental)
- [ ] Test after each removal
- [ ] Update documentation

### Testing Tasks
- [ ] Create unit test framework
- [ ] Write tests for each service
- [ ] Create integration tests
- [ ] Set up regression testing
- [ ] Achieve 80%+ test coverage

## Risk Assessment and Mitigation

### High Risk Areas
1. **Timer Management**: Critical for application stability
   - **Mitigation**: Extensive testing of timer lifecycle
   - **Fallback**: Keep old timer code until new system proven

2. **Event System**: New architecture could introduce bugs
   - **Mitigation**: Gradual rollout with feature flags
   - **Fallback**: Maintain old direct-call system in parallel

3. **Service Dependencies**: Circular dependencies could emerge
   - **Mitigation**: Strict dependency rules and validation
   - **Monitoring**: Regular dependency analysis

### Medium Risk Areas
1. **UI Performance**: Changes could slow down interface
   - **Mitigation**: Performance benchmarking at each step
   - **Monitoring**: UI response time measurements

2. **Memory Usage**: New architecture might use more memory
   - **Mitigation**: Memory profiling during development
   - **Optimization**: Continuous memory usage monitoring

### Low Risk Areas
1. **Dead Code Removal**: Minimal impact if done incrementally
2. **Utility Refactoring**: Already completed successfully
3. **Service Creation**: Well-isolated changes

## Success Metrics and Monitoring

### Code Quality Metrics
- **Cyclomatic Complexity**: Target < 10 per method
- **File Size**: Target < 500 lines per file
- **Dependency Count**: Target < 5 dependencies per class
- **Test Coverage**: Target > 80%

### Performance Metrics
- **UI Response Time**: Target < 100ms for updates
- **Memory Usage**: Target < 200MB total
- **Startup Time**: Target < 5 seconds
- **CPU Usage**: Target < 10% during idle

### Maintainability Metrics
- **Time to Add Feature**: Target 50% reduction
- **Bug Fix Time**: Target 40% reduction
- **Code Review Time**: Target 30% reduction
- **Onboarding Time**: Target 60% reduction for new developers

## Long-term Vision

### Modular Plugin Architecture
After refactoring completion, the architecture will support:

- **Plugin Services**: Easy addition of new functionality
- **Configurable UI**: Customizable interface components
- **External Integrations**: Clean APIs for third-party tools
- **Testing Framework**: Comprehensive automated testing

### Continuous Improvement Process
- **Monthly Architecture Reviews**: Assess and improve design
- **Performance Monitoring**: Continuous performance tracking
- **Code Quality Gates**: Automated quality checks in CI/CD
- **Developer Feedback**: Regular team input on architecture

## Conclusion

This comprehensive refactoring plan will transform the FoilView application from a monolithic, tightly-coupled system into a clean, modular, and maintainable architecture. The phased approach ensures minimal risk while delivering significant improvements in code quality, performance, and developer productivity.

The enhanced dead code analysis tool will help maintain code cleanliness, while the new service-oriented architecture will make the application more testable, extensible, and robust.

**Next Immediate Actions:**
1. Run the enhanced dead code analyzer
2. Begin Phase 3 controller refactoring
3. Set up unit testing framework
4. Create development branch for refactoring work

This refactoring represents a significant investment in the long-term health and maintainability of the FoilView codebase.