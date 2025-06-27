classdef ZStageControlApp < matlab.apps.AppBase
    % ZStageControlApp - Modern GUI for Z-stage positioning control
    %
    % This MATLAB App Designer application provides a comprehensive user interface
    % for microscope Z-stage control, featuring tabbed interface design, real-time
    % metrics display, automated scanning capabilities, and expandable plotting.
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
    %   - Event-driven updates for responsive user experience
    %   - Fixed-width main window with horizontal plot expansion
    %   - Timer-based refresh for position and metrics
    %
    % Usage:
    %   app = ZStageControlApp();        % Launch the application
    %   delete(app);                     % Clean shutdown when done
    %
    % UI Components:
    %   Manual Control Tab:
    %     - Step size dropdown (0.1 - 50 μm)
    %     - Up/Down movement buttons
    %     - Zero position reset
    %
    %   Auto Step Tab:
    %     - Custom step size and count configuration
    %     - Direction selection (up/down)
    %     - Delay timing control
    %     - Metrics recording toggle
    %     - Start/Stop sequence control
    %
    %   Bookmarks Tab:
    %     - Position labeling and storage
    %     - Saved positions list with metrics
    %     - Navigation and deletion controls
    %
    %   Metrics Display:
    %     - Real-time focus quality indicator
    %     - Metric type selection (Std Dev, Mean, Max)
    %     - Manual refresh capability
    %
    %   Expandable Plot:
    %     - Normalized metrics vs position visualization
    %     - Multi-metric overlay with legend
    %     - Data export and plot clearing controls
    %
    % Events Handled:
    %   - Controller status, position, and metric changes
    %   - Auto-stepping completion with plot expansion
    %   - User interactions for all controls
    %
    % See also: ZStageController, matlab.apps.AppBase
    
    %% Constants
    properties (Constant, Access = private)
        % Window Configuration
        % Fixed dimensions for consistent layout and professional appearance
        WINDOW_WIDTH = 320      % Base window width (pixels)
        WINDOW_HEIGHT = 380     % Window height to accommodate all controls
        PLOT_WIDTH = 400        % Additional width when plot is expanded
        
        % UI Theme Colors
        % Modern color scheme for professional appearance and good contrast
        COLORS = struct(...
            'Background', [0.95 0.95 0.95], ...  % Light gray background
            'Primary', [0.2 0.6 0.9], ...        % Blue for primary actions
            'Success', [0.2 0.7 0.3], ...        % Green for success states
            'Warning', [0.9 0.6 0.2], ...        % Orange for warnings
            'Danger', [0.9 0.3 0.3], ...         % Red for errors/dangers
            'Light', [0.98 0.98 0.98], ...       % Nearly white for highlights
            'TextMuted', [0.5 0.5 0.5])          % Gray for secondary text
        
        % UI Text
        % Centralized text constants for consistency and easy localization
        TEXT = struct(...
            'WindowTitle', 'Z-Stage Control', ... % Main window title
            'Ready', 'Ready')                     % Default status message
    end
    
    %% Public Properties - UI Components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainPanel                   matlab.ui.container.Panel
        MainLayout                  matlab.ui.container.GridLayout
        ControlTabs                 matlab.ui.container.TabGroup
    end
    
    %% Private Properties - UI Component Groups
    properties (Access = private)
        % Position Display
        PositionDisplay = struct('Label', [], 'Status', [])
        
        % Metric Display Components
        MetricDisplay = struct(...
            'Label', [], ...
            'Value', [], ...
            'TypeDropdown', [], ...
            'RefreshButton', [])
        
        % Manual Control Components
        ManualControls = struct(...
            'UpButton', [], ...
            'DownButton', [], ...
            'StepSizeDropdown', [], ...
            'ZeroButton', [])
        
        % Auto Step Components  
        AutoControls = struct(...
            'StepField', [], ...
            'StepsField', [], ...
            'DelayField', [], ...
            'UpButton', [], ...
            'DownButton', [], ...
            'StartStopButton', [], ...
            'RecordMetricsCheckbox', [])
        
        % Bookmark Components
        BookmarkControls = struct(...
            'PositionList', [], ...
            'MarkField', [], ...
            'MarkButton', [], ...
            'GoToButton', [], ...
            'DeleteButton', [])
        
        % Status Components
        StatusControls = struct('Label', [], 'RefreshButton', [])
        
        % Metrics Plot Components
        MetricsPlotControls = struct(...
            'Panel', [], ...
            'Axes', [], ...
            'ClearButton', [], ...
            'ExportButton', [], ...
            'ExpandButton', [])
    end
    
    %% Private Properties - Application State
    properties (Access = private)
        % Core Controller
        Controller                  ZStageController
        
        % UI State
        MetricsPlotLines = {}
        IsPlotExpanded = false
        
        % Timers
        RefreshTimer
        MetricTimer
    end
    
    %% Constructor and Destructor
    methods (Access = public)
        function app = ZStageControlApp()
            % ZStageControlApp Constructor
            % 
            % Creates and initializes the Z-Stage Control application with full
            % GUI setup, controller integration, and timer-based updates.
            %
            % Initialization sequence:
            %   1. Initialize component structures to prevent errors
            %   2. Create all UI components and layout
            %   3. Initialize ZStageController and event listeners
            %   4. Start refresh timers for position and metrics
            %   5. Register app with MATLAB App framework
            %
            % Returns:
            %   app - ZStageControlApp instance ready for use
            %
            % Example:
            %   app = ZStageControlApp();  % Launch the application
            
            % Initialize component structures
            initializeComponentStructures(app);
            
            % Create UI
            createComponents(app);
            
            % Initialize application
            initializeApplication(app);
            
            % Register app
            registerApp(app, app.UIFigure);
            
            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            % ZStageControlApp Destructor
            %
            % Performs clean shutdown of the application including:
            %   - Stopping all timers safely
            %   - Cleaning up controller resources
            %   - Closing UI figure
            %
            % Called automatically when app goes out of scope or is explicitly deleted.
            %
            % Example:
            %   delete(app);  % Clean shutdown
            
            cleanup(app);
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
    
    %% Initialization Methods
    methods (Access = private)
        function initializeComponentStructures(app)
            % Ensure all component structures are properly initialized
            app.PositionDisplay = struct('Label', [], 'Status', []);
            app.ManualControls = struct(...
                'UpButton', [], 'DownButton', [], ...
                'StepSizeDropdown', [], 'ZeroButton', []);
            app.AutoControls = struct(...
                'StepField', [], 'StepsField', [], 'DelayField', [], ...
                'UpButton', [], 'DownButton', [], 'StartStopButton', [], ...
                'RecordMetricsCheckbox', []);
            app.BookmarkControls = struct(...
                'PositionList', [], 'MarkField', [], 'MarkButton', [], ...
                'GoToButton', [], 'DeleteButton', []);
            app.StatusControls = struct('Label', [], 'RefreshButton', []);
            app.MetricDisplay = struct(...
                'Label', [], ...
                'Value', [], ...
                'TypeDropdown', [], ...
                'RefreshButton', []);
        end
        
        function initializeApplication(app)
            % Create controller
            app.Controller = ZStageController();
            
            % Set up event listeners
            addlistener(app.Controller, 'StatusChanged', @(src,evt) app.onControllerStatusChanged());
            addlistener(app.Controller, 'PositionChanged', @(src,evt) app.onControllerPositionChanged());
            addlistener(app.Controller, 'MetricChanged', @(src,evt) app.onControllerMetricChanged());
            addlistener(app.Controller, 'AutoStepComplete', @(src,evt) app.onControllerAutoStepComplete());
            
            % Update initial display
            updateAllUI(app);
            
            % Start refresh timers
            startRefreshTimer(app);
            startMetricTimer(app);
        end
        
        % Controller event handlers
        function onControllerStatusChanged(app)
            updateStatusDisplay(app);
        end
        
        function onControllerPositionChanged(app)
            updatePositionDisplay(app);
        end
        
        function onControllerMetricChanged(app)
            updateMetricDisplay(app);
        end
        
        function onControllerAutoStepComplete(app)
            updateControlStates(app);
            % If metrics were recorded, update the plot and expand the GUI
            if app.Controller.RecordMetrics
                metrics = app.Controller.getAutoStepMetrics();
                if ~isempty(metrics.Positions)
                    updateMetricsPlot(app);
                    % Expand the GUI to show the plot
                    if ~app.IsPlotExpanded
                        expandGUI(app);
                    end
                end
            end
        end
        
        function startRefreshTimer(app)
            app.RefreshTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', app.Controller.POSITION_REFRESH_PERIOD, ...
                'TimerFcn', @(~,~) app.Controller.refreshPosition());
            start(app.RefreshTimer);
        end
        
        function startMetricTimer(app)
            app.MetricTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', app.Controller.METRIC_REFRESH_PERIOD, ...
                'TimerFcn', @(~,~) app.Controller.updateMetric());
            start(app.MetricTimer);
        end
        
        function updateMetricDisplay(app)
            % Update the metric display with current value from controller
            app.MetricDisplay.Value.Text = sprintf('%.2f', app.Controller.CurrentMetric);
        end
        
        function initializeMetricsPlot(app)
            % Set initial axis limits to prevent errors
            xlim(app.MetricsPlotControls.Axes, [0, 1]);
            ylim(app.MetricsPlotControls.Axes, [0, 1]);
            
            % Create a legend
            legend(app.MetricsPlotControls.Axes, 'Location', 'northeast', 'Interpreter', 'none');
            
            % Initialize empty plot lines with different colors and markers
            colors = {'#0072BD', '#D95319', '#EDB120', '#7E2F8E', '#77AC30', '#4DBEEE', '#A2142F'};
            markers = {'o', 's', 'd', '^', 'v', '>', '<'};
            app.MetricsPlotLines = {};
            
            for i = 1:length(ZStageController.METRIC_TYPES)
                metricType = ZStageController.METRIC_TYPES{i};
                colorIdx = mod(i-1, length(colors)) + 1;
                markerIdx = mod(i-1, length(markers)) + 1;
                app.MetricsPlotLines{i} = plot(app.MetricsPlotControls.Axes, NaN, NaN, ...
                    'Color', colors{colorIdx}, ...
                    'Marker', markers{markerIdx}, ...
                    'LineStyle', '-', ...
                    'LineWidth', 1.5, ...
                    'MarkerSize', 4, ...
                    'DisplayName', metricType);
            end
            
            % Set axes properties for better visualization
            set(app.MetricsPlotControls.Axes, 'Box', 'on', 'TickDir', 'out', 'LineWidth', 1);
            
            % Force initial draw
            drawnow;
        end
        
        function clearMetricsPlot(app)
            % Clear all plot lines
            for i = 1:length(app.MetricsPlotLines)
                if ~isempty(app.MetricsPlotLines{i}) && isvalid(app.MetricsPlotLines{i})
                    set(app.MetricsPlotLines{i}, 'XData', NaN, 'YData', NaN);
                end
            end
            
            % Reset axes limits
            xlim(app.MetricsPlotControls.Axes, [0, 1]);
            ylim(app.MetricsPlotControls.Axes, [0, 1]);
            
            % Reset title and labels
            title(app.MetricsPlotControls.Axes, 'Metrics vs Z Position');
            ylabel(app.MetricsPlotControls.Axes, 'Normalized Metric Value');
            
            drawnow;
        end
        
        function updateMetricsPlot(app)
            try
                % Get metrics data from controller
                metrics = app.Controller.getAutoStepMetrics();
                
                % Update each metric line
                for i = 1:length(ZStageController.METRIC_TYPES)
                    metricType = ZStageController.METRIC_TYPES{i};
                    fieldName = strrep(metricType, ' ', '_');
                    if isfield(metrics.Values, fieldName) && ~isempty(app.MetricsPlotLines) && i <= length(app.MetricsPlotLines) && isvalid(app.MetricsPlotLines{i})
                        % Get the data
                        xData = metrics.Positions;
                        yData = metrics.Values.(fieldName);
                        
                        % Remove any NaN values
                        validIdx = ~isnan(yData);
                        xData = xData(validIdx);
                        yData = yData(validIdx);
                        
                        % Normalize to first value if we have data
                        if ~isempty(yData)
                            firstValue = yData(1);
                            if firstValue ~= 0  % Avoid division by zero
                                yData = yData / firstValue;
                            end
                        end
                        
                        % Update the line
                        set(app.MetricsPlotLines{i}, 'XData', xData, 'YData', yData);
                    end
                end
                
                % Update axes limits
                if ~isempty(metrics.Positions) && length(metrics.Positions) > 1
                    % Set x-axis limits with some padding
                    xMin = min(metrics.Positions);
                    xMax = max(metrics.Positions);
                    
                    % Add a small buffer if min and max are the same
                    if abs(xMax - xMin) < 0.001
                        xMin = xMin - 1;
                        xMax = xMax + 1;
                    end
                    
                    xRange = xMax - xMin;
                    xPadding = xRange * 0.05;  % 5% padding
                    
                    % Only set if we have valid limits
                    if xMax > xMin
                        xlim(app.MetricsPlotControls.Axes, [xMin - xPadding, xMax + xPadding]);
                    end
                    
                    % Calculate y limits across all metrics
                    yValues = [];
                    for i = 1:length(ZStageController.METRIC_TYPES)
                        metricType = ZStageController.METRIC_TYPES{i};
                        fieldName = strrep(metricType, ' ', '_');
                        if isfield(metrics.Values, fieldName)
                            validY = metrics.Values.(fieldName)(~isnan(metrics.Values.(fieldName)));
                            if ~isempty(validY)
                                % Normalize to first value
                                firstValue = validY(1);
                                if firstValue ~= 0  % Avoid division by zero
                                    validY = validY / firstValue;
                                end
                                yValues = [yValues, validY];
                            end
                        end
                    end
                    
                    if ~isempty(yValues)
                        yMin = min(yValues);
                        yMax = max(yValues);
                        
                        % Add a small buffer if min and max are the same
                        if abs(yMax - yMin) < 0.001
                            yMin = yMin - 1;
                            yMax = yMax + 1;
                        end
                        
                        yRange = yMax - yMin;
                        yPadding = max(yRange * 0.1, 0.1);  % 10% padding or at least 0.1
                        
                        % Only set if we have valid limits
                        if yMax > yMin
                            ylim(app.MetricsPlotControls.Axes, [yMin - yPadding, yMax + yPadding]);
                        end
                    end
                    
                    % Update the title to show the Z range and normalization info
                    title(app.MetricsPlotControls.Axes, sprintf('Normalized Metrics vs Z Position (%.1f - %.1f μm)', ...
                        xMin, xMax));
                end
                
                % Update y-axis label to indicate normalization
                ylabel(app.MetricsPlotControls.Axes, 'Normalized Metric Value (relative to first value)');
                
                % Force drawing update
                drawnow;
            catch e
                % Handle any errors without crashing
                fprintf('Error updating plot: %s\n', e.message);
            end
        end
    end
    
    %% UI Creation Methods
    methods (Access = private)
        function createComponents(app)
            createMainWindow(app);
            
            % Create tabs
            createManualControlTab(app);
            createAutoStepTab(app);
            createBookmarksTab(app);
            
            % Create expandable plot area
            createMetricsPlotArea(app);
            
            app.UIFigure.Visible = 'on';
        end
        
        function createMainWindow(app)
            % Create main figure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Units = 'pixels';  % Use pixels for precise control
            app.UIFigure.Position = [100 100 app.WINDOW_WIDTH app.WINDOW_HEIGHT];
            app.UIFigure.Name = app.TEXT.WindowTitle;
            app.UIFigure.Color = app.COLORS.Background;
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @onWindowClose, true);
            app.UIFigure.Resize = 'off';  % Disable resize to control expansion manually
            app.UIFigure.AutoResizeChildren = 'off';  % Prevent automatic child resizing
            
            % Create main panel with fixed position for the original UI
            app.MainPanel = uipanel(app.UIFigure);
            app.MainPanel.Position = [0, 0, app.WINDOW_WIDTH, app.WINDOW_HEIGHT];
            app.MainPanel.BorderType = 'none';
            app.MainPanel.BackgroundColor = app.COLORS.Background;
            app.MainPanel.AutoResizeChildren = 'off';  % Prevent automatic resizing
            app.MainPanel.Units = 'pixels';  % Use pixels for precise control
            
            % Create main layout within the fixed panel
            app.MainLayout = uigridlayout(app.MainPanel, [5, 1]);
            app.MainLayout.RowHeight = {'fit', 'fit', '1x', 'fit', 'fit'};
            app.MainLayout.ColumnWidth = {'1x'};
            app.MainLayout.Padding = [10 10 10 10];
            app.MainLayout.RowSpacing = 10;
            app.MainLayout.Scrollable = 'off';  % Disable scrolling to prevent size changes
            
            % Create sections
            createMetricDisplay(app);
            createPositionDisplay(app);
            
            % Create tab group
            app.ControlTabs = uitabgroup(app.MainLayout);
            app.ControlTabs.Layout.Row = 3;
            
            % Create expand button
            createExpandButton(app);
            
            createStatusBar(app);
        end
        
        function createMetricDisplay(app)
            % Create metric display panel
            metricPanel = uigridlayout(app.MainLayout, [1, 3]);
            metricPanel.ColumnWidth = {'fit', '1x', 'fit'};
            metricPanel.Layout.Row = 1;
            
            % Metric type dropdown
            app.MetricDisplay.TypeDropdown = uidropdown(metricPanel);
            app.MetricDisplay.TypeDropdown.Items = ZStageController.METRIC_TYPES;
            app.MetricDisplay.TypeDropdown.Value = ZStageController.DEFAULT_METRIC;
            app.MetricDisplay.TypeDropdown.FontSize = 9;
            app.MetricDisplay.TypeDropdown.ValueChangedFcn = ...
                createCallbackFcn(app, @onMetricTypeChanged, true);
            
            % Metric value label
            app.MetricDisplay.Value = uilabel(metricPanel);
            app.MetricDisplay.Value.Text = 'N/A';
            app.MetricDisplay.Value.FontSize = 12;
            app.MetricDisplay.Value.FontWeight = 'bold';
            app.MetricDisplay.Value.HorizontalAlignment = 'center';
            app.MetricDisplay.Value.BackgroundColor = app.COLORS.Light;
            
            % Refresh button
            app.MetricDisplay.RefreshButton = uibutton(metricPanel, 'push');
            app.MetricDisplay.RefreshButton.Text = '↻';
            app.MetricDisplay.RefreshButton.FontSize = 11;
            app.MetricDisplay.RefreshButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @onMetricRefreshButtonPushed, true);
        end
        
        function createPositionDisplay(app)
            % Create position display panel
            positionPanel = uigridlayout(app.MainLayout, [2, 1]);
            positionPanel.RowHeight = {'fit', 'fit'};
            positionPanel.RowSpacing = 5;
            positionPanel.Layout.Row = 2;
            
            % Position label
            app.PositionDisplay.Label = uilabel(positionPanel);
            app.PositionDisplay.Label.Text = '0.0 μm';
            app.PositionDisplay.Label.FontSize = 28;
            app.PositionDisplay.Label.FontWeight = 'bold';
            app.PositionDisplay.Label.FontName = 'Courier New';
            app.PositionDisplay.Label.HorizontalAlignment = 'center';
            app.PositionDisplay.Label.BackgroundColor = app.COLORS.Light;
            
            % Status label
            app.PositionDisplay.Status = uilabel(positionPanel);
            app.PositionDisplay.Status.Text = app.TEXT.Ready;
            app.PositionDisplay.Status.FontSize = 9;
            app.PositionDisplay.Status.HorizontalAlignment = 'center';
            app.PositionDisplay.Status.FontColor = app.COLORS.TextMuted;
        end
        
        function createExpandButton(app)
            % Create expand/collapse button
            app.MetricsPlotControls.ExpandButton = uibutton(app.MainLayout, 'push');
            app.MetricsPlotControls.ExpandButton.Layout.Row = 4;
            app.MetricsPlotControls.ExpandButton.Text = '📊 Show Plot';
            app.MetricsPlotControls.ExpandButton.FontSize = 10;
            app.MetricsPlotControls.ExpandButton.FontWeight = 'bold';
            app.MetricsPlotControls.ExpandButton.BackgroundColor = app.COLORS.Primary;
            app.MetricsPlotControls.ExpandButton.FontColor = [1 1 1];
            app.MetricsPlotControls.ExpandButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @onExpandButtonPushed, true);
        end
        
        function createStatusBar(app)
            statusBar = uigridlayout(app.MainLayout, [1, 2]);
            statusBar.ColumnWidth = {'1x', 'fit'};
            statusBar.Layout.Row = 5;
            
            % Status label
            app.StatusControls.Label = uilabel(statusBar);
            app.StatusControls.Label.Text = 'ScanImage: Initializing...';
            app.StatusControls.Label.FontSize = 9;
            
            % Refresh button
            app.StatusControls.RefreshButton = uibutton(statusBar, 'push');
            app.StatusControls.RefreshButton.Text = '↻';
            app.StatusControls.RefreshButton.FontSize = 11;
            app.StatusControls.RefreshButton.FontWeight = 'bold';
            app.StatusControls.RefreshButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @onRefreshButtonPushed, true);
        end
        
        function createManualControlTab(app)
            tab = uitab(app.ControlTabs, 'Title', 'Manual Control');
            grid = uigridlayout(tab, [2, 4]);
            
            % Configure grid layout
            grid.RowHeight = {'fit', 'fit'};
            grid.ColumnWidth = {'fit', 'fit', '1x', '1x'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 10;
            grid.ColumnSpacing = 10;
            
            % Step size controls
            label = uilabel(grid, 'Text', 'Step:', 'FontSize', 9);
            label.Layout.Row = 1;
            label.Layout.Column = 1;
            
            app.ManualControls.StepSizeDropdown = uidropdown(grid);
            app.ManualControls.StepSizeDropdown.Items = ...
                arrayfun(@(x) sprintf('%.1f μm', x), ZStageController.STEP_SIZES, 'UniformOutput', false);
            app.ManualControls.StepSizeDropdown.Value = sprintf('%.1f μm', ZStageController.DEFAULT_STEP_SIZE);
            app.ManualControls.StepSizeDropdown.FontSize = 9;
            app.ManualControls.StepSizeDropdown.Layout.Row = 1;
            app.ManualControls.StepSizeDropdown.Layout.Column = 2;
            app.ManualControls.StepSizeDropdown.ValueChangedFcn = ...
                createCallbackFcn(app, @onStepSizeChanged, true);
            
            % Movement buttons
            app.ManualControls.UpButton = createStyledButton(app, grid, ...
                'success', '▲', @onUpButtonPushed, [1, 3]);
            app.ManualControls.DownButton = createStyledButton(app, grid, ...
                'warning', '▼', @onDownButtonPushed, [1, 4]);
            
            % Zero button
            app.ManualControls.ZeroButton = createStyledButton(app, grid, ...
                'primary', 'ZERO', @onZeroButtonPushed, [2, [3 4]]);
        end
        
        function createAutoStepTab(app)
            tab = uitab(app.ControlTabs, 'Title', 'Auto Step');
            grid = uigridlayout(tab, [3, 4]);  % 3 rows, 4 columns
            
            % Configure grid layout
            grid.RowHeight = {'fit', 'fit', 'fit'};
            grid.ColumnWidth = {'fit', 'fit', '1x', '1x'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 10;
            grid.ColumnSpacing = 10;
            
            % Step size field
            label = uilabel(grid, 'Text', 'Size:', 'FontSize', 9);
            label.Layout.Row = 1;
            label.Layout.Column = 1;
            app.AutoControls.StepField = uieditfield(grid, 'numeric');
            app.AutoControls.StepField.Value = ZStageController.DEFAULT_AUTO_STEP;
            app.AutoControls.StepField.FontSize = 9;
            app.AutoControls.StepField.Layout.Row = 1;
            app.AutoControls.StepField.Layout.Column = 2;
            app.AutoControls.StepField.ValueChangedFcn = ...
                createCallbackFcn(app, @onAutoStepSizeChanged, true);
            
            % Steps field
            label = uilabel(grid, 'Text', 'Steps:', 'FontSize', 9);
            label.Layout.Row = 1;
            label.Layout.Column = 3;
            app.AutoControls.StepsField = uieditfield(grid, 'numeric');
            app.AutoControls.StepsField.Value = ZStageController.DEFAULT_AUTO_STEPS;
            app.AutoControls.StepsField.FontSize = 9;
            app.AutoControls.StepsField.Layout.Row = 1;
            app.AutoControls.StepsField.Layout.Column = 4;
            
            % Delay field
            label = uilabel(grid, 'Text', 'Delay:', 'FontSize', 9);
            label.Layout.Row = 2;
            label.Layout.Column = 1;
            app.AutoControls.DelayField = uieditfield(grid, 'numeric');
            app.AutoControls.DelayField.Value = ZStageController.DEFAULT_AUTO_DELAY;
            app.AutoControls.DelayField.FontSize = 9;
            app.AutoControls.DelayField.Layout.Row = 2;
            app.AutoControls.DelayField.Layout.Column = 2;
            
            % Record metrics checkbox
            app.AutoControls.RecordMetricsCheckbox = uicheckbox(grid);
            app.AutoControls.RecordMetricsCheckbox.Text = 'Record Metrics';
            app.AutoControls.RecordMetricsCheckbox.FontSize = 9;
            app.AutoControls.RecordMetricsCheckbox.Layout.Row = 2;
            app.AutoControls.RecordMetricsCheckbox.Layout.Column = [3 4];
            app.AutoControls.RecordMetricsCheckbox.ValueChangedFcn = ...
                createCallbackFcn(app, @onRecordMetricsChanged, true);
            
            % Direction buttons
            app.AutoControls.UpButton = createStyledButton(app, grid, ...
                'success', '▲', @onAutoDirectionChanged, [3, 1]);
            app.AutoControls.DownButton = createStyledButton(app, grid, ...
                'warning', '▼', @onAutoDirectionChanged, [3, 2]);
            
            % Initialize direction button appearance based on default direction (1)
            app.AutoControls.UpButton.BackgroundColor = app.COLORS.Success;
            app.AutoControls.DownButton.BackgroundColor = app.COLORS.Light;
            
            % Start/stop button
            app.AutoControls.StartStopButton = createStyledButton(app, grid, ...
                'success', 'START', @onStartStopButtonPushed, [3, [3 4]]);
        end
        
        function createBookmarksTab(app)
            tab = uitab(app.ControlTabs, 'Title', 'Bookmarks');
            grid = uigridlayout(tab, [3, 2]);
            
            % Configure grid layout
            grid.RowHeight = {'fit', 'fit', 'fit'};
            grid.ColumnWidth = {'1x', 'fit'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 10;
            grid.ColumnSpacing = 10;
            
            % Mark controls
            app.BookmarkControls.MarkField = uieditfield(grid, 'text');
            app.BookmarkControls.MarkField.Placeholder = 'Label...';
            app.BookmarkControls.MarkField.FontSize = 9;
            app.BookmarkControls.MarkField.Layout.Row = 1;
            app.BookmarkControls.MarkField.Layout.Column = 1;
            
            app.BookmarkControls.MarkButton = createStyledButton(app, grid, ...
                'primary', 'MARK', @onMarkButtonPushed, [1, 2]);
            
            % Position list
            app.BookmarkControls.PositionList = uilistbox(grid);
            app.BookmarkControls.PositionList.FontSize = 9;
            app.BookmarkControls.PositionList.FontName = 'Courier New';
            app.BookmarkControls.PositionList.Layout.Row = 2;
            app.BookmarkControls.PositionList.Layout.Column = [1 2];
            app.BookmarkControls.PositionList.ValueChangedFcn = ...
                createCallbackFcn(app, @onPositionListChanged, true);
            
            % Control buttons
            app.BookmarkControls.GoToButton = createStyledButton(app, grid, ...
                'success', 'GO TO', @onGoToButtonPushed, [3, 1]);
            app.BookmarkControls.GoToButton.Enable = 'off';
            
            app.BookmarkControls.DeleteButton = createStyledButton(app, grid, ...
                'danger', 'DELETE', @onDeleteButtonPushed, [3, 2]);
            app.BookmarkControls.DeleteButton.Enable = 'off';
        end
        
        function createMetricsPlotArea(app)
            % Create panel for plot area (initially hidden and positioned off-screen)
            app.MetricsPlotControls.Panel = uipanel(app.UIFigure);
            app.MetricsPlotControls.Panel.Units = 'pixels';  % Use pixels for precise control
            app.MetricsPlotControls.Panel.Position = [app.WINDOW_WIDTH + 10, 10, app.PLOT_WIDTH, app.WINDOW_HEIGHT - 20];
            app.MetricsPlotControls.Panel.Title = 'Metrics Plot';
            app.MetricsPlotControls.Panel.FontSize = 12;
            app.MetricsPlotControls.Panel.FontWeight = 'bold';
            app.MetricsPlotControls.Panel.Visible = 'off';
            app.MetricsPlotControls.Panel.AutoResizeChildren = 'off';  % Prevent automatic resizing
            
            % Create grid layout within the panel
            grid = uigridlayout(app.MetricsPlotControls.Panel, [2, 2]);
            grid.RowHeight = {'1x', 'fit'};
            grid.ColumnWidth = {'1x', 'fit'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 10;
            grid.ColumnSpacing = 10;
            
            % Create axes for the plot
            app.MetricsPlotControls.Axes = uiaxes(grid);
            app.MetricsPlotControls.Axes.Layout.Row = 1;
            app.MetricsPlotControls.Axes.Layout.Column = [1 2];
            
            % Set up the axes
            hold(app.MetricsPlotControls.Axes, 'on');
            app.MetricsPlotControls.Axes.XGrid = 'on';
            app.MetricsPlotControls.Axes.YGrid = 'on';
            xlabel(app.MetricsPlotControls.Axes, 'Z Position (μm)');
            ylabel(app.MetricsPlotControls.Axes, 'Normalized Metric Value');
            title(app.MetricsPlotControls.Axes, 'Metrics vs Z Position');
            
            % Control buttons
            app.MetricsPlotControls.ClearButton = createStyledButton(app, grid, ...
                'warning', 'CLEAR', @onClearPlotButtonPushed, [2, 1]);
            
            app.MetricsPlotControls.ExportButton = createStyledButton(app, grid, ...
                'primary', 'EXPORT', @onExportPlotButtonPushed, [2, 2]);
            
            % Initialize plot lines
            initializeMetricsPlot(app);
        end
    end
    
    %% UI Helper Methods
    methods (Access = private)
        function button = createStyledButton(app, parent, style, text, callback, position)
            button = uibutton(parent, 'push');
            button.Text = text;
            button.FontSize = 10;
            button.FontWeight = 'bold';
            button.Layout.Row = position(1);
            
            if length(position) > 1
                button.Layout.Column = position(2);
            end
            
            button.ButtonPushedFcn = createCallbackFcn(app, callback, true);
            
            % Apply style
            switch style
                case 'success'
                    button.BackgroundColor = app.COLORS.Success;
                case 'warning'
                    button.BackgroundColor = app.COLORS.Warning;
                case 'primary'
                    button.BackgroundColor = app.COLORS.Primary;
                case 'danger'
                    button.BackgroundColor = app.COLORS.Danger;
            end
            button.FontColor = [1 1 1];  % White text
        end
    end
    
    %% Auto Step Methods
    methods (Access = private)
        function startAutoStepping(app)
            if ~validateAutoStepParameters(app)
                return;
            end
            
            % Get parameters from UI
            stepSize = app.AutoControls.StepField.Value;
            numSteps = app.AutoControls.StepsField.Value;
            delay = app.AutoControls.DelayField.Value;
            direction = app.Controller.AutoDirection;
            recordMetrics = app.AutoControls.RecordMetricsCheckbox.Value;
            
            % Clear previous plot data if recording metrics
            if recordMetrics
                clearMetricsPlot(app);
            end
            
            % Start auto stepping in controller
            app.Controller.startAutoStepping(stepSize, numSteps, delay, direction, recordMetrics);
            updateAllUI(app);
        end
        
        function stopAutoStepping(app)
            app.Controller.stopAutoStepping();
            updateAllUI(app);
        end
        
        function valid = validateAutoStepParameters(app)
            valid = true;
            
            if app.AutoControls.StepField.Value <= 0
                uialert(app.UIFigure, 'Step size must be greater than 0', 'Invalid Parameter');
                valid = false;
            elseif app.AutoControls.StepsField.Value <= 0 || ...
                   mod(app.AutoControls.StepsField.Value, 1) ~= 0
                uialert(app.UIFigure, 'Number of steps must be a positive whole number', 'Invalid Parameter');
                valid = false;
            elseif app.AutoControls.DelayField.Value < 0
                uialert(app.UIFigure, 'Delay must be non-negative', 'Invalid Parameter');
                valid = false;
            end
        end
    end
    
    %% Bookmark Methods
    methods (Access = private)
        function markCurrentPosition(app, label)
            if isempty(strtrim(label))
                uialert(app.UIFigure, 'Please enter a label', 'Invalid Parameter');
                return;
            end
            
            try
                app.Controller.markCurrentPosition(label);
                updateBookmarksList(app);
            catch e
                uialert(app.UIFigure, e.message, 'Error');
            end
        end
        
        function goToMarkedPosition(app, index)
            if ~isValidBookmarkIndex(app, index) || app.Controller.IsAutoRunning
                return;
            end
            
            app.Controller.goToMarkedPosition(index);
        end
        
        function deleteMarkedPosition(app, index)
            if ~isValidBookmarkIndex(app, index)
                return;
            end
            
            app.Controller.deleteMarkedPosition(index);
            updateBookmarksList(app);
        end
        
        function valid = isValidBookmarkIndex(app, index)
            valid = index >= 1 && index <= length(app.Controller.MarkedPositions.Labels);
        end
    end
    
    %% UI Update Methods
    methods (Access = private)
        function updateAllUI(app)
            updatePositionDisplay(app);
            updateStatusDisplay(app);
            updateBookmarksList(app);
            updateControlStates(app);
            updateMetricDisplay(app);
        end
        
        function updatePositionDisplay(app)
            app.PositionDisplay.Label.Text = sprintf('%.1f μm', app.Controller.CurrentPosition);
            app.UIFigure.Name = sprintf('%s (%.1f μm)', app.TEXT.WindowTitle, app.Controller.CurrentPosition);
        end
        
        function updateStatusDisplay(app)
            if app.Controller.IsAutoRunning
                text = sprintf('Auto-stepping: %d/%d', app.Controller.CurrentStep, app.Controller.TotalSteps);
                app.PositionDisplay.Status.Text = text;
            else
                app.PositionDisplay.Status.Text = app.TEXT.Ready;
            end
            
            % Update connection status
            if app.Controller.SimulationMode
                app.StatusControls.Label.Text = ['ScanImage: Simulation (' app.Controller.StatusMessage ')'];
                app.StatusControls.Label.FontColor = app.COLORS.Warning;
            else
                app.StatusControls.Label.Text = ['ScanImage: ' app.Controller.StatusMessage];
                app.StatusControls.Label.FontColor = app.COLORS.Success;
            end
        end
        
        function updateBookmarksList(app)
            if isempty(app.Controller.MarkedPositions.Labels)
                app.BookmarkControls.PositionList.Items = {};
                app.BookmarkControls.GoToButton.Enable = 'off';
                app.BookmarkControls.DeleteButton.Enable = 'off';
                return;
            end
            
            % Format bookmark items with metrics
            items = arrayfun(@(i) sprintf('%-10s %6.1f μm %6.1f %s', ...
                app.Controller.MarkedPositions.Labels{i}, ...
                app.Controller.MarkedPositions.Positions(i), ...
                app.Controller.MarkedPositions.Metrics{i}.Value, ...
                app.Controller.MarkedPositions.Metrics{i}.Type), ...
                1:length(app.Controller.MarkedPositions.Labels), ...
                'UniformOutput', false);
            
            app.BookmarkControls.PositionList.Items = items;
            
            % Update button states
            hasSelection = ~isempty(app.BookmarkControls.PositionList.Value);
            app.BookmarkControls.GoToButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
            app.BookmarkControls.DeleteButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
        end
        
        function updateControlStates(app)
            if app.Controller.IsAutoRunning
                disableManualControls(app);
                updateAutoStepButton(app, true);
            else
                enableManualControls(app);
                updateAutoStepButton(app, false);
            end
        end
        
        function disableManualControls(app)
            app.ManualControls.UpButton.Enable = 'off';
            app.ManualControls.DownButton.Enable = 'off';
            app.ManualControls.ZeroButton.Enable = 'off';
            app.ManualControls.StepSizeDropdown.Enable = 'off';
            
            app.AutoControls.StepField.Enable = 'off';
            app.AutoControls.StepsField.Enable = 'off';
            app.AutoControls.DelayField.Enable = 'off';
            app.AutoControls.UpButton.Enable = 'off';
            app.AutoControls.DownButton.Enable = 'off';
        end
        
        function enableManualControls(app)
            app.ManualControls.UpButton.Enable = 'on';
            app.ManualControls.DownButton.Enable = 'on';
            app.ManualControls.ZeroButton.Enable = 'on';
            app.ManualControls.StepSizeDropdown.Enable = 'on';
            
            app.AutoControls.StepField.Enable = 'on';
            app.AutoControls.StepsField.Enable = 'on';
            app.AutoControls.DelayField.Enable = 'on';
            app.AutoControls.UpButton.Enable = 'on';
            app.AutoControls.DownButton.Enable = 'on';
        end
        
        function updateAutoStepButton(app, isRunning)
            if isRunning
                app.AutoControls.StartStopButton.Text = 'STOP';
                app.AutoControls.StartStopButton.BackgroundColor = app.COLORS.Danger;
            else
                app.AutoControls.StartStopButton.Text = 'START';
                app.AutoControls.StartStopButton.BackgroundColor = app.COLORS.Success;
            end
        end
    end
    
    %% Event Handlers
    methods (Access = private)
        % Manual Control Events
        function onUpButtonPushed(app, ~)
            idx = strcmp(app.ManualControls.StepSizeDropdown.Value, ...
                app.ManualControls.StepSizeDropdown.Items);
            stepSize = ZStageController.STEP_SIZES(idx);
            app.Controller.moveStage(stepSize);
        end
        
        function onDownButtonPushed(app, ~)
            idx = strcmp(app.ManualControls.StepSizeDropdown.Value, ...
                app.ManualControls.StepSizeDropdown.Items);
            stepSize = ZStageController.STEP_SIZES(idx);
            app.Controller.moveStage(-stepSize);
        end
        
        function onZeroButtonPushed(app, ~)
            app.Controller.resetPosition();
        end
        
        function onStepSizeChanged(app, event)
            stepValue = str2double(extractBefore(event.Value, ' μm'));
            app.AutoControls.StepField.Value = stepValue;
        end
        
        % Auto Step Events
        function onAutoStepSizeChanged(app, event)
            newStepSize = event.Value;
            [~, idx] = min(abs(ZStageController.STEP_SIZES - newStepSize));
            app.ManualControls.StepSizeDropdown.Value = ...
                sprintf('%.1f μm', ZStageController.STEP_SIZES(idx));
        end
        
        function onAutoDirectionChanged(app, event)
            if event.Source == app.AutoControls.UpButton
                app.Controller.AutoDirection = 1;
                app.AutoControls.UpButton.BackgroundColor = app.COLORS.Success;
                app.AutoControls.DownButton.BackgroundColor = app.COLORS.Light;
            else
                app.Controller.AutoDirection = -1;
                app.AutoControls.UpButton.BackgroundColor = app.COLORS.Light;
                app.AutoControls.DownButton.BackgroundColor = app.COLORS.Warning;
            end
        end
        
        function onStartStopButtonPushed(app, ~)
            if app.Controller.IsAutoRunning
                stopAutoStepping(app);
            else
                startAutoStepping(app);
            end
        end
        
        % Bookmark Events
        function onMarkButtonPushed(app, ~)
            label = strtrim(app.BookmarkControls.MarkField.Value);
            markCurrentPosition(app, label);
            app.BookmarkControls.MarkField.Value = '';
        end
        
        function onGoToButtonPushed(app, ~)
            selectedValue = app.BookmarkControls.PositionList.Value;
            if ~isempty(selectedValue)
                index = find(strcmp(app.BookmarkControls.PositionList.Items, selectedValue), 1);
                if ~isempty(index)
                    goToMarkedPosition(app, index);
                end
            end
        end
        
        function onDeleteButtonPushed(app, ~)
            selectedValue = app.BookmarkControls.PositionList.Value;
            if ~isempty(selectedValue)
                index = find(strcmp(app.BookmarkControls.PositionList.Items, selectedValue), 1);
                if ~isempty(index)
                    deleteMarkedPosition(app, index);
                end
            end
        end
        
        function onPositionListChanged(app, ~)
            updateBookmarksList(app);
        end
        
        % System Events
        function onRefreshButtonPushed(app, ~)
            app.Controller.connectToScanImage();
            updateAllUI(app);
        end
        
        function onWindowClose(app, ~)
            cleanup(app);
            delete(app);
        end
        
        % Metric Events
        function onMetricTypeChanged(app, event)
            app.Controller.setMetricType(event.Value);
        end
        
        function onMetricRefreshButtonPushed(app, ~)
            app.Controller.updateMetric();
        end
        
        function onRecordMetricsChanged(app, event)
            % This is handled by the UI when starting auto stepping
        end
        
        % Plot Control Events
        function onExpandButtonPushed(app, ~)
            if app.IsPlotExpanded
                collapseGUI(app);
            else
                expandGUI(app);
            end
        end
        
        function onClearPlotButtonPushed(app, ~)
            clearMetricsPlot(app);
        end
        
        function onExportPlotButtonPushed(app, ~)
            % Export the current plot data to a file
            metrics = app.Controller.getAutoStepMetrics();
            if isempty(metrics.Positions)
                uialert(app.UIFigure, 'No data to export. Run auto-stepping with "Record Metrics" enabled first.', 'No Data');
                return;
            end
            
            % Ask user for filename
            [file, path] = uiputfile('*.mat', 'Save Metrics Data');
            if file == 0
                return; % User cancelled
            end
            
            try
                % Save the metrics data
                save(fullfile(path, file), 'metrics');
                uialert(app.UIFigure, sprintf('Data exported to %s', fullfile(path, file)), 'Export Complete', 'Icon', 'success');
            catch e
                uialert(app.UIFigure, sprintf('Error exporting data: %s', e.message), 'Export Error');
            end
        end
    end
    
    %% Helper Methods
    methods (Access = private)
        function expandGUI(app)
            % Expand the GUI to show the plot
            if app.IsPlotExpanded
                return;
            end
            
            % Get current figure position
            figPos = app.UIFigure.Position;
            
            % Expand figure width
            newWidth = app.WINDOW_WIDTH + app.PLOT_WIDTH + 20; % +20 for padding
            app.UIFigure.Position = [figPos(1), figPos(2), newWidth, figPos(4)];
            
            % Position and show the plot panel
            app.MetricsPlotControls.Panel.Position = [app.WINDOW_WIDTH + 10, 10, app.PLOT_WIDTH, app.WINDOW_HEIGHT - 20];
            app.MetricsPlotControls.Panel.Visible = 'on';
            
            % Ensure main panel stays in correct position after any MATLAB adjustments
            ensureCorrectPositions(app);
            
            % Update button text and state
            app.MetricsPlotControls.ExpandButton.Text = '📊 Hide Plot';
            app.MetricsPlotControls.ExpandButton.BackgroundColor = app.COLORS.Warning;
            app.IsPlotExpanded = true;
            
            % Update window title
            app.UIFigure.Name = sprintf('%s - Plot Expanded', app.TEXT.WindowTitle);
        end
        
        function collapseGUI(app)
            % Collapse the GUI to hide the plot
            if ~app.IsPlotExpanded
                return;
            end
            
            % Hide the plot panel first
            app.MetricsPlotControls.Panel.Visible = 'off';
            
            % Get current figure position
            figPos = app.UIFigure.Position;
            
            % Collapse figure width back to original
            app.UIFigure.Position = [figPos(1), figPos(2), app.WINDOW_WIDTH, figPos(4)];
            
            % Ensure main panel stays in correct position after any MATLAB adjustments
            ensureCorrectPositions(app);
            
            % Update button text and state
            app.MetricsPlotControls.ExpandButton.Text = '📊 Show Plot';
            app.MetricsPlotControls.ExpandButton.BackgroundColor = app.COLORS.Primary;
            app.IsPlotExpanded = false;
            
            % Update window title
            app.UIFigure.Name = app.TEXT.WindowTitle;
        end
        
        function ensureCorrectPositions(app)
            % Force correct positions and handle any MATLAB automatic adjustments
            drawnow;  % Let MATLAB finish any automatic adjustments
            
            % Ensure figure units are pixels
            app.UIFigure.Units = 'pixels';
            
            % Ensure main panel is in correct position and size
            app.MainPanel.Units = 'pixels';
            app.MainPanel.Position = [0, 0, app.WINDOW_WIDTH, app.WINDOW_HEIGHT];
            
            % If expanded, ensure plot panel is in correct position
            if app.IsPlotExpanded
                app.MetricsPlotControls.Panel.Units = 'pixels';
                app.MetricsPlotControls.Panel.Position = [app.WINDOW_WIDTH + 10, 10, app.PLOT_WIDTH, app.WINDOW_HEIGHT - 20];
            end
            
            % Force the main layout grid to fit within the main panel
            % This prevents the grid from expanding beyond the panel boundaries
            if isvalid(app.MainLayout)
                % GridLayout should fill the entire panel but no more
                app.MainLayout.Padding = [10 10 10 10];
                app.MainLayout.RowSpacing = 10;
            end
            
            % Use a short timer to double-check positions after MATLAB settles
            t = timer('ExecutionMode', 'singleShot', 'StartDelay', 0.1, ...
                'TimerFcn', @(~,~) finalPositionCheck(app));
            start(t);
        end
        
        function finalPositionCheck(app)
            % Final check to ensure positions are correct
            if isvalid(app.MainPanel)
                app.MainPanel.Units = 'pixels';
                app.MainPanel.Position = [0, 0, app.WINDOW_WIDTH, app.WINDOW_HEIGHT];
            end
            
            if app.IsPlotExpanded && isvalid(app.MetricsPlotControls.Panel)
                app.MetricsPlotControls.Panel.Units = 'pixels';
                app.MetricsPlotControls.Panel.Position = [app.WINDOW_WIDTH + 10, 10, app.PLOT_WIDTH, app.WINDOW_HEIGHT - 20];
            end
            
            % Double-check that the main layout grid hasn't expanded
            if isvalid(app.MainLayout)
                % Ensure grid layout properties haven't changed
                app.MainLayout.RowHeight = {'fit', 'fit', '1x', 'fit', 'fit'};
                app.MainLayout.ColumnWidth = {'1x'};
                app.MainLayout.Padding = [10 10 10 10];
                app.MainLayout.RowSpacing = 10;
            end
        end
        
        function stopTimer(app, timer)
            if ~isempty(timer) && isvalid(timer)
                stop(timer);
                delete(timer);
            end
        end
        
        function cleanup(app)
            % Clean up controller
            if ~isempty(app.Controller) && isvalid(app.Controller)
                delete(app.Controller);
            end
            
            % Stop timers
            stopTimer(app, app.RefreshTimer);
            app.RefreshTimer = [];
            
            stopTimer(app, app.MetricTimer);
            app.MetricTimer = [];
            
            % Clean up any other timers
            allTimers = timerfindall;
            for timer = allTimers'
                if isvalid(timer)
                    stop(timer);
                    delete(timer);
                end
            end
            
            % Clear metrics plot lines
            app.MetricsPlotLines = {};
            
            % Clean up panels
            if ~isempty(app.MainPanel) && isvalid(app.MainPanel)
                delete(app.MainPanel);
            end
            if ~isempty(app.MetricsPlotControls.Panel) && isvalid(app.MetricsPlotControls.Panel)
                delete(app.MetricsPlotControls.Panel);
            end
        end
    end
end