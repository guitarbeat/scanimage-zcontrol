# Implementation Examples for Architecture Improvements

## Example 1: Interface Layer Implementation

### Current State (Tight Coupling)
```matlab
% In FoilviewController.m
classdef FoilviewController < handle
    properties
        StageControlService
        ScanControlService
        MetadataService
    end
    
    methods
        function moveStage(obj, x, y, z)
            obj.StageControlService.moveTo(x, y, z);
            obj.MetadataService.logPosition(x, y, z);
        end
    end
end
```

### Improved State (Interface-Based)
```matlab
% src/interfaces/IStageController.m
classdef IStageController < handle
    methods (Abstract)
        moveTo(x, y, z)
        getPosition()
        isMoving()
    end
end

% src/interfaces/IMetadataService.m
classdef IMetadataService < handle
    methods (Abstract)
        logPosition(x, y, z)
        logScan(scanData)
        getSessionStats()
    end
end

% src/controllers/core/StageController.m
classdef StageController < handle
    properties (Access = private)
        StageService IStageController
        MetadataService IMetadataService
    end
    
    methods
        function obj = StageController(stageService, metadataService)
            obj.StageService = stageService;
            obj.MetadataService = metadataService;
        end
        
        function moveStage(obj, x, y, z)
            obj.StageService.moveTo(x, y, z);
            obj.MetadataService.logPosition(x, y, z);
        end
    end
end
```

## Example 2: Repository Pattern Implementation

### Current State (Scattered Data Access)
```matlab
% In MetadataService.m
function writeMetadataToFile(obj, metadata, filePath)
    fid = fopen(filePath, 'a');
    fprintf(fid, '%s,%s,%s\n', metadata.timestamp, metadata.filename, metadata.scanner);
    fclose(fid);
end

% In ScanImageManager.m
function writeMetadataToFile(obj, metadata, filePath)
    fid = fopen(filePath, 'a');
    fprintf(fid, '%s,%s,%s\n', metadata.timestamp, metadata.filename, metadata.scanner);
    fclose(fid);
end
```

### Improved State (Repository Pattern)
```matlab
% src/repositories/IMetadataRepository.m
classdef IMetadataRepository < handle
    methods (Abstract)
        write(metadata, filePath)
        read(filePath)
        exists(filePath)
    end
end

% src/repositories/MetadataRepository.m
classdef MetadataRepository < IMetadataRepository
    methods
        function write(obj, metadata, filePath)
            fid = fopen(filePath, 'a');
            fprintf(fid, '%s,%s,%s\n', metadata.timestamp, metadata.filename, metadata.scanner);
            fclose(fid);
        end
        
        function data = read(obj, filePath)
            % Implementation for reading metadata
        end
        
        function exists = exists(obj, filePath)
            exists = exist(filePath, 'file');
        end
    end
end

% src/services/core/MetadataService.m
classdef MetadataService < handle
    properties (Access = private)
        Repository IMetadataRepository
    end
    
    methods
        function obj = MetadataService(repository)
            obj.Repository = repository;
        end
        
        function writeMetadata(obj, metadata, filePath)
            obj.Repository.write(metadata, filePath);
        end
    end
end
```

## Example 3: Strategy Pattern Implementation

### Current State (Hard-Coded Implementation)
```matlab
% In FoilviewController.m
function createMJC3Controller(obj, stepFactor)
    if obj.SimulationMode
        obj.MJC3Controller = MJC3_Simulation_Controller(obj.ZController, stepFactor);
    else
        try
            obj.MJC3Controller = MJC3_HID_Controller(obj.ZController, stepFactor);
        catch
            obj.MJC3Controller = MJC3_Native_Controller(obj.ZController, stepFactor);
        end
    end
end
```

