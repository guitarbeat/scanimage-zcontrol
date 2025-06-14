classdef ControllerAdapter < gui.interfaces.ControllerInterface
    % ControllerAdapter - Adapts existing controller to ControllerInterface
    % Simplified version for minimal UI
    
    properties (Access = private)
        controller  % The wrapped controller instance
    end
    
    methods
        function obj = ControllerAdapter(controller)
            % Constructor stores the controller instance
            obj.controller = controller;
        end
        
        % Z-stage control
        function z = getZ(obj)
            z = obj.controller.getZ();
        end
        
        function moveZUp(obj)
            obj.controller.moveZUp();
        end
        
        function moveZDown(obj)
            obj.controller.moveZDown();
        end
        
        % ScanImage control
        function startSIFocus(obj)
            if ismethod(obj.controller, 'startSIFocus')
                obj.controller.startSIFocus();
            elseif ismethod(obj.controller, 'toggleFocusMode')
                obj.controller.toggleFocusMode(true);
            end
        end
        
        function stopSIFocus(obj)
            if ismethod(obj.controller, 'stopSIFocus')
                obj.controller.stopSIFocus();
            elseif ismethod(obj.controller, 'toggleFocusMode')
                obj.controller.toggleFocusMode(false);
            end
        end
        
        function grabSIFrame(obj)
            if ismethod(obj.controller, 'grabSIFrame')
                obj.controller.grabSIFrame();
            elseif ismethod(obj.controller, 'grabFrame')
                obj.controller.grabFrame();
            end
        end
        
        % Operations
        function abortAllOperations(obj)
            if ismethod(obj.controller, 'abortAllOperations')
                obj.controller.abortAllOperations();
            else
                % Try individual abort operations
                try
                    if ismethod(obj.controller, 'stopSIFocus')
                        obj.controller.stopSIFocus();
                    end
                catch
                    % Ignore errors
                end
            end
        end
    end
end 