classdef foilview_initialization_manager < handle
    % foilview_initialization_manager - Manages application initialization
    %
    % This class breaks down the complex initialization process into focused,
    % manageable steps, improving code organization and maintainability.
    
    methods (Static)
        function initializeApplication(app)
            % Main initialization sequence
            foilview_initialization_manager.initializeCore(app);
            foilview_initialization_manager.initializeHelpers(app);
            foilview_initialization_manager.setupEventListeners(app);
            foilview_initialization_manager.initializePlot(app);
            foilview_initialization_manager.performInitialUpdates(app);
            foilview_initialization_manager.launchAdditionalWindows(app);
            foilview_initialization_manager.startTimers(app);
        end
        
        function initializeCore(app)
            % Initialize core components
            app.Controller = foilview_controller();
        end
        
        function initializeHelpers(app)
            % Initialize helper classes
            app.PlotManager = foilview_plot(app);
            app.WindowManager = foilview_window_manager(app);
        end
        
        function setupEventListeners(app)
            % Set up event listeners for controller events
            addlistener(app.Controller, 'StatusChanged', ...
                @(src,evt) app.onControllerStatusChanged());
            addlistener(app.Controller, 'PositionChanged', ...
                @(src,evt) app.onControllerPositionChanged());
            addlistener(app.Controller, 'MetricChanged', ...
                @(src,evt) app.onControllerMetricChanged());
            addlistener(app.Controller, 'AutoStepComplete', ...
                @(src,evt) app.onControllerAutoStepComplete());
        end
        
        function initializePlot(app)
            % Initialize the metrics plot
            app.PlotManager.initializeMetricsPlot(app.MetricsPlotControls.Axes);
        end
        
        function performInitialUpdates(app)
            % Perform initial UI updates
            foilview_updater.updateAllUI(app);
            app.updateAutoStepStatus();
            app.updateDirectionButtons();
        end
        
        function launchAdditionalWindows(app)
            % Launch additional windows and update status
            app.WindowManager.launchAllWindows();
            app.WindowManager.updateWindowStatusButtons();
        end
        
        function startTimers(app)
            % Start all application timers
            foilview_initialization_manager.startRefreshTimer(app);
            foilview_initialization_manager.startMetricTimer(app);
            foilview_initialization_manager.startResizeMonitorTimer(app);
        end
    end
    
    methods (Static, Access = private)
        function startRefreshTimer(app)
            % Start position refresh timer
            app.RefreshTimer = foilview_utils.createTimer('fixedRate', ...
                foilview_constants.POSITION_REFRESH_PERIOD, ...
                @(~,~) app.Controller.refreshPosition());
            start(app.RefreshTimer);
        end
        
        function startMetricTimer(app)
            % Start metrics update timer
            app.MetricTimer = foilview_utils.createTimer('fixedRate', ...
                foilview_constants.METRIC_REFRESH_PERIOD, ...
                @(~,~) app.Controller.updateMetric());
            
            % Pass timer reference to controller for coordination
            app.Controller.setMetricTimer(app.MetricTimer);
            start(app.MetricTimer);
        end
        
        function startResizeMonitorTimer(app)
            % Start window resize monitoring timer
            app.ResizeMonitorTimer = foilview_utils.createTimer('fixedRate', ...
                foilview_constants.RESIZE_MONITOR_INTERVAL, ...
                @(~,~) app.monitorWindowResize());
            
            % Initialize the last window size
            if isvalid(app.UIFigure)
                app.LastWindowSize = foilview_constants.DEFAULT_WINDOW_SIZE;
                app.LastWindowSize = app.UIFigure.Position;
            end
            
            start(app.ResizeMonitorTimer);
        end
    end
end 