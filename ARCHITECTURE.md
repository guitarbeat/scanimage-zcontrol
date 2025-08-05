# Foilview Application Architecture

This document provides a comprehensive overview of the current Foilview application architecture, including file structure, component relationships, and data flow patterns.

## Overview

Foilview is a MATLAB-based application for microscope stage control and focus optimization. The application follows a layered architecture with clear separation between UI, business logic, and data access layers.

## Directory Structure

```
src/
├── foilview.m                    # Main application entry point
├── FoilviewController.p          # Compiled controller (legacy)
├── config/                       # Configuration files (NEW)
│   └── ui_components.json        # ComponentFactory UI definitions
├── controllers/                  # Application controllers
│   ├── FoilviewController.m      # Main application controller
│   ├── HIDController.m           # MJC3 joystick integration
│   ├── ScanImageController.m     # ScanImage interface
│   ├── UIController.m            # UI state management
│   └── mjc3/                     # MJC3 joystick controllers
│       ├── BaseMJC3Controller.m
│       ├── MJC3_MEX_Controller.m
│       ├── MJC3_Simulation_Controller.m
│       ├── MJC3ControllerFactory.m
│       ├── build_mjc3_mex.m
│       ├── install_mjc3.m
│       ├── mjc3_joystick_mex.cpp
│       ├── mjc3_joystick_mex.mexw64
│       └── hidapi.dll
├── managers/                     # Data and resource managers
│   ├── BookmarkManager.m         # Position bookmark management
│   └── ScanImageManager.m        # ScanImage integration
├── services/                     # Business logic services
│   ├── ApplicationInitializer.m  # App startup and initialization
│   ├── CalibrationService.m      # MJC3 calibration
│   ├── ErrorHandlerService.m     # Error handling and logging
│   ├── LoggingService.m          # Unified logging
│   ├── MetadataService.m         # Metadata management
│   ├── MetricCalculationService.m # Focus metric calculations
│   ├── MetricsPlotService.m      # Plotting services
│   ├── ScanControlService.m      # Scan parameter management
│   ├── StageControlService.m     # Stage movement logic
│   └── UserNotificationService.m # User notifications
├── ui/                           # UI architecture components (NEW)
│   └── ComponentFactory.m        # Dynamic UI component creation
├── utils/                        # Utility classes
│   ├── ConfigUtils.m             # Configuration management
│   ├── FilePathUtils.m           # File path utilities
│   ├── FoilviewUtils.m           # General utilities
│   ├── MetadataWriter.m          # Metadata file writing
│   └── NumericUtils.m            # Numeric utilities
└── views/                        # UI components and views
    ├── BookmarksView.m           # Bookmark management UI
    ├── MJC3View.m                # Joystick control UI
    ├── PlotManager.m             # Plot management
    ├── StageView.m               # Camera/stage view
    ├── ToolsWindow.m             # Tools window
    ├── UiBuilder.m               # UI construction (REFACTORED)
    └── UiComponents.m            # UI component definitions
```

## Architecture Layers

