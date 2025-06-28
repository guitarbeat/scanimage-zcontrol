classdef foilview_ui < handle
    % foilview_ui - Handles creation of all UI components for foilview
    %
    % This class is responsible for creating and configuring all UI components
    % including the main window, tabs, controls, and plot areas. It separates
    % the UI creation logic from the main application logic.
    
    properties (Constant, Access = public)
        % Window Configuration
        MIN_WINDOW_WIDTH = 280   % Minimum window width (pixels)
        MIN_WINDOW_HEIGHT = 380  % Minimum window height (pixels)
        DEFAULT_WINDOW_WIDTH = 320      % Default window width (pixels)
        DEFAULT_WINDOW_HEIGHT = 420     % Default window height (pixels)
        PLOT_WIDTH = 400        % Additional width when plot is expanded
        
        % UI Theme Colors
        COLORS = struct(...
            'Background', [0.95 0.95 0.95], ...  % Light gray background
            'Primary', [0.2 0.6 0.9], ...        % Blue for primary actions
            'Success', [0.2 0.7 0.3], ...        % Green for success states
            'Warning', [0.9 0.6 0.2], ...        % Orange for warnings
            'Danger', [0.9 0.3 0.3], ...         % Red for errors/dangers
            'Light', [0.98 0.98 0.98], ...       % Nearly white for highlights
            'TextMuted', [0.5 0.5 0.5])          % Gray for secondary text
        
        % UI Text
        TEXT = struct(...
            'WindowTitle', 'FoilView - Z-Stage Control', ... % Main window title
            'Ready', 'Ready')                     % Default status message
    end
    
    methods (Static)
        function components = createAllComponents(app)
            % Create all UI components and return component structures
            % Input: app - the main ZStageControlApp instance
            % Output: components - struct containing all UI component references
            
            creator = foilview_ui();
            components = struct();
            
            % Create main window structure
            [components.UIFigure, components.MainPanel, components.MainLayout] = ...
                creator.createMainWindow(app);
            
            % Create component groups
            components.PositionDisplay = creator.createPositionDisplay(components.MainLayout);
            components.MetricDisplay = creator.createMetricDisplay(components.MainLayout);
            components.StatusControls = creator.createStatusBar(components.MainLayout);
            
            % Create control containers (no tabs)
            components.ManualControls = creator.createManualControlContainer(components.MainLayout, app);
            components.AutoControls = creator.createAutoStepContainer(components.MainLayout, app);
            
            % Create expandable plot area
            components.MetricsPlotControls = creator.createMetricsPlotArea(components.UIFigure, app);
            
            % Create expand button
            components.MetricsPlotControls.ExpandButton = creator.createExpandButton(components.MainLayout, app);
            
            components.UIFigure.Visible = 'on';
        end
    end
    
    methods (Access = private)
        function [uiFigure, mainPanel, mainLayout] = createMainWindow(obj, app)
            % Create main figure with resizable functionality
            uiFigure = uifigure('Visible', 'off');
            uiFigure.Units = 'pixels';
            uiFigure.Position = [100 100 obj.DEFAULT_WINDOW_WIDTH obj.DEFAULT_WINDOW_HEIGHT];
            uiFigure.Name = obj.TEXT.WindowTitle;
            uiFigure.Color = obj.COLORS.Background;
            % Note: CloseRequestFcn will be set by main app
            uiFigure.Resize = 'on';  % Enable resizing
            uiFigure.AutoResizeChildren = 'on';  % Enable auto-resize
            
            % Set minimum size constraints (handled by MATLAB's AutoResizeChildren)
            uiFigure.WindowState = 'normal';
            
            % Create main panel that fills the entire figure
            mainPanel = uipanel(uiFigure);
            mainPanel.Units = 'normalized';  % Use normalized units for flexibility
            mainPanel.Position = [0, 0, 1, 1];  % Fill entire figure
            mainPanel.BorderType = 'none';
            mainPanel.BackgroundColor = obj.COLORS.Background;
            mainPanel.AutoResizeChildren = 'on';  % Enable auto-resize for children
            
            % Create main layout that adapts to panel size
            mainLayout = uigridlayout(mainPanel, [6, 1]);
            mainLayout.RowHeight = {'fit', '1x', 'fit', 'fit', 'fit', 'fit'};  % Position display can expand
            mainLayout.ColumnWidth = {'1x'};
            mainLayout.Padding = [8 8 8 8];
            mainLayout.RowSpacing = 6;
            mainLayout.Scrollable = 'on';  % Enable scrolling for very small windows
        end
        
        function metricDisplay = createMetricDisplay(obj, mainLayout)
            % Create metric display panel
            metricPanel = uigridlayout(mainLayout, [1, 3]);
            metricPanel.ColumnWidth = {'fit', '1x', 'fit'};
            metricPanel.Layout.Row = 1;
            
            metricDisplay = struct();
            
            % Metric type dropdown
            metricDisplay.TypeDropdown = uidropdown(metricPanel);
            metricDisplay.TypeDropdown.Items = {'Std Dev', 'Mean', 'Max'};
            metricDisplay.TypeDropdown.Value = 'Std Dev';
            metricDisplay.TypeDropdown.FontSize = 9;
            
            % Metric value label
            metricDisplay.Value = uilabel(metricPanel);
            metricDisplay.Value.Text = 'N/A';
            metricDisplay.Value.FontSize = 12;
            metricDisplay.Value.FontWeight = 'bold';
            metricDisplay.Value.HorizontalAlignment = 'center';
            metricDisplay.Value.BackgroundColor = obj.COLORS.Light;
            
            % Refresh button
            metricDisplay.RefreshButton = uibutton(metricPanel, 'push');
            metricDisplay.RefreshButton.Text = '↻';
            metricDisplay.RefreshButton.FontSize = 11;
        end
        
        function positionDisplay = createPositionDisplay(obj, mainLayout)
            % Create position display panel
            positionPanel = uigridlayout(mainLayout, [2, 1]);
            positionPanel.RowHeight = {'fit', 'fit'};
            positionPanel.RowSpacing = 5;
            positionPanel.Layout.Row = 2;
            
            positionDisplay = struct();
            
            % Position label - responsive font size
            positionDisplay.Label = uilabel(positionPanel);
            positionDisplay.Label.Text = '0.0 μm';
            positionDisplay.Label.FontSize = 28;  % Base size - will be made responsive
            positionDisplay.Label.FontWeight = 'bold';
            positionDisplay.Label.FontName = 'Courier New';
            positionDisplay.Label.HorizontalAlignment = 'center';
            positionDisplay.Label.BackgroundColor = obj.COLORS.Light;
            
            % Status label
            positionDisplay.Status = uilabel(positionPanel);
            positionDisplay.Status.Text = obj.TEXT.Ready;
            positionDisplay.Status.FontSize = 9;
            positionDisplay.Status.HorizontalAlignment = 'center';
            positionDisplay.Status.FontColor = obj.COLORS.TextMuted;
        end
        
        function expandButton = createExpandButton(obj, mainLayout, app)
            % Create expand/collapse button
            expandButton = uibutton(mainLayout, 'push');
            expandButton.Layout.Row = 5;
            expandButton.Text = '📊 Show Plot';
            expandButton.FontSize = 10;
            expandButton.FontWeight = 'bold';
            expandButton.BackgroundColor = obj.COLORS.Primary;
            expandButton.FontColor = [1 1 1];
            % Note: ButtonPushedFcn will be set by main app
        end
        
        function statusControls = createStatusBar(obj, mainLayout)
            statusBar = uigridlayout(mainLayout, [1, 4]);
            statusBar.ColumnWidth = {'1x', 'fit', 'fit', 'fit'};
            statusBar.Layout.Row = 6;
            
            statusControls = struct();
            
            % Status label
            statusControls.Label = uilabel(statusBar);
            statusControls.Label.Text = 'ScanImage: Initializing...';
            statusControls.Label.FontSize = 9;
            
            % Bookmarks button
            statusControls.BookmarksButton = uibutton(statusBar, 'push');
            statusControls.BookmarksButton.Text = '📌';
            statusControls.BookmarksButton.FontSize = 11;
            statusControls.BookmarksButton.FontWeight = 'bold';
            statusControls.BookmarksButton.Tooltip = 'Toggle Bookmarks Window (Open/Close)';
            statusControls.BookmarksButton.BackgroundColor = obj.COLORS.Primary;
            statusControls.BookmarksButton.FontColor = [1 1 1];
            
            % Stage View button
            statusControls.StageViewButton = uibutton(statusBar, 'push');
            statusControls.StageViewButton.Text = '📹';
            statusControls.StageViewButton.FontSize = 11;
            statusControls.StageViewButton.FontWeight = 'bold';
            statusControls.StageViewButton.Tooltip = 'Toggle Stage View Camera Window (Open/Close)';
            statusControls.StageViewButton.BackgroundColor = obj.COLORS.Primary;
            statusControls.StageViewButton.FontColor = [1 1 1];
            
            % Refresh button
            statusControls.RefreshButton = uibutton(statusBar, 'push');
            statusControls.RefreshButton.Text = '↻';
            statusControls.RefreshButton.FontSize = 11;
            statusControls.RefreshButton.FontWeight = 'bold';
        end
        
        function manualControls = createManualControlContainer(obj, mainLayout, app)
            % Create manual control panel
            manualPanel = uipanel(mainLayout);
            manualPanel.Title = 'Manual Control';
            manualPanel.FontSize = 9;
            manualPanel.FontWeight = 'bold';
            manualPanel.Layout.Row = 3;
            
            grid = uigridlayout(manualPanel, [1, 6]);
            
            % Configure grid layout - responsive horizontal layout
            grid.RowHeight = {'fit'};
            grid.ColumnWidth = {'1x', '1x', '2x', '1x', '1x', '2x'};  % Responsive columns
            grid.Padding = [6 4 6 4];
            grid.ColumnSpacing = 4;
            
            manualControls = struct();
            
            % Single row: ▲ ◄ [Step] ► ▼ ZERO
            
            % Up button
            manualControls.UpButton = obj.createStyledButton(grid, ...
                'success', '▲', [], [1, 1]);
            
            % Step size decrease button
            manualControls.StepDownButton = uibutton(grid, 'push');
            manualControls.StepDownButton.Text = '◄';
            manualControls.StepDownButton.FontSize = 11;
            manualControls.StepDownButton.FontWeight = 'bold';
            manualControls.StepDownButton.Layout.Row = 1;
            manualControls.StepDownButton.Layout.Column = 2;
            manualControls.StepDownButton.Tooltip = 'Decrease step size';
            manualControls.StepDownButton.BackgroundColor = obj.COLORS.TextMuted;
            manualControls.StepDownButton.FontColor = [1 1 1];
            
            % Step size display - make it clearly a display, not a button
            stepSizePanel = uipanel(grid);
            stepSizePanel.Layout.Row = 1;
            stepSizePanel.Layout.Column = 3;
            stepSizePanel.BorderType = 'line';
            stepSizePanel.BackgroundColor = obj.COLORS.Light;
            stepSizePanel.BorderWidth = 1;
            stepSizePanel.HighlightColor = [0.8 0.8 0.8];
            
            stepSizeGrid = uigridlayout(stepSizePanel, [1, 1]);
            stepSizeGrid.Padding = [4 2 4 2];  % Slightly larger padding that will scale
            
            manualControls.StepSizeDisplay = uilabel(stepSizeGrid);
            manualControls.StepSizeDisplay.Text = '1.0μm';
            manualControls.StepSizeDisplay.FontSize = 9;
            manualControls.StepSizeDisplay.FontWeight = 'bold';
            manualControls.StepSizeDisplay.FontColor = [0.2 0.2 0.2];
            manualControls.StepSizeDisplay.HorizontalAlignment = 'center';
            manualControls.StepSizeDisplay.Layout.Row = 1;
            manualControls.StepSizeDisplay.Layout.Column = 1;
            
            % Step size increase button
            manualControls.StepUpButton = uibutton(grid, 'push');
            manualControls.StepUpButton.Text = '►';
            manualControls.StepUpButton.FontSize = 11;
            manualControls.StepUpButton.FontWeight = 'bold';
            manualControls.StepUpButton.Layout.Row = 1;
            manualControls.StepUpButton.Layout.Column = 4;
            manualControls.StepUpButton.Tooltip = 'Increase step size';
            manualControls.StepUpButton.BackgroundColor = obj.COLORS.TextMuted;
            manualControls.StepUpButton.FontColor = [1 1 1];
            
            % Down button
            manualControls.DownButton = obj.createStyledButton(grid, ...
                'warning', '▼', [], [1, 5]);
            
            % Zero button - larger and more prominent
            manualControls.ZeroButton = obj.createStyledButton(grid, ...
                'primary', 'ZERO', [], [1, 6]);
            
            % Hidden dropdown for compatibility (controlled by step up/down buttons)
            manualControls.StepSizeDropdown = uidropdown(grid);
            manualControls.StepSizeDropdown.Items = foilview_utils.formatStepSizeItems(foilview_controller.STEP_SIZES);
            manualControls.StepSizeDropdown.Value = foilview_utils.formatPosition(foilview_controller.DEFAULT_STEP_SIZE);
            manualControls.StepSizeDropdown.Visible = 'off'; % Hidden, controlled programmatically
            % Note: ValueChangedFcn will be set by main app
            
            % Store step sizes for cycling
            manualControls.StepSizes = foilview_controller.STEP_SIZES;
            manualControls.CurrentStepIndex = find(manualControls.StepSizes == foilview_controller.DEFAULT_STEP_SIZE, 1);
        end
        
        function autoControls = createAutoStepContainer(obj, mainLayout, app)
            % Create auto step panel
            autoPanel = uipanel(mainLayout);
            autoPanel.Title = 'Auto Step';
            autoPanel.FontSize = 9;
            autoPanel.FontWeight = 'bold';
            autoPanel.Layout.Row = 4;
            
            % Simplified 2-row layout
            grid = uigridlayout(autoPanel, [2, 4]);
            
            % Configure grid layout - responsive and flexible
            grid.RowHeight = {'fit', 'fit'};
            grid.ColumnWidth = {'2x', '1x', '1x', '1x'};  % Responsive columns that scale
            grid.Padding = [8 6 8 8];
            grid.RowSpacing = 6;
            grid.ColumnSpacing = 8;
            
            autoControls = struct();
            
            % Row 1: Simplified layout with readable fonts
            
            % Start/Stop button with direction
            autoControls.StartStopButton = obj.createStyledButton(grid, ...
                'success', 'START ▲', [], [1, 1]);
            
            % Step size field (larger, readable)
            autoControls.StepField = uieditfield(grid, 'numeric');
            autoControls.StepField.Value = foilview_controller.DEFAULT_AUTO_STEP;
            autoControls.StepField.FontSize = 10;
            autoControls.StepField.Layout.Row = 1;
            autoControls.StepField.Layout.Column = 2;
            autoControls.StepField.Tooltip = 'Step size (μm)';
            
            % Steps field (larger, readable)
            autoControls.StepsField = uieditfield(grid, 'numeric');
            autoControls.StepsField.Value = foilview_controller.DEFAULT_AUTO_STEPS;
            autoControls.StepsField.FontSize = 10;
            autoControls.StepsField.Layout.Row = 1;
            autoControls.StepsField.Layout.Column = 3;
            autoControls.StepsField.Tooltip = 'Number of steps';
            
            % Delay field (larger, readable)
            autoControls.DelayField = uieditfield(grid, 'numeric');
            autoControls.DelayField.Value = foilview_controller.DEFAULT_AUTO_DELAY;
            autoControls.DelayField.FontSize = 10;
            autoControls.DelayField.Layout.Row = 1;
            autoControls.DelayField.Layout.Column = 4;
            autoControls.DelayField.Tooltip = 'Delay between steps (seconds)';
            
            % Direction toggle button - hidden, controlled by start button
            autoControls.DirectionButton = obj.createStyledButton(grid, ...
                'success', '▲', [], [2, 4]);
            autoControls.DirectionButton.Tooltip = 'Toggle direction (Up/Down)';
            autoControls.DirectionButton.Visible = 'off';
            
            % Row 2: Simplified status display with better formatting
            statusGrid = uigridlayout(grid, [1, 3]);
            statusGrid.Layout.Row = 2;
            statusGrid.Layout.Column = [1 4];
            statusGrid.ColumnWidth = {'fit', '1x', 'fit'};
            statusGrid.Padding = [0 0 0 0];
            statusGrid.ColumnSpacing = 4;
            
            % Status label
            statusLabel = uilabel(statusGrid);
            statusLabel.Text = 'Ready:';
            statusLabel.FontSize = 10;
            statusLabel.FontWeight = 'bold';
            statusLabel.FontColor = [0.3 0.3 0.3];
            statusLabel.Layout.Column = 1;
            
            % Status display (main text)
            autoControls.StatusDisplay = uilabel(statusGrid);
            autoControls.StatusDisplay.Text = '100.0 μm upward (5.0s)';
            autoControls.StatusDisplay.FontSize = 10;
            autoControls.StatusDisplay.FontColor = [0.4 0.4 0.4];
            autoControls.StatusDisplay.Layout.Column = 2;
            
            % Units labels for clarity
            unitsLabel = uilabel(statusGrid);
            unitsLabel.Text = 'μm × steps @ s';
            unitsLabel.FontSize = 9;
            unitsLabel.FontColor = [0.6 0.6 0.6];
            unitsLabel.Layout.Column = 3;
        end
        
        function metricsPlotControls = createMetricsPlotArea(obj, uiFigure, app)
            metricsPlotControls = struct();
            
            % Create panel for plot area (initially hidden and positioned dynamically)
            metricsPlotControls.Panel = uipanel(uiFigure);
            metricsPlotControls.Panel.Units = 'pixels';
            % Position will be set dynamically when expanded
            metricsPlotControls.Panel.Position = [obj.DEFAULT_WINDOW_WIDTH + 10, 10, obj.PLOT_WIDTH, obj.DEFAULT_WINDOW_HEIGHT - 20];
            metricsPlotControls.Panel.Title = 'Metrics Plot';
            metricsPlotControls.Panel.FontSize = 12;
            metricsPlotControls.Panel.FontWeight = 'bold';
            metricsPlotControls.Panel.Visible = 'off';
            metricsPlotControls.Panel.AutoResizeChildren = 'on';  % Enable auto-resize for plot components
            
            % Create grid layout within the panel
            grid = uigridlayout(metricsPlotControls.Panel, [2, 2]);
            grid.RowHeight = {'1x', 'fit'};
            grid.ColumnWidth = {'1x', 'fit'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 10;
            grid.ColumnSpacing = 10;
            
            % Create axes for the plot
            metricsPlotControls.Axes = uiaxes(grid);
            metricsPlotControls.Axes.Layout.Row = 1;
            metricsPlotControls.Axes.Layout.Column = [1 2];
            
            % Set up the axes
            hold(metricsPlotControls.Axes, 'on');
            metricsPlotControls.Axes.XGrid = 'on';
            metricsPlotControls.Axes.YGrid = 'on';
            xlabel(metricsPlotControls.Axes, 'Z Position (μm)');
            ylabel(metricsPlotControls.Axes, 'Normalized Metric Value');
            title(metricsPlotControls.Axes, 'Metrics vs Z Position');
            
            % Control buttons
            metricsPlotControls.ClearButton = obj.createStyledButton(grid, ...
                'warning', 'CLEAR', [], [2, 1]);
            
            metricsPlotControls.ExportButton = obj.createStyledButton(grid, ...
                'primary', 'EXPORT', [], [2, 2]);
        end
        
        function button = createStyledButton(obj, parent, style, text, callback, position)
            button = uibutton(parent, 'push');
            button.Text = text;
            button.Layout.Row = position(1);
            
            if length(position) > 1
                button.Layout.Column = position(2);
            end
            
            % Note: ButtonPushedFcn will be set by main app if callback provided
            if ~isempty(callback)
                button.ButtonPushedFcn = callback;
            end
            
            % Apply style using centralized utility
            foilview_utils.applyButtonStyle(button, style, text);
        end
        

    end
    
    methods (Static)
        function adjustPlotPosition(uiFigure, plotPanel, plotWidth)
            % Dynamically adjust plot panel position based on main window size
            % This should match the positioning logic used in expandGUI
            if ~isvalid(uiFigure) || ~isvalid(plotPanel)
                return;
            end
            
            % Get current figure dimensions
            figPos = uiFigure.Position;
            currentHeight = figPos(4);
            
            % Calculate the main window width (without plot area)
            expandedWidth = figPos(3);
            mainWindowWidth = expandedWidth - plotWidth - 20; % Remove plot width and padding
            
            % Position plot panel within the expanded window (not as separate window)
            plotPanelX = mainWindowWidth + 10;  % 10px from main area
            plotPanelY = 10;  % 10px from bottom
            plotPanelHeight = currentHeight - 20;  % Leave 10px top and bottom
            
            plotPanel.Position = [plotPanelX, plotPanelY, plotWidth, plotPanelHeight];
        end
        
        function adjustFontSizes(components, windowSize)
            % Dynamically adjust font sizes based on window dimensions
            if nargin < 2 || isempty(windowSize)
                return;
            end
            
            % Calculate scaling factors based on window size vs defaults
            widthScale = windowSize(3) / foilview_ui.DEFAULT_WINDOW_WIDTH;
            heightScale = windowSize(4) / foilview_ui.DEFAULT_WINDOW_HEIGHT;
            overallScale = min(max(sqrt(widthScale * heightScale), 0.7), 1.5); % Limit scaling range
            
            % Adjust position display font (most prominent)
            if isfield(components, 'PositionDisplay') && isfield(components.PositionDisplay, 'Label')
                baseFontSize = 28;
                newFontSize = max(round(baseFontSize * overallScale), 18); % Min 18pt
                try
                    components.PositionDisplay.Label.FontSize = newFontSize;
                catch
                    % Ignore font size errors
                end
            end
            
            % Adjust other component fonts slightly
            if overallScale ~= 1.0
                try
                    % Adjust control font sizes modestly
                    fontFields = {'AutoControls', 'ManualControls', 'MetricDisplay', 'StatusControls'};
                    for i = 1:length(fontFields)
                        if isfield(components, fontFields{i})
                            foilview_ui.adjustControlFonts(components.(fontFields{i}), overallScale);
                        end
                    end
                catch
                    % Ignore errors during font adjustment
                end
            end
        end
        
        function adjustControlFonts(controlStruct, scale)
            % Helper to adjust fonts in a control structure
            if ~isstruct(controlStruct) || scale == 1.0
                return;
            end
            
            fields = fieldnames(controlStruct);
            for i = 1:length(fields)
                try
                    obj = controlStruct.(fields{i});
                    if isvalid(obj) && isprop(obj, 'FontSize')
                        currentSize = obj.FontSize;
                        newSize = max(round(currentSize * scale), 8); % Min 8pt
                        newSize = min(newSize, 16); % Max 16pt for controls
                        obj.FontSize = newSize;
                    end
                catch
                    % Skip invalid objects or properties
                    continue;
                end
            end
        end
    end
end 