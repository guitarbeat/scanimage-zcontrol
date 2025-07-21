classdef UiBuilder
    % UI CONSTRUCTION & LAYOUT - Static UI creation for FoilView application
    %
    % RESPONSIBILITY: One-time UI construction and layout setup
    % - Creates all UI components and their initial layout
    % - Defines component hierarchy and positioning
    % - Sets up grid layouts and component relationships
    % - Runs once during application initialization
    %
    % ARCHITECTURE:
    % - UiBuilder (this class): Static UI construction & layout
    % - UiComponents: Runtime management, styling, and dynamic updates
    % - All constants and styling come from UiComponents
    %
    % ===== CONTAINER CONSTRUCTION RESPONSIBILITIES =====
    % This class CREATES the initial structure and layout for:
    %
    % 1. "Manual Control" Container:
    %    - Method: createCompactManualControls()
    %    - Creates: UP/DOWN buttons, step size display, step adjustment buttons
    %    - Layout: 3-row grid with button positioning
    %
    % 2. "Auto Step Control" Container:
    %    - Method: createCompactAutoControls()
    %    - Creates: START button, input fields (step/steps/delay), direction switch
    %    - Layout: 4-row grid with controls and status areas
    %
    % 3. "Current Position" Container:
    %    - Method: createPositionDisplay()
    %    - Creates: Position value label, status text
    %    - Layout: 2-row card with centered display
    %
    % 4. "System Status & Tools" Container:
    %    - Method: createStatusBar()
    %    - Creates: Status label, tool buttons (bookmarks, stage view, refresh, metadata)
    %    - Layout: 6-column horizontal bar
    %
    % Main construction sections:
    % - Main window and layout setup
    % - Display components (position, metrics)
    % - Control panels (manual, auto)
    % - Status and utility components
    % - Plot area and expansion controls



    methods (Static)
        function components = build()
            % Static entry point to construct and return all UI components as a struct.
            components = struct();

            % Create main window structure
            [components.UIFigure, components.MainPanel, components.MainLayout] = ...
                UiBuilder.createMainWindow();

            % Create display components
            components.PositionDisplay = UiBuilder.createPositionDisplay(components.MainLayout);
            components.MetricDisplay = UiBuilder.createMetricDisplay(components.MainLayout);

            % Create control panels
            [components.ManualControls, components.AutoControls] = ...
                UiBuilder.createCombinedControlsContainer(components.MainLayout);

            % Create status and utility components
            components.StatusControls = UiBuilder.createStatusBar(components.MainLayout);

            % Create plot area
            components.MetricsPlotControls = UiBuilder.createMetricsPlotArea(components.UIFigure);

            % Show the window
            components.UIFigure.Visible = 'on';
        end
    end

    methods (Static, Access = private)
        % ===== MAIN WINDOW SETUP =====
        function [uiFigure, mainPanel, mainLayout] = createMainWindow()
            % Creates the main figure window, panel, and grid layout with modern styling.
            uiFigure = UiBuilder.createMainFigure();
            mainPanel = UiBuilder.createMainPanel(uiFigure);
            mainLayout = UiBuilder.createMainLayout(mainPanel);
        end

        function uiFigure = createMainFigure()
            % Creates and configures the main figure window with enhanced styling.
            uiFigure = uifigure('Visible', 'off');
            uiFigure.Units = 'pixels';
            uiFigure.Position = [100 100 UiComponents.MIN_WINDOW_WIDTH UiComponents.MIN_WINDOW_HEIGHT];
            uiFigure.Name = UiComponents.TEXT.WindowTitle;
            uiFigure.Color = UiComponents.COLORS.Background;
            uiFigure.Resize = 'on';
            uiFigure.AutoResizeChildren = 'off';  % Turn off to enable SizeChangedFcn
            uiFigure.WindowState = 'normal';
            uiFigure.WindowStyle = 'normal';
        end

        function mainPanel = createMainPanel(uiFigure)
            % Creates the main panel that fills the entire figure.
            mainPanel = uipanel(uiFigure);
            mainPanel.Units = 'normalized';
            mainPanel.Position = [0, 0, 1, 1];
            mainPanel.BorderType = 'none';
            mainPanel.BackgroundColor = UiComponents.COLORS.Background;
            mainPanel.AutoResizeChildren = 'on';
        end

        function mainLayout = createMainLayout(mainPanel)
            % Creates the main grid layout with 5 rows for all components.
            mainLayout = uigridlayout(mainPanel, [5, 1]);
            mainLayout.RowHeight = UiComponents.MAIN_ROW_HEIGHTS;
            mainLayout.ColumnWidth = {'1x'};
            mainLayout.Padding = UiComponents.MAIN_PADDING;
            mainLayout.RowSpacing = UiComponents.MAIN_ROW_SPACING;
            mainLayout.Scrollable = 'off';
        end

        % ===== DISPLAY COMPONENTS =====
        function metricDisplay = createMetricDisplay(mainLayout)
            % Creates the metric display section with enhanced modern styling.
            metricCard = UiBuilder.createCard(mainLayout, 1, '📊 Image Metrics', UiComponents.CONTROL_FONT_SIZE);
            metricPanel = uigridlayout(metricCard, [1, 4]); % Changed to 4 columns to include plot button
            metricPanel.ColumnWidth = {'fit', '1x', 'fit', 'fit'}; % Dropdown, Value, Refresh, Plot
            metricPanel.Padding = UiComponents.LOOSE_PADDING;
            metricPanel.ColumnSpacing = UiComponents.STANDARD_SPACING;

            metricDisplay = struct();
            % Enhanced dropdown with consistent styling
            metricDisplay.TypeDropdown = UiBuilder.createDropdown(metricPanel, {'Std Dev', 'Mean', 'Max'}, 'Std Dev');
            metricDisplay.TypeDropdown.FontSize = UiComponents.CONTROL_FONT_SIZE;
            metricDisplay.TypeDropdown.BackgroundColor = UiComponents.COLORS.White;

            % Enhanced value display with better prominence
            metricDisplay.Value = UiBuilder.createValueLabel(metricPanel, 'N/A', 16);
            metricDisplay.Value.FontColor = UiComponents.COLORS.Primary;
            metricDisplay.Value.BackgroundColor = UiComponents.COLORS.Light;

            % Enhanced refresh button with icon
            metricDisplay.RefreshButton = UiBuilder.createIconButton(metricPanel, '↻', 'Refresh metric calculation', 'info');
            
            % Plot button - logically grouped with metrics
            metricDisplay.ShowPlotButton = UiBuilder.createShowPlotButton(metricPanel);
            metricDisplay.ShowPlotButton.Text = 'Plot';
        end

        function positionDisplay = createPositionDisplay(mainLayout)
            % Creates the position display with modern card styling and enhanced visual hierarchy.
            positionCard = UiBuilder.createCard(mainLayout, 2, 'Current Position', UiComponents.CARD_TITLE_FONT_SIZE);
            positionCard.TitlePosition = 'centertop';

            positionPanel = uigridlayout(positionCard, [2, 1]);
            positionPanel.RowHeight = UiComponents.FIT_EXPAND_ROWS;
            positionPanel.RowSpacing = UiComponents.STANDARD_SPACING;
            positionPanel.Padding = UiComponents.LOOSE_PADDING;

            positionDisplay = struct();
            % Enhanced position label with better styling
            positionDisplay.Label = UiBuilder.createValueLabel(positionPanel, '0.0 μm', UiComponents.POSITION_DISPLAY_FONT_SIZE, 'Consolas');
            positionDisplay.Label.FontColor = UiComponents.COLORS.Primary;
            positionDisplay.Label.BackgroundColor = UiComponents.COLORS.Light;

            % Enhanced status label
            positionDisplay.Status = UiBuilder.createStatusLabel(positionPanel, '✓ Ready');
            positionDisplay.Status.FontColor = UiComponents.COLORS.StatusGood;
        end

        function showPlotButton = createShowPlotButton(parent)
            % Creates the Show Plot button for the status bar with consistent styling.
            showPlotButton = UiBuilder.createBaseButton(parent, ' Show Plot', 'Show/Hide metrics plot', UiComponents.CONTROL_FONT_SIZE);
            UiComponents.applyButtonStyle(showPlotButton, 'primary');
        end

        function statusControls = createStatusBar(mainLayout)
            % Creates a clean tools section without system status clutter.
            
            % Tools Card - centered and focused
            toolsCard = UiBuilder.createCard(mainLayout, 4, '🔧 Tools', UiComponents.CONTROL_FONT_SIZE);
            
            toolsGrid = uigridlayout(toolsCard, [2, 2]); % 2 rows, 2 columns (removed plot button)
            toolsGrid.RowHeight = {'fit', 'fit'};
            toolsGrid.ColumnWidth = {'1x', '1x'}; % Equal width columns for balance
            toolsGrid.Padding = UiComponents.STANDARD_PADDING;
            toolsGrid.RowSpacing = UiComponents.STANDARD_SPACING;
            toolsGrid.ColumnSpacing = UiComponents.STANDARD_SPACING;
            
            statusControls = struct();
            
            % Top row: Main tools
            statusControls.BookmarksButton = UiBuilder.createToolButton(toolsGrid, '📍', 'Toggle Bookmarks (Open/Close)');
            statusControls.BookmarksButton.Layout.Row = 1;
            statusControls.BookmarksButton.Layout.Column = 1;
            statusControls.BookmarksButton.Text = 'Bookmarks';
            
            statusControls.StageViewButton = UiBuilder.createToolButton(toolsGrid, '📷', 'Toggle Camera (Open/Close)');
            statusControls.StageViewButton.Layout.Row = 1;
            statusControls.StageViewButton.Layout.Column = 2;
            statusControls.StageViewButton.Text = 'Camera';
            
            % Bottom row: Utility tools
            statusControls.RefreshButton = UiBuilder.createToolButton(toolsGrid, '↻', 'Refresh position and status');
            statusControls.RefreshButton.Layout.Row = 2;
            statusControls.RefreshButton.Layout.Column = 1;
            statusControls.RefreshButton.Text = 'Refresh';
            
            statusControls.MetadataButton = UiBuilder.createToolButton(toolsGrid, '⚙', 'Metadata Logging');
            statusControls.MetadataButton.Layout.Row = 2;
            statusControls.MetadataButton.Layout.Column = 2;
            statusControls.MetadataButton.Text = 'Metadata';
            
            % Keep Label and ShowPlotButton properties for compatibility (but hidden/unused)
            statusControls.Label = uilabel(toolsGrid);
            statusControls.Label.Visible = 'off';
            
            % Create a dummy ShowPlotButton for compatibility - it will be overridden by MetricDisplay
            statusControls.ShowPlotButton = UiBuilder.createShowPlotButton(toolsGrid);
            statusControls.ShowPlotButton.Visible = 'off';
        end

        function metricsPlotControls = createMetricsPlotArea(uiFigure)
            % Creates the metrics plot panel with axes and buttons (initially hidden).
            metricsPlotControls = struct();

            metricsPlotControls.Panel = uipanel(uiFigure);
            metricsPlotControls.Panel.Units = 'pixels';
            metricsPlotControls.Panel.Position = [UiComponents.MIN_WINDOW_WIDTH + UiComponents.PLOT_PANEL_OFFSET, UiComponents.PLOT_PANEL_OFFSET, UiComponents.PLOT_WIDTH, UiComponents.MIN_WINDOW_HEIGHT - UiComponents.PLOT_PANEL_MARGIN];
            metricsPlotControls.Panel.Title = 'Metrics Plot';
            metricsPlotControls.Panel.FontSize = UiComponents.CARD_TITLE_FONT_SIZE;
            metricsPlotControls.Panel.FontWeight = 'bold';
            metricsPlotControls.Panel.Visible = 'off';
            metricsPlotControls.Panel.AutoResizeChildren = 'on';

            grid = uigridlayout(metricsPlotControls.Panel, [2, 2]);
            grid.RowHeight = UiComponents.FIT_EXPAND_ROWS;
            grid.ColumnWidth = UiComponents.STANDARD_COLUMN_WIDTHS;
            grid.Padding = UiComponents.PLOT_GRID_PADDING;
            grid.RowSpacing = UiComponents.PLOT_GRID_SPACING;
            grid.ColumnSpacing = UiComponents.PLOT_GRID_SPACING;

            metricsPlotControls.Axes = uiaxes(grid);
            metricsPlotControls.Axes.Layout.Row = 1;
            metricsPlotControls.Axes.Layout.Column = [1 2];
            hold(metricsPlotControls.Axes, 'on');
            metricsPlotControls.Axes.XGrid = 'on';
            metricsPlotControls.Axes.YGrid = 'on';
            xlabel(metricsPlotControls.Axes, 'Z Position (μm)');
            ylabel(metricsPlotControls.Axes, 'Normalized Metric Value');
            title(metricsPlotControls.Axes, 'Metrics vs Z Position');

            metricsPlotControls.ClearButton = UiBuilder.createStyledButton(grid, 'warning', '🗑 CLEAR', 'Clear all plot data', [2, 1]);
            metricsPlotControls.ExportButton = UiBuilder.createStyledButton(grid, 'primary', '📤 EXPORT', 'Export plot data to file', [2, 2]);
        end

        function [manualControls, autoControls] = createCombinedControlsContainer(mainLayout)
            % Creates a two-column layout with manual and auto controls side-by-side
            % Shared step size is positioned above manual controls on the left

            % Create the combined controls container
            combinedCard = uipanel(mainLayout);
            combinedCard.Layout.Row = 3;
            combinedCard.BorderType = 'none';
            combinedCard.BackgroundColor = UiComponents.COLORS.Background;

            % Two-column layout: Left (Step Size + Manual) | Right (Auto)
            twoColumnGrid = uigridlayout(combinedCard, [1, 2]);
            twoColumnGrid.ColumnWidth = UiComponents.STANDARD_COLUMN_WIDTHS;
            twoColumnGrid.Padding = UiComponents.TIGHT_PADDING;
            twoColumnGrid.ColumnSpacing = UiComponents.TIGHT_SPACING;

            % Left column: Step Size above Manual Controls
            leftColumnGrid = uigridlayout(twoColumnGrid, [2, 1]);
            leftColumnGrid.Layout.Column = 1;
            leftColumnGrid.RowHeight = UiComponents.FIT_EXPAND_ROWS;
            leftColumnGrid.Padding = UiComponents.TIGHT_PADDING;
            leftColumnGrid.RowSpacing = UiComponents.STANDARD_SPACING;

            % Create shared step size control in left column
            sharedStepSize = UiBuilder.createSharedStepSizeControl(leftColumnGrid);

            % Create Manual Controls below step size in left column
            manualControls = UiBuilder.createCompactManualControls(leftColumnGrid);

            % Create Auto Controls in right column
            autoControls = UiBuilder.createCompactAutoControls(twoColumnGrid);

            % Add shared step size reference to both controls
            manualControls.SharedStepSize = sharedStepSize;
            autoControls.SharedStepSize = sharedStepSize;
        end

        function manualControls = createCompactManualControls(parent)
            % Creates compact manual controls - now without step size controls (uses shared)
            manualCard = uipanel(parent);
            manualCard.Layout.Column = 1;
            manualCard.Title = 'Manual Control';
            manualCard.FontSize = UiComponents.CARD_TITLE_FONT_SIZE;
            manualCard.FontWeight = 'bold';
            manualCard.BorderType = 'line';
            manualCard.BackgroundColor = UiComponents.COLORS.Card;

            % Simplified grid: 2 rows - UP button, DOWN button
            grid = uigridlayout(manualCard, [2, 1]);
            grid.RowHeight = {'1x', '1x'}; % Equal expanding rows to fill full height
            grid.Padding = UiComponents.CONTROL_GRID_PADDING;
            grid.RowSpacing = UiComponents.CONTROL_GRID_SPACING;

            manualControls = struct();

            % Row 1: UP button (centered and prominent with better icon)
            manualControls.UpButton = UiBuilder.createStyledButton(grid, 'success', '▲ UP', 'Move stage up by current step size', [1, 1]);

            % Row 2: DOWN button (centered and prominent with better icon)
            manualControls.DownButton = UiBuilder.createStyledButton(grid, 'warning', '▼ DOWN', 'Move stage down by current step size', [2, 1]);

            % Keep compatibility properties for existing code (will reference shared step size)
            manualControls.StepSizes = FoilviewController.STEP_SIZES;
            manualControls.CurrentStepIndex = find(manualControls.StepSizes == FoilviewController.DEFAULT_STEP_SIZE, 1);
        end

        function autoControls = createCompactAutoControls(parent)
            % Creates auto step controls with reorganized layout
            autoCard = uipanel(parent);
            autoCard.Layout.Column = 2;
            autoCard.Title = 'Auto Step Control';
            autoCard.FontSize = UiComponents.CARD_TITLE_FONT_SIZE;
            autoCard.FontWeight = 'bold';
            autoCard.BorderType = 'line';
            autoCard.BackgroundColor = UiComponents.COLORS.Card;

            % Main grid: 3 rows - START button, controls row, status row
            grid = uigridlayout(autoCard, [3, 1]);
            grid.RowHeight = UiComponents.THREE_FIT_ROWS;
            grid.Padding = UiComponents.CONTROL_GRID_PADDING;
            grid.RowSpacing = UiComponents.CONTROL_GRID_SPACING;

            autoControls = struct();

            % Row 1: START button with icon
            autoControls.StartStopButton = UiBuilder.createStyledButton(grid, 'success', '▶ START', 'Start/Stop auto stepping', [1, 1]);
            autoControls.StartStopButton.FontSize = UiComponents.CONTROL_FONT_SIZE;
            autoControls.StartStopButton.FontWeight = 'bold';

            % Row 2: Controls row - Left side (Steps, Delay) | Right side (Direction)
            controlsGrid = uigridlayout(grid, [2, 2]);
            controlsGrid.Layout.Row = 2;
            controlsGrid.RowHeight = UiComponents.ALL_FIT_ROWS;
            controlsGrid.ColumnWidth = {'fit', 'fit'};
            controlsGrid.Padding = UiComponents.TIGHT_PADDING;
            controlsGrid.RowSpacing = UiComponents.STANDARD_SPACING;
            controlsGrid.ColumnSpacing = UiComponents.LOOSE_SPACING;

            % LEFT SIDE - Create input fields with arrow buttons
            autoControls.StepsField = UiBuilder.createArrowField(controlsGrid, 1, 'Steps     :', ...
                FoilviewController.DEFAULT_AUTO_STEPS, 'Number of steps', [], 1, 100);
            autoControls.DelayField = UiBuilder.createArrowField(controlsGrid, 2, 'Delay     :', ...
                FoilviewController.DEFAULT_AUTO_DELAY, 'Delay between steps (seconds)', 's', 0.1, 10);

            % RIGHT SIDE - Direction (spans both rows)
            directionGrid = uigridlayout(controlsGrid, [3, 1]);
            directionGrid.Layout.Row = [1 2];
            directionGrid.Layout.Column = 2;
            directionGrid.RowHeight = UiComponents.THREE_FIT_ROWS;
            directionGrid.Padding = UiComponents.TIGHT_PADDING;
            directionGrid.RowSpacing = UiComponents.STANDARD_SPACING;

            directionLabel = uilabel(directionGrid);
            directionLabel.Text = 'Direction';
            directionLabel.FontSize = UiComponents.CONTROL_FONT_SIZE;
            directionLabel.FontWeight = 'bold';
            directionLabel.HorizontalAlignment = 'center';
            directionLabel.Layout.Row = 1;

            autoControls.DirectionSwitch = uiswitch(directionGrid, 'toggle');
            autoControls.DirectionSwitch.Items = {'Down', 'Up'};
            autoControls.DirectionSwitch.Value = 'Up';
            autoControls.DirectionSwitch.FontSize = UiComponents.CONTROL_FONT_SIZE;
            autoControls.DirectionSwitch.Tooltip = 'Toggle direction (Up/Down)';
            autoControls.DirectionSwitch.Layout.Row = 2;

            % Row 3: Total Move
            totalLabel = uilabel(grid);
            totalLabel.Text = 'Total Move : 100 μm ↑';
            totalLabel.FontSize = UiComponents.CONTROL_FONT_SIZE;
            totalLabel.FontWeight = 'bold';
            totalLabel.FontColor = UiComponents.COLORS.TextMuted;
            totalLabel.Layout.Row = 3;

        end

        function sharedStepSize = createSharedStepSizeControl(parent)
            % Creates a shared step size control that both Manual and Auto controls use
            stepCard = uipanel(parent);
            stepCard.Layout.Row = 1;
            stepCard.Title = 'Step Size';
            stepCard.FontSize = UiComponents.CARD_TITLE_FONT_SIZE;
            stepCard.FontWeight = 'bold';
            stepCard.BorderType = 'line';
            stepCard.BackgroundColor = UiComponents.COLORS.Card;

            % Grid layout for step size controls: < [1.0 μm] >
            stepGrid = uigridlayout(stepCard, [1, 3]);
            stepGrid.ColumnWidth = {50, '1x', 50}; % Fixed width arrow buttons (50px each) with expanding center
            stepGrid.Padding = UiComponents.CONTROL_GRID_PADDING;
            stepGrid.ColumnSpacing = UiComponents.LOOSE_SPACING;

            sharedStepSize = struct();

            % Decrease button
            sharedStepSize.StepDownButton = UiBuilder.createStyledButton(stepGrid, 'muted', '<', 'Decrease step size', [1, 1]);

            % Step size display panel with value and units
            stepSizePanel = uipanel(stepGrid);
            stepSizePanel.Layout.Row = 1;
            stepSizePanel.Layout.Column = 2;
            stepSizePanel.BorderType = 'line';
            stepSizePanel.BackgroundColor = UiComponents.COLORS.Light;

            stepSizeInnerGrid = uigridlayout(stepSizePanel, [1, 2]);
            stepSizeInnerGrid.ColumnWidth = {'fit', 'fit'};
            stepSizeInnerGrid.Padding = UiComponents.LOOSE_PADDING;
            stepSizeInnerGrid.ColumnSpacing = UiComponents.STANDARD_SPACING;

            % Create clickable step size field instead of label
            sharedStepSize.StepSizeDisplay = uieditfield(stepSizeInnerGrid, 'numeric');
            sharedStepSize.StepSizeDisplay.Value = FoilviewController.DEFAULT_STEP_SIZE;
            sharedStepSize.StepSizeDisplay.FontSize = UiComponents.CONTROL_FONT_SIZE + 4; % Slightly larger for emphasis
            sharedStepSize.StepSizeDisplay.FontWeight = 'bold';
            sharedStepSize.StepSizeDisplay.HorizontalAlignment = 'center';
            sharedStepSize.StepSizeDisplay.FontColor = UiComponents.COLORS.DarkText;
            sharedStepSize.StepSizeDisplay.BackgroundColor = UiComponents.COLORS.Light;
            sharedStepSize.StepSizeDisplay.Limits = [0.001 1000];  % Reasonable limits
            sharedStepSize.StepSizeDisplay.Tooltip = 'Click to enter custom step size (0.001 - 1000 μm)';

            unitsLabel = uilabel(stepSizeInnerGrid);
            unitsLabel.Text = 'μm';
            unitsLabel.FontSize = UiComponents.CONTROL_FONT_SIZE;
            unitsLabel.FontWeight = 'bold';
            unitsLabel.FontColor = UiComponents.COLORS.TextMuted;

            % Increase button
            sharedStepSize.StepUpButton = UiBuilder.createStyledButton(stepGrid, 'muted', '>', 'Increase step size', [1, 3]);

            % Step size data and management
            sharedStepSize.StepSizes = FoilviewController.STEP_SIZES;
            sharedStepSize.CurrentStepIndex = find(sharedStepSize.StepSizes == FoilviewController.DEFAULT_STEP_SIZE, 1);
            sharedStepSize.CurrentValue = FoilviewController.DEFAULT_STEP_SIZE;

            % Hidden dropdown for compatibility with existing code
            sharedStepSize.StepSizeDropdown = uidropdown(stepGrid);
            sharedStepSize.StepSizeDropdown.Items = FoilviewUtils.formatStepSizeItems(FoilviewController.STEP_SIZES);
            sharedStepSize.StepSizeDropdown.Value = FoilviewUtils.formatPosition(FoilviewController.DEFAULT_STEP_SIZE);
            sharedStepSize.StepSizeDropdown.Visible = 'off';
            sharedStepSize.StepSizeDropdown.Layout.Row = 1;
            sharedStepSize.StepSizeDropdown.Layout.Column = 2;
        end

        % ===== HELPER METHODS =====
        function card = createCard(parent, row, title, fontSize)
            % Creates a standardized card panel with consistent styling.
            card = uipanel(parent);
            card.Layout.Row = row;
            card.BorderType = 'line';
            card.BackgroundColor = UiComponents.COLORS.Card;
            card.Title = title;
            card.FontSize = fontSize;
            card.FontWeight = 'bold';
        end

        function dropdown = createDropdown(parent, items, value)
            % Creates a standardized dropdown with consistent styling.
            dropdown = uidropdown(parent);
            dropdown.Items = items;
            dropdown.Value = value;
            dropdown.FontSize = UiComponents.CONTROL_FONT_SIZE;
            dropdown.BackgroundColor = UiComponents.COLORS.Light;
        end

        function label = createValueLabel(parent, text, fontSize, fontName)
            % Creates a value display label with consistent styling.
            label = uilabel(parent);
            label.Text = text;
            label.FontSize = fontSize;
            label.FontWeight = 'bold';
            label.HorizontalAlignment = 'center';
            label.BackgroundColor = UiComponents.COLORS.Light;
            label.FontColor = UiComponents.COLORS.Primary;
            if nargin > 3 && ~isempty(fontName)
                label.FontName = fontName;
            end
        end

        function label = createStatusLabel(parent, text)
            % Creates a status label with consistent styling.
            label = uilabel(parent);
            label.Text = text;
            label.FontSize = UiComponents.CONTROL_FONT_SIZE;
            label.HorizontalAlignment = 'center';
            label.FontColor = UiComponents.COLORS.TextMuted;
            label.FontWeight = 'bold';
        end

        function label = createLabel(parent, text, fontSize, fontWeight)
            % Creates a standardized label with consistent styling.
            label = uilabel(parent);
            label.Text = text;
            label.FontSize = fontSize;
            if nargin > 3 && ~isempty(fontWeight)
                label.FontWeight = fontWeight;
            end
        end

        function button = createBaseButton(parent, text, tooltip, fontSize)
            % Creates a base button with common properties.
            button = uibutton(parent, 'push');
            button.Text = text;
            button.FontSize = fontSize;
            button.FontWeight = 'bold';
            if ~isempty(tooltip)
                button.Tooltip = tooltip;
            end
        end

        function button = createToolButton(parent, text, tooltip)
            % Creates a standardized tool button with consistent styling.
            button = UiBuilder.createBaseButton(parent, text, tooltip, UiComponents.CONTROL_FONT_SIZE);
            UiComponents.applyButtonStyle(button, 'primary');
        end

        function button = createIconButton(parent, text, tooltip, style)
            % Creates an icon button with consistent styling.
            button = UiBuilder.createBaseButton(parent, text, tooltip, UiComponents.CONTROL_FONT_SIZE);
            UiComponents.applyButtonStyle(button, style);
        end

        function field = createLabeledField(parent, row, labelText, defaultValue, tooltip, units)
            % Creates a labeled input field with units in a standardized layout.
            field = UiBuilder.createFieldBase(parent, row, labelText, defaultValue, tooltip);

            if nargin > 5 && ~isempty(units)
                % Add units label to the field panel
                fieldPanel = field.Parent;
                unitsLabel = uilabel(fieldPanel);
                unitsLabel.Text = units;
                unitsLabel.FontSize = UiComponents.CONTROL_FONT_SIZE;
                unitsLabel.FontWeight = 'bold';
                unitsLabel.FontColor = UiComponents.COLORS.TextMuted;
            end
        end

        function field = createSimpleField(parent, row, labelText, defaultValue, tooltip)
            % Creates a simple labeled input field without units.
            field = UiBuilder.createFieldBase(parent, row, labelText, defaultValue, tooltip);
        end

        function fieldStruct = createArrowField(parent, row, labelText, defaultValue, tooltip, units, minValue, maxValue)
            % Creates a field with arrow buttons for increment/decrement, similar to step size control.
            fieldGrid = uigridlayout(parent, [1, 2]);
            fieldGrid.Layout.Row = row;
            fieldGrid.Layout.Column = 1;
            fieldGrid.ColumnWidth = UiComponents.FIT_EXPAND_COLUMNS;
            fieldGrid.Padding = UiComponents.TIGHT_PADDING;
            fieldGrid.ColumnSpacing = UiComponents.STANDARD_SPACING;

            % Label
            label = uilabel(fieldGrid);
            label.Text = labelText;
            label.FontSize = UiComponents.CONTROL_FONT_SIZE;
            label.FontWeight = 'bold';

            % Field panel with arrow buttons
            fieldPanel = uipanel(fieldGrid);
            fieldPanel.BorderType = 'line';
            fieldPanel.BackgroundColor = UiComponents.COLORS.Light;

            % Inner grid: < [value units] >
            fieldInnerGrid = uigridlayout(fieldPanel, [1, 3]);
            fieldInnerGrid.ColumnWidth = {30, '1x', 30}; % Small arrow buttons with expanding center
            fieldInnerGrid.Padding = UiComponents.TIGHT_PADDING;
            fieldInnerGrid.ColumnSpacing = UiComponents.STANDARD_SPACING;

            % Create struct to return multiple components
            fieldStruct = struct();

            % Decrease button
            fieldStruct.DecreaseButton = UiBuilder.createStyledButton(fieldInnerGrid, 'muted', '<', 'Decrease value', [1, 1]);

            % Center panel for value and units
            centerPanel = uipanel(fieldInnerGrid);
            centerPanel.Layout.Row = 1;
            centerPanel.Layout.Column = 2;
            centerPanel.BorderType = 'none';
            centerPanel.BackgroundColor = UiComponents.COLORS.Light;

            centerGrid = uigridlayout(centerPanel, [1, 2]);
            if nargin > 5 && ~isempty(units)
                centerGrid.ColumnWidth = {'1x', 'fit'};
            else
                centerGrid.ColumnWidth = {'1x'};
            end
            centerGrid.Padding = UiComponents.TIGHT_PADDING;
            centerGrid.ColumnSpacing = UiComponents.STANDARD_SPACING;

            % Value field
            fieldStruct.Field = uieditfield(centerGrid, 'numeric');
            fieldStruct.Field.Value = defaultValue;
            fieldStruct.Field.FontSize = UiComponents.CONTROL_FONT_SIZE;
            fieldStruct.Field.Tooltip = tooltip;
            fieldStruct.Field.HorizontalAlignment = 'center';
            
            % Set limits if provided
            if nargin > 6 && ~isempty(minValue)
                fieldStruct.Field.Limits = [minValue, maxValue];
            end

            % Units label if provided
            if nargin > 5 && ~isempty(units)
                unitsLabel = uilabel(centerGrid);
                unitsLabel.Text = units;
                unitsLabel.FontSize = UiComponents.CONTROL_FONT_SIZE;
                unitsLabel.FontWeight = 'bold';
                unitsLabel.FontColor = UiComponents.COLORS.TextMuted;
            end

            % Increase button
            fieldStruct.IncreaseButton = UiBuilder.createStyledButton(fieldInnerGrid, 'muted', '>', 'Increase value', [1, 3]);

            % Store configuration for easy access
            fieldStruct.MinValue = minValue;
            fieldStruct.MaxValue = maxValue;
            fieldStruct.DefaultValue = defaultValue;
        end

        function field = createFieldBase(parent, row, labelText, defaultValue, tooltip)
            % Creates the base structure for labeled input fields.
            fieldGrid = uigridlayout(parent, [1, 2]);
            fieldGrid.Layout.Row = row;
            fieldGrid.Layout.Column = 1;
            fieldGrid.ColumnWidth = UiComponents.FIT_EXPAND_COLUMNS;
            fieldGrid.Padding = UiComponents.TIGHT_PADDING;
            fieldGrid.ColumnSpacing = UiComponents.STANDARD_SPACING;

            label = uilabel(fieldGrid);
            label.Text = labelText;
            label.FontSize = UiComponents.CONTROL_FONT_SIZE;
            label.FontWeight = 'bold';

            fieldPanel = uipanel(fieldGrid);
            fieldPanel.BorderType = 'line';
            fieldPanel.BackgroundColor = UiComponents.COLORS.Light;

            fieldInnerGrid = uigridlayout(fieldPanel, [1, 2]);
            fieldInnerGrid.ColumnWidth = UiComponents.STANDARD_COLUMN_WIDTHS;
            fieldInnerGrid.Padding = UiComponents.STANDARD_PADDING;
            fieldInnerGrid.ColumnSpacing = UiComponents.STANDARD_SPACING;

            field = uieditfield(fieldInnerGrid, 'numeric');
            field.Value = defaultValue;
            field.FontSize = UiComponents.CONTROL_FONT_SIZE;
            field.Tooltip = tooltip;
            field.HorizontalAlignment = 'center';
        end

        function button = createStyledButton(parent, style, text, tooltip, layoutPosition)
            % Helper to create and style a button consistently with modern design.
            button = UiBuilder.createBaseButton(parent, text, tooltip, UiComponents.CONTROL_FONT_SIZE);

            if nargin > 4 && ~isempty(layoutPosition)
                button.Layout.Row = layoutPosition(1);
                button.Layout.Column = layoutPosition(2);
            end

            UiComponents.applyButtonStyle(button, style);
        end
    end
end