```mermaid
graph TB
    subgraph "Presentation Layer"
        UI[foilview.m<br/>Main UI App]
        Views[Views<br/>BookmarksView, MJC3View<br/>StageView, ToolsWindow]
        UiBuilder[UI Builder<br/>UiBuilder, UiComponents]
    end
    
    subgraph "Controller Layer"
        MainController[FoilviewController<br/>Main App Controller]
        UIController[UIController<br/>UI State Management]
        HIDController[HIDController<br/>Joystick Integration]
        ScanController[ScanImageController<br/>ScanImage Interface]
        MJC3Controllers[MJC3 Controllers<br/>MEX, Simulation, Factory]
    end
    
    subgraph "Service Layer"
        StageService[StageControlService<br/>Stage Movement Logic]
        MetricService[MetricCalculationService<br/>Focus Metrics]
        CalibService[CalibrationService<br/>Joystick Calibration]
        PlotService[MetricsPlotService<br/>Plotting Logic]
        ScanService[ScanControlService<br/>Scan Parameters]
        MetadataService[MetadataService<br/>Metadata Management]
        ErrorService[ErrorHandlerService<br/>Error Handling]
        LogService[LoggingService<br/>Unified Logging]
        NotifyService[UserNotificationService<br/>User Notifications]
    end
    
    subgraph "Manager Layer"
        ScanManager[ScanImageManager<br/>ScanImage Integration]
        BookmarkManager[BookmarkManager<br/>Position Bookmarks]
    end
    
    subgraph "Utility Layer"
        Utils[Utilities<br/>FoilviewUtils, ConfigUtils<br/>FilePathUtils, NumericUtils<br/>MetadataWriter]
    end
    
    subgraph "External Systems"
        ScanImage[ScanImage Software]
        MJC3Hardware[MJC3 Joystick Hardware]
        FileSystem[File System]
    end
    
    UI --> MainController
    Views --> MainController
    Views --> UIController
    UiBuilder --> Views
    
    MainController --> StageService
    MainController --> MetricService
    MainController --> BookmarkManager
    
    UIController --> Views
    HIDController --> MJC3Controllers
    ScanController --> ScanManager
    
    StageService --> ScanManager
    MetricService --> ScanManager
    CalibService --> MJC3Controllers
    PlotService --> Views
    
    ScanManager --> ScanImage
    MJC3Controllers --> MJC3Hardware
    MetadataService --> FileSystem
    
    ErrorService --> LogService
    LogService --> Utils
    
    style UI fill:#e1f5fe
    style MainController fill:#f3e5f5
    style StageService fill:#e8f5e8
    style ScanManager fill:#fff3e0
    style Utils fill:#fafafa
```

## Component Relationships

### Main Application Flow

```mermaid
sequenceDiagram
    participant User
    participant UI as foilview.m
    participant Controller as FoilviewController
    participant StageService as StageControlService
    participant ScanManager as ScanImageManager
    participant ScanImage as ScanImage Software
    
    User->>UI: Launch Application
    UI->>Controller: Initialize
    Controller->>StageService: Initialize
    Controller->>ScanManager: Initialize
    ScanManager->>ScanImage: Connect
    
    User->>UI: Move Stage
    UI->>Controller: moveStage(distance)
    Controller->>StageService: moveStage(distance)
    StageService->>ScanManager: moveStage(distance)
    ScanManager->>ScanImage: Perform Movement
    ScanImage-->>ScanManager: Position Updated
    ScanManager-->>StageService: Movement Complete
    StageService-->>Controller: Position Changed Event
    Controller-->>UI: Update Display
```

### Event System

```mermaid
graph LR
    subgraph "Event Publishers"
        StageService[StageControlService<br/>PositionChanged]
        MetricService[MetricCalculationService<br/>MetricCalculated<br/>MetricTypeChanged]
        Controller[FoilviewController<br/>StatusChanged<br/>PositionChanged<br/>MetricChanged<br/>AutoStepComplete]
    end
    
    subgraph "Event Listeners"
        MainUI[foilview.m<br/>UI Updates]
        PlotManager[PlotManager<br/>Plot Updates]
        Views[Various Views<br/>Display Updates]
    end
    
    StageService -->|notify| Controller
    MetricService -->|notify| Controller
    Controller -->|addlistener| MainUI
    Controller -->|events| PlotManager
    Controller -->|events| Views
    
    style StageService fill:#e8f5e8
    style MetricService fill:#e8f5e8
    style Controller fill:#f3e5f5
    style MainUI fill:#e1f5fe
```

## Key Design Patterns

### 1. Model-View-Controller (MVC)
- **Model**: Services and Managers handle business logic and data
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

```mermaid
flowchart TD
    A[User Input] --> B[UI Component]
    B --> C[FoilviewController]
    C --> D[StageControlService]
    D --> E[ScanImageManager]
    E --> F[ScanImage Software]
    F --> G[Hardware Stage]
    
    G --> H[Position Feedback]
    H --> E
    E --> I[Position Update Event]
    I --> D
    D --> J[PositionChanged Event]
    J --> C
    C --> K[UI Update]
    K --> L[Display Refresh]
    
    style A fill:#e1f5fe
    style G fill:#ffebee
    style L fill:#e1f5fe
```

