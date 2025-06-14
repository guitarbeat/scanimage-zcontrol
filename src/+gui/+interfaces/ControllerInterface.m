classdef ControllerInterface < handle
    % ControllerInterface - Minimal interface for controller implementations
    % Provides a standard interface that UI components can depend on
    % without tight coupling to specific controller implementation
    
    methods (Abstract)
        % Z-stage control
        z = getZ(obj)
        moveZUp(obj)
        moveZDown(obj)
        
        % ScanImage control
        startSIFocus(obj)
        stopSIFocus(obj)
        grabSIFrame(obj)
        
        % Operations
        abortAllOperations(obj)
    end
end 