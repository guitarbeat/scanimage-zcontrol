classdef foilview < matlab.apps.AppBase
    
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainPanel                   matlab.ui.container.Panel
        MainLayout                  matlab.ui.container.GridLayout
        ControlTabs                 matlab.ui.container.TabGroup
    end
    
    properties (Access = public)
        PositionDisplay
        MetricDisplay
        ManualControls
        AutoControls
        StatusControls
        MetricsPlotControls
    end
    
    properties (Access = public)
        Controller                  FoilviewController
        PlotManager                 UiComponents
        StageViewApp
        BookmarksViewApp
    end
    
    properties (Access = private)
        RefreshTimer
        MetricTimer
        ResizeMonitorTimer
        LastWindowSize = [0 0 0 0]
        IgnoreNextResize = false
    end
    
    methods (Access = public)
        function app = foilview()
            components = UiComponents.createAllComponents(app);
            app.copyComponentsFromStruct(components);
            app.setupCallbacks();
            app.initializeApplication();
            registerApp(app, app.UIFigure);
            
            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            % Main destructor for the application.
            app.cleanup();
            
            % Safely delete the UIFigure without recursion.
            if isvalid(app.UIFigure)
                app.UIFigure.CloseRequestFcn = '';
                delete(app.UIFigure);
            end
        end
    end
    
    methods (Access = private)
        function copyComponentsFromStruct(app, components)
            fields = fieldnames(components);
            for i = 1:length(fields)
                app.(fields{i}) = components.(fields{i});
            end
        end
        
        function initializeApplication(app)
            app.Controller = FoilviewController();
            app.PlotManager = UiComponents(app);
            
            addlistener(app.Controller, 'StatusChanged', @(src,evt) app.onControllerStatusChanged());
            addlistener(app.Controller, 'PositionChanged', @(src,evt) app.onControllerPositionChanged());
            addlistener(app.Controller, 'MetricChanged', @(src,evt) app.onControllerMetricChanged());
            addlistener(app.Controller, 'AutoStepComplete', @(src,evt) app.onControllerAutoStepComplete());
            
            app.PlotManager.initializeMetricsPlot(app.MetricsPlotControls.Axes);
            UiComponents.updateAllUI(app);
            app.updateAutoStepStatus();
            app.updateDirectionButtons();
            app.launchStageView();
            app.launchBookmarksView();
            app.updateWindowStatusButtons();
            app.startRefreshTimer();
            app.startMetricTimer();
            app.startResizeMonitorTimer();
        end
        
        function startRefreshTimer(app)
            app.RefreshTimer = FoilviewUtils.createTimer('fixedRate', ...
                app.Controller.POSITION_REFRESH_PERIOD, ...
                @(~,~) app.Controller.refreshPosition());
            start(app.RefreshTimer);
        end
        
        function startMetricTimer(app)
            app.MetricTimer = FoilviewUtils.createTimer('fixedRate', ...
                app.Controller.METRIC_REFRESH_PERIOD, ...
                @(~,~) app.Controller.updateMetric());
            start(app.MetricTimer);
        end
        
        function startResizeMonitorTimer(app)
            % Monitor window size changes and adjust UI responsively
            app.ResizeMonitorTimer = FoilviewUtils.createTimer('fixedRate', ...
                0.5, ...  % Check every 0.5 seconds
                @(~,~) app.monitorWindowResize());
            
            % Initialize the last window size
            if isvalid(app.UIFigure)
                app.LastWindowSize = app.UIFigure.Position;
            end
            
            start(app.ResizeMonitorTimer);
        end
        
        function launchStageView(app)
            % Launch the stage view window
            if isempty(app.StageViewApp) || ~isvalid(app.StageViewApp) || ~isvalid(app.StageViewApp.UIFigure)
                try
                    app.StageViewApp = StageView();
                catch ME
                    warning('foilview:StageViewLaunch', 'Failed to launch Stage View: %s', ME.message);
                    app.StageViewApp = [];
                end
            else
                app.StageViewApp.bringToFront();
            end
        end
        
        function launchBookmarksView(app)
            % Launch the Bookmarks View window automatically
            if isempty(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp.UIFigure)
                try
                    app.BookmarksViewApp = BookmarksView(app.Controller);
                catch ME
                    warning('foilview:BookmarksViewLaunch', 'Failed to launch Bookmarks View: %s', ME.message);
                    app.BookmarksViewApp = [];
                end
            else
                figure(app.BookmarksViewApp.UIFigure);
            end
        end
        
        function setupCallbacks(app)
            % Set up all UI callback functions
            
            % Main window
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @app.onWindowClose, true);
            
            % Manual control callbacks
            app.ManualControls.StepSizeDropdown.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onStepSizeChanged, true);
            app.ManualControls.UpButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onUpButtonPushed, true);
            app.ManualControls.DownButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onDownButtonPushed, true);
            app.ManualControls.ZeroButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onZeroButtonPushed, true);
            app.ManualControls.StepUpButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onStepUpButtonPushed, true);
            app.ManualControls.StepDownButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onStepDownButtonPushed, true);
            
            % Auto step callbacks
            app.AutoControls.StepField.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onAutoStepSizeChanged, true);
            app.AutoControls.StepsField.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onAutoStepsChanged, true);
            app.AutoControls.DelayField.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onAutoDelayChanged, true);
            app.AutoControls.DirectionButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onAutoDirectionToggled, true);
            app.AutoControls.StartStopButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onStartStopButtonPushed, true);
            

            
            % Metric callbacks
            app.MetricDisplay.TypeDropdown.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onMetricTypeChanged, true);
            app.MetricDisplay.RefreshButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onMetricRefreshButtonPushed, true);
            
            % Status callbacks
            app.StatusControls.RefreshButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onRefreshButtonPushed, true);
            app.StatusControls.BookmarksButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onBookmarksButtonPushed, true);
            app.StatusControls.StageViewButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onStageViewButtonPushed, true);
            
            % Plot control callbacks
            app.MetricsPlotControls.ExpandButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onExpandButtonPushed, true);
            app.MetricsPlotControls.ClearButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onClearPlotButtonPushed, true);
            app.MetricsPlotControls.ExportButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onExportPlotButtonPushed, true);
        end
    end
    

    methods (Access = private)
        function onControllerStatusChanged(app)
            UiComponents.updateStatusDisplay(app.PositionDisplay, app.StatusControls, app.Controller);
        end
        
        function onControllerPositionChanged(app)
            UiComponents.updatePositionDisplay(app.UIFigure, app.PositionDisplay, app.Controller);
        end
        
        function onControllerMetricChanged(app)
            UiComponents.updateMetricDisplay(app.MetricDisplay, app.Controller);
        end
        
        function onControllerAutoStepComplete(app)
            UiComponents.updateControlStates(app.ManualControls, app.AutoControls, app.Controller);
            % If metrics were recorded, update the plot and expand the GUI
            if app.Controller.RecordMetrics
                metrics = app.Controller.getAutoStepMetrics();
                if ~isempty(metrics.Positions)
                    app.PlotManager.updateMetricsPlot(app.MetricsPlotControls.Axes, app.Controller);
                    % Expand the GUI to show the plot
                    if ~app.PlotManager.getIsPlotExpanded()
                        app.PlotManager.expandGUI(app.UIFigure, app.MainPanel, ...
                            app.MetricsPlotControls.Panel, app.MetricsPlotControls.ExpandButton, app);
                    end
                end
            end
        end
    end
    

    methods (Access = private)

        function onUpButtonPushed(app, varargin)
            app.Controller.moveStageManual(app.ManualControls, 1);
        end
        
        function onDownButtonPushed(app, varargin)
            app.Controller.moveStageManual(app.ManualControls, -1);
        end
        
        function onZeroButtonPushed(app, varargin)
            app.Controller.resetPosition();
        end
        
        function onStepSizeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                app.Controller.syncStepSizes(app.ManualControls, app.AutoControls, event.Value, true);
            end
        end
        
        function onStepUpButtonPushed(app, varargin)
            % Cycle to next larger step size
            currentIndex = app.ManualControls.CurrentStepIndex;
            if currentIndex < length(app.ManualControls.StepSizes)
                newIndex = currentIndex + 1;
                newStepSize = app.ManualControls.StepSizes(newIndex);
                app.updateStepSizeDisplay(newIndex, newStepSize);
            end
        end
        
        function onStepDownButtonPushed(app, varargin)
            % Cycle to next smaller step size
            currentIndex = app.ManualControls.CurrentStepIndex;
            if currentIndex > 1
                newIndex = currentIndex - 1;
                newStepSize = app.ManualControls.StepSizes(newIndex);
                app.updateStepSizeDisplay(newIndex, newStepSize);
            end
        end
        

        function onAutoStepSizeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                app.Controller.syncStepSizes(app.ManualControls, app.AutoControls, event.Value, false);
                app.updateAutoStepStatus();
            end
        end
        
        function onAutoStepsChanged(app, varargin)
            app.updateAutoStepStatus();
        end
        
        function onAutoDelayChanged(app, varargin)
            app.updateAutoStepStatus();
        end
        
        function onAutoDirectionToggled(app, varargin)
            % Toggle between up and down directions
            currentDirection = app.Controller.AutoDirection;
            newDirection = -currentDirection;  % Toggle: 1 -> -1, -1 -> 1
            app.Controller.setAutoDirectionWithValidation(app.AutoControls, newDirection);
            app.updateAutoStepStatus();
            app.updateDirectionButtons();
        end
        
        function onStartStopButtonPushed(app, varargin)
            if app.Controller.IsAutoRunning
                app.Controller.stopAutoStepping();
            else
                app.Controller.startAutoSteppingWithValidation(app, app.AutoControls, app.PlotManager);
            end
            UiComponents.updateAllUI(app);
            app.updateAutoStepStatus();
            app.updateDirectionButtons();
        end
        

        

        function onRefreshButtonPushed(app, ~, ~)
            app.Controller.refreshPosition();
        end
        
        function onBookmarksButtonPushed(app, ~, ~)
            if isempty(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp.UIFigure)
                app.launchBookmarksView();
            else
                delete(app.BookmarksViewApp);
                app.BookmarksViewApp = [];
            end
            app.updateWindowStatusButtons();
        end
        
        function onStageViewButtonPushed(app, ~, ~)
            if isempty(app.StageViewApp) || ~isvalid(app.StageViewApp) || ~isvalid(app.StageViewApp.UIFigure)
                app.launchStageView();
            else
                delete(app.StageViewApp);
                app.StageViewApp = [];
            end
            app.updateWindowStatusButtons();
        end
        
        function onWindowClose(app, varargin)
            % This function is called when the main window is closed.
            % The delete() method will handle all cleanup.
            delete(app);
        end
        

        function onMetricTypeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                app.Controller.setMetricTypeWithValidation(event.Value);
            end
            
            % Close any child windows
            if ~isempty(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp)
                delete(app.BookmarksViewApp);
            end
            app.BookmarksViewApp = [];
            
            if ~isempty(app.StageViewApp) && isvalid(app.StageViewApp)
                delete(app.StageViewApp);
            end
            app.StageViewApp = [];
            
            FoilviewUtils.safeStopTimer(app.ResizeMonitorTimer);
            app.ResizeMonitorTimer = [];
        end
        
        function onMetricRefreshButtonPushed(app, ~, ~)
            app.Controller.updateMetric();
        end
        

        

        function onExpandButtonPushed(app, ~, ~)
            isExpanded = app.PlotManager.getIsPlotExpanded();
            if isExpanded
                app.PlotManager.collapseGUI(app.UIFigure, app.MainPanel, ...
                    app.MetricsPlotControls.Panel, app.MetricsPlotControls.ExpandButton, app);
            else
                app.PlotManager.expandGUI(app.UIFigure, app.MainPanel, ...
                    app.MetricsPlotControls.Panel, app.MetricsPlotControls.ExpandButton, app);
            end
        end
        
        function onClearPlotButtonPushed(app, varargin)
            app.PlotManager.clearMetricsPlot(app.MetricsPlotControls.Axes);
        end
        
        function onExportPlotButtonPushed(app, varargin)
            app.PlotManager.exportPlotData(app.UIFigure, app.Controller);
        end
    end
    

    methods (Access = private)
        function updateStepSizeDisplay(app, newIndex, newStepSize)
            % Update step size display and sync controls
            app.ManualControls.CurrentStepIndex = newIndex;
            
            % Update display label
            app.ManualControls.StepSizeDisplay.Text = sprintf('%.1fμm', newStepSize);
            
            % Update hidden dropdown for compatibility
            formattedValue = FoilviewUtils.formatPosition(newStepSize);
            if ismember(formattedValue, app.ManualControls.StepSizeDropdown.Items)
                app.ManualControls.StepSizeDropdown.Value = formattedValue;
            end
            
            % Sync with auto controls
            app.AutoControls.StepField.Value = newStepSize;
        end
        
        function updateAutoStepStatus(app)
            UiComponents.updateControlStates(app.ManualControls, app.AutoControls, app.Controller);
        end
        
        function updateDirectionButtons(app)
            % Update direction button and start button to show current direction
            direction = app.Controller.AutoDirection;
            
            % Style direction button based on direction and running state
            if direction > 0
                app.AutoControls.DirectionButton.Text = '▲';
                baseColor = [0.2 0.7 0.3];  % success color
            else
                app.AutoControls.DirectionButton.Text = '▼';
                baseColor = [0.9 0.6 0.2];  % warning color
            end
            
            if app.Controller.IsAutoRunning
                app.AutoControls.DirectionButton.BackgroundColor = [0.9 0.3 0.3];  % danger color
            else
                app.AutoControls.DirectionButton.BackgroundColor = baseColor;
            end
            
            app.AutoControls.DirectionButton.FontColor = [1 1 1];  % white text
            app.AutoControls.DirectionButton.FontSize = 10;
            app.AutoControls.DirectionButton.FontWeight = 'bold';
            
            % Style start/stop button based on state and direction
            if direction > 0
                if app.Controller.IsAutoRunning
                    app.AutoControls.StartStopButton.BackgroundColor = [0.9 0.3 0.3];  % danger color
                    app.AutoControls.StartStopButton.Text = 'STOP ▲';
                else
                    app.AutoControls.StartStopButton.BackgroundColor = [0.2 0.7 0.3];  % success color
                    app.AutoControls.StartStopButton.Text = 'START ▲';
                end
            else
                if app.Controller.IsAutoRunning
                    app.AutoControls.StartStopButton.BackgroundColor = [0.9 0.3 0.3];  % danger color
                    app.AutoControls.StartStopButton.Text = 'STOP ▼';
                else
                    app.AutoControls.StartStopButton.BackgroundColor = [0.2 0.7 0.3];  % success color
                    app.AutoControls.StartStopButton.Text = 'START ▼';
                end
            end
            app.AutoControls.StartStopButton.FontColor = [1 1 1];  % white text
            app.AutoControls.StartStopButton.FontSize = 10;
            app.AutoControls.StartStopButton.FontWeight = 'bold';
        end
        
        function updateWindowStatusButtons(app)
            isBookmarksOpen = ~isempty(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp.UIFigure);
            isStageViewOpen = ~isempty(app.StageViewApp) && isvalid(app.StageViewApp) && isvalid(app.StageViewApp.UIFigure);

            if isBookmarksOpen
                app.StatusControls.BookmarksButton.Text = 'Close Bookmarks';
                app.StatusControls.BookmarksButton.Icon = '';
            else
                app.StatusControls.BookmarksButton.Text = 'Open Bookmarks';
                app.StatusControls.BookmarksButton.Icon = '';
            end

            if isStageViewOpen
                app.StatusControls.StageViewButton.Text = 'Close Stage View';
                app.StatusControls.StageViewButton.Icon = '';
            else
                app.StatusControls.StageViewButton.Text = 'Open Stage View';
                app.StatusControls.StageViewButton.Icon = '';
            end
        end
        
        function monitorWindowResize(app)
            % Monitor window size changes and adjust UI elements accordingly
            if ~isvalid(app.UIFigure)
                return;
            end
            
            % Update window status buttons to catch external window closures
            app.updateWindowStatusButtons();
            
            currentSize = app.UIFigure.Position;
            
            % Skip monitoring if we're ignoring programmatic resizes
            if app.IgnoreNextResize
                app.IgnoreNextResize = false;
                app.LastWindowSize = currentSize;
                return;
            end
            
            % Check if window size has changed significantly
            sizeDiff = abs(currentSize - app.LastWindowSize);
            threshold = 30; % Pixel threshold for user-initiated changes
            
            % For font scaling, only consider HEIGHT changes (ignore width changes from plot)
            % This way, plot expand/collapse (width changes) won't trigger font scaling
            heightChanged = sizeDiff(4) > threshold;
            
            if heightChanged % Only adjust fonts based on height changes
                % Window height changed significantly (likely user resize)
                try
                    % Collect all UI components for font adjustment
                    components = struct();
                    components.PositionDisplay = app.PositionDisplay;
                    components.AutoControls = app.AutoControls;
                    components.ManualControls = app.ManualControls;
                    components.MetricDisplay = app.MetricDisplay;
                    components.StatusControls = app.StatusControls;
                    
                    % Calculate scaling based on height change only
                    heightBasedSize = [currentSize(1:2), app.LastWindowSize(3), currentSize(4)];
                    UiComponents.adjustFontSizes(components, heightBasedSize);
                    
                catch ME
                    % Log errors for debugging but don't crash
                    warning('foilview:ResizeError', 'Error during font resize: %s', ME.message);
                end
            end
            
            % Handle plot repositioning separately (for any significant size change)
            if any(sizeDiff(3:4) > threshold)
                try
                    % If plot is expanded, adjust its position with extra validation
                    if app.PlotManager.getIsPlotExpanded() && ...
                       isvalid(app.MetricsPlotControls.Panel) && ...
                       strcmp(app.MetricsPlotControls.Panel.Visible, 'on')
                        
                        % Only adjust if we have reasonable window dimensions
                        if currentSize(3) > 400 && currentSize(4) > 200
                            UiComponents.adjustPlotPosition(app.UIFigure, ...
                                app.MetricsPlotControls.Panel, 400);
                            
                            % Ensure plot panel stays visible
                            app.MetricsPlotControls.Panel.Visible = 'on';
                        end
                    end
                    
                catch ME
                    % Log errors for debugging but don't crash
                    warning('foilview:ResizeError', 'Error during plot resize: %s', ME.message);
                end
            end
            
            % Update last known size
            app.LastWindowSize = currentSize;
        end
        
        function stopTimers(app)
            % Stop and delete all timers
            FoilviewUtils.safeStopTimer(app.RefreshTimer);
            app.RefreshTimer = [];
            
            FoilviewUtils.safeStopTimer(app.MetricTimer);
            app.MetricTimer = [];
            
            FoilviewUtils.safeStopTimer(app.ResizeMonitorTimer);
            app.ResizeMonitorTimer = [];
        end
        
        function cleanup(app)
            % Clean up all application resources.
            
            % Stop timers
            app.stopTimers();
            
            % Clean up controller
            if ~isempty(app.Controller) && isvalid(app.Controller)
                app.Controller.cleanup();
            end
            
            % Close any child windows by deleting their app objects.
            if ~isempty(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp)
                delete(app.BookmarksViewApp);
                app.BookmarksViewApp = [];
            end
            
            if ~isempty(app.StageViewApp) && isvalid(app.StageViewApp)
                delete(app.StageViewApp);
                app.StageViewApp = [];
            end
        end
    end
end 
