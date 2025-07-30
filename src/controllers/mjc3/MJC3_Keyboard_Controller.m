classdef MJC3_Keyboard_Controller < BaseMJC3Controller
    % MJC3_Keyboard_Controller - Alternative joystick controller
    % Uses keyboard shortcuts to simulate joystick when hardware access fails
    % This is NOT a simulation - it's a workaround for PsychHID issues
    
    properties
        keyFigure      % Hidden figure for key capture
    end
    
    methods
        function obj = MJC3_Keyboard_Controller(zController, stepFactor)
            % Constructor
            % zController: Z-controller (must implement relativeMove method)
            % stepFactor: micrometres moved per unit (optional)
            
            % Call parent constructor
            obj@BaseMJC3Controller(zController, stepFactor);
            
            fprintf('MJC3 Keyboard Controller initialized (Step factor: %.1f μm/unit)\n', obj.stepFactor);
            fprintf('This controller uses keyboard shortcuts as a workaround for PsychHID issues\n');
        end
        
        function start(obj)
            % Start the controller
            if ~obj.running
                obj.running = true;
                fprintf('MJC3 Keyboard Controller started\n');
                fprintf('Use Ctrl+Up/Down arrows in MATLAB command window for Z control\n');
                fprintf('Or call controller.moveUp() and controller.moveDown() methods\n');
            end
        end
        
        function stop(obj)
            % Stop the controller
            if obj.running
                obj.running = false;
                fprintf('MJC3 Keyboard Controller stopped\n');
            end
        end
        
        function success = connectToMJC3(obj)
            % Always return true since this is a keyboard workaround
            success = true;
        end
        
        function delete(obj)
            obj.stop();
        end
    end
end 