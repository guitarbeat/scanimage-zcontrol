%==============================================================================
% MJC3_SIMULATION_CONTROLLER.M
%==============================================================================
% Simulated joystick controller for MJC3 testing and development.
%
% This controller provides a keyboard-based simulation of the MJC3 joystick
% when hardware is not available. It implements the same interface as the
% MEX controller but uses keyboard input to simulate joystick movements,
% making it useful for testing and development without physical hardware.
%
% Key Features:
%   - Keyboard-based joystick simulation
%   - Arrow key controls for Z-axis movement
%   - Space bar for stopping simulation
%   - Visual feedback window with instructions
%   - Compatible interface with real MJC3 controller
%   - Safe fallback when hardware is unavailable
%
% Simulation Controls:
%   - Up Arrow: Move Z-axis up (positive direction)
%   - Down Arrow: Move Z-axis down (negative direction)
%   - Space: Stop simulation
%   - Escape: Stop simulation
%
% Dependencies:
%   - BaseMJC3Controller: Abstract base class interface
%   - MATLAB Figure: Visual feedback and key capture
%   - Z-controller: Stage movement interface
%   - LoggingService: Unified logging system
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   controller = MJC3_Simulation_Controller(zController, 5.0);
%   controller.start();  % Begin keyboard simulation
%   controller.stop();   % Stop simulation
%
%==============================================================================

classdef MJC3_Simulation_Controller < BaseMJC3Controller
    % MJC3_Simulation_Controller - Simulated joystick controller for testing
    % Provides keyboard-based simulation of joystick input when hardware isn't available
    
    properties
        stepFactor     % Micrometres moved per unit of joystick deflection - from abstract base
        running        % Logical flag indicating whether polling is active - from abstract base
        timerObj       % Timer for keyboard polling
        simulatedZ     % Current simulated Z position
        keyListener    % Figure for capturing key events
    end
    
    methods
        function obj = MJC3_Simulation_Controller(zController, stepFactor)
            % Constructor
            % zController: Z-controller (must implement relativeMove method)
            % stepFactor: micrometres moved per simulated unit (optional)
            
            % Call parent constructor
            obj@BaseMJC3Controller(zController, stepFactor);
            
            obj.simulatedZ = 0;
            
            % Create invisible figure for key capture
            obj.keyListener = figure('Visible', 'off', 'Name', 'MJC3 Simulation Key Listener');
            set(obj.keyListener, 'KeyPressFcn', @(src,evt)obj.handleKeyPress(evt));
            
            obj.Logger.info('MJC3 Simulation Controller initialized (Step factor: %.1f μm/unit)', obj.stepFactor);
            obj.Logger.info('Keyboard controls: Up Arrow = Z up, Down Arrow = Z down, Space = Stop');
        end
        
        function start(obj)
            % Start the simulation controller
            if ~obj.running
                obj.running = true;
                
                % Make the key listener figure active for key capture
                figure(obj.keyListener);
                set(obj.keyListener, 'Visible', 'on', 'Position', [100 100 300 100]);
                
                % Add instructions
                uicontrol('Parent', obj.keyListener, 'Style', 'text', ...
                    'String', {'MJC3 Simulation Active', 'Up/Down Arrows: Move Z-axis', 'Space: Stop'}, ...
                    'Units', 'normalized', 'Position', [0.1 0.2 0.8 0.6], ...
                    'FontSize', 10, 'HorizontalAlignment', 'center');
                
                obj.Logger.info('MJC3 Simulation Controller started');
                obj.Logger.info('Use Up/Down arrow keys to simulate joystick movement');
                obj.Logger.info('Press Space to stop, or close the simulation window');
            end
        end
        
        function stop(obj)
            % Stop the simulation controller
            if obj.running
                obj.running = false;
                if isvalid(obj.keyListener)
                    set(obj.keyListener, 'Visible', 'off');
                end
                obj.Logger.info('MJC3 Simulation Controller stopped');
            end
        end
        
        function success = connectToMJC3(obj)
            % Simulate connection - always succeeds
            success = true;
            obj.Logger.info('MJC3 device connection simulated successfully');
            obj.Logger.debug('Simulation mode - no actual hardware connection required');
        end
        
        function pos = getCurrentPosition(obj)
            % Get current simulated position
            pos = obj.simulatedZ;
            obj.Logger.debug('Current simulated Z position: %.1f μm', pos);
        end
        
        function delete(obj)
            obj.Logger.info('Cleaning up MJC3 Simulation Controller...');
            obj.stop();
            if isvalid(obj.keyListener)
                delete(obj.keyListener);
                obj.Logger.debug('Key listener figure deleted');
            end
            obj.Logger.info('MJC3 Simulation Controller cleanup complete');
        end
    end
    
    methods (Access = private)
        function handleKeyPress(obj, evt)
            if ~obj.running
                return;
            end
            
            switch evt.Key
                case 'uparrow'
                    obj.simulateMovement(1);
                case 'downarrow'
                    obj.simulateMovement(-1);
                case 'space'
                    obj.Logger.info('Simulation stopped by user (Space key)');
                    obj.stop();
                case 'escape'
                    obj.Logger.info('Simulation stopped by user (Escape key)');
                    obj.stop();
            end
        end
        
        function simulateMovement(obj, direction)
            % Simulate joystick movement
            dz = direction * obj.stepFactor;
            obj.simulatedZ = obj.simulatedZ + dz;
            
            directionStr = ternary(direction > 0, 'up', 'down');
            obj.Logger.debug('Simulated joystick %s: %.1f μm (Total: %.1f μm)', directionStr, abs(dz), obj.simulatedZ);
            
            % In a real implementation, this would call the stage control service
            % For simulation, we just log the movement
        end
    end
end

function result = ternary(condition, trueValue, falseValue)
    % Simple ternary operator function
    if condition
        result = trueValue;
    else
        result = falseValue;
    end
end 