### Improved State (Strategy Pattern)
```matlab
% src/strategies/IControllerStrategy.m
classdef IControllerStrategy < handle
    methods (Abstract)
        createController(zController, stepFactor)
        isAvailable()
    end
end

% src/strategies/SimulationControllerStrategy.m
classdef SimulationControllerStrategy < IControllerStrategy
    methods
        function controller = createController(obj, zController, stepFactor)
            controller = MJC3_Simulation_Controller(zController, stepFactor);
        end
        
        function available = isAvailable(obj)
            available = true; % Always available in simulation
        end
    end
end

% src/strategies/HIDControllerStrategy.m
classdef HIDControllerStrategy < IControllerStrategy
    methods
        function controller = createController(obj, zController, stepFactor)
            controller = MJC3_HID_Controller(zController, stepFactor);
        end
        
        function available = isAvailable(obj)
            try
                PsychHID('Devices');
                available = true;
            catch
                available = false;
            end
        end
    end
end

% src/controllers/core/ControllerFactory.m
classdef ControllerFactory < handle
    properties (Access = private)
        Strategies IControllerStrategy
    end
    
    methods
        function obj = ControllerFactory()
            obj.Strategies = {SimulationControllerStrategy(), ...
                             HIDControllerStrategy(), ...
                             NativeControllerStrategy()};
        end
        
        function controller = createController(obj, zController, stepFactor)
            for i = 1:length(obj.Strategies)
                if obj.Strategies{i}.isAvailable()
                    controller = obj.Strategies{i}.createController(zController, stepFactor);
                    return;
                end
            end
            error('No available controller strategy');
        end
    end
end
```

## Example 4: Command Pattern Implementation

### Current State (Direct Method Calls)
```matlab
% In StageController.m
function moveToPosition(obj, x, y, z)
    obj.StageService.moveTo(x, y, z);
    obj.MetadataService.logPosition(x, y, z);
    obj.notify('PositionChanged');
end
```

### Improved State (Command Pattern)
```matlab
% src/commands/ICommand.m
classdef ICommand < handle
    methods (Abstract)
        execute()
        undo()
    end
end

% src/commands/StageCommands.m
classdef MoveStageCommand < ICommand
    properties (Access = private)
        StageService
        MetadataService
        OldPosition
        NewPosition
    end
    
    methods
        function obj = MoveStageCommand(stageService, metadataService, newPosition)
            obj.StageService = stageService;
            obj.MetadataService = metadataService;
            obj.NewPosition = newPosition;
        end
        
        function execute(obj)
            obj.OldPosition = obj.StageService.getPosition();
            obj.StageService.moveTo(obj.NewPosition.x, obj.NewPosition.y, obj.NewPosition.z);
            obj.MetadataService.logPosition(obj.NewPosition.x, obj.NewPosition.y, obj.NewPosition.z);
        end
        
        function undo(obj)
            obj.StageService.moveTo(obj.OldPosition.x, obj.OldPosition.y, obj.OldPosition.z);
            obj.MetadataService.logPosition(obj.OldPosition.x, obj.OldPosition.y, obj.OldPosition.z);
        end
    end
end

% src/controllers/core/StageController.m
classdef StageController < handle
    properties (Access = private)
        CommandHistory ICommand
    end
    
    methods
        function moveToPosition(obj, x, y, z)
            command = MoveStageCommand(obj.StageService, obj.MetadataService, struct('x', x, 'y', y, 'z', z));
            command.execute();
            obj.CommandHistory{end+1} = command;
            obj.notify('PositionChanged');
        end
        
        function undoLastMove(obj)
            if ~isempty(obj.CommandHistory)
                lastCommand = obj.CommandHistory{end};
                lastCommand.undo();
                obj.CommandHistory(end) = [];
                obj.notify('PositionChanged');
            end
        end
    end
end
```

## Example 5: Domain Model Implementation

### Current State (Primitive Data)
```matlab
% In MetadataService.m
function metadata = createMetadata(obj, timestamp, filename, scanner, x, y, z)
    metadata = struct();
    metadata.timestamp = timestamp;
    metadata.filename = filename;
    metadata.scanner = scanner;
    metadata.xPos = x;
    metadata.yPos = y;
    metadata.zPos = z;
end
```

