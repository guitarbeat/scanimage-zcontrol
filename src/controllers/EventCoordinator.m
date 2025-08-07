classdef EventCoordinator < handle
    %EVENTCOORDINATOR Handles event coordination and callbacks for Foilview
    %   Extracted from FoilviewController for better separation of concerns
    %   Manages event listeners, notifications, and callback coordination
    
    properties (Access = private)
        Logger
        StatusUpdateCallback
        PositionUpdateCallback
        MetricUpdateCallback
        AutoStepCompleteCallback
    end
    
    methods
        function obj = EventCoordinator()
            obj.Logger = LoggingService('EventCoordinator', 'SuppressInitMessage', true);
        end
        
        function setCallbacks(obj, statusCallback, positionCallback, metricCallback, autoStepCallback)
            %SETCALLBACKS Set the callback functions for various events
            obj.StatusUpdateCallback = statusCallback;
            obj.PositionUpdateCallback = positionCallback;
            obj.MetricUpdateCallback = metricCallback;
            obj.AutoStepCompleteCallback = autoStepCallback;
        end
        
        function notifyStatusChanged(obj, controller)
            %NOTIFYSTATUSCHANGED Notify listeners of status changes
            try
                % Trigger event only if controller supports events
                if isa(controller, 'handle')
                    notify(controller, 'StatusChanged');
                end
                
                % Execute callback if set
                if ~isempty(obj.StatusUpdateCallback)
                    obj.StatusUpdateCallback(controller.StatusMessage, controller.SimulationMode);
                end
                
            catch ME
                obj.Logger.error('Error in status notification: %s', ME.message);
            end
        end
        
        function notifyPositionChanged(obj, controller)
            %NOTIFYPOSITIONCHANGED Notify listeners of position changes
            try
                % Trigger event only if controller supports events
                if isa(controller, 'handle')
                    notify(controller, 'PositionChanged');
                end
                
                % Execute callback if set
                if ~isempty(obj.PositionUpdateCallback)
                    obj.PositionUpdateCallback(controller.CurrentPosition, ...
                        controller.CurrentXPosition, controller.CurrentYPosition);
                end
                
            catch ME
                obj.Logger.error('Error in position notification: %s', ME.message);
            end
        end
        
        function notifyMetricChanged(obj, controller)
            %NOTIFYMETRICCHANGED Notify listeners of metric changes
            try
                % Trigger event only if controller supports events
                if isa(controller, 'handle')
                    notify(controller, 'MetricChanged');
                end
                
                % Execute callback if set
                if ~isempty(obj.MetricUpdateCallback)
                    obj.MetricUpdateCallback(controller.CurrentMetric, ...
                        controller.AllMetrics, controller.CurrentMetricType);
                end
                
            catch ME
                obj.Logger.error('Error in metric notification: %s', ME.message);
            end
        end
        
        function notifyAutoStepComplete(obj, controller)
            %NOTIFYAUTOSTEPCOMPLETE Notify listeners of auto-step completion
            try
                % Trigger event only if controller supports events
                if isa(controller, 'handle')
                    notify(controller, 'AutoStepComplete');
                end
                
                % Execute callback if set
                if ~isempty(obj.AutoStepCompleteCallback)
                    obj.AutoStepCompleteCallback(controller.AutoStepMetrics);
                end
                
            catch ME
                obj.Logger.error('Error in auto-step complete notification: %s', ME.message);
            end
        end
        
        function onStagePositionChanged(obj, controller, ~, eventData)
            %ONSTAGEPOSITIONCHANGED Handle stage position change events
            try
                % Update controller positions from service
                if ~isempty(eventData) && isfield(eventData, 'Positions')
                    positions = eventData.Positions;
                    controller.CurrentPosition = positions.z;
                    controller.CurrentXPosition = positions.x;
                    controller.CurrentYPosition = positions.y;
                end
                
                % Notify position change
                obj.notifyPositionChanged(controller);
                
            catch ME
                obj.Logger.error('Error handling stage position change: %s', ME.message);
            end
        end
        
        function onMetricCalculated(obj, controller, ~, eventData)
            %ONMETRICCALCULATED Handle metric calculation events
            try
                % Update controller metrics from service
                if ~isempty(eventData)
                    if isfield(eventData, 'AllMetrics')
                        controller.AllMetrics = eventData.AllMetrics;
                    end
                    if isfield(eventData, 'CurrentMetric')
                        controller.CurrentMetric = eventData.CurrentMetric;
                    end
                end
                
                % Notify metric change
                obj.notifyMetricChanged(controller);
                
            catch ME
                obj.Logger.error('Error handling metric calculation: %s', ME.message);
            end
        end
        
        function setupServiceListeners(obj, controller)
            %SETUPSERVICELISTENERS Set up event listeners for services
            try
                if ~isempty(controller.StageControlService)
                    addlistener(controller.StageControlService, 'PositionChanged', ...
                        @(src, evt) obj.onStagePositionChanged(controller, src, evt));
                end
                
                if ~isempty(controller.MetricCalculationService)
                    addlistener(controller.MetricCalculationService, 'MetricCalculated', ...
                        @(src, evt) obj.onMetricCalculated(controller, src, evt));
                end
                
            catch ME
                obj.Logger.error('Error setting up service listeners: %s', ME.message);
            end
        end
        
        function success = recoverFromMotorError(obj, controller)
            %RECOVERFROMOTORERROR Attempt to recover from motor error state
            success = FoilviewUtils.safeExecuteWithReturn(@() doRecover(), 'recoverFromMotorError', false);

            function success = doRecover()
                success = false;

                if controller.SimulationMode
                    success = true;
                    return;
                end

                try
                    % Find motor controls window
                    motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                    if isempty(motorFig)
                        return;
                    end

                    % Check for error state on Z axis
                    if controller.ScanImageManager.checkMotorErrorState(motorFig, 'Z')
                        obj.Logger.warning('Motor error detected, attempting recovery...');
                        controller.ScanImageManager.clearMotorError(motorFig, 'Z');
                        pause(1.0); % Give more time for recovery

                        % Check if recovery was successful
                        if ~controller.ScanImageManager.checkMotorErrorState(motorFig, 'Z')
                            obj.Logger.info('Motor error recovery successful');
                            success = true;
                        else
                            obj.Logger.warning('Motor error recovery failed');
                        end
                    else
                        obj.Logger.info('No motor error detected');
                        success = true;
                    end

                catch ME
                    obj.Logger.error('Error during motor recovery: %s', ME.message);
                end
            end
        end
        
        function success = refreshConnection(~, controller)
            %REFRESHCONNECTION Enhanced connection refresh with return value
            success = FoilviewUtils.safeExecuteWithReturn(@() doRefresh(), ...
                'refreshConnection', false);

            function success = doRefresh()
                controller.connectToScanImage();
                success = true;
            end
        end
    end
end