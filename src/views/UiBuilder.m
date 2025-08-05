%==============================================================================
% UiBuilder - Static UI Construction and Layout
%==============================================================================
%
% Purpose:
%   Provides static UI construction and layout setup for the FoilView application.
%   This class is responsible for creating the initial UI structure and component
%   hierarchy, while UiComponents handles styling and runtime management.
%
% Key Features:
%   - One-time UI construction and layout setup
%   - Component hierarchy and positioning
%   - Grid layouts and component relationships
%   - Integration with controller and service layers
%   - Support for custom and standard UI elements
%
% Dependencies:
%   - MATLAB App Designer: UI components
%   - UiComponents: UI styling and constants
%   - FoilviewUtils: UI style constants
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   components = UiBuilder.build();
%
%==============================================================================

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
            % 
            % Returns:
            %   components: Struct containing all UI components organized by category
            
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

            % Create plot area
            components.MetricsPlotControls = UiBuilder.createMetricsPlotArea(components.UIFigure);
            
            % Create separate tools window
            components.ToolsWindow = ToolsWindow(components.UIFigure);
            
            % Set up tools button callback
            components.MetricDisplay.ToolsButton.ButtonPushedFcn = @(~,~) components.ToolsWindow.toggle();
            
            % Set up Show FoilView button callback
            components.ToolsWindow.ShowFoilViewButton.ButtonPushedFcn = @(~,~) UiBuilder.toggleMainWindow(components.UIFigure, components.ToolsWindow.ShowFoilViewButton);
            
            % Create StatusControls struct for compatibility, referencing tools window buttons
            components.StatusControls = struct();
            components.StatusControls.ShowFoilViewButton = components.ToolsWindow.ShowFoilViewButton;
            components.StatusControls.BookmarksButton = components.ToolsWindow.BookmarksButton;
            components.StatusControls.StageViewButton = components.ToolsWindow.StageViewButton;
            components.StatusControls.MJC3Button = components.ToolsWindow.MJC3Button;
            components.StatusControls.RefreshButton = components.ToolsWindow.RefreshButton;
            components.StatusControls.MetadataButton = components.ToolsWindow.MetadataButton;
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
            % Creates the main grid layout with 3 rows for all components (removed tools section).
            mainLayout = uigridlayout(mainPanel, [3, 1]);
            mainLayout.RowHeight = {'fit', 'fit', '1x'}; % Updated for 3 rows: metrics, position, controls
            mainLayout.ColumnWidth = {'1x'};
            mainLayout.Padding = UiComponents.MAIN_PADDING;
            mainLayout.RowSpacing = UiComponents.MAIN_ROW_SPACING;
            mainLayout.Scrollable = 'off';
        end

        % ===== DISPLAY COMPONENTS =====
        function metricDisplay = createMetricDisplay(mainLayout)
            % Creates the metric display section with enhanced modern styling.
            metricCard = UiBuilder.createCard(mainLayout, 1, '📊 Image Metrics', UiComponents.CONTROL_FONT_SIZE);
            metricPanel = uigridlayout(metricCard, [1, 5]); % Changed to 5 columns to include tools button
            metricPanel.ColumnWidth = {'fit', '1x', 'fit', 'fit', 'fit'}; % Dropdown, Value, Refresh, Plot, Tools
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
            
            % Tools button - toggle tools window
            metricDisplay.ToolsButton = UiBuilder.createIconButton(metricPanel, '🔧', 'Show/Hide Tools Window', 'primary');
            metricDisplay.ToolsButton.Text = 'Tools';
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
            % Creates a new layout: Left (numeric controls) | Right (action controls)
            % Left: Step Size, Steps, Delay (stacked vertically)
            % Right: Manual Control, Direction, Start Button (stacked vertically)

            % Create the combined controls container
            combinedCard = uipanel(mainLayout);
            combinedCard.Layout.Row = 3;
            combinedCard.BorderType = 'none';
            combinedCard.BackgroundColor = UiComponents.COLORS.Background;

            % Two-column layout: Left (Numeric Controls) | Right (Action Controls)
            twoColumnGrid = uigridlayout(combinedCard, [1, 2]);
            twoColumnGrid.ColumnWidth = UiComponents.STANDARD_COLUMN_WIDTHS;
            twoColumnGrid.Padding = UiComponents.TIGHT_PADDING;
            twoColumnGrid.ColumnSpacing = UiComponents.STANDARD_SPACING;

            % LEFT COLUMN: Numeric Controls (Step Size, Steps, Delay)
            leftColumnGrid = uigridlayout(twoColumnGrid, [3, 1]);
            leftColumnGrid.Layout.Column = 1;
            leftColumnGrid.RowHeight = {'fit', 'fit', 'fit'};
            leftColumnGrid.Padding = UiComponents.TIGHT_PADDING;
            leftColumnGrid.RowSpacing = UiComponents.STANDARD_SPACING;

            % Create numeric controls in left column
            sharedStepSize = UiBuilder.createSharedStepSizeControl(leftColumnGrid, 1);
            stepsControl = UiBuilder.createStepsControl(leftColumnGrid, 2);
            delayControl = UiBuilder.createDelayControl(leftColumnGrid, 3);

            % RIGHT COLUMN: Action Controls (Manual, Direction, Start)
            rightColumnGrid = uigridlayout(twoColumnGrid, [3, 1]);
            rightColumnGrid.Layout.Column = 2;
            rightColumnGrid.RowHeight = {'fit', 'fit', 'fit'};
            rightColumnGrid.Padding = UiComponents.TIGHT_PADDING;
            rightColumnGrid.RowSpacing = UiComponents.STANDARD_SPACING;

            % Create action controls in right column
            manualControls = UiBuilder.createCompactManualControls(rightColumnGrid, 1);
            directionControl = UiBuilder.createDirectionControl(rightColumnGrid, 2);
            startControl = UiBuilder.createStartControl(rightColumnGrid, 3);

            % Create autoControls struct combining all the auto-related controls
            autoControls = struct();
            autoControls.StepsField = stepsControl;
            autoControls.DelayField = delayControl;
            autoControls.DirectionSwitch = directionControl.DirectionSwitch;
            autoControls.StartStopButton = startControl.StartStopButton;
            autoControls.TotalMoveLabel = startControl.TotalMoveLabel;

            % Add shared step size reference to both controls
            manualControls.SharedStepSize = sharedStepSize;
            autoControls.SharedStepSize = sharedStepSize;
        end

        function manualControls = createCompactManualControls(parent, row)
            % Creates compact manual controls - now without step size controls (uses shared)
            if nargin < 2, row = 2; end
            manualCard = uipanel(parent);
            manualCard.Layout.Row = row;
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



        function sharedStepSize = createSharedStepSizeControl(parent, row)
            % Creates a shared step size control that both Manual and Auto controls use
            if nargin < 2, row = 1; end
            stepCard = uipanel(parent);
            stepCard.Layout.Row = row;
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
            
            % If no label text, create field panel directly in parent
            if isempty(labelText)
                fieldPanel = uipanel(parent);
                fieldPanel.Layout.Row = row;
            else
                            % Create grid with label and field
            [fieldGrid, label] = UiBuilder.createLabeledGrid(parent, row, labelText);

                            % Field panel with arrow buttons
            fieldPanel = uipanel(fieldGrid);
            end
            fieldPanel = UiBuilder.createFieldPanel(fieldPanel);

            % Use the common arrow field components creation
            fieldStruct = UiBuilder.createArrowFieldComponents(fieldPanel, defaultValue, tooltip, units, minValue, maxValue);
        end
        
        function fieldStruct = createArrowFieldDirect(parent, defaultValue, tooltip, units, minValue, maxValue)
            % Creates an arrow field directly in the parent (no label, no grid)
            
            % Create a uipanel first, then apply field panel styling
            panel = uipanel(parent);
            fieldPanel = UiBuilder.createFieldPanel(panel);

            % Use the common arrow field components creation
            fieldStruct = UiBuilder.createArrowFieldComponents(fieldPanel, defaultValue, tooltip, units, minValue, maxValue);
        end

        function field = createFieldBase(parent, row, labelText, defaultValue, tooltip)
            % Creates the base structure for labeled input fields.
            [fieldGrid, label] = UiBuilder.createLabeledGrid(parent, row, labelText);

            fieldPanel = UiBuilder.createFieldPanel(uipanel(fieldGrid));

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
        
        function stepsControl = createStepsControl(parent, row)
            % Creates the steps control (similar to step size but for number of steps)
            [stepsCard, stepsGrid] = UiBuilder.createControlCard(parent, row, 'Steps');
            
            % Create arrow field structure for steps (without label since it's in the card title)
            stepsControl = UiBuilder.createArrowFieldDirect(stepsGrid, ...
                FoilviewController.DEFAULT_AUTO_STEPS, 'Number of steps', [], 1, 100);
        end
        
        function delayControl = createDelayControl(parent, row)
            % Creates the delay control (similar to step size but for delay)
            [delayCard, delayGrid] = UiBuilder.createControlCard(parent, row, 'Delay');
            
            % Create arrow field structure for delay (without label since it's in the card title)
            delayControl = UiBuilder.createArrowFieldDirect(delayGrid, ...
                1, 'Delay between steps (seconds)', 's', 0.1, 10);
        end
        
        function directionControl = createDirectionControl(parent, row)
            % Creates the direction control
            [directionCard, directionGrid] = UiBuilder.createControlCard(parent, row, 'Direction');

            directionControl = struct();
            directionControl.DirectionSwitch = uiswitch(directionGrid, 'toggle');
            directionControl.DirectionSwitch.Items = {'Down', 'Up'};
            directionControl.DirectionSwitch.Value = 'Up';
            directionControl.DirectionSwitch.FontSize = UiComponents.CONTROL_FONT_SIZE;
            directionControl.DirectionSwitch.Tooltip = 'Toggle direction (Up/Down)';
        end
        
        function startControl = createStartControl(parent, row)
            % Creates the start/stop control with total move display
            [startCard, startGrid] = UiBuilder.createControlCard(parent, row, 'Control');
            
            % Override grid layout for start control (needs 2 rows)
            startGrid.RowHeight = {'fit', 'fit'};
            startGrid.RowSpacing = UiComponents.CONTROL_GRID_SPACING;

            startControl = struct();
            
            % Start/Stop button
            startControl.StartStopButton = UiBuilder.createStyledButton(startGrid, 'success', '▶ START', 'Start/Stop auto stepping', [1, 1]);
            startControl.StartStopButton.FontSize = UiComponents.CONTROL_FONT_SIZE;
            startControl.StartStopButton.FontWeight = 'bold';

            % Total move label
            startControl.TotalMoveLabel = uilabel(startGrid);
            startControl.TotalMoveLabel.Text = 'Total Move : 100 μm ↑';
            startControl.TotalMoveLabel.FontSize = UiComponents.CONTROL_FONT_SIZE;
            startControl.TotalMoveLabel.FontWeight = 'bold';
            startControl.TotalMoveLabel.FontColor = UiComponents.COLORS.TextMuted;
            startControl.TotalMoveLabel.HorizontalAlignment = 'center';
            startControl.TotalMoveLabel.Layout.Row = 2;
        end
        
        function onMainWindowResize(mainWindow, toolsWindow)
            % Callback for main window resize - updates tools window position
            if ~isempty(toolsWindow) && isvalid(toolsWindow) && toolsWindow.isVisible()
                toolsWindow.updatePosition();
            end
        end
        
        function toggleMainWindow(mainWindow, showButton)
            % Toggle main window visibility and update button text
            if ~isvalid(mainWindow) || ~isvalid(showButton)
                return;
            end
            
            if strcmp(mainWindow.Visible, 'on')
                % Hide main window
                mainWindow.Visible = 'off';
                showButton.Text = '🚀 Show FoilView';
                showButton.Tooltip = 'Show Main FoilView Window';
                UiComponents.applyButtonStyle(showButton, 'success');
            else
                % Show main window
                mainWindow.Visible = 'on';
                showButton.Text = '📦 Hide FoilView';
                showButton.Tooltip = 'Hide Main FoilView Window';
                UiComponents.applyButtonStyle(showButton, 'warning');
            end
        end
        
        function fieldStruct = createArrowFieldComponents(fieldPanel, defaultValue, tooltip, units, minValue, maxValue)
            % Helper method to create the common arrow field components
            % This extracts the duplicated logic from createArrowField and createArrowFieldDirect
            % fieldPanel: the panel to contain the arrow field components
            % defaultValue: initial value for the field
            % tooltip: tooltip text
            % units: units text (optional)
            % minValue, maxValue: limits (optional)
            
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
            if nargin > 3 && ~isempty(units)
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
            if nargin > 4 && ~isempty(minValue)
                fieldStruct.Field.Limits = [minValue, maxValue];
            end

            % Units label if provided
            if nargin > 3 && ~isempty(units)
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
        
        function [card, grid] = createControlCard(parent, row, title)
            % Helper method to create a control card with standard styling
            % This extracts the duplicated logic from createStepsControl and createDelayControl
            % parent: parent container
            % row: grid row position
            % title: card title
            % Returns: [card, grid] - the card panel and its inner grid
            
            card = uipanel(parent);
            card.Layout.Row = row;
            card.Title = title;
            card.FontSize = UiComponents.CARD_TITLE_FONT_SIZE;
            card.FontWeight = 'bold';
            card.BorderType = 'line';
            card.BackgroundColor = UiComponents.COLORS.Card;

            % Create grid layout for the control
            grid = uigridlayout(card, [1, 1]);
            grid.Padding = UiComponents.CONTROL_GRID_PADDING;
        end
        
        function fieldPanel = createFieldPanel(panel)
            % Helper method to apply standard styling to a field panel
            % This extracts the duplicated logic from createArrowField and createArrowFieldDirect
            % panel: the panel to style
            % Returns: the styled panel
            
            fieldPanel = panel;
            fieldPanel.BorderType = 'line';
            fieldPanel.BackgroundColor = UiComponents.COLORS.Light;
        end
        
        function [fieldGrid, label] = createLabeledGrid(parent, row, labelText)
            % Helper method to create a labeled grid layout
            % This extracts the duplicated logic from createArrowField and createFieldBase
            % parent: parent container
            % row: grid row position
            % labelText: text for the label
            % Returns: [fieldGrid, label] - the grid and label components
            
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
        end
    end
end