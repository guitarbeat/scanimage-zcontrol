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
        WindowManager               foilview_window_manager
    end
    
    %% Private Properties - Internal State
    properties (Access = private)
        % Timers
        RefreshTimer
        MetricTimer
        ResizeMonitorTimer
        
        % Window sizing tracking
        LastWindowSize              % Track previous window size for resize detection
        IgnoreNextResize = false    % Flag to ignore programmatic resizes
        
        % Sync prevention flag
        IsSyncingStepSize = false
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
            
            % Create UI components
            components = foilview_ui.createAllComponents(app);
            app.copyComponentsFromStruct(components);
            
            % Set up callbacks
            foilview_callback_manager.setupAllCallbacks(app);
            
            % Initialize application
            foilview_initialization_manager.initializeApplication(app);
            
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
    end
    
    %% Controller Event Handlers
    methods (Access = private)
        function onControllerStatusChanged(app)
            foilview_updater.updateStatusDisplay(app.PositionDisplay, app.StatusControls, app.Controller);
        end
        
        function onControllerPositionChanged(app)
            % Update position label
            foilview_updater.updatePositionDisplay(app.UIFigure, app.PositionDisplay, app.Controller);
            % Refresh expand button styling and window title
            foilview_updater.updatePlotExpansionState(app.MetricsPlotControls, app.PlotManager.getIsPlotExpanded());
            foilview_updater.updateWindowTitle(app);
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
        
        function onStepUpButtonPushed(app, varargin)
            % Cycle to next preset step size
            sizes = app.ManualControls.StepSizes;
            idx = app.ManualControls.CurrentStepIndex;
            if idx < numel(sizes)
                idx = idx + 1;
            end
            newVal = sizes(idx);
            app.ManualControls.CurrentStepIndex = idx;
            app.ManualControls.StepSizeField.Value = newVal;
        end
        
        function onStepDownButtonPushed(app, varargin)
            % Cycle to previous preset step size
            sizes = app.ManualControls.StepSizes;
            idx = app.ManualControls.CurrentStepIndex;
            if idx > 1
                idx = idx - 1;
            end
            newVal = sizes(idx);
            app.ManualControls.CurrentStepIndex = idx;
            app.ManualControls.StepSizeField.Value = newVal;
        end
        
        function onManualStepSizeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                
                % Only sync if not already syncing to prevent infinite loops
                if ~app.IsSyncingStepSize
                    app.IsSyncingStepSize = true;
                    try
                        foilview_logic.syncStepSizes(app.ManualControls, app.AutoControls, event.Value, true);
                    catch
                        % Ignore errors during sync
                    end
                    % Update preset index based on new manual value
                    sizes = app.ManualControls.StepSizes;
                    [~, idx] = min(abs(sizes - event.Value));
                    app.ManualControls.CurrentStepIndex = idx;
                    app.IsSyncingStepSize = false;
                end
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
            app.WindowManager.toggleBookmarksView();
        end
        
        function onStageViewButtonPushed(app, varargin)
            app.WindowManager.toggleStageView();
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
            % Toggle GUI expansion/collapse
            if app.PlotManager.getIsPlotExpanded()
                app.PlotManager.collapseGUI(app.UIFigure, app.MainPanel, ...
                    app.MetricsPlotControls.Panel, app.MetricsPlotControls.ExpandButton, app);
            else
                app.PlotManager.expandGUI(app.UIFigure, app.MainPanel, ...
                    app.MetricsPlotControls.Panel, app.MetricsPlotControls.ExpandButton, app);
            end
            % Immediately refresh expand button styling and window title
            foilview_updater.updatePlotExpansionState(app.MetricsPlotControls, app.PlotManager.getIsPlotExpanded());
            foilview_updater.updateWindowTitle(app);
        end
        
        function onClearPlotButtonPushed(app, varargin)
            app.PlotManager.clearMetricsPlot(app.MetricsPlotControls.Axes);
        end
        
        function onExportPlotButtonPushed(app, varargin)
            app.PlotManager.exportPlotData(app.UIFigure, app.Controller);
        end
        
        % Auto Step Events
        function onAutoStepSizeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                % Prevent recursive syncing
                if ~app.IsSyncingStepSize
                    app.IsSyncingStepSize = true;
                    try
                        foilview_logic.syncStepSizes(app.ManualControls, app.AutoControls, event.Value, false);
                    catch
                        % Ignore errors during sync
                    end
                    app.IsSyncingStepSize = false;
                end
                app.updateAutoStepStatus();
            end
        end
    end
    
    %% Helper Methods
    methods (Access = private)
        function updateAutoStepStatus(app)
            % Update the smart status display using centralized formatting
            stepSize = app.AutoControls.StepField.Value;
            numSteps = app.AutoControls.StepsField.Value;
            delay = app.AutoControls.DelayField.Value;
            direction = app.Controller.AutoDirection;
            isRunning = app.Controller.IsAutoRunning;
            
            statusText = foilview_constants.formatAutoStepStatus(isRunning, stepSize, numSteps, direction, delay);
            app.AutoControls.StatusDisplay.Text = statusText;
        end
        
        function updateDirectionButtons(app)
            % Update direction button and start button to show current direction
            direction = app.Controller.AutoDirection;
            isRunning = app.Controller.IsAutoRunning;
            
            % Style direction button using centralized styling
            foilview_styling.styleDirectionButton(app.AutoControls.DirectionButton, direction, isRunning);
            
            % Style start/stop button based on state and direction using constants
            buttonText = foilview_constants.getStartStopButtonText(isRunning, direction);
            app.AutoControls.StartStopButton.Text = buttonText;
            
            if isRunning
                foilview_styling.styleButton(app.AutoControls.StartStopButton, 'danger', 'base');
            else
                foilview_styling.styleButton(app.AutoControls.StartStopButton, 'success', 'base');
            end
        end
        
        function monitorWindowResize(app)
            % Monitor window size changes and adjust UI elements accordingly
            if ~isvalid(app.UIFigure)
                return;
            end
            
            % Update window status buttons to catch external window closures
            app.WindowManager.updateWindowStatusButtons();
            
            currentSize = app.UIFigure.Position;
            
            % Skip monitoring if we're ignoring programmatic resizes
            if app.IgnoreNextResize
                app.IgnoreNextResize = false;
                app.LastWindowSize = currentSize;
                return;
            end
            
            % Check if window size has changed significantly
            sizeDiff = abs(currentSize - app.LastWindowSize);
            threshold = foilview_constants.RESIZE_THRESHOLD;
            
            % For font scaling, only consider HEIGHT changes (ignore width changes from plot)
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
                        if currentSize(3) > foilview_constants.MIN_WINDOW_WIDTH && ...
                           currentSize(4) > foilview_constants.MIN_WINDOW_HEIGHT
                            foilview_ui.adjustPlotPosition(app.UIFigure, ...
                                app.MetricsPlotControls.Panel, foilview_constants.PLOT_MIN_WIDTH);
                            
                            % Ensure plot panel stays visible
                            app.MetricsPlotControls.Panel.Visible = 'on';
                        end
                    end
                    
                catch ME
                    warning('foilview:ResizeError', 'Error during plot resize: %s', ME.message);
                end
            end
            
            % Update last known size
            app.LastWindowSize = currentSize;
        end
        
        function cleanup(app)
            % Clean up all application resources
            
            % Clean up window manager
            if ~isempty(app.WindowManager) && isvalid(app.WindowManager)
                app.WindowManager.cleanup();
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