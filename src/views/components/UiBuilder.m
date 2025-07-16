classdef UiBuilder
    % Builds the user interface for the FoilView application.
    % This class creates all the UI components and lays them out in the main window.

    methods (Static)
        function components = build()
            % Static entry point to construct and return all UI components as a struct.
            components = struct();

            [components.UIFigure, components.MainPanel, components.MainLayout] = ...
                UiBuilder.createMainWindow();

            components.PositionDisplay = UiBuilder.createPositionDisplay(components.MainLayout);
            components.MetricDisplay = UiBuilder.createMetricDisplay(components.MainLayout);
            components.StatusControls = UiBuilder.createStatusBar(components.MainLayout);
            components.ManualControls = UiBuilder.createManualControlContainer(components.MainLayout);
            components.AutoControls = UiBuilder.createAutoStepContainer(components.MainLayout);
            components.MetricsPlotControls = UiBuilder.createMetricsPlotArea(components.UIFigure);
            components.MetricsPlotControls.ExpandButton = UiBuilder.createExpandButton(components.MainLayout);

            components.UIFigure.Visible = 'on';
        end
    end

    methods (Static, Access = private)
        function [uiFigure, mainPanel, mainLayout] = createMainWindow()
            % Creates the main figure window, panel, and grid layout with modern styling.
            uiFigure = uifigure('Visible', 'off');
            uiFigure.Units = 'pixels';
            uiFigure.Position = [100 100 UiComponents.DEFAULT_WINDOW_WIDTH UiComponents.DEFAULT_WINDOW_HEIGHT];
            uiFigure.Name = UiComponents.TEXT.WindowTitle;
            uiFigure.Color = UiComponents.COLORS.Background;
            uiFigure.Resize = 'on';
            uiFigure.AutoResizeChildren = 'off';  % Turn off to enable SizeChangedFcn
            uiFigure.WindowState = 'normal';
            % Remove minimum size constraints to allow more flexibility
            uiFigure.WindowStyle = 'normal';

            mainPanel = uipanel(uiFigure);
            mainPanel.Units = 'normalized';
            mainPanel.Position = [0, 0, 1, 1];
            mainPanel.BorderType = 'none';
            mainPanel.BackgroundColor = UiComponents.COLORS.Background;
            mainPanel.AutoResizeChildren = 'on';

            mainLayout = uigridlayout(mainPanel, [6, 1]);
            mainLayout.RowHeight = {'fit', '2x', 'fit', '1x', 'fit', 'fit'};
            mainLayout.ColumnWidth = {'1x'};
            mainLayout.Padding = [8 8 8 8];
            mainLayout.RowSpacing = 6;
            mainLayout.Scrollable = 'on';
        end

        function metricDisplay = createMetricDisplay(mainLayout)
            % Creates the metric display section with modern card styling.
            metricCard = uipanel(mainLayout);
            metricCard.Layout.Row = 1;
            metricCard.BorderType = 'line';
            metricCard.BorderWidth = 1;
            metricCard.BorderColor = UiComponents.COLORS.Border;
            metricCard.BackgroundColor = UiComponents.COLORS.Card;
            metricCard.Title = 'Image Metrics';
            metricCard.FontSize = 10;
            metricCard.FontWeight = 'bold';
            
            metricPanel = uigridlayout(metricCard, [1, 3]);
            metricPanel.ColumnWidth = {'fit', '1x', 'fit'};
            metricPanel.Padding = [8 8 8 8];
            metricPanel.ColumnSpacing = 8;

            metricDisplay = struct();

            metricDisplay.TypeDropdown = uidropdown(metricPanel);
            metricDisplay.TypeDropdown.Items = {'Std Dev', 'Mean', 'Max'};
            metricDisplay.TypeDropdown.Value = 'Std Dev';
            metricDisplay.TypeDropdown.FontSize = 10;
            metricDisplay.TypeDropdown.BackgroundColor = UiComponents.COLORS.Light;

            metricDisplay.Value = uilabel(metricPanel);
            metricDisplay.Value.Text = 'N/A';
            metricDisplay.Value.FontSize = 14;
            metricDisplay.Value.FontWeight = 'bold';
            metricDisplay.Value.HorizontalAlignment = 'center';
            metricDisplay.Value.BackgroundColor = UiComponents.COLORS.Light;
            metricDisplay.Value.FontColor = UiComponents.COLORS.Primary;

            metricDisplay.RefreshButton = uibutton(metricPanel, 'push');
            metricDisplay.RefreshButton.Text = '🔄';
            metricDisplay.RefreshButton.FontSize = 12;
            metricDisplay.RefreshButton.BackgroundColor = UiComponents.COLORS.Info;
            metricDisplay.RefreshButton.FontColor = [1 1 1];
            metricDisplay.RefreshButton.Tooltip = 'Refresh metric calculation';
        end

        function positionDisplay = createPositionDisplay(mainLayout)
            % Creates the position display with modern card styling and enhanced visual hierarchy.
            positionCard = uipanel(mainLayout);
            positionCard.Layout.Row = 2;
            positionCard.BorderType = 'line';
            positionCard.BorderWidth = 2;
            positionCard.BorderColor = UiComponents.COLORS.Primary;
            positionCard.BackgroundColor = UiComponents.COLORS.Card;
            positionCard.Title = 'Current Position';
            positionCard.FontSize = 11;
            positionCard.FontWeight = 'bold';
            positionCard.TitlePosition = 'centertop';
            
            positionPanel = uigridlayout(positionCard, [2, 1]);
            positionPanel.RowHeight = {'1x', 'fit'};
            positionPanel.RowSpacing = 8;
            positionPanel.Padding = [12 12 12 12];

            positionDisplay = struct();

            positionDisplay.Label = uilabel(positionPanel);
            positionDisplay.Label.Text = '0.0 μm';
            positionDisplay.Label.FontSize = 32;
            positionDisplay.Label.FontWeight = 'bold';
            positionDisplay.Label.FontName = 'Consolas';
            positionDisplay.Label.HorizontalAlignment = 'center';
            positionDisplay.Label.BackgroundColor = UiComponents.COLORS.Light;
            positionDisplay.Label.FontColor = UiComponents.COLORS.Primary;

            positionDisplay.Status = uilabel(positionPanel);
            positionDisplay.Status.Text = UiComponents.TEXT.Ready;
            positionDisplay.Status.FontSize = 11;
            positionDisplay.Status.HorizontalAlignment = 'center';
            positionDisplay.Status.FontColor = UiComponents.COLORS.TextMuted;
            positionDisplay.Status.FontWeight = 'bold';
        end

        function expandButton = createExpandButton(mainLayout)
            % Creates the button to expand/show the metrics plot.
            expandButton = uibutton(mainLayout, 'push');
            expandButton.Layout.Row = 5;
            expandButton.Text = '📊 Show Plot';
            expandButton.FontSize = 10;
            expandButton.FontWeight = 'bold';
            expandButton.BackgroundColor = UiComponents.COLORS.Primary;
            expandButton.FontColor = [1 1 1];
        end

        function statusControls = createStatusBar(mainLayout)
            % Creates the status bar with modern card styling and enhanced button layout.
            statusCard = uipanel(mainLayout);
            statusCard.Layout.Row = 6;
            statusCard.BorderType = 'line';
            statusCard.BorderWidth = 1;
            statusCard.BorderColor = UiComponents.COLORS.Border;
            statusCard.BackgroundColor = UiComponents.COLORS.Card;
            statusCard.Title = '🔧 System Status & Tools';
            statusCard.FontSize = 10;
            statusCard.FontWeight = 'bold';
            
            statusBar = uigridlayout(statusCard, [1, 6]);
            statusBar.ColumnWidth = {'1x', 40, 40, 40, 40, 40};
            statusBar.Padding = [8 8 8 8];
            statusBar.ColumnSpacing = 4;

            statusControls = struct();

            statusControls.Label = uilabel(statusBar);
            statusControls.Label.Text = 'ScanImage: Initializing...';
            statusControls.Label.FontSize = 10;
            statusControls.Label.FontWeight = 'bold';

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

        function manualControls = createManualControlContainer(mainLayout)
            % Creates the manual control panel with modern card styling and improved layout.
            manualCard = uipanel(mainLayout);
            manualCard.Title = '🎮 Manual Control';
            manualCard.FontSize = 11;
            manualCard.FontWeight = 'bold';
            manualCard.Layout.Row = 3;
            manualCard.BorderType = 'line';
            manualCard.BorderWidth = 1;
            manualCard.BorderColor = UiComponents.COLORS.Border;
            manualCard.BackgroundColor = UiComponents.COLORS.Card;

            grid = uigridlayout(manualCard, [1, 6]);
            grid.RowHeight = {'fit'};
            grid.ColumnWidth = {'1x', '1x', '2x', '1x', '1x', '2x'};
            grid.Padding = [10 8 10 8];
            grid.ColumnSpacing = 6;

            manualControls = struct();

            manualControls.UpButton = UiBuilder.createStyledButton(grid, 'success', '⬆️ UP', 'Move stage up', [1, 1]);

            manualControls.StepDownButton = UiBuilder.createStyledButton(grid, 'muted', '⬅️', 'Decrease step size', [1, 2]);

            stepSizePanel = uipanel(grid);
            stepSizePanel.Layout.Row = 1;
            stepSizePanel.Layout.Column = 3;
            stepSizePanel.BorderType = 'line';
            stepSizePanel.BackgroundColor = UiComponents.COLORS.Light;

            stepSizeGrid = uigridlayout(stepSizePanel, [1, 1]);
            stepSizeGrid.Padding = [4 2 4 2];

            manualControls.StepSizeDisplay = uilabel(stepSizeGrid);
            manualControls.StepSizeDisplay.Text = '1.0μm';
            manualControls.StepSizeDisplay.FontSize = 9;
            manualControls.StepSizeDisplay.FontWeight = 'bold';
            manualControls.StepSizeDisplay.FontColor = [0.2 0.2 0.2];
            manualControls.StepSizeDisplay.HorizontalAlignment = 'center';

            manualControls.StepUpButton = UiBuilder.createStyledButton(grid, 'muted', '➡️', 'Increase step size', [1, 4]);

            manualControls.DownButton = UiBuilder.createStyledButton(grid, 'warning', '⬇️ DOWN', 'Move stage down', [1, 5]);
            manualControls.ZeroButton = UiBuilder.createStyledButton(grid, 'primary', '🎯 ZERO', 'Set position to zero', [1, 6]);

            manualControls.StepSizeDropdown = uidropdown(grid);
            manualControls.StepSizeDropdown.Items = FoilviewUtils.formatStepSizeItems(FoilviewController.STEP_SIZES);
            manualControls.StepSizeDropdown.Value = FoilviewUtils.formatPosition(FoilviewController.DEFAULT_STEP_SIZE);
            manualControls.StepSizeDropdown.Layout.Row = 1;
            manualControls.StepSizeDropdown.Layout.Column = 3;
            manualControls.StepSizeDropdown.Visible = 'off';

            manualControls.StepSizes = FoilviewController.STEP_SIZES;
            manualControls.CurrentStepIndex = find(manualControls.StepSizes == FoilviewController.DEFAULT_STEP_SIZE, 1);
        end

        function autoControls = createAutoStepContainer(mainLayout)
            % Creates the auto step control panel with modern card styling and enhanced layout.
            autoCard = uipanel(mainLayout);
            autoCard.Title = '⚡ Auto Step Control';
            autoCard.FontSize = 11;
            autoCard.FontWeight = 'bold';
            autoCard.Layout.Row = 4;
            autoCard.BorderType = 'line';
            autoCard.BorderWidth = 1;
            autoCard.BorderColor = UiComponents.COLORS.Border;
            autoCard.BackgroundColor = UiComponents.COLORS.Card;
            autoCard.AutoResizeChildren = 'on';

            grid = uigridlayout(autoCard, [2, 5]);
            grid.RowHeight = {'1x', 'fit'};
            grid.ColumnWidth = {'fit', '1x', '1x', '1x', 'fit'};
            grid.Padding = [8 6 8 8];
            grid.RowSpacing = 6;
            grid.ColumnSpacing = 8;

            autoControls = struct();

            autoControls.StartStopButton = UiBuilder.createStyledButton(grid, 'success', 'START ▲', [], [1, 1]);
            autoControls.StartStopButton.HorizontalAlignment = 'center';

            autoControls.StepField = uieditfield(grid, 'numeric');
            autoControls.StepField.Value = FoilviewController.DEFAULT_AUTO_STEP;
            autoControls.StepField.FontSize = 10;
            autoControls.StepField.Layout.Row = 1;
            autoControls.StepField.Layout.Column = 2;
            autoControls.StepField.Tooltip = 'Step size (μm)';
            autoControls.StepField.HorizontalAlignment = 'center';

            autoControls.StepsField = uieditfield(grid, 'numeric');
            autoControls.StepsField.Value = FoilviewController.DEFAULT_AUTO_STEPS;
            autoControls.StepsField.FontSize = 10;
            autoControls.StepsField.Layout.Row = 1;
            autoControls.StepsField.Layout.Column = 3;
            autoControls.StepsField.Tooltip = 'Number of steps';
            autoControls.StepsField.HorizontalAlignment = 'center';

            autoControls.DelayField = uieditfield(grid, 'numeric');
            autoControls.DelayField.Value = FoilviewController.DEFAULT_AUTO_DELAY;
            autoControls.DelayField.FontSize = 10;
            autoControls.DelayField.Layout.Row = 1;
            autoControls.DelayField.Layout.Column = 4;
            autoControls.DelayField.Tooltip = 'Delay between steps (seconds)';
            autoControls.DelayField.HorizontalAlignment = 'center';

            directionPanel = uipanel(grid);
            directionPanel.Layout.Row = 1;
            directionPanel.Layout.Column = 5;
            directionPanel.BorderType = 'none';
            directionPanel.BackgroundColor = UiComponents.COLORS.Background;

            directionGrid = uigridlayout(directionPanel, [1, 2]);
            directionGrid.RowHeight = {'fit'};
            directionGrid.ColumnWidth = {'fit', '1x'};
            directionGrid.Padding = [2 2 2 2];
            directionGrid.RowSpacing = 2;
            directionGrid.ColumnSpacing = 4;

            directionLabel = uilabel(directionGrid);
            directionLabel.Text = 'Direction';
            directionLabel.FontSize = 9;
            directionLabel.FontWeight = 'bold';
            directionLabel.HorizontalAlignment = 'right';
            directionLabel.Layout.Row = 1;
            directionLabel.Layout.Column = 1;

            autoControls.DirectionSwitch = uiswitch(directionGrid, 'toggle');
            autoControls.DirectionSwitch.Items = {'Down', 'Up'};
            autoControls.DirectionSwitch.Value = 'Up';
            autoControls.DirectionSwitch.FontSize = 9;
            autoControls.DirectionSwitch.Tooltip = 'Toggle direction (Up/Down)';
            autoControls.DirectionSwitch.Layout.Row = 1;
            autoControls.DirectionSwitch.Layout.Column = 2;

            autoControls.DirectionButton = UiBuilder.createStyledButton(grid, 'success', '▲', 'Toggle direction (Up/Down)', [2, 4]);
            autoControls.DirectionButton.Visible = 'off';

            statusGrid = uigridlayout(grid, [1, 3]);
            statusGrid.Layout.Row = 2;
            statusGrid.Layout.Column = [1 4];
            statusGrid.ColumnWidth = {'fit', '1x', 'fit'};
            statusGrid.RowHeight = {'fit'};
            statusGrid.Padding = [0 0 0 0];
            statusGrid.ColumnSpacing = 4;

            statusLabel = uilabel(statusGrid);
            statusLabel.Text = 'Ready:';
            statusLabel.FontSize = 10;
            statusLabel.FontWeight = 'bold';
            statusLabel.FontColor = [0.3 0.3 0.3];
            statusLabel.HorizontalAlignment = 'right';
            statusLabel.Layout.Row = 1;
            statusLabel.Layout.Column = 1;

            autoControls.StatusDisplay = uilabel(statusGrid);
            autoControls.StatusDisplay.Text = 'Ready';
            autoControls.StatusDisplay.FontSize = 10;
            autoControls.StatusDisplay.FontColor = [0.4 0.4 0.4];
            autoControls.StatusDisplay.HorizontalAlignment = 'left';
            autoControls.StatusDisplay.Layout.Row = 1;
            autoControls.StatusDisplay.Layout.Column = 2;

            unitsLabel = uilabel(statusGrid);
            unitsLabel.Text = 'μm × steps @ s';
            unitsLabel.FontSize = 9;
            unitsLabel.FontColor = [0.6 0.6 0.6];
            unitsLabel.HorizontalAlignment = 'left';
            unitsLabel.Layout.Row = 1;
            unitsLabel.Layout.Column = 3;
        end

        function metricsPlotControls = createMetricsPlotArea(uiFigure)
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

            metricsPlotControls.ClearButton = UiBuilder.createStyledButton(grid, 'warning', 'CLEAR', [], [2, 1]);
            metricsPlotControls.ExportButton = UiBuilder.createStyledButton(grid, 'primary', 'EXPORT', [], [2, 2]);
        end

        function button = createStyledButton(parent, style, text, tooltip, layoutPosition)
            % Helper to create and style a button consistently with modern design.
            button = uibutton(parent, 'push');
            button.Text = text;
            button.FontSize = 11;
            button.FontWeight = 'bold';

            if ~isempty(tooltip)
                button.Tooltip = tooltip;
            end

            if ~isempty(layoutPosition)
                button.Layout.Row = layoutPosition(1);
                button.Layout.Column = layoutPosition(2);
            end

            % Apply modern button styling with subtle shadows and rounded appearance
            if strcmp(style, 'muted')
                button.BackgroundColor = UiComponents.COLORS.TextMuted;
                button.FontColor = [1 1 1];
            else
                UiComponents.applyButtonStyle(button, style, text);
            end
            
            % Add consistent button styling for better visual hierarchy
            button.FontSize = 10;
            button.FontWeight = 'bold';
        end
    end
end