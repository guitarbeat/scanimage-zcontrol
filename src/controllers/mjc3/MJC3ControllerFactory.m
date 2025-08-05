%==============================================================================
% MJC3CONTROLLERFACTORY.M
%==============================================================================
% Factory class for creating MJC3 joystick controllers.
%
% This factory class provides a unified interface for creating different types
% of MJC3 controllers (MEX-based, simulation, etc.) while automatically
% selecting the best available implementation. It implements the Factory pattern
% to abstract controller creation and provide fallback options.
%
% Key Features:
%   - Automatic controller type selection based on availability
%   - Preference-based controller creation (MEX preferred over simulation)
%   - Availability checking for different controller types
%   - Fallback to simulation controller when MEX is unavailable
%   - Comprehensive controller type listing and description
%
% Controller Types:
%   - MEX: High-performance controller with direct HID access (primary)
%   - Simulation: Simulated joystick for testing and development (fallback)
%
% Dependencies:
%   - MJC3_MEX_Controller: High-performance MEX implementation
%   - MJC3_Simulation_Controller: Simulation implementation
%   - mjc3_joystick_mex: MEX function for hardware communication
%   - LoggingService: Unified logging system
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   controller = MJC3ControllerFactory.createController(zController, 5.0);
%   types = MJC3ControllerFactory.getAvailableTypes();
%   MJC3ControllerFactory.listAvailableTypes();
%
%==============================================================================

