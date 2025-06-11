classdef ControllerInterface < handle
    % ControllerInterface - Abstract interface for controller implementations
    % Provides a standard interface that UI components can depend on
    % without tight coupling to specific controller implementation
    
    methods (Abstract)
        % Z-stage control
        z = getZ(obj)
        moveZUp(obj)
        moveZDown(obj)
        setZ(obj, position)
        
        % Scanning control
        toggleZScan(obj, enable, varargin)
        toggleMonitor(obj, enable)
        moveToMaxBrightness(obj)
        
        % Limits and parameters
        limit = getZLimit(obj, which)  % which: 'min' or 'max'
        setMinZLimit(obj, value)
        setMaxZLimit(obj, value)
        updateStepSizeImmediate(obj, value)
        
        % Operations
        abortAllOperations(obj)
    end
end 