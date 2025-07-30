classdef BaseMJC3Controller < handle
    % BaseMJC3Controller - Abstract base class for MJC3 joystick controllers
    % Defines the common interface that all MJC3 controllers must implement
    
    properties (Abstract)
        stepFactor     % Micrometres moved per unit of joystick deflection
        running        % Logical flag indicating whether polling is active
    end
    
    properties (Access = protected)
        zController    % Z-axis controller (must implement relativeMove method)
    end
    
    methods (Abstract)
        start(obj)     % Start the controller
        stop(obj)      % Stop the controller
        success = connectToMJC3(obj)  % Connect to MJC3 device
    end
    
    methods
        function obj = BaseMJC3Controller(zController, stepFactor)
            % Constructor
            % zController: object that implements relativeMove(dz) method
            % stepFactor: micrometres moved per unit of joystick deflection
            
            if nargin < 1
                error('BaseMJC3Controller requires a Z-controller');
            end
            if nargin < 2
                stepFactor = 5; % default micrometres per unit
            end
            
            obj.zController = zController;
            obj.stepFactor = stepFactor;
            obj.running = false;
        end
        
        function setStepFactor(obj, newStepFactor)
            % Update the step factor for joystick sensitivity
            if newStepFactor > 0
                obj.stepFactor = newStepFactor;
                fprintf('MJC3 step factor updated to %.1f μm/unit\n', newStepFactor);
            else
                warning('Step factor must be positive');
            end
        end
        
        function moveUp(obj, steps)
            % Manual Z-axis movement up
            if nargin < 2, steps = 1; end
            dz = steps * obj.stepFactor;
            success = obj.zController.relativeMove(dz);
            if success
                fprintf('Manual Z up: %.1f μm\n', dz);
            else
                fprintf('Failed to move Z up by %.1f μm\n', dz);
            end
        end
        
        function moveDown(obj, steps)
            % Manual Z-axis movement down
            if nargin < 2, steps = 1; end
            dz = -steps * obj.stepFactor;
            success = obj.zController.relativeMove(dz);
            if success
                fprintf('Manual Z down: %.1f μm\n', abs(dz));
            else
                fprintf('Failed to move Z down by %.1f μm\n', abs(dz));
            end
        end
        
        function delete(obj)
            % Destructor - ensure controller stops
            obj.stop();
        end
    end
end 