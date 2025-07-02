classdef foilview_ui < handle
    % foilview_ui - Handles creation of all UI components for foilview
    %
    % This class is responsible for creating and configuring all UI components
    % including the main window, tabs, controls, and plot areas. Refactored for
    % better maintainability, reduced complexity, and improved organization.
    
    properties (Constant, Access = public)
        % Window dimension constants
        MIN_WINDOW_WIDTH = 260
        MIN_WINDOW_HEIGHT = 320
        DEFAULT_WINDOW_WIDTH = 280
        DEFAULT_WINDOW_HEIGHT = 360
        PLOT_WIDTH = 400
        
        % Layout configuration constants
        MAIN_LAYOUT_ROWS = 7
        MAIN_LAYOUT_ROW_HEIGHTS = {'fit', 'fit', 'fit', 'fit', '1x', 'fit', 'fit'}
        
        % Control layout constants
        MANUAL_CONTROL_COLUMNS = 6
        AUTO_CONTROL_ROWS = 2
        AUTO_CONTROL_COLUMNS = 4
        
        % Font size constants
        BASE_FONT_SIZE = 8
        LARGE_FONT_SIZE = 10
        POSITION_FONT_SIZE = 22
        FIELD_FONT_SIZE = 9
        
        % Logo configuration
        LOGO_HEIGHT = 50  % Height in pixels for the logo
        
        % Text constants
        TEXT = struct(...
            'WindowTitle', 'FoilView - Z-Stage Control', ...
            'Ready', 'Ready', ...
            'ManualControlTitle', 'Manual Control', ...
            'AutoStepTitle', 'Auto Step', ...
            'MetricsPlotTitle', 'Metrics Plot')
        
        % Control symbols and labels
        SYMBOLS = struct(...
            'Up', '▲', ...
            'Down', '▼', ...
            'Left', '◄', ...
            'Right', '►', ...
            'Refresh', '↻', ...
            'Plot', '📊', ...
            'Bookmarks', '📌', ...
            'StageView', '📹')
    end
    
    methods (Static)
        function components = createAllComponents(app)
            % Create all UI components with improved organization
            creator = foilview_ui();
            components = creator.buildCompleteInterface(app);
        end
    end
    
    methods (Access = private)
        function components = buildCompleteInterface(obj, ~)
            % Main interface building method with better organization
            components = struct();
            
            % Create main window structure
            [components.UIFigure, components.MainPanel, components.MainLayout] = ...
                obj.createMainWindow();
            
            % Create logo display
            components.LogoDisplay = obj.createLogoDisplay(components.MainLayout);
            
            % Create display components
            components.MetricDisplay = obj.createMetricDisplay(components.MainLayout);
            components.PositionDisplay = obj.createPositionDisplay(components.MainLayout);
            
            % Create control components
            components.ManualControls = obj.createManualControls(components.MainLayout);
            components.AutoControls = obj.createAutoControls(components.MainLayout);
            
            % Create utility components
            components.StatusControls = obj.createStatusControls(components.MainLayout);
            components.MetricsPlotControls = obj.createPlotComponents(components.UIFigure, components.MainLayout);
            
            % Show the interface
            components.UIFigure.Visible = 'on';
        end
        
        %% Main Window Creation
        
        function [uiFigure, mainPanel, mainLayout] = createMainWindow(obj)
            % Create main window with improved configuration
            uiFigure = obj.createMainFigure();
            mainPanel = obj.createMainPanel(uiFigure);
            mainLayout = obj.createMainLayout(mainPanel);
        end
        
        function uiFigure = createMainFigure(obj)
            % Create and configure main figure
            uiFigure = uifigure('Visible', 'off');
            uiFigure.Units = 'pixels';
            uiFigure.Position = [100 100 obj.DEFAULT_WINDOW_WIDTH obj.DEFAULT_WINDOW_HEIGHT];
            uiFigure.Name = obj.TEXT.WindowTitle;
            uiFigure.Resize = 'on';
            uiFigure.AutoResizeChildren = 'on';
            uiFigure.WindowState = 'normal';
            
            % Apply styling
            colors = foilview_styling.getColors();
            uiFigure.Color = colors.Background;
        end
        
        function mainPanel = createMainPanel(obj, uiFigure)
            % Create main panel that fills the figure
            mainPanel = uipanel(uiFigure);
            mainPanel.Units = 'normalized';
            mainPanel.Position = [0, 0, 1, 1];
            mainPanel.BorderType = 'none';
            mainPanel.AutoResizeChildren = 'on';
            
            % Apply styling
            colors = foilview_styling.getColors();
            mainPanel.BackgroundColor = colors.Background;
        end
        
        function mainLayout = createMainLayout(obj, mainPanel)
            % Create compact responsive main layout grid
            mainLayout = uigridlayout(mainPanel, [obj.MAIN_LAYOUT_ROWS, 1]);
            mainLayout.RowHeight = obj.MAIN_LAYOUT_ROW_HEIGHTS;
            mainLayout.ColumnWidth = {'1x'};
            
            % Configure minimal spacing for compactness
            mainLayout.Padding = [foilview_styling.SPACE_1, foilview_styling.SPACE_1, foilview_styling.SPACE_1, foilview_styling.SPACE_1];
            mainLayout.RowSpacing = foilview_styling.SPACE_1;
            mainLayout.Scrollable = 'off';
        end
        
        %% Display Component Creation
        
        function logoDisplay = createLogoDisplay(obj, mainLayout)
            % Create logo display at the top of the interface
            logoPanel = obj.createComponentGrid(mainLayout, [1, 1], {'1x'}, 1);
            logoPanel.Padding = [2, 2, 2, 2];  % Minimal padding
            
            logoDisplay = struct();
            logoDisplay.Image = obj.createLogoImage(logoPanel);
        end
        
        function metricDisplay = createMetricDisplay(obj, mainLayout)
            % Create metric display with improved organization
            metricPanel = obj.createComponentGrid(mainLayout, [1, 3], {'fit', '1x', 'fit'}, 2);
            
            metricDisplay = struct();
            metricDisplay.TypeDropdown = obj.createMetricDropdown(metricPanel);
            metricDisplay.Value = obj.createMetricValueLabel(metricPanel);
            metricDisplay.RefreshButton = obj.createMetricRefreshButton(metricPanel);
        end
        
        function positionDisplay = createPositionDisplay(obj, mainLayout)
            % Create ultra-compact position display with no gray space
            positionPanel = obj.createComponentGrid(mainLayout, [2, 1], {'fit', 'fit'}, 3);
            positionPanel.RowSpacing = 0;  % No spacing between rows
            positionPanel.Padding = [0, 0, 0, 0];  % No padding at all
            
            positionDisplay = struct();
            positionDisplay.Label = obj.createPositionLabel(positionPanel);
            positionDisplay.Status = obj.createStatusLabel(positionPanel);
        end
        
        %% Control Component Creation
        
        function manualControls = createManualControls(obj, mainLayout)
            % Create manual control panel with improved organization
            manualPanel = obj.createTitledPanel(mainLayout, obj.TEXT.ManualControlTitle, 4);
            grid = obj.createControlGrid(manualPanel, [1, obj.MANUAL_CONTROL_COLUMNS]);
            
            manualControls = obj.buildManualControlComponents(grid);
            obj.configureManualControlBehavior(manualControls);
        end
        
        function autoControls = createAutoControls(obj, mainLayout)
            % Create auto control panel with simplified layout
            autoPanel = obj.createTitledPanel(mainLayout, obj.TEXT.AutoStepTitle, 5);
            grid = obj.createControlGrid(autoPanel, [obj.AUTO_CONTROL_ROWS, obj.AUTO_CONTROL_COLUMNS]);
            
            autoControls = obj.buildAutoControlComponents(grid);
        end
        
        function statusControls = createStatusControls(obj, mainLayout)
            % Create status control bar
            statusBar = obj.createComponentGrid(mainLayout, [1, 4], {'1x', 'fit', 'fit', 'fit'}, 7);
            
            statusControls = struct();
            statusControls.Label = obj.createStatusLabel(statusBar);
            statusControls.BookmarksButton = obj.createUtilityButton(statusBar, obj.SYMBOLS.Bookmarks, 'Toggle Bookmarks Window (Open/Close)');
            statusControls.StageViewButton = obj.createUtilityButton(statusBar, obj.SYMBOLS.StageView, 'Toggle Stage View Camera Window (Open/Close)');
            statusControls.RefreshButton = obj.createUtilityButton(statusBar, obj.SYMBOLS.Refresh, 'Refresh');
        end
        
        function plotControls = createPlotComponents(obj, uiFigure, mainLayout)
            % Create plot-related components
            plotControls = struct();
            plotControls.ExpandButton = obj.createExpandButton(mainLayout);
            plotControls = obj.addPlotArea(plotControls, uiFigure);
        end
        
        %% Helper Methods for Component Creation
        
        function grid = createComponentGrid(obj, parent, gridSize, columnWidths, row)
            % Create a standardized component grid
            grid = uigridlayout(parent, gridSize);
            if nargin >= 4 && ~isempty(columnWidths)
                grid.ColumnWidth = columnWidths;
            end
            if nargin >= 5 && ~isempty(row)
                grid.Layout.Row = row;
            end
        end
        
        function panel = createTitledPanel(obj, parent, title, row)
            % Create a compact titled panel for controls
            panel = uipanel(parent);
            panel.Title = title;
            panel.FontSize = obj.BASE_FONT_SIZE - 1;  % Slightly smaller for compactness
            panel.FontWeight = 'bold';
            panel.Layout.Row = row;
            panel.AutoResizeChildren = 'on';
        end
        
        function grid = createControlGrid(obj, parent, gridSize)
            % Create a standardized control grid with compact spacing
            grid = uigridlayout(parent, gridSize);
            
            % Configure responsive layout
            if gridSize(2) == obj.MANUAL_CONTROL_COLUMNS
                grid.ColumnWidth = repmat({'1x'}, 1, gridSize(2));
            elseif gridSize(2) == obj.AUTO_CONTROL_COLUMNS
                grid.RowHeight = {'fit', 'fit'};
                grid.ColumnWidth = repmat({'1x'}, 1, gridSize(2));
            end
            
            % Apply minimal spacing for compactness
            grid.Padding = [foilview_styling.SPACE_1, foilview_styling.SPACE_1, foilview_styling.SPACE_1, foilview_styling.SPACE_1];
            grid.ColumnSpacing = foilview_styling.SPACE_1;
            grid.RowSpacing = foilview_styling.SPACE_1;
        end
        
        %% Specific Component Builders
        
        function dropdown = createMetricDropdown(obj, parent)
            % Create metric type dropdown
            dropdown = uidropdown(parent);
            dropdown.Items = {'Std Dev', 'Mean', 'Max'};
            dropdown.Value = 'Std Dev';
            dropdown.FontSize = obj.BASE_FONT_SIZE;
        end
        
        function label = createMetricValueLabel(obj, parent)
            % Create metric value display label
            label = uilabel(parent);
            label.Text = 'N/A';
            label.FontSize = obj.LARGE_FONT_SIZE;
            label.FontWeight = 'bold';
            label.HorizontalAlignment = 'center';
            
            colors = foilview_styling.getColors();
            label.BackgroundColor = colors.Light;
        end
        
        function button = createMetricRefreshButton(obj, parent)
            % Create metric refresh button
            button = uibutton(parent, 'push');
            button.Text = obj.SYMBOLS.Refresh;
            button.FontSize = obj.BASE_FONT_SIZE;
        end
        
        function label = createPositionLabel(obj, parent)
            % Create main position display label with no background
            label = uilabel(parent);
            label.Text = '0.0 μm';
            label.FontSize = obj.POSITION_FONT_SIZE;
            label.FontWeight = 'bold';
            label.FontName = 'Courier New';
            label.HorizontalAlignment = 'center';
            % No background color to eliminate gray space
        end
        
        function label = createStatusLabel(obj, parent)
            % Create status label (versatile for different contexts)
            label = uilabel(parent);
            label.Text = obj.TEXT.Ready;
            label.FontSize = obj.BASE_FONT_SIZE;
            label.HorizontalAlignment = 'center';
            
            colors = foilview_styling.getColors();
            label.FontColor = colors.TextMuted;
        end
        
        function button = createExpandButton(obj, parent)
            % Create plot expand/collapse button
            button = uibutton(parent, 'push');
            button.Layout.Row = 6;
            button.Text = sprintf('%s Show Plot', obj.SYMBOLS.Plot);
            button.FontSize = obj.FIELD_FONT_SIZE;
            button.FontWeight = 'bold';
            
            foilview_styling.styleButton(button, 'primary', 'base');
        end
        
        function button = createUtilityButton(obj, parent, symbol, tooltip)
            % Create standardized utility buttons
            button = uibutton(parent, 'push');
            button.Text = symbol;
            button.FontSize = obj.BASE_FONT_SIZE;
            button.FontWeight = 'bold';
            button.Tooltip = tooltip;
            
            foilview_styling.styleButton(button, 'primary', 'sm');
        end
        
        function logoImage = createLogoImage(obj, parent)
            % Create logo image display
            try
                % Get the absolute path to the logo file
                logoPath = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'assets', 'foil.svg');
                
                % Check if the logo file exists
                if exist(logoPath, 'file')
                    % Create HTML component to display SVG
                    logoImage = uihtml(parent);
                    
                    % Read the SVG file content
                    fid = fopen(logoPath, 'r');
                    if fid ~= -1
                        svgContent = fread(fid, '*char')';
                        fclose(fid);
                        
                        % Create HTML to display the SVG with constrained height
                        htmlContent = sprintf(['<div style="display: flex; justify-content: center; align-items: center; height: %dpx; overflow: hidden;">' ...
                                             '<div style="height: %dpx; width: auto;">%s</div></div>'], ...
                                             obj.LOGO_HEIGHT, obj.LOGO_HEIGHT, svgContent);
                        
                        logoImage.HTMLSource = htmlContent;
                    else
                        % Fallback to text if SVG can't be read
                        logoImage = obj.createLogoFallback(parent);
                    end
                else
                    % Fallback to text if SVG file doesn't exist
                    logoImage = obj.createLogoFallback(parent);
                end
            catch
                % Fallback to text if any error occurs
                logoImage = obj.createLogoFallback(parent);
            end
        end
        
        function logoFallback = createLogoFallback(obj, parent)
            % Create text fallback for logo if SVG fails
            logoFallback = uilabel(parent);
            logoFallback.Text = 'Functional Optical Laboratory';
            logoFallback.FontSize = 12;
            logoFallback.FontWeight = 'bold';
            logoFallback.HorizontalAlignment = 'center';
            logoFallback.FontColor = [0.2 0.2 0.6];  % Professional blue color
        end
        
        %% Complex Component Builders
        
        function manualControls = buildManualControlComponents(obj, grid)
            % Build all manual control components in organized manner
            manualControls = struct();
            
            % Create directional buttons
            manualControls.UpButton = obj.createDirectionalButton(grid, obj.SYMBOLS.Up, 'success', [1, 1]);
            manualControls.DownButton = obj.createDirectionalButton(grid, obj.SYMBOLS.Down, 'warning', [1, 5]);
            
            % Create step size controls
            [manualControls.StepDownButton, manualControls.StepSizeField, manualControls.StepUpButton] = ...
                obj.createStepSizeControls(grid);
            
            % Create zero button
            manualControls.ZeroButton = obj.createActionButton(grid, 'ZERO', 'primary', [1, 6]);
        end
        
        function [stepDownBtn, stepField, stepUpBtn] = createStepSizeControls(obj, grid)
            % Create the step size control group
            
            % Step decrease button
            stepDownBtn = obj.createStepButton(grid, obj.SYMBOLS.Left, [1, 2], 'Quick preset: 0.5 μm');
            
            % Step size field in panel
            stepField = obj.createStepSizeFieldInPanel(grid, [1, 3]);
            
            % Step increase button
            stepUpBtn = obj.createStepButton(grid, obj.SYMBOLS.Right, [1, 4], 'Quick preset: 5.0 μm');
        end
        
        function field = createStepSizeFieldInPanel(obj, grid, position)
            % Create step size field within a bordered panel
            colors = foilview_styling.getColors();
            
            stepSizePanel = uipanel(grid);
            stepSizePanel.Layout.Row = position(1);
            stepSizePanel.Layout.Column = position(2);
            stepSizePanel.BorderType = 'line';
            stepSizePanel.BackgroundColor = colors.Light;
            stepSizePanel.BorderWidth = 1;
            stepSizePanel.HighlightColor = [0.8 0.8 0.8];
            
            stepSizeGrid = uigridlayout(stepSizePanel, [1, 1]);
            stepSizeGrid.Padding = [4 2 4 2];
            
            field = obj.createStepSizeField(stepSizeGrid, ...
                foilview_controller.DEFAULT_STEP_SIZE, obj.BASE_FONT_SIZE, [1, 1], ...
                'Manual step size (μm) - synced with Auto Step');
            field.FontColor = [0.2 0.2 0.2];
        end
        
        function autoControls = buildAutoControlComponents(obj, grid)
            % Build auto control components with simplified layout
            autoControls = struct();
            
            % Row 1: Main controls
            autoControls.StartStopButton = obj.createActionButton(grid, 'START ▲', 'success', [1, 1]);
            autoControls.StepField = obj.createNumericField(grid, foilview_controller.DEFAULT_STEP_SIZE, 'Step size (μm) - synced with Manual Control', [1, 2]);
            autoControls.StepsField = obj.createNumericField(grid, foilview_controller.DEFAULT_AUTO_STEPS, 'Number of steps', [1, 3]);
            autoControls.DelayField = obj.createNumericField(grid, foilview_controller.DEFAULT_AUTO_DELAY, 'Delay between steps (seconds)', [1, 4]);
            
            % Row 2: Status and direction
            autoControls.DirectionButton = obj.createActionButton(grid, '▲ UP', 'success', [2, 4]);
            autoControls.StatusDisplay = obj.createAutoStatusDisplay(grid);
        end
        
        function statusDisplay = createAutoStatusDisplay(obj, grid)
            % Create auto step status display
            statusGrid = uigridlayout(grid, [1, 3]);
            statusGrid.Layout.Row = 2;
            statusGrid.Layout.Column = [1 4];
            statusGrid.ColumnWidth = {'fit', '1x', 'fit'};
            statusGrid.Padding = [0 0 0 0];
            statusGrid.ColumnSpacing = 4;
            
            % Status components
            statusDisplay = struct();
            statusDisplay.Label = obj.createLabel(statusGrid, 'Ready:', obj.FIELD_FONT_SIZE, 'bold', [0.3 0.3 0.3]);
            statusDisplay.Display = obj.createLabel(statusGrid, '100.0 μm upward (5.0s)', obj.FIELD_FONT_SIZE, 'normal', [0.4 0.4 0.4]);
            statusDisplay.Units = obj.createLabel(statusGrid, 'μm × steps @ s', obj.BASE_FONT_SIZE, 'normal', [0.6 0.6 0.6]);
        end
        
        function plotControls = addPlotArea(obj, plotControls, uiFigure)
            % Add plot area components
            plotControls.Panel = obj.createPlotPanel(uiFigure);
            grid = obj.createPlotGrid(plotControls.Panel);
            
            plotControls.Axes = obj.createPlotAxes(grid);
            plotControls.ClearButton = obj.createActionButton(grid, 'CLEAR', 'warning', [2, 1]);
            plotControls.ExportButton = obj.createActionButton(grid, 'EXPORT', 'primary', [2, 2]);
        end
        
        function panel = createPlotPanel(obj, uiFigure)
            % Create plot panel with proper configuration
            panel = uipanel(uiFigure);
            panel.Units = 'pixels';
            panel.Position = [obj.DEFAULT_WINDOW_WIDTH + 10, 10, obj.PLOT_WIDTH, obj.DEFAULT_WINDOW_HEIGHT - 20];
            panel.Title = obj.TEXT.MetricsPlotTitle;
            panel.FontSize = obj.LARGE_FONT_SIZE;
            panel.FontWeight = 'bold';
            panel.Visible = 'off';
            panel.AutoResizeChildren = 'on';
        end
        
        function grid = createPlotGrid(obj, panel)
            % Create plot grid layout
            grid = uigridlayout(panel, [2, 2]);
            grid.RowHeight = {'1x', 'fit'};
            grid.ColumnWidth = {'1x', 'fit'};
            
            spacing = foilview_styling.SPACE_2;
            grid.Padding = repmat(spacing, 1, 4);
            grid.RowSpacing = spacing;
            grid.ColumnSpacing = spacing;
        end
        
        function axes = createPlotAxes(obj, grid)
            % Create and configure plot axes
            axes = uiaxes(grid);
            axes.Layout.Row = 1;
            axes.Layout.Column = [1 2];
            
            hold(axes, 'on');
            axes.XGrid = 'on';
            axes.YGrid = 'on';
            xlabel(axes, 'Z Position (μm)');
            ylabel(axes, 'Normalized Metric Value');
            title(axes, 'Metrics vs Z Position');
        end
        
        %% Configuration and Behavior Methods
        
        function configureManualControlBehavior(obj, manualControls)
            % Configure manual control specific behaviors
            manualControls.StepSizes = foilview_controller.STEP_SIZES;
            manualControls.CurrentStepIndex = find(manualControls.StepSizes == foilview_controller.DEFAULT_STEP_SIZE, 1);
            
            selectedStepSize = manualControls.StepSizes(manualControls.CurrentStepIndex);
            manualControls.StepSizeField.Value = selectedStepSize;
        end
        
        %% Generic Component Creation Helpers
        
        function button = createDirectionalButton(obj, parent, text, style, position)
            % Create directional control buttons
            button = obj.createStyledButton(parent, style, text, [], position);
        end
        
        function button = createActionButton(obj, parent, text, style, position)
            % Create action buttons
            button = obj.createStyledButton(parent, style, text, [], position);
        end
        
        function button = createStepButton(obj, parent, text, position, tooltip)
            % Create step control buttons
            colors = foilview_styling.getColors();
            
            button = uibutton(parent, 'push');
            button.Text = text;
            button.FontSize = 11;
            button.FontWeight = 'bold';
            button.Layout.Row = position(1);
            button.Layout.Column = position(2);
            button.Tooltip = tooltip;
            button.BackgroundColor = colors.TextMuted;
            button.FontColor = [1 1 1];
        end
        
        function field = createNumericField(obj, parent, defaultValue, tooltip, position)
            % Create standardized numeric input fields
            field = uieditfield(parent, 'numeric');
            field.Value = defaultValue;
            field.FontSize = obj.FIELD_FONT_SIZE;
            field.Layout.Row = position(1);
            field.Layout.Column = position(2);
            field.Tooltip = tooltip;
        end
        
        function label = createLabel(obj, parent, text, fontSize, fontWeight, fontColor)
            % Create standardized labels
            label = uilabel(parent);
            label.Text = text;
            label.FontSize = fontSize;
            label.FontWeight = fontWeight;
            label.FontColor = fontColor;
        end
        
        function button = createStyledButton(obj, parent, style, text, callback, position)
            % Create styled buttons with consistent approach
            button = uibutton(parent, 'push');
            button.Layout.Row = position(1);
            if length(position) > 1
                button.Layout.Column = position(2);
            end
            if ~isempty(callback)
                button.ButtonPushedFcn = callback;
            end
            
            foilview_styling.styleButton(button, style, 'base');
            if ~isempty(text)
                button.Text = text;
            end
        end
        
        function stepField = createStepSizeField(obj, parent, defaultValue, fontSize, position, tooltip)
            % Create step size field with standard configuration
            stepField = uieditfield(parent, 'numeric');
            stepField.Value = defaultValue;
            stepField.FontSize = fontSize;
            stepField.FontWeight = 'bold';
            stepField.HorizontalAlignment = 'center';
            stepField.Tooltip = tooltip;
            stepField.Limits = [foilview_controller.MIN_STEP_SIZE, foilview_controller.MAX_STEP_SIZE];
            stepField.Layout.Row = position(1);
            if length(position) > 1
                stepField.Layout.Column = position(2);
            end
        end
    end
    
    methods (Static)
        function adjustPlotPosition(uiFigure, plotPanel, plotWidth)
            % Utility method for dynamic plot positioning
            if ~isvalid(uiFigure) || ~isvalid(plotPanel)
                return;
            end
            
            figPos = uiFigure.Position;
            currentHeight = figPos(4);
            expandedWidth = figPos(3);
            mainWindowWidth = expandedWidth - plotWidth - 20;
            
            plotPanelX = mainWindowWidth + 10;
            plotPanelY = 10;
            plotPanelHeight = currentHeight - 20;
            
            plotPanel.Position = [plotPanelX, plotPanelY, plotWidth, plotPanelHeight];
        end
        
        function adjustFontSizes(components, windowSize)
            % Dynamic font size adjustment based on window size
            if nargin < 2 || isempty(windowSize)
                return;
            end
            
            widthScale = windowSize(3) / foilview_ui.DEFAULT_WINDOW_WIDTH;
            heightScale = windowSize(4) / foilview_ui.DEFAULT_WINDOW_HEIGHT;
            overallScale = min(max(sqrt(widthScale * heightScale), 0.7), 1.5);
            
            foilview_ui.adjustPositionDisplayFont(components, overallScale);
            foilview_ui.adjustControlFonts(components, overallScale);
        end
        
        function adjustPositionDisplayFont(components, scale)
            % Adjust position display font specifically
            if isfield(components, 'PositionDisplay') && isfield(components.PositionDisplay, 'Label')
                baseFontSize = foilview_ui.POSITION_FONT_SIZE;
                newFontSize = max(round(baseFontSize * scale), 18);
                try
                    components.PositionDisplay.Label.FontSize = newFontSize;
                catch
                    % Ignore font adjustment errors
                end
            end
        end
        
        function adjustControlFonts(components, scale)
            % Adjust control fonts across all control groups
            if scale == 1.0
                return;
            end
            
            try
                controlGroups = {'AutoControls', 'ManualControls', 'MetricDisplay', 'StatusControls'};
                for i = 1:length(controlGroups)
                    if isfield(components, controlGroups{i})
                        foilview_ui.adjustControlGroupFonts(components.(controlGroups{i}), scale);
                    end
                end
            catch
                % Ignore errors during font adjustment
            end
        end
        
        function adjustControlGroupFonts(controlStruct, scale)
            % Helper to adjust fonts in a specific control group
            if ~isstruct(controlStruct)
                return;
            end
            
            fields = fieldnames(controlStruct);
            for i = 1:length(fields)
                try
                    obj = controlStruct.(fields{i});
                    if isvalid(obj) && isprop(obj, 'FontSize')
                        currentSize = obj.FontSize;
                        newSize = max(round(currentSize * scale), 8);
                        newSize = min(newSize, 16);
                        obj.FontSize = newSize;
                    end
                catch
                    continue;
                end
            end
        end
    end
end 