### Metric Calculation Flow

```mermaid
flowchart TD
    A[Image Acquisition] --> B[ScanImageManager]
    B --> C[MetricCalculationService]
    C --> D[Focus Metric Algorithm]
    D --> E[Metric Result]
    E --> F[MetricCalculated Event]
    F --> G[FoilviewController]
    G --> H[UI Update]
    G --> I[Plot Update]
    
    style A fill:#ffebee
    style E fill:#e8f5e8
    style H fill:#e1f5fe
    style I fill:#e1f5fe
```

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
- Hard to mock external dependencies

## File Dependencies

### Core Dependencies

```mermaid
graph TD
    foilview[foilview.m] --> FoilviewController
    FoilviewController --> StageControlService
    FoilviewController --> MetricCalculationService
    FoilviewController --> BookmarkManager
    FoilviewController --> ScanImageManager
    
    StageControlService --> ScanImageManager
    MetricCalculationService --> ScanImageManager
    
    HIDController --> MJC3ControllerFactory
    MJC3ControllerFactory --> BaseMJC3Controller
    MJC3ControllerFactory --> MJC3_MEX_Controller
    MJC3ControllerFactory --> MJC3_Simulation_Controller
    
    Views --> UiBuilder
    Views --> UiComponents
    Views --> FoilviewController
    
    All_Classes --> FoilviewUtils
    All_Classes --> LoggingService
    
    style foilview fill:#e1f5fe
    style FoilviewController fill:#f3e5f5
    style StageControlService fill:#e8f5e8
    style ScanImageManager fill:#fff3e0
```

## Recent Architecture Improvements

### ComponentFactory Pattern Implementation
**Status**: ✅ **In Progress** - Phase 1 of UiBuilder refactoring

**New Components Added**:
- `src/ui/ComponentFactory.m` - Dynamic UI component creation from JSON configuration
- `src/config/ui_components.json` - Declarative UI component definitions

**Refactored Methods** (3/4 complete):
- ✅ `createPositionDisplay` - 20 lines refactored
- ✅ `createMetricDisplay` - 69 lines refactored (largest method)
- ✅ `createCompactManualControls` - 25 lines refactored
- 🔄 `createAutoControls` - 45 lines (next target)

**Benefits Achieved**:
- **Configuration-driven UI**: Components defined in JSON instead of hardcoded
- **Reduced code duplication**: Common UI patterns centralized
- **Improved maintainability**: UI changes via config files
- **Better testability**: ComponentFactory can be tested in isolation

**Progress Metrics**:
- **Lines Refactored**: 114 of 774 lines (15% complete)
- **Methods Refactored**: 3 of 36 methods (8% complete)
- **Target Reduction**: 774 → 200 lines (74% reduction goal)

### Architecture Pattern Evolution

```mermaid
graph LR
    subgraph "Before: Procedural UI"
        A[Hard-coded UI Creation]
        B[Repetitive Component Code]
        C[Mixed UI/Logic Concerns]
    end
    
    subgraph "After: ComponentFactory Pattern"
        D[JSON Configuration]
        E[Dynamic Component Creation]
        F[Separation of Concerns]
    end
    
    A --> D
    B --> E
    C --> F
    
    style D fill:#e8f5e8
    style E fill:#e8f5e8
    style F fill:#e8f5e8
```

## Summary

The current architecture demonstrates good separation of concerns with distinct layers for presentation, business logic, and data access. **Recent improvements** include the introduction of a ComponentFactory pattern that enables configuration-driven UI creation, reducing code duplication and improving maintainability.

The ongoing refactoring of UiBuilder.m represents a significant architectural evolution from procedural UI creation to a modern, declarative approach. This improvement addresses several of the identified issues including mixed responsibilities and testing challenges.

The codebase shows mature MATLAB development practices with comprehensive error handling, logging, and documentation. The modular structure makes it relatively easy to understand and maintain, and the recent architectural improvements further enhance the overall design quality.