function test_service_integration()
    % test_service_integration - Test the integration of new services
    % This script tests the StageControlService and MetricCalculationService
    % integration with the existing UI components
    
    fprintf('Testing Service Integration...\n');
    fprintf('==============================\n\n');
    
    try
        % Test 1: StageControlService Integration
        fprintf('1. Testing StageControlService Integration...\n');
        test_stage_control_service();
        fprintf('   ✓ StageControlService integration test passed\n\n');
        
        % Test 2: MetricCalculationService Integration
        fprintf('2. Testing MetricCalculationService Integration...\n');
        test_metric_calculation_service();
        fprintf('   ✓ MetricCalculationService integration test passed\n\n');
        
        % Test 3: UIController Integration
        fprintf('3. Testing UIController Integration...\n');
        test_ui_controller_integration();
        fprintf('   ✓ UIController integration test passed\n\n');
        
        % Test 4: Controller Event Integration
        fprintf('4. Testing Controller Event Integration...\n');
        test_controller_events();
        fprintf('   ✓ Controller event integration test passed\n\n');
        
        fprintf('All service integration tests passed! 🎉\n');
        
    catch ME
        fprintf('❌ Service integration test failed: %s\n', ME.message);
        fprintf('Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
        rethrow(ME);
    end
end

function test_stage_control_service()
    % Test StageControlService functionality
    
    % Create mock ScanImageManager
    mockScanImageManager = MockScanImageManager();
    
    % Create StageControlService
    stageService = StageControlService(mockScanImageManager);
    
    % Test basic movement
    success = stageService.moveStage('Z', 10.0);
    assert(success, 'Stage movement should succeed');
    
    % Test position retrieval
    positions = stageService.getCurrentPositions();
    assert(abs(positions.z - 10.0) < 0.01, 'Position should be updated correctly');
    
    % Test absolute positioning
    success = stageService.setAbsolutePosition('X', 5.0);
    assert(success, 'Absolute positioning should succeed');
    
    positions = stageService.getCurrentPositions();
    assert(abs(positions.x - 5.0) < 0.01, 'X position should be set correctly');
    
    % Test validation
    [valid, ~] = StageControlService.validateStageMovementParameters('Z', 1.0);
    assert(valid, 'Valid parameters should pass validation');
    
    [valid, ~] = StageControlService.validateStageMovementParameters('Invalid', 1.0);
    assert(~valid, 'Invalid axis should fail validation');
end

function test_metric_calculation_service()
    % Test MetricCalculationService functionality
    
    % Create mock ScanImageManager
    mockScanImageManager = MockScanImageManager();
    
    % Create MetricCalculationService
    metricService = MetricCalculationService(mockScanImageManager);
    
    % Test metric calculation
    position = [0, 0, 0];
    metrics = metricService.calculateAllMetrics(position);
    
    % Verify all metric types are calculated
    expectedFields = {'Std_Dev', 'Mean', 'Max'};
    for i = 1:length(expectedFields)
        assert(isfield(metrics, expectedFields{i}), ...
            sprintf('Metric %s should be calculated', expectedFields{i}));
        assert(~isnan(metrics.(expectedFields{i})), ...
            sprintf('Metric %s should not be NaN', expectedFields{i}));
    end
    
    % Test metric type setting
    success = metricService.setMetricType('Mean');
    assert(success, 'Setting valid metric type should succeed');
    
    currentType = metricService.getMetricType();
    assert(strcmp(currentType, 'Mean'), 'Metric type should be updated');
    
    % Test current metric retrieval
    currentMetric = metricService.getCurrentMetric(position);
    assert(~isnan(currentMetric), 'Current metric should not be NaN');
    
    % Test validation
    [valid, ~] = MetricCalculationService.validateMetricType('Std Dev');
    assert(valid, 'Valid metric type should pass validation');
    
    [valid, ~] = MetricCalculationService.validateMetricType('Invalid');
    assert(~valid, 'Invalid metric type should fail validation');
end

function test_ui_controller_integration()
    % Test UIController integration (mock UI components)
    
    % Create mock app structure
    mockApp = struct();
    mockApp.PositionDisplay = struct();
    mockApp.PositionDisplay.XValue = MockUIComponent();
    mockApp.PositionDisplay.YValue = MockUIComponent();
    mockApp.PositionDisplay.ZValue = MockUIComponent();
    
    mockApp.MetricDisplay = struct();
    mockApp.MetricDisplay.ValueLabel = MockUIComponent();
    mockApp.MetricDisplay.TypeDropdown = MockUIComponent();
    
    mockApp.ManualControls = struct();
    mockApp.ManualControls.UpButton = MockUIComponent();
    mockApp.ManualControls.DownButton = MockUIComponent();
    
    mockApp.AutoControls = struct();
    mockApp.AutoControls.StartStopButton = MockUIComponent();
    
    mockApp.StatusControls = struct();
    mockApp.StatusControls.StatusLabel = MockUIComponent();
    
    % Create mock controller
    mockApp.Controller = struct();
    mockApp.Controller.CurrentXPosition = 1.0;
    mockApp.Controller.CurrentYPosition = 2.0;
    mockApp.Controller.CurrentPosition = 3.0;
    mockApp.Controller.CurrentMetric = 42.5;
    mockApp.Controller.CurrentMetricType = 'Std Dev';
    mockApp.Controller.IsAutoRunning = false;
    mockApp.Controller.StatusMessage = 'Ready';
    mockApp.Controller.SimulationMode = true;
    
    % Create UIController
    uiController = UIController(mockApp);
    
    % Test UI updates (should not throw errors)
    uiController.updateAllUI();
    uiController.updatePositionDisplay();
    uiController.updateMetricDisplay();
    uiController.updateControlStates();
    uiController.updateStatusDisplay();
    
    % Verify some updates were applied
    assert(~isempty(mockApp.PositionDisplay.XValue.Text), 'X position should be updated');
    assert(~isempty(mockApp.MetricDisplay.ValueLabel.Text), 'Metric value should be updated');
end

function test_controller_events()
    % Test controller event integration
    
    % Create mock ScanImageManager
    mockScanImageManager = MockScanImageManager();
    
    % Create controller (this will create services internally)
    controller = FoilviewController();
    
    % Test that services are properly initialized
    assert(~isempty(controller.StageControlService), 'StageControlService should be initialized');
    assert(~isempty(controller.MetricCalculationService), 'MetricCalculationService should be initialized');
    
    % Test basic operations
    controller.moveStage(5.0);
    controller.updateMetric();
    
    % Test that positions are synchronized
    positions = controller.StageControlService.getCurrentPositions();
    assert(abs(controller.CurrentPosition - positions.z) < 0.01, ...
        'Controller position should be synchronized with service');
end

% Mock classes for testing
classdef MockScanImageManager < handle
    properties
        SimulationMode = true
        CurrentX = 0
        CurrentY = 0
        CurrentZ = 0
    end
    
    methods
        function obj = MockScanImageManager()
            obj.SimulationMode = true;
        end
        
        function isSimulation = isSimulationMode(obj)
            isSimulation = obj.SimulationMode;
        end
        
        function newPos = moveStage(obj, axis, microns)
            switch upper(axis)
                case 'X'
                    obj.CurrentX = obj.CurrentX + microns;
                    newPos = obj.CurrentX;
                case 'Y'
                    obj.CurrentY = obj.CurrentY + microns;
                    newPos = obj.CurrentY;
                case 'Z'
                    obj.CurrentZ = obj.CurrentZ + microns;
                    newPos = obj.CurrentZ;
                otherwise
                    error('Invalid axis');
            end
        end
        
        function positions = getPositions(obj)
            positions = struct('x', obj.CurrentX, 'y', obj.CurrentY, 'z', obj.CurrentZ);
        end
        
        function pixelData = getImageData(~)
            % Return mock image data
            pixelData = rand(100, 100) * 255;
        end
        
        function cleanup(~)
            % Mock cleanup
        end
    end
end

classdef MockUIComponent < handle
    properties
        Text = ''
        Value = ''
        Enable = 'on'
        BackgroundColor = [1 1 1]
        FontColor = [0 0 0]
        FontSize = 10
        FontWeight = 'normal'
    end
    
    methods
        function obj = MockUIComponent()
            % Mock UI component constructor
        end
    end
end