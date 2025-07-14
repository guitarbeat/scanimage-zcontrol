classdef UiBuilder < handle
    % Builds the user interface for the FoilView application.
    % This class creates all the UI components and lays them out in the main window.

    methods (Static)
        function components = build(app)
            % Static entry point to construct and return all UI components as a struct.
            creator = UiBuilder();
            components = struct();

            [components.UIFigure, components.MainPanel, components.MainLayout] = ...
                creator.createMainWindow(app);

            components.PositionDisplay = creator.createPositionDisplay(components.MainLayout);
            components.MetricDisplay = creator.createMetricDisplay(components.MainLayout);
            components.StatusControls = creator.createStatusBar(components.MainLayout);
            components.ManualControls = creator.createManualControlContainer(components.MainLayout, app);
            components.AutoControls = creator.createAutoStepContainer(components.MainLayout, app);
            components.MetricsPlotControls = creator.createMetricsPlotArea(components.UIFigure, app);
            components.MetricsPlotControls.ExpandButton = creator.createExpandButton(components.MainLayout, app);

            components.UIFigure.Visible = 'on';
        end
    end

    methods (Access = private)
        function [uiFigure, mainPanel, mainLayout] = createMainWindow(~, app)
            % Creates the main figure window, panel, and grid layout.
            uiFigure = uifigure('Visible', 'off');
            uiFigure.Units = 'pixels';
            uiFigure.Position = [100 100 UiComponents.DEFAULT_WINDOW_WIDTH UiComponents.DEFAULT_WINDOW_HEIGHT];
            uiFigure.Name = UiComponents.TEXT.WindowTitle;
            uiFigure.Color = UiComponents.COLORS.Background;
            uiFigure.Resize = 'on';
            uiFigure.AutoResizeChildren = 'on';
            uiFigure.WindowState = 'normal';

            mainPanel = uipanel(uiFigure);
            mainPanel.Units = 'normalized';
            mainPanel.Position = [0, 0, 1, 1];
            mainPanel.BorderType = 'none';
            mainPanel.BackgroundColor = UiComponents.COLORS.Background;
            mainPanel.AutoResizeChildren = 'on';

            mainLayout = uigridlayout(mainPanel, [6, 1]);
            mainLayout.RowHeight = {'fit', '1x', 'fit', 'fit', 'fit', 'fit'};
            mainLayout.ColumnWidth = {'1x'};
            mainLayout.Padding = [8 8 8 8];
            mainLayout.RowSpacing = 6;
            mainLayout.Scrollable = 'on';
        end

        function metricDisplay = createMetricDisplay(~, mainLayout)
            % Creates the metric display section with dropdown, value label, and refresh button.
            metricPanel = uigridlayout(mainLayout, [1, 3]);
            metricPanel.ColumnWidth = {'fit', '1x', 'fit'};
            metricPanel.Layout.Row = 1;

            metricDisplay = struct();

            metricDisplay.TypeDropdown = uidropdown(metricPanel);
            metricDisplay.TypeDropdown.Items = {'Std Dev', 'Mean', 'Max'};
            metricDisplay.TypeDropdown.Value = 'Std Dev';
            metricDisplay.TypeDropdown.FontSize = 9;

            metricDisplay.Value = uilabel(metricPanel);
            metricDisplay.Value.Text = 'N/A';
            metricDisplay.Value.FontSize = 12;
            metricDisplay.Value.FontWeight = 'bold';
            metricDisplay.Value.HorizontalAlignment = 'center';
            metricDisplay.Value.BackgroundColor = UiComponents.COLORS.Light;

            metricDisplay.RefreshButton = uibutton(metricPanel, 'push');
            metricDisplay.RefreshButton.Text = '↻';
            metricDisplay.RefreshButton.FontSize = 11;
        end

        function positionDisplay = createPositionDisplay(~, mainLayout)
            % Creates the position display with label and status.
            positionPanel = uigridlayout(mainLayout, [2, 1]);
            positionPanel.RowHeight = {'fit', 'fit'};
            positionPanel.RowSpacing = 5;
            positionPanel.Layout.Row = 2;

            positionDisplay = struct();

            positionDisplay.Label = uilabel(positionPanel);
            positionDisplay.Label.Text = '0.0 μm';
            positionDisplay.Label.FontSize = 28;
            positionDisplay.Label.FontWeight = 'bold';
            positionDisplay.Label.FontName = 'Courier New';
            positionDisplay.Label.HorizontalAlignment = 'center';
            positionDisplay.Label.BackgroundColor = UiComponents.COLORS.Light;

            positionDisplay.Status = uilabel(positionPanel);
            positionDisplay.Status.Text = UiComponents.TEXT.Ready;
            positionDisplay.Status.FontSize = 9;
            positionDisplay.Status.HorizontalAlignment = 'center';
            positionDisplay.Status.FontColor = UiComponents.COLORS.TextMuted;
        end

        function expandButton = createExpandButton(~, mainLayout, ~)
            % Creates the button to expand/show the metrics plot.
            expandButton = uibutton(mainLayout, 'push');
            expandButton.Layout.Row = 5;
            expandButton.Text = '📊 Show Plot';
            expandButton.FontSize = 10;
            expandButton.FontWeight = 'bold';
            expandButton.BackgroundColor = UiComponents.COLORS.Primary;
            expandButton.FontColor = [1 1 1];
        end

        function statusControls = createStatusBar(~, mainLayout)
            % Creates the status bar with label and control buttons.
            statusBar = uigridlayout(mainLayout, [1, 6]);  % Fixed: Expanded to 6 columns for MotorRecoveryButton
            statusBar.ColumnWidth = {'1x', 'fit', 'fit', 'fit', 'fit', 'fit'};
            statusBar.Layout.Row = 6;

            statusControls = struct();

            statusControls.Label = uilabel(statusBar);
            statusControls.Label.Text = 'ScanImage: Initializing...';
            statusControls.Label.FontSize = 9;

            statusControls.BookmarksButton = uibutton(statusBar, 'push');
            statusControls.BookmarksButton.Text = '📌';
            statusControls.BookmarksButton.FontSize = 11;
            statusControls.BookmarksButton.FontWeight = 'bold';
            statusControls.BookmarksButton.Tooltip = 'Toggle Bookmarks Window (Open/Close)';
            statusControls.BookmarksButton.BackgroundColor = UiComponents.COLORS.Primary;
            statusControls.BookmarksButton.FontColor = [1 1 1];

            statusControls.StageViewButton = uibutton(statusBar, 'push');
            statusControls.StageViewButton.Text = '📹';
            statusControls.StageViewButton.FontSize = 11;
            statusControls.StageViewButton.FontWeight = 'bold';
            statusControls.StageViewButton.Tooltip = 'Toggle Stage View Camera Window (Open/Close)';
            statusControls.StageViewButton.BackgroundColor = UiComponents.COLORS.Primary;
            statusControls.StageViewButton.FontColor = [1 1 1];

            statusControls.RefreshButton = uibutton(statusBar, 'push');
            statusControls.RefreshButton.Text = '↻';
            statusControls.RefreshButton.FontSize = 11;
            statusControls.RefreshButton.FontWeight = 'bold';

            statusControls.MetadataButton = uibutton(statusBar, 'push');
            statusControls.MetadataButton.Text = '📝';
            statusControls.MetadataButton.FontSize = 11;
            statusControls.MetadataButton.FontWeight = 'bold';
            statusControls.MetadataButton.Tooltip = 'Initialize Metadata Logging';
            statusControls.MetadataButton.BackgroundColor = UiComponents.COLORS.Primary;
            statusControls.MetadataButton.FontColor = [1 1 1];

            statusControls.MotorRecoveryButton = uibutton(statusBar, 'push');
            statusControls.MotorRecoveryButton.Text = '🔧';
            statusControls.MotorRecoveryButton.FontSize = 11;
            statusControls.MotorRecoveryButton.FontWeight = 'bold';
            statusControls.MotorRecoveryButton.Tooltip = 'Recover from Motor Error';
            statusControls.MotorRecoveryButton.BackgroundColor = [0.9 0.6 0.2];  % Warning color
            statusControls.MotorRecoveryButton.FontColor = [1 1 1];
        end

        function manualControls = createManualControlContainer(obj, mainLayout, ~)
            % Creates the manual control panel with buttons and step size controls.
            manualPanel = uipanel(mainLayout);
            manualPanel.Title = 'Manual Control';
            manualPanel.FontSize = 9;
            manualPanel.FontWeight = 'bold';
            manualPanel.Layout.Row = 3;

            grid = uigridlayout(manualPanel, [1, 6]);
            grid.RowHeight = {'fit'};
            grid.ColumnWidth = {'1x', '1x', '2x', '1x', '1x', '2x'};
            grid.Padding = [6 4 6 4];
            grid.ColumnSpacing = 4;

            manualControls = struct();

            manualControls.UpButton = obj.createStyledButton(grid, 'success', '▲', [], [1, 1]);

            % Standardized: Use createStyledButton for step buttons with muted style
            manualControls.StepDownButton = obj.createStyledButton(grid, 'muted', '◄', 'Decrease step size', [1, 2]);

            stepSizePanel = uipanel(grid);
            stepSizePanel.Layout.Row = 1;
            stepSizePanel.Layout.Column = 3;
            stepSizePanel.BorderType = 'line';
            stepSizePanel.BackgroundColor = UiComponents.COLORS.Light;
            stepSizePanel.BorderWidth = 1;
            stepSizePanel.HighlightColor = [0.8 0.8 0.8];

            stepSizeGrid = uigridlayout(stepSizePanel, [1, 1]);
            stepSizeGrid.Padding = [4 2 4 2];

            manualControls.StepSizeDisplay = uilabel(stepSizeGrid);
            manualControls.StepSizeDisplay.Text = '1.0μm';
            manualControls.StepSizeDisplay.FontSize = 9;
            manualControls.StepSizeDisplay.FontWeight = 'bold';
            manualControls.StepSizeDisplay.FontColor = [0.2 0.2 0.2];
            manualControls.StepSizeDisplay.HorizontalAlignment = 'center';

            manualControls.StepUpButton = obj.createStyledButton(grid, 'muted', '►', 'Increase step size', [1, 4]);

            manualControls.DownButton = obj.createStyledButton(grid, 'warning', '▼', [], [1, 5]);
            manualControls.ZeroButton = obj.createStyledButton(grid, 'primary', 'ZERO', [], [1, 6]);

            % Fixed: Placed hidden dropdown in column 3 (overlaps stepSizePanel if needed, but visible='off')
            manualControls.StepSizeDropdown = uidropdown(grid);
            manualControls.StepSizeDropdown.Items = FoilviewUtils.formatStepSizeItems(FoilviewController.STEP_SIZES);
            manualControls.StepSizeDropdown.Value = FoilviewUtils.formatPosition(FoilviewController.DEFAULT_STEP_SIZE);
            manualControls.StepSizeDropdown.Layout.Row = 1;
            manualControls.StepSizeDropdown.Layout.Column = 3;
            manualControls.StepSizeDropdown.Visible = 'off';

            manualControls.StepSizes = FoilviewController.STEP_SIZES;
            manualControls.CurrentStepIndex = find(manualControls.StepSizes == FoilviewController.DEFAULT_STEP_SIZE, 1);
        end

        function autoControls = createAutoStepContainer(obj, mainLayout, ~)
            % Creates the auto step control panel with fields, switch, and status.
            autoPanel = uipanel(mainLayout);
            autoPanel.Title = 'Auto Step';
            autoPanel.FontSize = 9;
            autoPanel.FontWeight = 'bold';
            autoPanel.Layout.Row = 4;

            grid = uigridlayout(autoPanel, [2, 5]);
            grid.RowHeight = {'fit', 'fit'};
            grid.ColumnWidth = {'2x', '1x', '1x', '1x', '1x'};
            grid.Padding = [8 6 8 8];
            grid.RowSpacing = 6;
            grid.ColumnSpacing = 8;

            autoControls = struct();

            autoControls.StartStopButton = obj.createStyledButton(grid, 'success', 'START ▲', [], [1, 1]);

            autoControls.StepField = uieditfield(grid, 'numeric');
            autoControls.StepField.Value = FoilviewController.DEFAULT_AUTO_STEP;
            autoControls.StepField.FontSize = 10;
            autoControls.StepField.Layout.Row = 1;
            autoControls.StepField.Layout.Column = 2;
            autoControls.StepField.Tooltip = 'Step size (μm)';

            autoControls.StepsField = uieditfield(grid, 'numeric');
            autoControls.StepsField.Value = FoilviewController.DEFAULT_AUTO_STEPS;
            autoControls.StepsField.FontSize = 10;
            autoControls.StepsField.Layout.Row = 1;
            autoControls.StepsField.Layout.Column = 3;
            autoControls.StepsField.Tooltip = 'Number of steps';

            autoControls.DelayField = uieditfield(grid, 'numeric');
            autoControls.DelayField.Value = FoilviewController.DEFAULT_AUTO_DELAY;
            autoControls.DelayField.FontSize = 10;
            autoControls.DelayField.Layout.Row = 1;
            autoControls.DelayField.Layout.Column = 4;
            autoControls.DelayField.Tooltip = 'Delay between steps (seconds)';

            % Direction toggle switch
            directionPanel = uipanel(grid);
            directionPanel.Layout.Row = 1;
            directionPanel.Layout.Column = 5;
            directionPanel.BorderType = 'none';
            directionPanel.BackgroundColor = UiComponents.COLORS.Background;

            directionGrid = uigridlayout(directionPanel, [2, 1]);
            directionGrid.RowHeight = {'fit', 'fit'};
            directionGrid.Padding = [2 2 2 2];
            directionGrid.RowSpacing = 2;

            directionLabel = uilabel(directionGrid);
            directionLabel.Text = 'Direction';
            directionLabel.FontSize = 9;
            directionLabel.FontWeight = 'bold';
            directionLabel.HorizontalAlignment = 'center';

            autoControls.DirectionSwitch = uiswitch(directionGrid, 'toggle');
            autoControls.DirectionSwitch.Items = {'Down', 'Up'};
            autoControls.DirectionSwitch.Value = 'Up';
            autoControls.DirectionSwitch.FontSize = 9;
            autoControls.DirectionSwitch.Tooltip = 'Toggle direction (Up/Down)';

            % Hidden direction button (alternative UI?)
            autoControls.DirectionButton = obj.createStyledButton(grid, 'success', '▲', 'Toggle direction (Up/Down)', [2, 4]);
            autoControls.DirectionButton.Visible = 'off';

            statusGrid = uigridlayout(grid, [1, 3]);
            statusGrid.Layout.Row = 2;
            statusGrid.Layout.Column = [1 4];
            statusGrid.ColumnWidth = {'fit', '1x', 'fit'};
            statusGrid.Padding = [0 0 0 0];
            statusGrid.ColumnSpacing = 4;

            statusLabel = uilabel(statusGrid);
            statusLabel.Text = 'Ready:';
            statusLabel.FontSize = 10;
            statusLabel.FontWeight = 'bold';
            statusLabel.FontColor = [0.3 0.3 0.3];

            autoControls.StatusDisplay = uilabel(statusGrid);
            autoControls.StatusDisplay.Text = '100.0 μm upward (5.0s)';
            autoControls.StatusDisplay.FontSize = 10;
            autoControls.StatusDisplay.FontColor = [0.4 0.4 0.4];

            unitsLabel = uilabel(statusGrid);
            unitsLabel.Text = 'μm × steps @ s';
            unitsLabel.FontSize = 9;
            unitsLabel.FontColor = [0.6 0.6 0.6];
        end

        function metricsPlotControls = createMetricsPlotArea(~, uiFigure, ~)
            % Creates the metrics plot panel with axes and buttons (initially hidden).
            metricsPlotControls = struct();

            metricsPlotControls.Panel = uipanel(uiFigure);
            metricsPlotControls.Panel.Units = 'pixels';
            metricsPlotControls.Panel.Position = [UiComponents.DEFAULT_WINDOW_WIDTH + 10, 10, UiComponents.PLOT_WIDTH, UiComponents.DEFAULT_WINDOW_HEIGHT - 20];
            metricsPlotControls.Panel.Title = 'Metrics Plot';
            metricsPlotControls.Panel.FontSize = 12;
            metricsPlotControls.Panel.FontWeight = 'bold';
            metricsPlotControls.Panel.Visible = 'off';
            metricsPlotControls.Panel.AutoResizeChildren = 'on';

            grid = uigridlayout(metricsPlotControls.Panel, [2, 2]);
            grid.RowHeight = {'1x', 'fit'};
            grid.ColumnWidth = {'1x', 'fit'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 10;
            grid.ColumnSpacing = 10;

            metricsPlotControls.Axes = uiaxes(grid);
            metricsPlotControls.Axes.Layout.Row = 1;
            metricsPlotControls.Axes.Layout.Column = [1 2];
            hold(metricsPlotControls.Axes, 'on');
            metricsPlotControls.Axes.XGrid = 'on';
            metricsPlotControls.Axes.YGrid = 'on';
            xlabel(metricsPlotControls.Axes, 'Z Position (μm)');
            ylabel(metricsPlotControls.Axes, 'Normalized Metric Value');
            title(metricsPlotControls.Axes, 'Metrics vs Z Position');

            metricsPlotControls.ClearButton = createStyledButton(grid, 'warning', 'CLEAR', [], [2, 1]);
            metricsPlotControls.ExportButton = createStyledButton(grid, 'primary', 'EXPORT', [], [2, 2]);
        end

        function button = createStyledButton(~, parent, style, text, tooltip, layoutPosition)
            % Helper to create and style a button consistently.
            button = uibutton(parent, 'push');
            button.Text = text;
            button.FontSize = 11;  % Default font size, override in apply if needed
            button.FontWeight = 'bold';

            if ~isempty(tooltip)
                button.Tooltip = tooltip;
            end

            if ~isempty(layoutPosition)
                button.Layout.Row = layoutPosition(1);
                button.Layout.Column = layoutPosition(2);
            end

            % Assume UiComponents.applyButtonStyle handles style-specific properties
            % Added 'muted' style handling if not present (e.g., in UiComponents)
            if strcmp(style, 'muted')
                button.BackgroundColor = UiComponents.COLORS.TextMuted;
                button.FontColor = [1 1 1];
            else
                UiComponents.applyButtonStyle(button, style, text);
            end
        end
    end
end