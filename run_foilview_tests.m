function run_foilview_tests()
    % run_foilview_tests - Run comprehensive FoilView test suite
    % 
    % This script runs all tests for the enhanced FoilView application
    % with robust error handling and initialization.
    
    fprintf('FoilView Enhanced Test Runner\n');
    fprintf('============================\n\n');
    
    try
        % Add paths for testing
        addpath('src/services');
        addpath('src/managers');
        addpath('src/testing');
        addpath('src/app');
        
        % Create and run test suite
        testSuite = FoilviewTestSuite();
        testSuite.runAllTests();
        
        fprintf('Test execution completed successfully.\n');
        fprintf('Check the logs/ directory for detailed test reports.\n\n');
        
    catch ME
        fprintf('Error running test suite: %s\n', ME.message);
        
        if ~isempty(ME.stack)
            fprintf('\nStack trace:\n');
            for i = 1:length(ME.stack)
                fprintf('  at %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
            end
        end
        
        fprintf('\nTroubleshooting:\n');
        fprintf('1. Ensure all source files are in the MATLAB path\n');
        fprintf('2. Check that you have write permissions in the current directory\n');
        fprintf('3. Verify MATLAB version is R2019b or later\n');
        fprintf('4. Try running individual test components\n\n');
    end
end