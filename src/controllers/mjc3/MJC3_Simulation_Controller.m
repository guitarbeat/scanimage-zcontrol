classdef MJC3_Simulation_Controller < BaseMJC3Controller
    % MJC3_Simulation_Controller - Simulated joystick controller for testing
    % Provides keyboard-based simulation of joystick input when hardware isn't available
    
    properties
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
            
            fprintf('MJC3 Simulation Controller initialized (Step factor: %.1f μm/unit)\n', obj.stepFactor);
            fprintf('Keyboard controls: Up Arrow = Z up, Down Arrow = Z down, Space = Stop\n');
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
                
                fprintf('MJC3 Simulation Controller started\n');
                fprintf('Use Up/Down arrow keys to simulate joystick movement\n');
                fprintf('Press Space to stop, or close the simulation window\n');
            end
        end
        
        function stop(obj)
            % Stop the simulation controller
            if obj.running
                obj.running = false;
                if isvalid(obj.keyListener)
                    set(obj.keyListener, 'Visible', 'off');
                end
                fprintf('MJC3 Simulation Controller stopped\n');
            end
        end
        
        function success = connectToMJC3(obj)
            % Simulate connection - always succeeds
            success = true;
            fprintf('[Sim] MJC3 device connection simulated successfully\n');
        end
        
        function pos = getCurrentPosition(obj)
            % Get current simulated position
            pos = obj.simulatedZ;
        end
        
        function delete(obj)
            obj.stop();
            if isvalid(obj.keyListener)
                delete(obj.keyListener);
            end
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
                    obj.stop();
                case 'escape'
                    obj.stop();
            end
        end
        
        function simulateMovement(obj, direction)
            % Simulate joystick movement
            dz = direction * obj.stepFactor;
            obj.simulatedZ = obj.simulatedZ + dz;
            
            directionStr = ternary(direction > 0, 'up', 'down');
            fprintf('[Sim] Joystick %s: %.1f μm (Total: %.1f μm)\n', directionStr, abs(dz), obj.simulatedZ);
            
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