classdef ZStageControlApp < matlab.apps.AppBase
    % ZStageControlApp - Streamlined Z-stage positioning control interface
    % Provides manual and automatic z control, and position bookmarking
    
    %% Constants
    properties (Constant, Access = private)
        % Window Configuration
        WINDOW_WIDTH = 320
        WINDOW_HEIGHT = 380  % Increased height to accommodate metric display
        
        % UI Theme Colors
        COLORS = struct(...
            'Background', [0.95 0.95 0.95], ...
            'Primary', [0.2 0.6 0.9], ...
            'Success', [0.2 0.7 0.3], ...
            'Warning', [0.9 0.6 0.2], ...
            'Danger', [0.9 0.3 0.3], ...
            'Light', [0.98 0.98 0.98], ...
            'TextMuted', [0.5 0.5 0.5])
        
        % UI Text
        TEXT = struct(...
            'WindowTitle', 'Z-Stage Control', ...
            'Ready', 'Ready')
    end
    
    %% Public Properties - UI Components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
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
    end
    
    %% Private Properties - Application State
    properties (Access = private)
        % Core Controller
        Controller                  ZStageController
        
        % UI State
        MetricsPlotFigure
        MetricsPlotAxes
        MetricsPlotLines = {}
        
        % Timers
        RefreshTimer
        MetricTimer
    end
    
    %% Constructor and Destructor
    methods (Access = public)
        function app = ZStageControlApp()
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
            % If metrics were recorded, show a plot
            if app.Controller.RecordMetrics
                metrics = app.Controller.getAutoStepMetrics();
                if ~isempty(metrics.Positions)
                    updateMetricsPlot(app);
                    % Bring figure to front
                    if ~isempty(app.MetricsPlotFigure) && isvalid(app.MetricsPlotFigure)
                        figure(app.MetricsPlotFigure);
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
            % Create a figure to display the metrics
            app.MetricsPlotFigure = figure('Name', 'Metrics vs Z Position', ...
                'NumberTitle', 'off', ...
                'Position', [100, 100, 800, 500], ...
                'DeleteFcn', @(src,~) onMetricsPlotClosed(app));
            
            % Create axes
            app.MetricsPlotAxes = axes(app.MetricsPlotFigure);
            hold(app.MetricsPlotAxes, 'on');
            grid(app.MetricsPlotAxes, 'on');
            xlabel(app.MetricsPlotAxes, 'Z Position (μm)');
            ylabel(app.MetricsPlotAxes, 'Metric Value');
            title(app.MetricsPlotAxes, 'Metrics vs Z Position');
            
            % Set initial axis limits to prevent errors
            xlim(app.MetricsPlotAxes, [0, 1]);
            ylim(app.MetricsPlotAxes, [0, 1]);
            
            % Create a legend
            legend(app.MetricsPlotAxes, 'Location', 'eastoutside', 'Interpreter', 'none');
            
            % Initialize empty plot lines with different colors and markers
            colors = {'#0072BD', '#D95319', '#EDB120', '#7E2F8E', '#77AC30', '#4DBEEE', '#A2142F'};
            markers = {'o', 's', 'd', '^', 'v', '>', '<'};
            app.MetricsPlotLines = {};
            
            for i = 1:length(ZStageController.METRIC_TYPES)
                metricType = ZStageController.METRIC_TYPES{i};
                colorIdx = mod(i-1, length(colors)) + 1;
                markerIdx = mod(i-1, length(markers)) + 1;
                app.MetricsPlotLines{i} = plot(app.MetricsPlotAxes, NaN, NaN, ...
                    'Color', colors{colorIdx}, ...
                    'Marker', markers{markerIdx}, ...
                    'LineStyle', '-', ...
                    'LineWidth', 2, ...
                    'MarkerSize', 6, ...
                    'DisplayName', metricType);
            end
            
            % Set figure properties for better visualization
            set(app.MetricsPlotFigure, 'Color', 'white');
            set(app.MetricsPlotAxes, 'Box', 'on', 'TickDir', 'out', 'LineWidth', 1);
            
            % Force initial draw
            drawnow;
        end
        

        function onMetricsPlotClosed(app)
            % Handle the case when the user closes the metrics plot window
            app.MetricsPlotFigure = [];
            app.MetricsPlotAxes = [];
            app.MetricsPlotLines = {};
        end
        
        function updateMetricsPlot(app)
            % If figure doesn't exist, create it
            if isempty(app.MetricsPlotFigure) || ~isvalid(app.MetricsPlotFigure)
                initializeMetricsPlot(app);
            end
            
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
                        xlim(app.MetricsPlotAxes, [xMin - xPadding, xMax + xPadding]);
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
                            ylim(app.MetricsPlotAxes, [yMin - yPadding, yMax + yPadding]);
                        end
                    end
                    
                    % Update the figure title to show the Z range and normalization info
                    title(app.MetricsPlotAxes, sprintf('Normalized Metrics vs Z Position (%.1f - %.1f μm)', ...
                        xMin, xMax));
                end
                
                % Update y-axis label to indicate normalization
                ylabel(app.MetricsPlotAxes, 'Normalized Metric Value (relative to first value)');
                
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
            
            app.UIFigure.Visible = 'on';
        end
        
        function createMainWindow(app)
            % Create main figure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 app.WINDOW_WIDTH app.WINDOW_HEIGHT];
            app.UIFigure.Name = app.TEXT.WindowTitle;
            app.UIFigure.Color = app.COLORS.Background;
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @onWindowClose, true);
            app.UIFigure.Resize = 'on';
            
            % Create main layout
            app.MainLayout = uigridlayout(app.UIFigure, [4, 1]);
            app.MainLayout.RowHeight = {'fit', 'fit', '1x', 'fit'};
            app.MainLayout.ColumnWidth = {'1x'};
            app.MainLayout.Padding = [10 10 10 10];
            app.MainLayout.RowSpacing = 10;
            
            % Create sections
            createMetricDisplay(app);
            createPositionDisplay(app);
            
            % Create tab group
            app.ControlTabs = uitabgroup(app.MainLayout);
            app.ControlTabs.Layout.Row = 3;
            
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
        

        
        function createStatusBar(app)
            statusBar = uigridlayout(app.MainLayout, [1, 2]);
            statusBar.ColumnWidth = {'1x', 'fit'};
            statusBar.Layout.Row = 4;
            
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
            
            % Initialize metrics plot if recording
            if recordMetrics
                if isempty(app.MetricsPlotFigure) || ~isvalid(app.MetricsPlotFigure)
                    initializeMetricsPlot(app);
                end
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
    end
    
    %% Helper Methods
    methods (Access = private)
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
            
            % Clean up metrics plot
            if ~isempty(app.MetricsPlotFigure) && isvalid(app.MetricsPlotFigure)
                delete(app.MetricsPlotFigure);
                app.MetricsPlotFigure = [];
            end
        end
    end
end