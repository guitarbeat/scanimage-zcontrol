classdef ControllerAdapter < gui.interfaces.ControllerInterface
    % ControllerAdapter - Adapts existing controller to ControllerInterface
    % Wraps an existing controller implementation to conform to the
    % ControllerInterface, enabling better separation of concerns
    
    properties (Access = private)
        controller  % The wrapped controller instance
    end
    
    properties
        % Dynamic property access to the wrapped controller
        % This allows direct access to controller.params, etc.
        params
        hSI  % ScanImage handle - common property accessed directly
    end
    
    methods
        function obj = ControllerAdapter(controller)
            % Constructor stores the controller instance and sets up property forwarding
            obj.controller = controller;
            
            % Set up property forwarding for known properties
            if isfield(controller, 'params') || isprop(controller, 'params')
                obj.params = controller.params;
            end
            
            % Forward ScanImage handle if available
            if isfield(controller, 'hSI') || isprop(controller, 'hSI')
                obj.hSI = controller.hSI;
            end
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
        
        function setZ(obj, position)
            if ismethod(obj.controller, 'setZ')
                obj.controller.setZ(position);
            elseif ismethod(obj.controller, 'moveToPosition')
                obj.controller.moveToPosition(position);
            else
                error('ControllerAdapter:NoSetZMethod', 'No method found to set Z position');
            end
        end
        
        % Scanning control
        function toggleZScan(obj, enable, varargin)
            obj.controller.toggleZScan(enable, varargin{:});
        end
        
        function toggleMonitor(obj, enable)
            obj.controller.toggleMonitor(enable);
        end
        
        function moveToMaxBrightness(obj)
            obj.controller.moveToMaxBrightness();
        end
        
        % Limits and parameters
        function limit = getZLimit(obj, which)
            limit = obj.controller.getZLimit(which);
        end
        
        function setMinZLimit(obj, value)
            obj.controller.setMinZLimit(value);
        end
        
        function setMaxZLimit(obj, value)
            obj.controller.setMaxZLimit(value);
        end
        
        function updateStepSizeImmediate(obj, value)
            obj.controller.updateStepSizeImmediate(value);
        end
        
        % Operations
        function abortAllOperations(obj)
            obj.controller.abortAllOperations();
        end
        
        % Dynamic property access
        function varargout = subsref(obj, S)
            % Override subsref to forward property/method access to controller
            try
                % First try handling through normal means (adapter properties/methods)
                [varargout{1:nargout}] = builtin('subsref', obj, S);
            catch ME
                % If property/method not found in adapter, try forwarding to controller
                if strcmp(ME.identifier, 'MATLAB:noSuchMethodOrField') || ...
                   strcmp(ME.identifier, 'MATLAB:class:InvalidHandle') || ...
                   strcmp(ME.identifier, 'MATLAB:class:SubsRefParentheses')
                   
                    % Debug log
                    fprintf('ControllerAdapter: Forwarding access to controller. Type: %s\n', S(1).type);
                    if S(1).type == '.' && length(S(1).subs) > 0
                        fprintf('ControllerAdapter: Accessing property: %s\n', S(1).subs);
                    end
                    
                    try
                        % Forward to controller
                        if ~isempty(obj.controller) && isvalid(obj.controller)
                            [varargout{1:nargout}] = subsref(obj.controller, S);
                        else
                            fprintf('ControllerAdapter: Controller is empty or invalid\n');
                            rethrow(ME);
                        end
                    catch ME2
                        fprintf('ControllerAdapter: Error forwarding to controller: %s\n', ME2.message);
                        % If forwarding also failed, rethrow original error
                        rethrow(ME);
                    end
                else
                    % For other types of errors, rethrow
                    fprintf('ControllerAdapter: Unhandled error: %s\n', ME.identifier);
                    rethrow(ME);
                end
            end
        end
    end
end 