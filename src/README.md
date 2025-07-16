# FoilView Source Code

This directory contains the main source code for the FoilView application, organized in a modular, maintainable architecture.

## Architecture Overview

The FoilView application follows a layered architecture with clear separation of concerns:

```
┌─────────────────┐
│   Application   │  ← foilview.m (main app, coordination)
├─────────────────┤
│   Controllers   │  ← Business logic coordination
├─────────────────┤
│    Services     │  ← Pure business logic (no UI)
├─────────────────┤
│    Managers     │  ← Resource and state management
├─────────────────┤
│   Utilities     │  ← Helper functions and utilities
├─────────────────┤
│     Views       │  ← UI components and builders
└─────────────────┘
```

## Directory Structure

### `/app/` - Application Layer
- `foilview.m` - Main application entry point and coordination
- Handles application lifecycle, event routing, and high-level coordination
- Minimal business logic - delegates to controllers and services

### `/controllers/` - Controller Layer
- `FoilviewController.m` - Main business logic controller
- `UIController.m` - UI state management and updates
- Coordinates between services and UI, handles user interactions
- No direct UI component manipulation (delegated to UIController)

### `/services/` - Service Layer (Pure Business Logic)
- `StageControlService.m` - Stage movement and positioning
- `MetricCalculationService.m` - Metric calculations with caching
- `ScanControlService.m` - Scan parameter validation and control
- `MetadataService.m` - Metadata logging and session statistics
- `MetricsPlotService.m` - Plot data management
- **No UI dependencies** - testable, reusable business logic

### `/managers/` - Manager Layer
- `ScanImageManager.m` - ScanImage integration and hardware abstraction
- `PlotManager.m` - Plot coordination and management
- `BookmarkManager.m` - Bookmark storage and retrieval
- Resource management, external system integration

### `/utils/` - Utility Layer
- `FoilviewUtils.m` - Core utilities and helper functions
- `ConfigUtils.m` - Configuration management
- `FilePathUtils.m` - File and path operations
- `NumericUtils.m` - Numeric computations and validations
- Stateless helper functions, no business logic

### `/views/` - View Layer
- `UiBuilder.m` - UI component construction
- `UiComponents.m` - UI component management
- `StageView.m` - Stage position visualization
- `BookmarksView.m` - Bookmark management UI
- UI construction and component management

## Key Architectural Principles

### 1. Separation of Concerns
Each layer has a specific responsibility:
- **Services**: Pure business logic, no UI dependencies
- **Controllers**: Coordinate services and manage application flow
- **Managers**: Handle external resources and state
- **Views**: UI construction and presentation
- **Utils**: Stateless helper functions

### 2. Dependency Direction
Dependencies flow downward only:
```
App → Controllers → Services
  ↓       ↓           ↓
Views → Managers → Utils
```
No upward dependencies (services don't know about controllers)

### 3. Event-Driven Communication
Loose coupling through MATLAB events:
```matlab
% Services notify controllers of changes
notify(obj, 'PositionChanged', eventData);

% Controllers listen and respond
addlistener(service, 'PositionChanged', @obj.onPositionChanged);
```

### 4. Dependency Injection
Services receive dependencies through constructors:
```matlab
obj.StageControlService = StageControlService(obj.ScanImageManager);
```

## Migration Benefits

This modular architecture provides:

### **Maintainability**
- Smaller, focused files (average ~300 lines vs 1600+ before)
- Clear responsibilities and interfaces
- Easier to understand and modify individual components

### **Testability**
- Services can be unit tested in isolation
- Mock dependencies for reliable testing
- Clear interfaces make testing straightforward

### **Reusability**
- Services can be used by multiple controllers
- Utilities are shared across the application
- Components can be easily extracted for other projects

### **Performance**
- Selective UI updates (only changed components)
- Metric calculation caching
- Throttled operations to prevent UI flooding

### **Extensibility**
- Easy to add new services or controllers
- Plugin-like architecture for new features
- Clear extension points

## Development Workflow

### Adding New Features
1. **Identify the layer**: Determine if it's business logic (service), coordination (controller), or UI (view)
2. **Create service first**: Implement core business logic without UI dependencies
3. **Add controller integration**: Coordinate the service with existing components
4. **Update UI**: Modify views and controllers to use the new functionality
5. **Add tests**: Unit test services, integration test controllers

### Modifying Existing Features
1. **Locate the responsibility**: Find which service/controller handles the logic
2. **Update service**: Modify business logic in the appropriate service
3. **Update integration**: Ensure controllers properly use the updated service
4. **Test thoroughly**: Verify both unit and integration tests pass

### Debugging Issues
1. **Check service layer**: Verify business logic is correct
2. **Check controller integration**: Ensure services are called properly
3. **Check UI updates**: Verify UIController is updating the right components
4. **Check event flow**: Ensure events are being fired and handled correctly

## Code Quality Standards

### Service Requirements
- No UI dependencies (no direct UI component references)
- Clear, focused responsibility
- Comprehensive error handling
- Event notifications for state changes
- Input validation
- Proper resource cleanup

### Controller Requirements
- Delegate business logic to services
- Handle service events appropriately
- Coordinate between multiple services
- Minimal direct UI manipulation (use UIController)

### Testing Requirements
- Unit tests for all services
- Integration tests for controllers
- Mock external dependencies
- Test error conditions and edge cases

## Performance Monitoring

Key metrics to monitor:
- **UI Response Time**: Target < 100ms for updates
- **Memory Usage**: Monitor for leaks, especially in timers and events
- **Service Performance**: Cache hit rates, calculation times
- **Event Overhead**: Ensure event system doesn't impact performance

## Future Architecture Improvements

Planned enhancements:
- **Configuration Service**: Centralized app configuration
- **Logging Service**: Structured logging with levels
- **State Management**: Application state persistence
- **Plugin Architecture**: Dynamic service loading
- **API Layer**: External integration capabilities

This architecture represents a significant improvement in code organization, maintainability, and extensibility while maintaining all existing functionality.

See `MIGRATION_CHECKLIST.md` for detailed migration progress. 