### Improved State (Domain Models)
```matlab
% src/models/Metadata.m
classdef Metadata < handle
    properties
        Timestamp
        Filename
        Scanner
        Position
        ScanParameters
    end
    
    methods
        function obj = Metadata(timestamp, filename, scanner, position, scanParams)
            obj.Timestamp = timestamp;
            obj.Filename = filename;
            obj.Scanner = scanner;
            obj.Position = position;
            obj.ScanParameters = scanParams;
        end
        
        function str = toCSV(obj)
            str = sprintf('%s,%s,%s,%.2f,%.2f,%.2f', ...
                obj.Timestamp, obj.Filename, obj.Scanner, ...
                obj.Position.X, obj.Position.Y, obj.Position.Z);
        end
    end
end

% src/models/Position.m
classdef Position < handle
    properties
        X
        Y
        Z
    end
    
    methods
        function obj = Position(x, y, z)
            obj.X = x;
            obj.Y = y;
            obj.Z = z;
        end
        
        function distance = distanceTo(obj, otherPosition)
            distance = sqrt((obj.X - otherPosition.X)^2 + ...
                          (obj.Y - otherPosition.Y)^2 + ...
                          (obj.Z - otherPosition.Z)^2);
        end
    end
end

% src/services/core/MetadataService.m
classdef MetadataService < handle
    methods
        function metadata = createMetadata(obj, timestamp, filename, scanner, position, scanParams)
            metadata = Metadata(timestamp, filename, scanner, position, scanParams);
        end
    end
end
```

## Example 6: Component-Based View Implementation

### Current State (Monolithic View)
```matlab
% In StageView.m (1157 lines)
classdef StageView < handle
    properties
        MainWindow
        StagePanel
        PositionPanel
        ControlPanel
        % ... many more properties
    end
    
    methods
        function createUI(obj)
            % 500+ lines of UI creation code
        end
        
        function updatePosition(obj, x, y, z)
            % 200+ lines of position update code
        end
        
        function handleButtonClick(obj, source, event)
            % 300+ lines of event handling code
        end
    end
end
```

### Improved State (Component-Based)
```matlab
% src/views/components/StageComponent.m
classdef StageComponent < handle
    properties (Access = private)
        Panel
        PositionDisplay
        ControlButtons
    end
    
    methods
        function obj = StageComponent(parent)
            obj.createUI(parent);
        end
        
        function createUI(obj, parent)
            obj.Panel = uipanel(parent);
            obj.createPositionDisplay();
            obj.createControlButtons();
        end
        
        function updatePosition(obj, x, y, z)
            obj.PositionDisplay.update(x, y, z);
        end
    end
end

% src/views/components/PositionDisplay.m
classdef PositionDisplay < handle
    properties (Access = private)
        Panel
        XLabel
        YLabel
        ZLabel
    end
    
    methods
        function obj = PositionDisplay(parent)
            obj.createUI(parent);
        end
        
        function update(obj, x, y, z)
            obj.XLabel.Text = sprintf('X: %.2f', x);
            obj.YLabel.Text = sprintf('Y: %.2f', y);
            obj.ZLabel.Text = sprintf('Z: %.2f', z);
        end
    end
end

% src/views/layouts/StageLayout.m
classdef StageLayout < handle
    properties (Access = private)
        Components StageComponent
    end
    
    methods
        function obj = StageLayout(parent)
            obj.createComponents(parent);
        end
        
        function createComponents(obj, parent)
            obj.Components = StageComponent(parent);
        end
    end
end
```

## Benefits Demonstrated

### 1. **Testability**
```matlab
% Easy to mock interfaces for testing
function testStageController()
    mockStageService = MockStageService();
    mockMetadataService = MockMetadataService();
    controller = StageController(mockStageService, mockMetadataService);
    
    controller.moveStage(10, 20, 30);
    
    assert(mockStageService.moveToCalled);
    assert(mockMetadataService.logPositionCalled);
end
```

### 2. **Extensibility**
```matlab
% Easy to add new controller strategies
classdef BluetoothControllerStrategy < IControllerStrategy
    methods
        function controller = createController(obj, zController, stepFactor)
            controller = MJC3_Bluetooth_Controller(zController, stepFactor);
        end
        
        function available = isAvailable(obj)
            available = obj.checkBluetoothAvailability();
        end
    end
end
```

### 3. **Maintainability**
```matlab
% Clear separation of concerns
% Each class has a single responsibility
% Dependencies are explicit and injectable
% Easy to understand and modify
```

This implementation approach transforms the current monolithic architecture into a clean, maintainable, and extensible system following modern software engineering principles. 