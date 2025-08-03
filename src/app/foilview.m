classdef foilview < matlab.apps.AppBase
    % foilview - Modern GUI for Z-stage positioning control and foil analysis
    %
    % This MATLAB App Designer application provides a comprehensive user interface
    % for microscope Z-stage control optimized for foil analysis workflows. 
    % This refactored version uses separate classes for different concerns, 
    % improving maintainability and code organization.
    %
    % Key Features:
    %   - Tabbed interface (Manual Control, Auto Step, Bookmarks)
    %   - Real-time position and focus metrics display
    %   - Expandable metrics plotting with data export
    %   - Position bookmarking system with labeled storage
    %   - Automated stepping sequences with progress tracking
    %   - Modern UI with responsive design and visual feedback
    %
    % Architecture:
    %   - Follows Model-View-Controller pattern with ZStageController
    %   - Separated UI creation, plotting, business logic, and UI updates
    %   - Event-driven updates for responsive user experience
    %   - Fixed-width main window with horizontal plot expansion
    %   - Timer-based refresh for position and metrics
    %
    % Usage:
    %   app = foilview();    % Launch the application
    %   delete(app);         % Clean shutdown when done
    %
    % See also: foilview_controller, foilview_ui, foilview_plot, 
    %           foilview_logic, foilview_updater
    
    %% Public Properties - UI Components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainPanel                   matlab.ui.container.Panel
        MainLayout                  matlab.ui.container.GridLayout
        ControlTabs                 matlab.ui.container.TabGroup
    end
    
    %% Private Properties - UI Component Groups
    properties (Access = public)
        % Position Display
        PositionDisplay
        
        % Metric Display Components
        MetricDisplay
        
        % Manual Control Components
        ManualControls
        
        % Auto Step Components  
        AutoControls
        
        % Status Components
        StatusControls
        
        % Metrics Plot Components
        MetricsPlotControls
    end
    
    %% Properties - Application State and Helpers
    properties (Access = public)
        % Core Controller
        Controller                  foilview_controller
        
        % Helper Classes
        PlotManager                 foilview_plot
        
        % Additional Windows
        StageViewApp                stageview
        BookmarksViewApp            bookmarksview
    end
    
    %% Private Properties - Internal State
    properties (Access = private)
        % Timers
        RefreshTimer
        MetricTimer
        ResizeMonitorTimer
        
        % * UI Update throttling - replaces persistent variable in updater
        LastUpdateTime (1,1) double = 0  % Timestamp of last UI update for throttling
        
        % Window sizing tracking
        LastWindowSize = [0 0 0 0]  % Track previous window size for resize detection
        IgnoreNextResize = false    % Flag to ignore programmatic resizes
    end
    
    %% Constructor and Destructor
    methods (Access = public)
        function app = foilview()
            % foilview Constructor
            % 
            % Creates and initializes the Z-Stage Control application with full
            % GUI setup, controller integration, and timer-based updates.
            %
            % Initialization sequence:
            %   1. Create all UI components using UICreator
            %   2. Initialize foilview_controller and helper classes
            %   3. Set up event listeners
            %   4. Start refresh timers for position and metrics
            %   5. Register app with MATLAB App framework
            %
            % Returns:
            %   app - foilview instance ready for use
            
            % Create UI components using the UI creator
            components = foilview_ui.createAllComponents(app);
            app.copyComponentsFromStruct(components);
            
            % Set up all callbacks
            app.setupCallbacks();
            
            % Initialize application
            app.initializeApplication();
            
            % Register app
            registerApp(app, app.UIFigure);
            
            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            % foilview Destructor
            %
            % Performs clean shutdown of the application including:
            %   - Stopping all timers safely
            %   - Cleaning up controller resources
            %   - Closing UI figure
            %
            % Called automatically when app goes out of scope or is explicitly deleted.
            
            app.cleanup();
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
    
    %% Initialization Methods
    methods (Access = private)
        function copyComponentsFromStruct(app, components)
            % Copy UI components from struct to app properties
            fields = fieldnames(components);
            for i = 1:length(fields)
                app.(fields{i}) = components.(fields{i});
            end
        end
        
        function initializeApplication(app)
            % Initialize the application with controller and helpers
            
            % Create controller
            app.Controller = foilview_controller();
            
            % Create helper classes
            app.PlotManager = foilview_plot(app);
            
            % Set up event listeners
            addlistener(app.Controller, 'StatusChanged', @(src,evt) app.onControllerStatusChanged());
            addlistener(app.Controller, 'PositionChanged', @(src,evt) app.onControllerPositionChanged());
            addlistener(app.Controller, 'MetricChanged', @(src,evt) app.onControllerMetricChanged());
            addlistener(app.Controller, 'AutoStepComplete', @(src,evt) app.onControllerAutoStepComplete());
            
            % Initialize plot
            app.PlotManager.initializeMetricsPlot(app.MetricsPlotControls.Axes);
            
            % Update initial display
            foilview_updater.updateAllUI(app);
            
            % Initialize status displays
            app.updateAutoStepStatus();
            app.updateDirectionButtons();
            
            % Launch additional windows
            app.launchStageView();
            app.launchBookmarksView();
            
            % Start refresh timers
            app.startRefreshTimer();
            app.startMetricTimer();
            app.startResizeMonitorTimer();
        end
        
        function startRefreshTimer(app)
            app.RefreshTimer = foilview_utils.createTimer('fixedRate', ...
                app.Controller.POSITION_REFRESH_PERIOD, ...
                @(~,~) app.Controller.refreshPosition());
            start(app.RefreshTimer);
        end
        
        function startMetricTimer(app)
            app.MetricTimer = foilview_utils.createTimer('fixedRate', ...
                app.Controller.METRIC_REFRESH_PERIOD, ...
                @(~,~) app.Controller.updateMetric());
            start(app.MetricTimer);
        end
        
        function startResizeMonitorTimer(app)
            % Monitor window size changes and adjust UI responsively
            app.ResizeMonitorTimer = foilview_utils.createTimer('fixedRate', ...
                0.5, ...  % Check every 0.5 seconds
                @(~,~) app.monitorWindowResize());
            
            % Initialize the last window size
            if isvalid(app.UIFigure)
                app.LastWindowSize = app.UIFigure.Position;
            end
            
            start(app.ResizeMonitorTimer);
        end
        
        function launchStageView(app)
            % Launch the Stage View window automatically
            try
                % Create the stage view application
                app.StageViewApp = stageview();
                
                % Position the stage view window to the right of the main window
                app.positionStageViewWindow();
                
            catch ME
                warning('foilview:StageViewLaunch', ...
                       'Failed to launch Stage View: %s', ME.message);
                % Don't show error dialog during initialization to avoid blocking
                app.StageViewApp = [];
            end
        end
        
        function launchBookmarksView(app)
            % Launch the Bookmarks View window automatically
            try
                % Create the bookmarks view application with controller reference
                app.BookmarksViewApp = bookmarksview(app.Controller);
                
                % Position the bookmarks window to the left of the main window
                app.positionBookmarksViewWindow();
                
            catch ME
                warning('foilview:BookmarksViewLaunch', ...
                       'Failed to launch Bookmarks View: %s', ME.message);
                % Don't show error dialog during initialization to avoid blocking
                app.BookmarksViewApp = [];
            end
        end
        
        function positionStageViewWindow(app)
            % Position stage view window relative to main window
            if ~isempty(app.StageViewApp) && isvalid(app.StageViewApp.UIFigure)
                mainPos = app.UIFigure.Position;
                stagePos = app.StageViewApp.UIFigure.Position;
                
                % Place stage view to the right of main window with some spacing
                app.StageViewApp.UIFigure.Position(1) = mainPos(1) + mainPos(3) + 20;
                app.StageViewApp.UIFigure.Position(2) = mainPos(2);
            end
        end
        
        function positionBookmarksViewWindow(app)
            % Position bookmarks view window relative to main window
            if ~isempty(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp.UIFigure)
                mainPos = app.UIFigure.Position;
                bookmarksPos = app.BookmarksViewApp.UIFigure.Position;
                
                % Place bookmarks view to the left of main window with some spacing
                app.BookmarksViewApp.UIFigure.Position(1) = mainPos(1) - bookmarksPos(3) - 20;
                app.BookmarksViewApp.UIFigure.Position(2) = mainPos(2);
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
    
    %% Controller Event Handlers
    methods (Access = private)
        function onControllerStatusChanged(app)
            foilview_updater.updateStatusDisplay(app.PositionDisplay, app.StatusControls, app.Controller);
        end
        
        function onControllerPositionChanged(app)
            foilview_updater.updatePositionDisplay(app.UIFigure, app.PositionDisplay, app.Controller);
        end
        
        function onControllerMetricChanged(app)
            foilview_updater.updateMetricDisplay(app.MetricDisplay, app.Controller);
        end
        
        function onControllerAutoStepComplete(app)
            foilview_updater.updateControlStates(app.ManualControls, app.AutoControls, app.Controller);
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
    
    %% UI Event Handlers
    methods (Access = private)
        % Manual Control Events
        function onUpButtonPushed(app, varargin)
            foilview_logic.moveStageManual(app.Controller, app.ManualControls, 1);
        end
        
        function onDownButtonPushed(app, varargin)
            foilview_logic.moveStageManual(app.Controller, app.ManualControls, -1);
        end
        
        function onZeroButtonPushed(app, varargin)
            foilview_logic.resetPosition(app.Controller);
        end
        
        function onStepSizeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                foilview_logic.syncStepSizes(app.ManualControls, app.AutoControls, event.Value, true);
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
        
        % Auto Step Events
        function onAutoStepSizeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                foilview_logic.syncStepSizes(app.ManualControls, app.AutoControls, event.Value, false);
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
            foilview_logic.setAutoDirection(app.Controller, app.AutoControls, newDirection);
            app.updateAutoStepStatus();
            app.updateDirectionButtons();
        end
        
        function onStartStopButtonPushed(app, varargin)
            if app.Controller.IsAutoRunning
                foilview_logic.stopAutoStepping(app.Controller);
            else
                foilview_logic.startAutoStepping(app, app.Controller, app.AutoControls, app.PlotManager);
            end
            foilview_updater.updateAllUI(app);
            app.updateAutoStepStatus();
            app.updateDirectionButtons();
        end
        

        
        % System Events
        function onRefreshButtonPushed(app, varargin)
            foilview_logic.refreshConnection(app.Controller);
            foilview_updater.updateAllUI(app);
        end
        
        function onBookmarksButtonPushed(app, varargin)
            % Toggle Bookmarks window (Open/Close)
            if isempty(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp.UIFigure)
                % Window doesn't exist or was closed, create new one
                app.launchBookmarksView();
            else
                % Window exists - check if it's visible
                if strcmp(app.BookmarksViewApp.UIFigure.Visible, 'on')
                    % Window is visible, close it
                    delete(app.BookmarksViewApp);
                    app.BookmarksViewApp = [];
                else
                    % Window exists but hidden, make it visible and bring to front
                    app.BookmarksViewApp.UIFigure.Visible = 'on';
                    figure(app.BookmarksViewApp.UIFigure);
                    app.positionBookmarksViewWindow();
                end
            end
        end
        
        function onStageViewButtonPushed(app, varargin)
            % Toggle Stage View window (Open/Close)
            if isempty(app.StageViewApp) || ~isvalid(app.StageViewApp) || ~isvalid(app.StageViewApp.UIFigure)
                % Window doesn't exist or was closed, create new one
                app.launchStageView();
            else
                % Window exists - check if it's visible
                if strcmp(app.StageViewApp.UIFigure.Visible, 'on')
                    % Window is visible, close it
                    delete(app.StageViewApp);
                    app.StageViewApp = [];
                else
                    % Window exists but hidden, make it visible and bring to front
                    app.StageViewApp.UIFigure.Visible = 'on';
                    figure(app.StageViewApp.UIFigure);
                    app.positionStageViewWindow();
                end
            end
        end
        
        function onWindowClose(app, varargin)
            app.cleanup();
            delete(app);
        end
        
        % Metric Events
        function onMetricTypeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                foilview_logic.setMetricType(app.Controller, event.Value);
            end
        end
        
        function onMetricRefreshButtonPushed(app, varargin)
            foilview_logic.updateMetric(app.Controller);
        end
        

        
        % Plot Control Events
        function onExpandButtonPushed(app, varargin)
            if app.PlotManager.getIsPlotExpanded()
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
    
    %% Helper Methods
    methods (Access = private)
        function updateStepSizeDisplay(app, newIndex, newStepSize)
            % Update step size display and sync controls
            app.ManualControls.CurrentStepIndex = newIndex;
            
            % Update display label
            app.ManualControls.StepSizeDisplay.Text = sprintf('%.1fμm', newStepSize);
            
            % Update hidden dropdown for compatibility
            formattedValue = foilview_utils.formatPosition(newStepSize);
            if ismember(formattedValue, app.ManualControls.StepSizeDropdown.Items)
                app.ManualControls.StepSizeDropdown.Value = formattedValue;
            end
            
            % Sync with auto controls
            app.AutoControls.StepField.Value = newStepSize;
        end
        
        function updateAutoStepStatus(app)
            % Update the smart status display
            stepSize = app.AutoControls.StepField.Value;
            numSteps = app.AutoControls.StepsField.Value;
            delay = app.AutoControls.DelayField.Value;
            
            % Calculate total distance
            totalDistance = stepSize * numSteps;
            
            % Get direction
            direction = app.Controller.AutoDirection;
            directionText = '';
            if direction > 0
                directionText = 'upward';
            else
                directionText = 'downward';
            end
            
            % Create status message
            if app.Controller.IsAutoRunning
                statusText = sprintf('Sweeping %.1f μm %s...', totalDistance, directionText);
            else
                totalTime = numSteps * delay;
                if totalTime < 60
                    statusText = sprintf('Ready: %.1f μm %s (%.1fs)', totalDistance, directionText, totalTime);
                else
                    minutes = floor(totalTime / 60);
                    seconds = mod(totalTime, 60);
                    statusText = sprintf('Ready: %.1f μm %s (%dm %.0fs)', totalDistance, directionText, minutes, seconds);
                end
            end
            
            app.AutoControls.StatusDisplay.Text = statusText;
        end
        
        function updateDirectionButtons(app)
            % Update direction button and start button to show current direction
            direction = app.Controller.AutoDirection;
            
            if direction > 0
                % Upward direction
                app.AutoControls.DirectionButton.Text = '▲';
                app.AutoControls.DirectionButton.BackgroundColor = foilview_ui.COLORS.Success;
                if app.Controller.IsAutoRunning
                    app.AutoControls.StartStopButton.Text = 'STOP ▲';
                    app.AutoControls.StartStopButton.BackgroundColor = foilview_ui.COLORS.Danger;
                else
                    app.AutoControls.StartStopButton.Text = 'START ▲';
                    app.AutoControls.StartStopButton.BackgroundColor = foilview_ui.COLORS.Success;
                end
            else
                % Downward direction
                app.AutoControls.DirectionButton.Text = '▼';
                app.AutoControls.DirectionButton.BackgroundColor = foilview_ui.COLORS.Warning;
                if app.Controller.IsAutoRunning
                    app.AutoControls.StartStopButton.Text = 'STOP ▼';
                    app.AutoControls.StartStopButton.BackgroundColor = foilview_ui.COLORS.Danger;
                else
                    app.AutoControls.StartStopButton.Text = 'START ▼';
                    app.AutoControls.StartStopButton.BackgroundColor = foilview_ui.COLORS.Success;
                end
            end
        end
        
        function monitorWindowResize(app)
            % Monitor window size changes and adjust UI elements accordingly
            if ~isvalid(app.UIFigure)
                return;
            end
            
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
                    foilview_ui.adjustFontSizes(components, heightBasedSize);
                    
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
                            foilview_ui.adjustPlotPosition(app.UIFigure, ...
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
        
        function cleanup(app)
            % Clean up additional windows
            if ~isempty(app.StageViewApp) && isvalid(app.StageViewApp)
                delete(app.StageViewApp);
            end
            if ~isempty(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp)
                delete(app.BookmarksViewApp);
            end
            
            % Clean up controller
            if ~isempty(app.Controller) && isvalid(app.Controller)
                delete(app.Controller);
            end
            
            % Stop timers using centralized utility
            foilview_utils.safeStopTimer(app.RefreshTimer);
            app.RefreshTimer = [];
            
            foilview_utils.safeStopTimer(app.MetricTimer);
            app.MetricTimer = [];
            
            foilview_utils.safeStopTimer(app.ResizeMonitorTimer);
            app.ResizeMonitorTimer = [];
            
            % Clean up all timers using centralized utility
            foilview_utils.cleanupAllTimers();
            
            % Clean up panels using centralized validation
            if foilview_utils.validateUIComponent(app.MainPanel)
                delete(app.MainPanel);
            end
            if ~isempty(app.MetricsPlotControls) && foilview_utils.validateUIComponent(app.MetricsPlotControls.Panel)
                delete(app.MetricsPlotControls.Panel);
            end
        end
    end
end 