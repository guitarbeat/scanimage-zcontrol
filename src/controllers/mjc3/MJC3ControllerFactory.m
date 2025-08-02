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
            
            % Determine available controller types
            availableTypes = MJC3ControllerFactory.getAvailableTypes();
            
            % Select controller type
            if ~isempty(preferredType) && ismember(preferredType, availableTypes)
                selectedType = preferredType;
            else
                selectedType = availableTypes{1}; % Use first available
            end
            
            % Create controller based on type
            switch selectedType
                case 'MEX'
                    controller = MJC3_MEX_Controller(zController, stepFactor);
                case 'Simulation'
                    controller = MJC3_Simulation_Controller(zController, stepFactor);
                otherwise
                    error('Unknown controller type: %s', selectedType);
            end
            
            fprintf('MJC3 Controller Factory: Created %s controller\n', selectedType);
        end
        
        function types = getAvailableTypes()
            % Get list of available controller types in order of preference
            types = {};
            
            % Check for MEX controller (primary implementation)
            if exist('mjc3_joystick_mex', 'file') == 3  % 3 = MEX file
                try
                    % Test if MEX function works
                    result = mjc3_joystick_mex('test');
                    if ~isempty(result) && result
                        types{end+1} = 'MEX';
                    end
                catch
                    % MEX exists but doesn't work - show warning
                    warning('MJC3:MEXNotWorking', 'MEX function exists but not working. Run build_mjc3_mex() to rebuild.');
                end
            end
            
            % Simulation controller is always available as fallback
            types{end+1} = 'Simulation';
            
            % If no MEX controller, show setup message
            if ~ismember('MEX', types)
                fprintf('ℹ MEX controller not available. Run build_mjc3_mex() to enable high-performance controller.\n');
            end
        end
        
        function listAvailableTypes()
            % List all available controller types with descriptions
            fprintf('\nAvailable MJC3 Controller Types:\n');
            fprintf('================================\n');
            
            availableTypes = MJC3ControllerFactory.getAvailableTypes();
            
            for i = 1:length(availableTypes)
                type = availableTypes{i};
                switch type
                    case 'MEX'
                        desc = 'High-performance MEX with direct HID access (primary)';
                    case 'Simulation'
                        desc = 'Simulated joystick for testing and development';
                end
                fprintf('%d. %s: %s\n', i, type, desc);
            end
            fprintf('\n');
        end
        
        function testController(controllerType, zController)
            % Test a specific controller type
            if nargin < 1
                error('Controller type must be specified');
            end
            if nargin < 2
                error('Z-controller must be provided for testing');
            end
            
            try
                controller = MJC3ControllerFactory.createController(zController, 5, controllerType);
                fprintf('✓ %s controller created successfully\n', controllerType);
                
                % Test connection
                if controller.connectToMJC3()
                    fprintf('✓ %s controller connected successfully\n', controllerType);
                else
                    fprintf('✗ %s controller connection failed\n', controllerType);
                end
                
                % Clean up
                delete(controller);
                
            catch ME
                fprintf('✗ %s controller test failed: %s\n', controllerType, ME.message);
            end
        end
    end
end 