%==============================================================================
% BASEMJC3CONTROLLER.M
%==============================================================================
% Abstract base class for MJC3 joystick controllers.
%
% This abstract class defines the common interface that all MJC3 controllers
% must implement. It provides the foundation for different controller types
% (MEX-based, simulation, etc.) while ensuring consistent behavior and
% interface across all implementations.
%
% Key Features:
%   - Abstract interface for MJC3 controller implementations
%   - Common step factor management
%   - Manual movement methods (moveUp, moveDown)
%   - Z-controller integration interface
%   - Automatic cleanup on destruction
%   - Unified logging system
%
% Abstract Methods:
%   - start(): Start the controller polling
%   - stop(): Stop the controller polling
%   - connectToMJC3(): Connect to MJC3 device
%
% Dependencies:
%   - Z-controller: Stage movement interface (must implement relativeMove)
%   - LoggingService: Unified logging system
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   % This is an abstract class - use concrete implementations:
%   % controller = MJC3_MEX_Controller(zController, stepFactor);
%   % controller = MJC3_Simulation_Controller(zController, stepFactor);
%
%==============================================================================

classdef BaseMJC3Controller < handle
    % BaseMJC3Controller - Abstract base class for MJC3 joystick controllers
    % Defines the common interface that all MJC3 controllers must implement
    
    properties (Abstract)
        stepFactor     % Micrometres moved per unit of joystick deflection
        running        % Logical flag indicating whether polling is active
    end
    
    properties (Access = protected)
        zController    % Z-axis controller (must implement relativeMove method)
        Logger         % Logging service for structured output
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
            
            % Initialize logger
            obj.Logger = LoggingService('BaseMJC3Controller', 'SuppressInitMessage', true);
            obj.Logger.info('Base controller initialized with step factor: %.1f μm/unit', stepFactor);
        end
        
        function setStepFactor(obj, newStepFactor)
            % Update the step factor for joystick sensitivity
            if newStepFactor > 0
                obj.stepFactor = newStepFactor;
                obj.Logger.info('Step factor updated to %.1f μm/unit', newStepFactor);
            else
                obj.Logger.warning('Step factor must be positive');
            end
        end
        
        function moveUp(obj, steps)
            % Manual Z-axis movement up
            if nargin < 2, steps = 1; end
            dz = steps * obj.stepFactor;
            success = obj.zController.relativeMove(dz);
            if success
                obj.Logger.info('Manual Z up: %.1f μm', dz);
            else
                obj.Logger.warning('Failed to move Z up by %.1f μm', dz);
            end
        end
        
        function moveDown(obj, steps)
            % Manual Z-axis movement down
            if nargin < 2, steps = 1; end
            dz = -steps * obj.stepFactor;
            success = obj.zController.relativeMove(dz);
            if success
                obj.Logger.info('Manual Z down: %.1f μm', abs(dz));
            else
                obj.Logger.warning('Failed to move Z down by %.1f μm', abs(dz));
            end
        end
        
        function delete(obj)
            % Destructor - ensure controller stops
            obj.Logger.info('Cleaning up base controller');
            obj.stop();
        end
    end
end 