classdef MJC3ControllerFactory < handle
    % MJC3ControllerFactory - Factory for creating MJC3 joystick controllers
    % Primary implementation uses high-performance MEX controller
    
    properties (Constant)
        % Controller types in order of preference (MEX is primary)
        CONTROLLER_TYPES = {'MEX', 'Simulation'};
        
        % Default step factor
        DEFAULT_STEP_FACTOR = 5;
    end
    
    methods (Static)
        function controller = createController(zController, stepFactor, preferredType)
            % Create the best available MJC3 controller
            % zController: Z-axis controller (must implement relativeMove method)
            % stepFactor: micrometres moved per unit (optional)
            % preferredType: preferred controller type (optional)
            % Returns: MJC3 controller instance
            
            if nargin < 1
                error('MJC3ControllerFactory requires a Z-controller');
            end
            if nargin < 2
                stepFactor = MJC3ControllerFactory.DEFAULT_STEP_FACTOR;
            end
            if nargin < 3
                preferredType = '';
            end
            
            % Create logger for factory operations
            logger = LoggingService('MJC3ControllerFactory', 'SuppressInitMessage', true);
            
            logger.info('Creating MJC3 controller (step factor: %.1f μm/unit)', stepFactor);
            
            % Determine available controller types
            availableTypes = MJC3ControllerFactory.getAvailableTypes();
            logger.debug('Available controller types: %s', strjoin(availableTypes, ', '));
            
            if isempty(availableTypes)
                logger.error('No MJC3 controller types available');
                error('MJC3ControllerFactory:NoControllers', 'No MJC3 controller types available');
            end
            
            % Select controller type
            if ~isempty(preferredType) && ismember(preferredType, availableTypes)
                selectedType = preferredType;
                logger.info('Using preferred controller type: %s', selectedType);
            else
                selectedType = availableTypes{1}; % Use first available
                logger.info('Using best available controller type: %s', selectedType);
            end
            
            % Create controller based on type
            try
                switch selectedType
                    case 'MEX'
                        logger.debug('Creating high-performance MEX controller...');
                        controller = MJC3_MEX_Controller(zController, stepFactor);
                        logger.info('Created high-performance MEX controller (50Hz polling)');
                        
                        % Test connection immediately
                        if controller.connectToMJC3()
                            logger.info('MJC3 hardware detected and connected');
                        else
                            logger.warning('MJC3 hardware not detected - controller created but not connected');
                        end
                        
                    case 'Simulation'
                        logger.debug('Creating simulation controller...');
                        controller = MJC3_Simulation_Controller(zController, stepFactor);
                        logger.info('Created simulation controller for testing');
                        
                    otherwise
                        logger.error('Unknown controller type: %s', selectedType);
                        error('Unknown controller type: %s', selectedType);
                end
                
                logger.info('Controller created successfully with step factor: %.1f μm/unit', stepFactor);
                
            catch ME
                logger.error('Failed to create %s controller: %s', selectedType, ME.message);
                logger.debug('Controller creation error details: %s', ME.getReport());
                
                % Try fallback to simulation if MEX failed
                if strcmp(selectedType, 'MEX') && ismember('Simulation', availableTypes)
                    logger.warning('Falling back to simulation controller');
                    try
                        controller = MJC3_Simulation_Controller(zController, stepFactor);
                        logger.info('Fallback simulation controller created successfully');
                    catch fallbackME
                        logger.error('Fallback to simulation also failed: %s', fallbackME.message);
                        logger.debug('Fallback error details: %s', fallbackME.getReport());
                        rethrow(ME); % Re-throw original error
                    end
                else
                    rethrow(ME);
                end
            end
        end
        
        function types = getAvailableTypes()
            % Get list of available controller types in order of preference
            types = {};
            
            % Check for MEX controller (primary implementation)
            if exist('mjc3_joystick_mex', 'file') == 3  % 3 = MEX file
                try
                    % Test if MEX function works
                    result = mjc3_joystick_mex('test');
                    if ~isempty(result)
                        types{end+1} = 'MEX';
                    end
                catch ME
                    % MEX file exists but doesn't work properly
                    % Log this at debug level since it's expected behavior
                end
            end
            
            % Always include simulation controller as fallback
            types{end+1} = 'Simulation';
        end
        
        function listAvailableTypes()
            % List all available controller types with descriptions
            logger = LoggingService('MJC3ControllerFactory', 'SuppressInitMessage', true);
            
            availableTypes = MJC3ControllerFactory.getAvailableTypes();
            
            if isempty(availableTypes)
                logger.warning('No MJC3 controller types available');
                return;
            end
            
            logger.info('Available MJC3 controller types:');
            
            for i = 1:length(availableTypes)
                type = availableTypes{i};
                switch type
                    case 'MEX'
                        logger.info('  • MEX: High-performance controller with direct HID access (recommended)');
                        logger.debug('    - 50Hz polling rate, <1ms latency');
                        logger.debug('    - Direct hardware communication via hidapi');
                        logger.debug('    - Full calibration support');
                    case 'Simulation'
                        logger.info('  • Simulation: Simulated joystick for testing and development');
                        logger.debug('    - Keyboard-based simulation');
                        logger.debug('    - No hardware required');
                        logger.debug('    - Limited to basic testing');
                    otherwise
                        logger.info('  • %s: Unknown controller type', type);
                end
            end
            
            if ismember('MEX', availableTypes)
                logger.info('MEX controller is available and will be used by default');
                logger.debug('MEX controller provides best performance and features');
            else
                logger.warning('MEX controller not available - using simulation mode');
                logger.info('To enable MEX controller, run: build_mjc3_mex()');
                logger.debug('MEX controller requires compiled MEX function and hidapi library');
            end
        end
        
        function testController(controllerType)
            % Test a specific controller type
            % controllerType: 'MEX' or 'Simulation'
            
            logger = LoggingService('MJC3ControllerFactory');
            
            if nargin < 1
                controllerType = 'MEX';
            end
            
            logger.info('Testing %s controller...', controllerType);
            
            try
                % Create a dummy Z-controller for testing
                dummyZController = struct();
                dummyZController.relativeMove = @(dz) true;
                dummyZController.relativeMoveX = @(dx) true;
                dummyZController.relativeMoveY = @(dy) true;
                
                logger.debug('Created dummy Z-controller for testing');
                
                % Create controller
                controller = MJC3ControllerFactory.createController(dummyZController, 5.0, controllerType);
                
                % Test basic functionality
                if strcmp(controllerType, 'MEX')
                    % Test MEX-specific functionality
                    logger.debug('Testing MEX controller connection...');
                    if controller.connectToMJC3()
                        logger.info('✓ MEX controller test passed - device connected');
                    else
                        logger.warning('⚠ MEX controller works but device not connected');
                        logger.debug('This is normal if MJC3 hardware is not plugged in');
                    end
                    
                    % Test calibration functionality
                    logger.debug('Testing calibration functionality...');
                    try
                        status = controller.getCalibrationStatus();
                        logger.debug('Calibration status: %s', jsonencode(status));
                        logger.info('✓ Calibration system functional');
                    catch ME
                        logger.warning('⚠ Calibration test failed: %s', ME.message);
                    end
                    
                else
                    logger.info('✓ Simulation controller test passed');
                end
                
                % Clean up
                delete(controller);
                logger.debug('Test controller cleaned up');
                
            catch ME
                logger.error('✗ %s controller test failed: %s', controllerType, ME.message);
                logger.debug('Test error details: %s', ME.getReport());
            end
        end
        
        function installInstructions()
            % Display installation instructions for MJC3 controllers
            logger = LoggingService('MJC3ControllerFactory');
            
            logger.info('MJC3 Controller Installation Instructions:');
            logger.info('');
            logger.info('1. MEX Controller (Recommended):');
            logger.info('   • Run: build_mjc3_mex()');
            logger.info('   • Requires: hidapi library, C++ compiler');
            logger.info('   • Performance: 50Hz polling, <1ms latency');
            logger.info('   • Features: Full calibration, multi-axis support');
            logger.info('');
            logger.info('2. Simulation Controller:');
            logger.info('   • No installation required');
            logger.info('   • Use for testing without hardware');
            logger.info('   • Performance: Limited to simulation');
            logger.info('   • Features: Basic keyboard simulation');
            logger.info('');
            logger.info('3. Hardware Requirements:');
            logger.info('   • MJC3 joystick (VID:1313, PID:9000)');
            logger.info('   • USB connection');
            logger.info('   • Windows/Linux/Mac compatible');
            logger.info('');
            logger.info('4. Calibration:');
            logger.info('   • Automatic calibration during first use');
            logger.info('   • Manual calibration via UI controls');
            logger.info('   • Calibration data saved persistently');
        end
    end
end 