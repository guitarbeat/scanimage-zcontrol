function test_stage_control_service()
    % test_stage_control_service - Test the new StageControlService
    % This script demonstrates the functionality of the extracted service
    
    fprintf('Testing StageControlService...\n\n');
    
    try
        % Create a mock ScanImageManager for testing
        mockScanImageManager = createMockScanImageManager();
        
        % Create the StageControlService
        stageService = StageControlService(mockScanImageManager);
        
        % Test 1: Basic movement
        fprintf('=== Test 1: Basic Stage Movement ===\n');
        success = stageService.moveStage('Z', 5.0);
        fprintf('Move Z by 5.0 μm: %s\n', success2str(success));
        
        success = stageService.moveStage('X', -2.5);
        fprintf('Move X by -2.5 μm: %s\n', success2str(success));
        
        % Test 2: Absolute positioning
        fprintf('\n=== Test 2: Absolute Positioning ===\n');
        success = stageService.setAbsolutePosition('Z', 10.0);
        fprintf('Set Z to 10.0 μm: %s\n', success2str(success));
        
        success = stageService.setXYZPosition(1.0, 2.0, 3.0);
        fprintf('Set XYZ to (1.0, 2.0, 3.0): %s\n', success2str(success));
        
        % Test 3: Position queries
        fprintf('\n=== Test 3: Position Queries ===\n');
        positions = stageService.getCurrentPositions();
        fprintf('Current positions: X=%.1f, Y=%.1f, Z=%.1f μm\n', ...
            positions.x, positions.y, positions.z);
        
        % Test 4: Validation
        fprintf('\n=== Test 4: Parameter Validation ===\n');
        [valid, msg] = StageControlService.validateStageMovementParameters('Z', 5.0);
        fprintf('Valid movement (Z, 5.0): %s %s\n', valid2str(valid), msg);
        
        [valid, msg] = StageControlService.validateStageMovementParameters('Q', 5.0);
        fprintf('Invalid axis (Q, 5.0): %s %s\n', valid2str(valid), msg);
        
        [valid, msg] = StageControlService.validateAbsolutePosition(100.0);
        fprintf('Valid position (100.0): %s %s\n', valid2str(valid), msg);
        
        [valid, msg] = StageControlService.validateAbsolutePosition(50000.0);
        fprintf('Invalid position (50000.0): %s %s\n', valid2str(valid), msg);
        
        % Test 5: Utility methods
        fprintf('\n=== Test 5: Utility Methods ===\n');
        distance = stageService.calculateDistance(5.0, 5.0, 5.0);
        fprintf('Distance to (5,5,5): %.2f μm\n', distance);
        
        inBounds = stageService.isPositionInBounds(100, 200, 300);
        fprintf('Position (100,200,300) in bounds: %s\n', valid2str(inBounds));
        
        stepSize = stageService.getOptimalStepSize(25.0);
        fprintf('Optimal step size for 25μm distance: %.1f μm\n', stepSize);
        
        % Test 6: Reset functionality
        fprintf('\n=== Test 6: Reset Functionality ===\n');
        success = stageService.resetPosition('Z');
        fprintf('Reset Z position: %s\n', success2str(success));
        
        success = stageService.resetPosition('ALL');
        fprintf('Reset all positions: %s\n', success2str(success));
        
        fprintf('\n✅ All tests completed successfully!\n');
        
    catch ME
        fprintf('\n❌ Test failed with error: %s\n', ME.message);
        fprintf('Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
    end
end

function mockManager = createMockScanImageManager()
    % Create a simple mock ScanImageManager for testing
    mockManager = struct();
    mockManager.SimulationMode = true;
    mockManager.currentX = 0;
    mockManager.currentY = 0;
    mockManager.currentZ = 0;
    
    % Mock moveStage method
    mockManager.moveStage = @(axis, microns) mockMoveStage(mockManager, axis, microns);
    
    % Mock getPositions method
    mockManager.getPositions = @() struct('x', mockManager.currentX, ...
                                         'y', mockManager.currentY, ...
                                         'z', mockManager.currentZ);
end

function newPos = mockMoveStage(mockManager, axis, microns)
    % Mock implementation of stage movement
    switch upper(axis)
        case 'X'
            mockManager.currentX = mockManager.currentX + microns;
            newPos = mockManager.currentX;
        case 'Y'
            mockManager.currentY = mockManager.currentY + microns;
            newPos = mockManager.currentY;
        case 'Z'
            mockManager.currentZ = mockManager.currentZ + microns;
            newPos = mockManager.currentZ;
        otherwise
            error('Invalid axis: %s', axis);
    end
end

function str = success2str(success)
    % Convert boolean success to string
    if success
        str = '✅ SUCCESS';
    else
        str = '❌ FAILED';
    end
end

function str = valid2str(valid)
    % Convert boolean valid to string
    if valid
        str = '✅ VALID';
    else
        str = '❌ INVALID';
    end
end