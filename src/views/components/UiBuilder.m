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
            [components.ManualControls, components.AutoControls] = UiBuilder.createCombinedControlsContainer(components.MainLayout);
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

            mainLayout = uigridlayout(mainPanel, [5, 1]);
            mainLayout.RowHeight = {'fit', 'fit', '1.2x', 'fit', 'fit'};
            mainLayout.ColumnWidth = {'1x'};
            mainLayout.Padding = [4 4 4 4];      % Ultra-tight 4px gutters
            mainLayout.RowSpacing = 3;           % Minimal 3px between sections
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
            metricCard.FontSize = 9;
            metricCard.FontWeight = 'bold';

            metricPanel = uigridlayout(metricCard, [1, 3]);
            metricPanel.ColumnWidth = {'fit', '1x', 'fit'};
            metricPanel.Padding = [2 1 2 1];  % Ultra-tight padding
            metricPanel.ColumnSpacing = 2;     % Minimal spacing

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
            metricDisplay.RefreshButton.Text = '';
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
            positionPanel.RowSpacing = 2;     % Ultra-tight row spacing
            positionPanel.Padding = [4 2 4 2];   % Minimal padding

            positionDisplay = struct();

            positionDisplay.Label = uilabel(positionPanel);
            positionDisplay.Label.Text = '0.0 μm';
            positionDisplay.Label.FontSize = 20;  % Even smaller position text
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
            expandButton.Text = ' Show Plot';
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
            statusCard.Title = ' System Status & Tools';
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
            statusControls.BookmarksButton.Text = '';
            statusControls.BookmarksButton.FontSize = 11;
            statusControls.BookmarksButton.FontWeight = 'bold';
            statusControls.BookmarksButton.Tooltip = 'Toggle Bookmarks Window (Open/Close)';
            statusControls.BookmarksButton.BackgroundColor = UiComponents.COLORS.Primary;
            statusControls.BookmarksButton.FontColor = [1 1 1];

            statusControls.StageViewButton = uibutton(statusBar, 'push');
            statusControls.StageViewButton.Text = '';
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
            statusControls.MetadataButton.Text = '';
            statusControls.MetadataButton.FontSize = 11;
            statusControls.MetadataButton.FontWeight = 'bold';
            statusControls.MetadataButton.Tooltip = 'Initialize Metadata Logging';
            statusControls.MetadataButton.BackgroundColor = UiComponents.COLORS.Primary;
            statusControls.MetadataButton.FontColor = [1 1 1];

        end

        function manualControls = createManualControlContainer(mainLayout)
            % Creates the manual control panel with modern card styling and improved layout.
            manualCard = uipanel(mainLayout);
            manualCard.Title = ' Manual Control';
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
            manualControls.ZeroButton = UiBuilder.createStyledButton(grid, 'primary', ' ZERO', 'Set position to zero', [1, 6]);

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
            grid.RowHeight = {'1x', 40};  % Fixed height for status row
            grid.ColumnWidth = {'fit', '1x', '1x', '1x', 120};
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

        function [manualControls, autoControls] = createCombinedControlsContainer(mainLayout)
            % Creates a two-column layout with manual and auto controls side-by-side

            % Create the combined controls container
            combinedCard = uipanel(mainLayout);
            combinedCard.Layout.Row = 3;
            combinedCard.BorderType = 'none';
            combinedCard.BackgroundColor = UiComponents.COLORS.Background;

            % Two-column layout: Manual | Auto - ultra compact
            twoColumnGrid = uigridlayout(combinedCard, [1, 2]);
            twoColumnGrid.ColumnWidth = {'1x', '1.2x'};  % More balanced
            twoColumnGrid.Padding = [0 0 0 0];
            twoColumnGrid.ColumnSpacing = 4;  % Minimal column spacing

            % Create Manual Controls (Left Column)
            manualControls = UiBuilder.createCompactManualControls(twoColumnGrid);

            % Create Auto Controls (Right Column)
            autoControls = UiBuilder.createCompactAutoControls(twoColumnGrid);
        end

        function manualControls = createCompactManualControls(parent)
            % Creates compact manual controls matching the ASCII design
            manualCard = uipanel(parent);
            manualCard.Layout.Column = 1;
            manualCard.Title = 'Manual Control';
            manualCard.FontSize = 11;
            manualCard.FontWeight = 'bold';
            manualCard.BorderType = 'line';
            manualCard.BorderWidth = 1;
            manualCard.BorderColor = UiComponents.COLORS.Border;
            manualCard.BackgroundColor = UiComponents.COLORS.Card;

            % Main grid: 3 rows - UP button, step controls, DOWN button
            grid = uigridlayout(manualCard, [3, 1]);
            grid.RowHeight = {'1x', 'fit', '1x'};
            grid.Padding = [6 4 6 4];  % Much more compact padding
            grid.RowSpacing = 4;       % Tighter row spacing

            manualControls = struct();

            % Row 1: UP button (centered and prominent)
            manualControls.UpButton = UiBuilder.createStyledButton(grid, 'success', '↑ UP', 'Move stage up', [1, 1]);

            % Row 2: Step size controls (< [1.0 μm] >)
            stepGrid = uigridlayout(grid, [2, 3]);
            stepGrid.Layout.Row = 2;
            stepGrid.RowHeight = {'fit', 'fit'};
            stepGrid.ColumnWidth = {'fit', '1x', 'fit'};
            stepGrid.ColumnSpacing = 6;
            stepGrid.RowSpacing = 4;
            stepGrid.Padding = [0 0 0 0];

            % Step size controls row
            manualControls.StepDownButton = UiBuilder.createStyledButton(stepGrid, 'muted', '<', 'Decrease step size', [1, 1]);

            % Step size display with units
            stepSizePanel = uipanel(stepGrid);
            stepSizePanel.Layout.Row = 1;
            stepSizePanel.Layout.Column = 2;
            stepSizePanel.BorderType = 'line';
            stepSizePanel.BorderWidth = 1;
            stepSizePanel.BorderColor = UiComponents.COLORS.Border;
            stepSizePanel.BackgroundColor = UiComponents.COLORS.Light;

            stepSizeGrid = uigridlayout(stepSizePanel, [1, 1]);
            stepSizeGrid.Padding = [4 2 4 2];

            manualControls.StepSizeDisplay = uilabel(stepSizeGrid);
            manualControls.StepSizeDisplay.Text = '1.0 μm';
            manualControls.StepSizeDisplay.FontSize = 11;
            manualControls.StepSizeDisplay.FontWeight = 'bold';
            manualControls.StepSizeDisplay.HorizontalAlignment = 'center';
            manualControls.StepSizeDisplay.FontColor = [0.2 0.2 0.2];

            manualControls.StepUpButton = UiBuilder.createStyledButton(stepGrid, 'muted', '>', 'Increase step size', [1, 3]);

            % Row 3: DOWN button (centered and prominent)
            manualControls.DownButton = UiBuilder.createStyledButton(grid, 'warning', '↓ DOWN', 'Move stage down', [3, 1]);

            % Hidden dropdown for compatibility
            manualControls.StepSizeDropdown = uidropdown(stepGrid);
            manualControls.StepSizeDropdown.Items = FoilviewUtils.formatStepSizeItems(FoilviewController.STEP_SIZES);
            manualControls.StepSizeDropdown.Value = FoilviewUtils.formatPosition(FoilviewController.DEFAULT_STEP_SIZE);
            manualControls.StepSizeDropdown.Visible = 'off';
            manualControls.StepSizeDropdown.Layout.Row = 2;
            manualControls.StepSizeDropdown.Layout.Column = 2;

            % Step size data
            manualControls.StepSizes = FoilviewController.STEP_SIZES;
            manualControls.CurrentStepIndex = find(manualControls.StepSizes == FoilviewController.DEFAULT_STEP_SIZE, 1);
        end

        function autoControls = createCompactAutoControls(parent)
            % Creates auto step controls matching the ASCII design exactly
            autoCard = uipanel(parent);
            autoCard.Layout.Column = 2;
            autoCard.Title = '⚡ Auto Step Control';
            autoCard.FontSize = 11;
            autoCard.FontWeight = 'bold';
            autoCard.BorderType = 'line';
            autoCard.BorderWidth = 1;
            autoCard.BorderColor = UiComponents.COLORS.Border;
            autoCard.BackgroundColor = UiComponents.COLORS.Card;

            % Main grid: 5 rows - ultra compact
            grid = uigridlayout(autoCard, [5, 2]);
            grid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};
            grid.ColumnWidth = {'1x', '1x'};
            grid.Padding = [4 2 4 2];  % Ultra compact padding
            grid.RowSpacing = 2;       % Minimal row spacing
            grid.ColumnSpacing = 4;    % Minimal column spacing

            autoControls = struct();

            % Row 1: Step Size
            stepSizeLabel = uilabel(grid);
            stepSizeLabel.Text = 'Step Size  :';
            stepSizeLabel.FontSize = 10;
            stepSizeLabel.FontWeight = 'bold';
            stepSizeLabel.Layout.Row = 1;
            stepSizeLabel.Layout.Column = 1;

            stepSizePanel = uipanel(grid);
            stepSizePanel.Layout.Row = 1;
            stepSizePanel.Layout.Column = 2;
            stepSizePanel.BorderType = 'line';
            stepSizePanel.BorderWidth = 1;
            stepSizePanel.BorderColor = UiComponents.COLORS.Border;
            stepSizePanel.BackgroundColor = UiComponents.COLORS.Light;

            stepSizeGrid = uigridlayout(stepSizePanel, [1, 2]);
            stepSizeGrid.ColumnWidth = {'1x', 'fit'};
            stepSizeGrid.Padding = [4 2 4 2];
            stepSizeGrid.ColumnSpacing = 4;

            autoControls.StepField = uieditfield(stepSizeGrid, 'numeric');
            autoControls.StepField.Value = FoilviewController.DEFAULT_AUTO_STEP;
            autoControls.StepField.FontSize = 10;
            autoControls.StepField.Tooltip = 'Step size (μm)';
            autoControls.StepField.HorizontalAlignment = 'center';

            stepUnits = uilabel(stepSizeGrid);
            stepUnits.Text = 'μm';
            stepUnits.FontSize = 10;
            stepUnits.FontWeight = 'bold';
            stepUnits.FontColor = [0.3 0.3 0.3];

            % Row 2: Steps
            stepsLabel = uilabel(grid);
            stepsLabel.Text = 'Steps      :';
            stepsLabel.FontSize = 10;
            stepsLabel.FontWeight = 'bold';
            stepsLabel.Layout.Row = 2;
            stepsLabel.Layout.Column = 1;

            autoControls.StepsField = uieditfield(grid, 'numeric');
            autoControls.StepsField.Value = FoilviewController.DEFAULT_AUTO_STEPS;
            autoControls.StepsField.FontSize = 10;
            autoControls.StepsField.Layout.Row = 2;
            autoControls.StepsField.Layout.Column = 2;
            autoControls.StepsField.Tooltip = 'Number of steps';
            autoControls.StepsField.HorizontalAlignment = 'center';

            % Row 3: Delay
            delayLabel = uilabel(grid);
            delayLabel.Text = 'Delay      :';
            delayLabel.FontSize = 10;
            delayLabel.FontWeight = 'bold';
            delayLabel.Layout.Row = 3;
            delayLabel.Layout.Column = 1;

            delayPanel = uipanel(grid);
            delayPanel.Layout.Row = 3;
            delayPanel.Layout.Column = 2;
            delayPanel.BorderType = 'line';
            delayPanel.BorderWidth = 1;
            delayPanel.BorderColor = UiComponents.COLORS.Border;
            delayPanel.BackgroundColor = UiComponents.COLORS.Light;

            delayGrid = uigridlayout(delayPanel, [1, 2]);
            delayGrid.ColumnWidth = {'1x', 'fit'};
            delayGrid.Padding = [4 2 4 2];
            delayGrid.ColumnSpacing = 4;

            autoControls.DelayField = uieditfield(delayGrid, 'numeric');
            autoControls.DelayField.Value = FoilviewController.DEFAULT_AUTO_DELAY;
            autoControls.DelayField.FontSize = 10;
            autoControls.DelayField.Tooltip = 'Delay between steps (seconds)';
            autoControls.DelayField.HorizontalAlignment = 'center';

            delayUnits = uilabel(delayGrid);
            delayUnits.Text = 's';
            delayUnits.FontSize = 10;
            delayUnits.FontWeight = 'bold';
            delayUnits.FontColor = [0.3 0.3 0.3];

            % Row 4: START button (spans both columns)
            autoControls.StartStopButton = UiBuilder.createStyledButton(grid, 'success', 'START', 'Start/Stop auto stepping', [4, [1 2]]);
            autoControls.StartStopButton.FontSize = 12;
            autoControls.StartStopButton.FontWeight = 'bold';

            % Row 5: Status and Direction
            statusGrid = uigridlayout(grid, [2, 2]);
            statusGrid.Layout.Row = 5;
            statusGrid.Layout.Column = [1 2];
            statusGrid.RowHeight = {'fit', 'fit'};
            statusGrid.ColumnWidth = {'1x', 'fit'};
            statusGrid.Padding = [0 0 0 0];
            statusGrid.RowSpacing = 4;
            statusGrid.ColumnSpacing = 8;

            % Total Move status
            totalLabel = uilabel(statusGrid);
            totalLabel.Text = 'Total Move  : 100 μm ↑';
            totalLabel.FontSize = 9;
            totalLabel.FontWeight = 'bold';
            totalLabel.FontColor = [0.4 0.4 0.4];
            totalLabel.Layout.Row = 1;
            totalLabel.Layout.Column = 1;

            % Direction section
            directionGrid = uigridlayout(statusGrid, [3, 1]);
            directionGrid.Layout.Row = [1 2];
            directionGrid.Layout.Column = 2;
            directionGrid.RowHeight = {'fit', 'fit', 'fit'};
            directionGrid.Padding = [0 0 0 0];
            directionGrid.RowSpacing = 2;

            directionLabel = uilabel(directionGrid);
            directionLabel.Text = 'Direction';
            directionLabel.FontSize = 9;
            directionLabel.FontWeight = 'bold';
            directionLabel.HorizontalAlignment = 'center';
            directionLabel.Layout.Row = 1;

            autoControls.DirectionSwitch = uiswitch(directionGrid, 'toggle');
            autoControls.DirectionSwitch.Items = {'Down', 'Up'};
            autoControls.DirectionSwitch.Value = 'Up';
            autoControls.DirectionSwitch.FontSize = 8;
            autoControls.DirectionSwitch.Tooltip = 'Toggle direction (Up/Down)';
            autoControls.DirectionSwitch.Layout.Row = 2;

            % Status row
            statusLabel = uilabel(statusGrid);
            statusLabel.Text = 'Status : Ready';
            statusLabel.FontSize = 9;
            statusLabel.FontWeight = 'bold';
            statusLabel.FontColor = [0.4 0.4 0.4];
            statusLabel.Layout.Row = 2;
            statusLabel.Layout.Column = 1;

            % Status display for compatibility
            autoControls.StatusDisplay = uilabel(statusGrid);
            autoControls.StatusDisplay.Text = 'Ready';
            autoControls.StatusDisplay.FontSize = 9;
            autoControls.StatusDisplay.FontColor = [0.4 0.4 0.4];
            autoControls.StatusDisplay.Visible = 'off';

            % Hidden direction button for compatibility
            autoControls.DirectionButton = UiBuilder.createStyledButton(statusGrid, 'success', '▲', 'Toggle direction (Up/Down)', [1, 1]);
            autoControls.DirectionButton.Visible = 'off';
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
