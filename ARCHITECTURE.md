# Foilview Application Architecture

## Overview
MATLAB-based microscope stage control application with layered architecture: UI → Controllers → Services → Managers → Hardware.

## Directory Structure
```
src/
├── foilview.m                    # Main application entry point (71KB, 1528 lines)
├── config/ui_components.json     # ComponentFactory UI definitions (3.3KB, 80 lines)
├── controllers/                  # Application controllers
│   ├── FoilviewController.m      # Main application controller (36KB, 900 lines)
│   ├── EventCoordinator.m        # Event coordination (8.8KB, 213 lines)
│   ├── UIOrchestrator.m          # UI orchestration (13KB, 296 lines)
│   ├── UIController.m            # UI state management (11KB, 286 lines)
│   ├── HIDController.m           # MJC3 joystick integration (13KB, 326 lines)
│   ├── ScanImageController.m     # ScanImage interface (12KB, 309 lines)
│   └── mjc3/                    # MJC3 joystick controllers
├── hardware/                     # Hardware interface layer
│   └── ScanImageInterface.m      # Low-level ScanImage interface (18KB, 421 lines)
├── managers/                     # Data and resource managers
│   ├── BookmarkManager.m         # Position bookmark management (9.9KB, 233 lines)
│   └── ScanImageManager.m        # ScanImage integration (31KB, 737 lines)
├── services/                     # Business logic services
│   ├── ApplicationInitializer.m  # App startup and initialization (24KB, 590 lines)
│   ├── CalibrationService.m      # MJC3 calibration (24KB, 541 lines)
│   ├── ErrorHandlerService.m     # Error handling and logging (11KB, 269 lines)
│   ├── LoggingService.m          # Unified logging (15KB, 380 lines)
│   ├── MetadataService.m         # Metadata management (12KB, 281 lines)
│   ├── MetricCalculationService.m # Focus metric calculations (17KB, 469 lines)
│   ├── MetricsPlotService.m      # Plotting services (7.8KB, 210 lines)
│   ├── ScanControlService.m      # Scan parameter management (8.6KB, 221 lines)
│   ├── ScanImageMetadata.m       # ScanImage metadata handling (13KB, 324 lines)
│   ├── StageControlService.m     # Stage movement logic (15KB, 406 lines)
│   └── UserNotificationService.m # User notifications (19KB, 467 lines)
├── ui/ComponentFactory.m         # Dynamic UI component creation (11KB, 284 lines)
├── utils/                        # Utility classes
│   ├── ConfigUtils.m             # Configuration management (3.1KB, 90 lines)
│   ├── FilePathUtils.m           # File path utilities (4.3KB, 128 lines)
│   ├── FoilviewUtils.m           # General utilities (24KB, 640 lines)
│   ├── MetadataWriter.m          # Metadata file writing (6.2KB, 145 lines)
│   └── NumericUtils.m            # Numeric utilities (5.8KB, 176 lines)
└── views/                        # UI components and views
    ├── BookmarksView.m           # Bookmark management UI (17KB, 454 lines)
    ├── MJC3View.m                # Joystick control UI (74KB, 1686 lines)
    ├── PlotManager.m             # Plot management (8.4KB, 221 lines)
    ├── StageView.m               # Camera/stage view (48KB, 1188 lines)
    ├── ToolsWindow.m             # Tools window (14KB, 359 lines)
    ├── UiBuilder.m               # UI construction (38KB, 775 lines)
    └── UiComponents.m            # UI component definitions (28KB, 682 lines)
```

## Architecture Layers

### 1. Presentation Layer
- **foilview.m**: Main UI App (1528 lines)
- **Views**: BookmarksView, MJC3View, StageView, ToolsWindow, PlotManager
- **UiBuilder**: UI construction and ComponentFactory
- **UiComponents**: UI component definitions

### 2. Controller Layer
- **FoilviewController**: Main App Controller (900 lines)
- **UIOrchestrator**: UI validation and coordination (296 lines)
- **UIController**: UI state management (286 lines)
- **EventCoordinator**: Event management (213 lines)
- **HIDController**: Joystick integration (326 lines)
- **ScanImageController**: ScanImage interface (309 lines)

### 3. Service Layer
- **ApplicationInitializer**: App startup and initialization (590 lines)
- **CalibrationService**: MJC3 calibration (541 lines)
- **StageControlService**: Stage movement logic (406 lines)
- **MetricCalculationService**: Focus metrics (469 lines)
- **UserNotificationService**: User notifications (467 lines)
- **LoggingService**: Unified logging (380 lines)
- **ScanImageMetadata**: ScanImage metadata handling (324 lines)
- **MetadataService**: Metadata management (281 lines)
- **ErrorHandlerService**: Error handling (269 lines)
- **ScanControlService**: Scan parameters (221 lines)
- **MetricsPlotService**: Plotting services (210 lines)

