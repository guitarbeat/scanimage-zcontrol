classdef MJC3ControllerFactory < handle
    % MJC3ControllerFactory - Factory for creating MJC3 joystick controllers
    % Automatically selects the best available controller implementation
    
    properties (Constant)
        % Controller types in order of preference
        CONTROLLER_TYPES = {'HID', 'Native', 'Windows_HID', 'Keyboard', 'Simulation'};
        
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
                case 'HID'
                    controller = MJC3_HID_Controller(zController, stepFactor);
                case 'Native'
                    controller = MJC3_Native_Controller(zController, stepFactor);
                case 'Windows_HID'
                    controller = MJC3_Windows_HID_Controller(zController, stepFactor);
                case 'Keyboard'
                    controller = MJC3_Keyboard_Controller(zController, stepFactor);
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
            
            % Check for HID controller (requires PsychHID)
            if exist('PsychHID', 'file')
                types{end+1} = 'HID';
            end
            
            % Check for Native controller (Windows API)
            if ispc
                types{end+1} = 'Native';
                types{end+1} = 'Windows_HID';
            end
            
            % Keyboard controller is always available
            types{end+1} = 'Keyboard';
            
            % Simulation controller is always available
            types{end+1} = 'Simulation';
        end
        
        function listAvailableTypes()
            % List all available controller types with descriptions
            fprintf('\nAvailable MJC3 Controller Types:\n');
            fprintf('================================\n');
            
            availableTypes = MJC3ControllerFactory.getAvailableTypes();
            
            for i = 1:length(availableTypes)
                type = availableTypes{i};
                switch type
                    case 'HID'
                        desc = 'Direct HID access via PsychHID (recommended)';
                    case 'Native'
                        desc = 'Windows native joystick API';
                    case 'Windows_HID'
                        desc = 'Windows HID API (simplified)';
                    case 'Keyboard'
                        desc = 'Keyboard shortcuts as joystick alternative';
                    case 'Simulation'
                        desc = 'Simulated joystick for testing';
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