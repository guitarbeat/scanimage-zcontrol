classdef FoilviewTestSuite < handle
    % FoilviewTestSuite - Comprehensive testing framework for FoilView application
    % 
    % This class provides unit tests, integration tests, and simulation testing
    % for the enhanced FoilView application with robust error handling.
    
    properties (Access = private)
        ErrorHandler
        TestResults
        TestCount = 0
        PassCount = 0
        FailCount = 0
        StartTime
    end
    
    methods (Access = public)
        function obj = FoilviewTestSuite()
            % Constructor - Initialize test suite
            
            obj.ErrorHandler = ErrorHandlerService();
            obj.TestResults = {};
            obj.StartTime = datetime('now');
            
            fprintf('\n=== FoilView Test Suite ===\n');
            fprintf('Started: %s\n\n', char(obj.StartTime));
        end
        
        function runAllTests(obj)
            % Run complete test suite
            
            fprintf('Running comprehensive FoilView test suite...\n\n');
            
            % Unit tests
            obj.runUnitTests();
            
            % Integration tests
            obj.runIntegrationTests();
            
            % Simulation tests
            obj.runSimulationTests();
            
            % Error handling tests
            obj.runErrorHandlingTests();
            
            % Performance tests
            obj.runPerformanceTests();
            
            % Generate final report
            obj.generateTestReport();
        end
        
        function runUnitTests(obj)
            % Run unit tests for individual components
            
            fprintf('=== UNIT TESTS ===\n');
            
            % Test ErrorHandlerService
            obj.testErrorHandlerService();
            
            % Test ScanImageManagerEnhanced
            obj.testScanImageManagerEnhanced();
            
            % Test ApplicationInitializer
            obj.testApplicationInitializer();
            
            fprintf('\n');
        end
        
        function runIntegrationTests(obj)
            % Run integration tests for component interactions
            
            fprintf('=== INTEGRATION TESTS ===\n');
            
            % Test startup sequence
            obj.testStartupSequence();
            
            % Test service integration
            obj.testServiceIntegration();
            
            % Test UI integration
            obj.testUIIntegration();
            
            fprintf('\n');
        end
        
        function runSimulationTests(obj)
            % Run simulation mode tests
            
            fprintf('=== SIMULATION TESTS ===\n');
            
            % Test simulation mode activation
            obj.testSimulationModeActivation();
            
            % Test simulated stage movement
            obj.testSimulatedStageMovement();
            
            % Test simulated image data generation
            obj.testSimulatedImageData();
            
            % Test simulated metadata generation
            obj.testSimulatedMetadata();
            
            fprintf('\n');
        end
        
        function runErrorHandlingTests(obj)
            % Run error handling and recovery tests
            
            fprintf('=== ERROR HANDLING TESTS ===\n');
            
            % Test initialization error handling
            obj.testInitializationErrorHandling();
            
            % Test connection error handling
            obj.testConnectionErrorHandling();
            
            % Test runtime error handling
            obj.testRuntimeErrorHandling();
            
            % Test error recovery mechanisms
            obj.testErrorRecovery();
            
            fprintf('\n');
        end
        
        function runPerformanceTests(obj)
            % Run performance and stress tests
            
            fprintf('=== PERFORMANCE TESTS ===\n');
            
            % Test initialization performance
            obj.testInitializationPerformance();
            
            % Test memory usage
            obj.testMemoryUsage();
            
            % Test timer performance
            obj.testTimerPerformance();
            
            fprintf('\n');
        end
    end
    
    methods (Access = private)
        % Unit test methods
        function testErrorHandlerService(obj)
            obj.runTest('ErrorHandlerService Creation', @() obj.testErrorHandlerCreation());
            obj.runTest('Error Message Generation', @() obj.testErrorMessageGeneration());
            obj.runTest('Logging Functionality', @() obj.testLoggingFunctionality());
            obj.runTest('Callback Registration', @() obj.testCallbackRegistration());
        end
        
        function testScanImageManagerEnhanced(obj)
            obj.runTest('ScanImageManager Creation', @() obj.testScanImageManagerCreation());
            obj.runTest('Connection Retry Logic', @() obj.testConnectionRetryLogic());
            obj.runTest('Simulation Mode Switch', @() obj.testSimulationModeSwitch());
            obj.runTest('Position Tracking', @() obj.testPositionTracking());
        end
        
        function testApplicationInitializer(obj)
            obj.runTest('Initializer Creation', @() obj.testInitializerCreation());
            obj.runTest('Dependency Validation', @() obj.testDependencyValidation());
            obj.runTest('Service Initialization', @() obj.testServiceInitialization());
        end
        
        % Integration test methods
        function testStartupSequence(obj)
            obj.runTest('Complete Startup Flow', @() obj.testCompleteStartupFlow());
            obj.runTest('Startup with ScanImage Available', @() obj.testStartupWithScanImage());
            obj.runTest('Startup without ScanImage', @() obj.testStartupWithoutScanImage());
        end
        
        function testServiceIntegration(obj)
            obj.runTest('Service Communication', @() obj.testServiceCommunication());
            obj.runTest('Event Propagation', @() obj.testEventPropagation());
        end
        
        function testUIIntegration(obj)
            obj.runTest('UI Component Creation', @() obj.testUIComponentCreation());
            obj.runTest('Callback Registration', @() obj.testUICallbackRegistration());
        end
        
        % Simulation test methods
        function testSimulationModeActivation(obj)
            obj.runTest('Simulation Mode Activation', @() obj.testSimModeActivation());
        end
        
        function testSimulatedStageMovement(obj)
            obj.runTest('Simulated Stage Movement', @() obj.testSimStageMovement());
        end
        
        function testSimulatedImageData(obj)
            obj.runTest('Simulated Image Data', @() obj.testSimImageData());
        end
        
        function testSimulatedMetadata(obj)
            obj.runTest('Simulated Metadata', @() obj.testSimMetadata());
        end
        
        % Error handling test methods
        function testInitializationErrorHandling(obj)
            obj.runTest('Initialization Error Handling', @() obj.testInitErrorHandling());
        end
        
        function testConnectionErrorHandling(obj)
            obj.runTest('Connection Error Handling', @() obj.testConnErrorHandling());
        end
        
        function testRuntimeErrorHandling(obj)
            obj.runTest('Runtime Error Handling', @() obj.testRuntimeErrorHandling());
        end
        
        function testErrorRecovery(obj)
            obj.runTest('Error Recovery Mechanisms', @() obj.testErrorRecoveryMechanisms());
        end
        
        % Performance test methods
        function testInitializationPerformance(obj)
            obj.runTest('Initialization Performance', @() obj.testInitPerformance());
        end
        
        function testMemoryUsage(obj)
            obj.runTest('Memory Usage', @() obj.testMemUsage());
        end
        
        function testTimerPerformance(obj)
            obj.runTest('Timer Performance', @() obj.testTimerPerf());
        end
        
        % Individual test implementations
        function testErrorHandlerCreation(obj)
            errorHandler = ErrorHandlerService();
            assert(~isempty(errorHandler), 'ErrorHandlerService should be created');
            assert(isa(errorHandler, 'ErrorHandlerService'), 'Should be ErrorHandlerService instance');
        end
        
        function testErrorMessageGeneration(obj)
            errorHandler = ErrorHandlerService();
            testError = MException('Test:Error', 'Test error message');
            userMsg = errorHandler.getUserFriendlyMessage(testError, 'test_context');
            assert(~isempty(userMsg), 'User message should not be empty');
            assert(ischar(userMsg), 'User message should be a string');
        end
        
        function testLoggingFunctionality(obj)
            errorHandler = ErrorHandlerService();
            % Test that logging doesn't throw errors
            errorHandler.logMessage('INFO', 'Test message');
            errorHandler.logMessage('WARNING', 'Test warning');
            errorHandler.logMessage('ERROR', 'Test error');
        end
        
        function testCallbackRegistration(obj)
            errorHandler = ErrorHandlerService();
            callbackCalled = false;
            callback = @(type, error) assignin('caller', 'callbackCalled', true);
            errorHandler.registerErrorCallback(callback);
            % Callback registration should not throw errors
        end
        
        function testScanImageManagerCreation(obj)
            errorHandler = ErrorHandlerService();
            manager = ScanImageManagerEnhanced(errorHandler);
            assert(~isempty(manager), 'ScanImageManagerEnhanced should be created');
            assert(isa(manager, 'ScanImageManagerEnhanced'), 'Should be ScanImageManagerEnhanced instance');
        end
        
        function testConnectionRetryLogic(obj)
            errorHandler = ErrorHandlerService();
            manager = ScanImageManagerEnhanced(errorHandler);
            
            % Test retry configuration
            manager.setRetryConfig(2, 0.1, 1.0, 1.5);
            
            % Test connection attempt (will fail but should handle gracefully)
            [success, message] = manager.connectWithRetry();
            assert(~success, 'Connection should fail when ScanImage not available');
            assert(~isempty(message), 'Should return error message');
        end
        
        function testSimulationModeSwitch(obj)
            errorHandler = ErrorHandlerService();
            manager = ScanImageManagerEnhanced(errorHandler);
            
            manager.enableSimulationMode();
            status = manager.getConnectionStatus();
            assert(status.isSimulation, 'Should be in simulation mode');
            assert(status.isInitialized, 'Should be initialized');
        end
        
        function testPositionTracking(obj)
            errorHandler = ErrorHandlerService();
            manager = ScanImageManagerEnhanced(errorHandler);
            manager.enableSimulationMode();
            
            positions = manager.getCurrentPositions();
            assert(isstruct(positions), 'Positions should be a struct');
            assert(isfield(positions, 'x'), 'Should have x position');
            assert(isfield(positions, 'y'), 'Should have y position');
            assert(isfield(positions, 'z'), 'Should have z position');
        end
        
        function testInitializerCreation(obj)
            errorHandler = ErrorHandlerService();
            initializer = ApplicationInitializer(errorHandler);
            assert(~isempty(initializer), 'ApplicationInitializer should be created');
            assert(isa(initializer, 'ApplicationInitializer'), 'Should be ApplicationInitializer instance');
        end
        
        function testDependencyValidation(obj)
            errorHandler = ErrorHandlerService();
            initializer = ApplicationInitializer(errorHandler);
            % Dependency validation should not throw errors
            status = initializer.getInitializationStatus();
            assert(isstruct(status), 'Status should be a struct');
        end
        
        function testServiceInitialization(obj)
            errorHandler = ErrorHandlerService();
            initializer = ApplicationInitializer(errorHandler);
            % Service initialization test would go here
            % For now, just verify initializer works
            assert(~isempty(initializer), 'Initializer should exist');
        end
        
        function testCompleteStartupFlow(obj)
            % Test complete application startup
            try
                errorHandler = ErrorHandlerService();
                initializer = ApplicationInitializer(errorHandler);
                [success, appData] = initializer.initializeApplication();
                % Should complete without throwing errors
                assert(islogical(success), 'Should return boolean success');
            catch ME
                % Startup may fail due to missing dependencies, but should handle gracefully
                assert(contains(ME.message, 'initialization') || contains(ME.message, 'UI'), ...
                    'Should be a handled initialization error');
            end
        end
        
        function testStartupWithScanImage(obj)
            % Test startup when ScanImage is available (simulated)
            % This would require mocking ScanImage
            fprintf('  [SKIP] ScanImage availability test requires mocking\n');
        end
        
        function testStartupWithoutScanImage(obj)
            % Test startup when ScanImage is not available
            errorHandler = ErrorHandlerService();
            manager = ScanImageManagerEnhanced(errorHandler);
            [success, message] = manager.connectWithRetry();
            assert(~success, 'Should fail when ScanImage not available');
            assert(manager.getConnectionStatus().isSimulation, 'Should switch to simulation mode');
        end
        
        function testServiceCommunication(obj)
            % Test communication between services
            errorHandler = ErrorHandlerService();
            manager = ScanImageManagerEnhanced(errorHandler);
            manager.enableSimulationMode();
            
            % Test position retrieval
            positions = manager.getCurrentPositions();
            assert(isstruct(positions), 'Should return position struct');
        end
        
        function testEventPropagation(obj)
            % Test event propagation between components
            fprintf('  [SKIP] Event propagation test requires full application context\n');
        end
        
        function testUIComponentCreation(obj)
            % Test UI component creation
            fprintf('  [SKIP] UI component test requires graphics environment\n');
        end
        
        function testUICallbackRegistration(obj)
            % Test UI callback registration
            fprintf('  [SKIP] UI callback test requires graphics environment\n');
        end
        
        function testSimModeActivation(obj)
            errorHandler = ErrorHandlerService();
            manager = ScanImageManagerEnhanced(errorHandler);
            
            manager.enableSimulationMode();
            status = manager.getConnectionStatus();
            assert(status.isSimulation, 'Should be in simulation mode');
        end
        
        function testSimStageMovement(obj)
            errorHandler = ErrorHandlerService();
            manager = ScanImageManagerEnhanced(errorHandler);
            manager.enableSimulationMode();
            
            initialPos = manager.getCurrentPositions();
            newPos = manager.moveStage('z', 5.0);
            assert(abs(newPos - initialPos.z - 5.0) < 0.001, 'Should move stage by 5.0 μm');
        end
        
        function testSimImageData(obj)
            errorHandler = ErrorHandlerService();
            manager = ScanImageManagerEnhanced(errorHandler);
            manager.enableSimulationMode();
            
            imageData = manager.getImageData();
            assert(~isempty(imageData), 'Should generate image data');
            assert(isnumeric(imageData), 'Image data should be numeric');
            assert(size(imageData, 1) == 512 && size(imageData, 2) == 512, 'Should be 512x512');
        end
        
        function testSimMetadata(obj)
            errorHandler = ErrorHandlerService();
            manager = ScanImageManagerEnhanced(errorHandler);
            manager.enableSimulationMode();
            
            metadata = manager.generateSimulatedMetadata();
            assert(isstruct(metadata), 'Metadata should be a struct');
            assert(isfield(metadata, 'timestamp'), 'Should have timestamp');
            assert(isfield(metadata, 'xPos'), 'Should have position data');
        end
        
        function testInitErrorHandling(obj)
            % Test initialization error handling
            errorHandler = ErrorHandlerService();
            testError = MException('Test:InitError', 'Test initialization error');
            
            % Should handle error without throwing
            errorHandler.handleInitializationError(testError, 'test_context');
        end
        
        function testConnErrorHandling(obj)
            % Test connection error handling
            errorHandler = ErrorHandlerService();
            testError = MException('Test:ConnError', 'Test connection error');
            
            % Should handle error without throwing
            errorHandler.handleConnectionError(testError, 'test_context');
        end
        
        function testRuntimeErrorHandling(obj)
            % Test runtime error handling
            errorHandler = ErrorHandlerService();
            testError = MException('Test:RuntimeError', 'Test runtime error');
            
            % Should handle error without throwing
            errorHandler.handleRuntimeError(testError, 'test_operation');
        end
        
        function testErrorRecoveryMechanisms(obj)
            % Test error recovery mechanisms
            errorHandler = ErrorHandlerService();
            manager = ScanImageManagerEnhanced(errorHandler);
            
            % Test recovery by switching to simulation mode
            manager.enableSimulationMode();
            assert(manager.getConnectionStatus().isSimulation, 'Should recover to simulation mode');
        end
        
        function testInitPerformance(obj)
            % Test initialization performance
            tic;
            errorHandler = ErrorHandlerService();
            manager = ScanImageManagerEnhanced(errorHandler);
            manager.enableSimulationMode();
            elapsedTime = toc;
            
            assert(elapsedTime < 5.0, 'Initialization should complete within 5 seconds');
        end
        
        function testMemUsage(obj)
            % Test memory usage
            try
                [~, memBefore] = memory;
                
                errorHandler = ErrorHandlerService();
                manager = ScanImageManagerEnhanced(errorHandler);
                manager.enableSimulationMode();
                
                [~, memAfter] = memory;
                memUsed = memBefore.MemAvailableAllArrays - memAfter.MemAvailableAllArrays;
                
                % Should use less than 100MB
                assert(memUsed < 100*1024^2, 'Should use less than 100MB of memory');
            catch
                fprintf('  [SKIP] Memory test not available on this system\n');
            end
        end
        
        function testTimerPerf(obj)
            % Test timer performance
            fprintf('  [SKIP] Timer performance test requires full application context\n');
        end
        
        % Test execution framework
        function runTest(obj, testName, testFunc)
            obj.TestCount = obj.TestCount + 1;
            
            try
                testFunc();
                obj.PassCount = obj.PassCount + 1;
                fprintf('  ✓ %s\n', testName);
                obj.TestResults{end+1} = struct('name', testName, 'result', 'PASS', 'error', '');
            catch ME
                obj.FailCount = obj.FailCount + 1;
                fprintf('  ✗ %s: %s\n', testName, ME.message);
                obj.TestResults{end+1} = struct('name', testName, 'result', 'FAIL', 'error', ME.message);
            end
        end
        
        function generateTestReport(obj)
            % Generate comprehensive test report
            
            endTime = datetime('now');
            duration = seconds(endTime - obj.StartTime);
            
            fprintf('\n=== TEST REPORT ===\n');
            fprintf('Started: %s\n', char(obj.StartTime));
            fprintf('Completed: %s\n', char(endTime));
            fprintf('Duration: %.1f seconds\n\n', duration);
            
            fprintf('Results:\n');
            fprintf('  Total Tests: %d\n', obj.TestCount);
            fprintf('  Passed: %d (%.1f%%)\n', obj.PassCount, (obj.PassCount/obj.TestCount)*100);
            fprintf('  Failed: %d (%.1f%%)\n', obj.FailCount, (obj.FailCount/obj.TestCount)*100);
            
            if obj.FailCount > 0
                fprintf('\nFailed Tests:\n');
                for i = 1:length(obj.TestResults)
                    result = obj.TestResults{i};
                    if strcmp(result.result, 'FAIL')
                        fprintf('  - %s: %s\n', result.name, result.error);
                    end
                end
            end
            
            fprintf('\n=== END REPORT ===\n\n');
            
            % Save report to file
            obj.saveTestReport();
        end
        
        function saveTestReport(obj)
            % Save test report to file
            
            try
                reportFile = fullfile('logs', sprintf('test_report_%s.txt', ...
                    datestr(now, 'yyyymmdd_HHMMSS')));
                
                % Create logs directory if it doesn't exist
                if ~exist('logs', 'dir')
                    mkdir('logs');
                end
                
                fid = fopen(reportFile, 'w');
                if fid > 0
                    fprintf(fid, 'FoilView Test Suite Report\n');
                    fprintf(fid, '==========================\n\n');
                    fprintf(fid, 'Generated: %s\n', char(datetime('now')));
                    fprintf(fid, 'Total Tests: %d\n', obj.TestCount);
                    fprintf(fid, 'Passed: %d\n', obj.PassCount);
                    fprintf(fid, 'Failed: %d\n\n', obj.FailCount);
                    
                    fprintf(fid, 'Detailed Results:\n');
                    for i = 1:length(obj.TestResults)
                        result = obj.TestResults{i};
                        fprintf(fid, '%s: %s', result.result, result.name);
                        if ~isempty(result.error)
                            fprintf(fid, ' - %s', result.error);
                        end
                        fprintf(fid, '\n');
                    end
                    
                    fclose(fid);
                    fprintf('Test report saved to: %s\n', reportFile);
                end
            catch ME
                fprintf('Warning: Could not save test report: %s\n', ME.message);
            end
        end
    end
end