### 4. Manager Layer
- **ScanImageManager**: ScanImage integration (737 lines)
- **BookmarkManager**: Position bookmarks (233 lines)

### 5. Hardware Layer
- **ScanImageInterface**: Low-level ScanImage interface (421 lines)

### 6. Utility Layer
- **FoilviewUtils**: General utilities (640 lines)
- **ConfigUtils**: Configuration management (90 lines)
- **FilePathUtils**: File path utilities (128 lines)
- **MetadataWriter**: Metadata file writing (145 lines)
- **NumericUtils**: Numeric utilities (176 lines)

## Key Design Patterns

### 1. Model-View-Controller (MVC)
- **Model**: Services and Managers handle business logic
- **View**: UI components in `views/` directory
- **Controller**: Controllers coordinate between Model and View

### 2. Service Layer Pattern
- Business logic encapsulated in service classes
- Services are stateful and handle specific domains
- Clear separation from UI concerns

### 3. Manager Pattern
- Managers handle external system integration
- `ScanImageManager` - ScanImage software integration
- `BookmarkManager` - Position bookmark persistence

### 4. Factory Pattern
- `MJC3ControllerFactory` creates appropriate joystick controllers
- Handles MEX vs Simulation controller selection

### 5. Observer Pattern
- Event-driven architecture using MATLAB's event system
- Services notify controllers of state changes
- Controllers notify UI of updates

## Data Flow Patterns

### Stage Movement Flow
```
User Input → UI → FoilviewController → StageControlService → ScanImageManager → ScanImageInterface → ScanImage Software → Hardware Stage
                                                                                    ↓
UI Update ← FoilviewController ← PositionChanged Event ← StageControlService ← Position Update Event ← ScanImageManager
```

### Metric Calculation Flow
```
Image Acquisition → ScanImageManager → MetricCalculationService → Focus Metric Algorithm → Metric Result → MetricCalculated Event → FoilviewController → UI/Plot Updates
```

## Recent Architecture Improvements

### MJC3 Joystick System Enhancement ✅
**Key Achievements**:
- **Hardware-Accelerated MEX Interface**: 50Hz polling with <1ms latency
- **Comprehensive Calibration System**: Per-axis calibration with persistent storage
- **Enhanced UI Layout**: Redesigned MJC3View with better organization
- **Unified Logging Integration**: All components use centralized LoggingService

**Components Added**:
- `mjc3_joystick_mex.cpp` - High-performance HID interface
- `CalibrationService.m` - Multi-axis calibration with persistent storage
- `MJC3View.m` - Enhanced UI with calibration controls

## Current Architecture Issues

### 1. Mixed Responsibilities
- Some controllers handle both business logic and UI state
- Services sometimes have UI dependencies

### 2. Tight Coupling
- Direct instantiation of dependencies
- Hard-coded class references throughout codebase

### 3. Inconsistent Patterns
- Mix of Managers and Services doing similar work
- No clear interface contracts

### 4. Event System Complexity
- Multiple event systems (MATLAB events, custom notifications)
- Potential for circular event dependencies

### 5. Testing Challenges
- Tight coupling makes unit testing difficult
- No dependency injection mechanism

## Future Architecture Considerations

### 1. Service Consolidation Opportunities
- **System Services**: Combine ErrorHandlerService, LoggingService, ApplicationInitializer
- **Hardware Services**: Merge StageControlService, ScanControlService, CalibrationService
- **Analysis Services**: Combine MetricCalculationService and MetricsPlotService

### 2. Configuration-Driven Architecture
- Replace hard-coded UI layouts with YAML/JSON configuration files
- Implement plugin architecture for hardware components
- Enable runtime component configuration without code changes

### 3. Unified Event System
- Standardize on single event mechanism across all components
- Implement centralized EventBus for loose coupling
- Reduce circular dependencies in event handling

## Summary

**Architecture Strengths**:
- **Layered Architecture**: Clear separation between UI, controllers, services, and utilities
- **Hardware Integration**: Professional-grade joystick control with MEX-based performance
- **Unified Logging**: Consistent LoggingService usage across all components
- **Modular Design**: Easy to understand, maintain, and extend
- **Error Resilience**: Comprehensive error handling and recovery mechanisms

**Current Status**: Fully functional MJC3 joystick system with hardware-accelerated performance, comprehensive calibration capabilities, and unified logging throughout the application.

**Codebase Size**: ~200KB across 25+ files with clear separation of concerns and mature MATLAB development practices.