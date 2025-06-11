classdef UIComponentFactory < handle
    % UIComponentFactory - Modern factory class for creating UI components
    % Provides consistent styling and layout for FocusGUI application
    
    properties (Constant, Access = private)
        % Design system constants
        COLORS = struct(...
            'Primary', [0.2 0.4 0.8], ...
            'Secondary', [0.6 0.6 0.7], ...
            'Success', [0.2 0.7 0.3], ...
            'Warning', [0.9 0.6 0.1], ...
            'Danger', [0.8 0.2 0.2], ...
            'Background', [0.96 0.96 0.98], ...
            'Surface', [1 1 1], ...
            'Border', [0.8 0.8 0.8], ...
            'Text', [0.2 0.2 0.2], ...
            'TextLight', [0.5 0.5 0.5], ...
            'ActionButton', [0.85 0.95 0.95], ...
            'MonitorButton', [0.85 0.95 0.85], ... 
            'ScanButton', [0.7 0.85 1.0], ...
            'EmergencyButton', [1.0 0.7 0.7], ...
            'MaxFocusButton', [1.0 0.85 0.85] ...
        );
        
        FONTS = struct(...
            'DefaultSize', 11, ...
            'SmallSize', 9, ...
            'LargeSize', 13, ...
            'TitleSize', 15 ...
        );
        
        SPACING = struct(...
            'Small', 5, ...     % Reduced from 8
            'Medium', 8, ...    % Reduced from 15
            'Large', 10, ...    % Reduced from 20
            'XLarge', 15 ...    % Reduced from 25
        );
    end
    
    methods (Static)
        %% Core UI Components
        function panel = createStyledPanel(parent, title, row, column, options)
            % Creates a styled panel with consistent appearance
            arguments
                parent
                title string
                row
                column
                options.BackgroundColor = gui.components.UIComponentFactory.COLORS.Background
                options.FontSize = gui.components.UIComponentFactory.FONTS.DefaultSize
            end
            
            panel = uipanel(parent, ...
                'Title', title, ...
                'FontWeight', 'bold', ...
                'FontSize', options.FontSize, ...
                'BackgroundColor', options.BackgroundColor);
            
            if ~isempty(row)
                panel.Layout.Row = row;
            end
            if ~isempty(column)
                panel.Layout.Column = column;
            end
        end
        
        function label = createStyledLabel(parent, text, row, column, options)
            % Creates a styled label with consistent appearance
            arguments
                parent
                text string
                row
                column
                options.Tooltip string = ""
                options.FontWeight string = "bold"
                options.FontSize = gui.components.UIComponentFactory.FONTS.DefaultSize
                options.FontColor = gui.components.UIComponentFactory.COLORS.Text
                options.HorizontalAlignment string = "left"
                options.VerticalAlignment string = "center"
            end
            
            label = uilabel(parent, ...
                'Text', text, ...
                'FontWeight', options.FontWeight, ...
                'FontSize', options.FontSize, ...
                'FontColor', options.FontColor, ...
                'HorizontalAlignment', options.HorizontalAlignment, ...
                'VerticalAlignment', options.VerticalAlignment);
            
            if options.Tooltip ~= ""
                label.Tooltip = options.Tooltip;
            end
            
            if ~isempty(row)
                label.Layout.Row = row;
            end
            if ~isempty(column)
                label.Layout.Column = column;
            end
        end
        
        function edit = createStyledEditField(parent, row, column, options)
            % Creates a styled numeric edit field
            arguments
                parent
                row
                column
                options.Value = 0
                options.Format string = "%.1f"
                options.Tooltip string = ""
                options.FontSize = gui.components.UIComponentFactory.FONTS.DefaultSize
                options.BackgroundColor = gui.components.UIComponentFactory.COLORS.Surface
                options.Width = []
            end
            
            edit = uieditfield(parent, 'numeric', ...
                'Value', options.Value, ...
                'HorizontalAlignment', 'center', ...
                'FontSize', options.FontSize, ...
                'ValueDisplayFormat', options.Format, ...
                'AllowEmpty', 'on', ...
                'BackgroundColor', options.BackgroundColor);
            
            if options.Tooltip ~= ""
                edit.Tooltip = options.Tooltip;
            end
            
            if ~isempty(row)
                edit.Layout.Row = row;
            end
            if ~isempty(column)
                edit.Layout.Column = column;
            end
            
            if ~isempty(options.Width)
                edit.Layout.Width = options.Width;
            end
        end
        
        function btn = createStyledButton(parent, text, row, column, callback, options)
            % Creates a styled button with consistent appearance
            arguments
                parent
                text string
                row
                column
                callback function_handle
                options.Tooltip string = ""
                options.BackgroundColor = [0.9 0.9 0.95]
                options.FontSize = gui.components.UIComponentFactory.FONTS.DefaultSize
                options.Enable string = "on"
                options.Icon string = ""
                options.Width = []
                options.HorizontalAlignment string = "center"
            end
            
            if options.Icon ~= ""
                displayText = sprintf('%s %s', options.Icon, text);
            else
                displayText = text;
            end
            
            btn = uibutton(parent, ...
                'Text', displayText, ...
                'FontSize', options.FontSize, ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', callback, ...
                'BackgroundColor', options.BackgroundColor, ...
                'Enable', options.Enable, ...
                'HorizontalAlignment', options.HorizontalAlignment);
            
            if options.Tooltip ~= ""
                btn.Tooltip = options.Tooltip;
            end
            
            if ~isempty(row)
                btn.Layout.Row = row;
            end
            if ~isempty(column)
                btn.Layout.Column = column;
            end
            
            if ~isempty(options.Width)
                btn.Layout.Width = options.Width;
            end
        end
        
        function panel = createValueBox(parent, row, column, options)
            % Creates a styled value display box
            arguments
                parent
                row
                column
                options.BackgroundColor = gui.components.UIComponentFactory.COLORS.Surface
                options.BorderType string = "line"
            end
            
            panel = uipanel(parent, ...
                'BorderType', options.BorderType, ...
                'BackgroundColor', options.BackgroundColor);
            
            if ~isempty(row)
                panel.Layout.Row = row;
            end
            if ~isempty(column)
                panel.Layout.Column = column;
            end
        end
        
        %% Specialized Panels
        function createInstructionPanel(parent, grid)
            % Creates an informative instruction panel
            htmlContent = gui.components.UIComponentFactory.buildInstructionHTML();
            
            instructText = uilabel(grid, ...
                'Text', htmlContent, ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'top', ...
                'Interpreter', 'html');
            instructText.Layout.Row = 1;
            instructText.Layout.Column = 1;
        end
        
        function components = createScanParametersPanel(parent, paramPanel, controller)
            % Creates the scan parameters panel with all controls
            paramGrid = gui.components.UIComponentFactory.setupParameterGrid(paramPanel);
            
            % Create components
            components = struct();
            [components.stepSizeSlider, components.stepSizeValue] = ...
                gui.components.UIComponentFactory.createStepSizeControls(paramGrid, paramPanel, controller);
            
            gui.components.UIComponentFactory.createSeparator(paramGrid, paramPanel);
            
            components.pauseTimeEdit = gui.components.UIComponentFactory.createPauseTimeControl(paramGrid, controller);
            components.metricDropDown = gui.components.UIComponentFactory.createMetricControl(paramGrid);
            
            % Use RangeSlider for Z limits instead of separate controls
            components.zRangeSlider = gui.components.UIComponentFactory.createZRangeSlider(paramGrid, controller);
            
            % Keep minZEdit and maxZEdit properties for backward compatibility
            components.minZEdit = components.zRangeSlider.MinValueField;
            components.maxZEdit = components.zRangeSlider.MaxValueField;
        end
        
        function currentZLabel = createZControlPanel(parent, zControlPanel, controller)
            % Creates Z-axis control panel
            zControlGrid = uigridlayout(zControlPanel, [3, 2]);
            zControlGrid.RowHeight = {'fit', '1x', 'fit'};
            zControlGrid.ColumnWidth = {'1x', '1x'};
            zControlGrid.Padding = [8 8 8 8];        % Reduced padding
            zControlGrid.RowSpacing = 6;             % Reduced spacing
            zControlGrid.ColumnSpacing = 8;          % Reduced spacing
            
            % Current Z position display
            gui.components.UIComponentFactory.createStyledLabel(zControlGrid, 'Current Z Position (µm):', 1, [1 2], ...
                Tooltip="Current Z stage position", ...
                HorizontalAlignment="center");
            
            currentZLabel = gui.components.UIComponentFactory.createZPositionDisplay(zControlGrid);
            gui.components.UIComponentFactory.createZMovementButtons(zControlGrid, controller);
        end
        
        function axes = createPlotPanel(plotPanel)
            % Creates the brightness plot panel
            plotGrid = uigridlayout(plotPanel, [1, 1]);
            plotGrid.Padding = [8 8 8 8];  % Reduced padding
            
            axes = uiaxes(plotGrid);
            gui.components.UIComponentFactory.stylePlotAxes(axes);
        end
        
        function buttons = createActionPanel(parent, actionPanel, controller)
            % Creates the main action control panel
            actionGrid = uigridlayout(actionPanel, [1, 4]);
            actionGrid.RowHeight = {'1x'};
            actionGrid.ColumnWidth = {'1x', '1x', '1x', '0.8x'};
            actionGrid.Padding = [12 15 12 15];
            actionGrid.ColumnSpacing = 15;
            
            buttons = struct();
            
            % Main scanning controls
            [buttons.monitorToggle, buttons.zScanToggle, buttons.moveToMaxButton] = ...
                gui.components.UIComponentFactory.createScanControls(actionGrid, actionPanel, controller);
            
            % ScanImage controls
            [buttons.focusButton, buttons.grabButton, buttons.abortButton] = ...
                gui.components.UIComponentFactory.createScanImageControls(actionGrid, controller);
        end
        
        function [statusText, statusBar] = createStatusBar(hFig)
            % Creates a modern status bar
            statusBar = uipanel(hFig, ...
                'BorderType', 'none', ...
                'BackgroundColor', [0.92 0.92 0.95], ...
                'Position', [0 0 hFig.Position(3) 25]);
            
            statusText = uilabel(statusBar, ...
                'Text', 'Ready', ...
                'Position', [10 4 statusBar.Position(3)-20 18], ...
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize, ...
                'FontColor', gui.components.UIComponentFactory.COLORS.TextLight);
            
            % Top border line
            uipanel(statusBar, ...
                'BorderType', 'line', ...
                'HighlightColor', gui.components.UIComponentFactory.COLORS.Border, ...
                'Position', [0 24 statusBar.Position(3) 1]);
        end
        
        %% Tab UI Components
        function tabGroup = createModeTabGroup(parent, row, column, options)
            % Creates a TabGroup for organizing different focus mode UIs
            arguments
                parent
                row
                column
                options.BackgroundColor = gui.components.UIComponentFactory.COLORS.Background
                options.Padding = [0 0 0 0]
            end
            
            % Create a container panel for the TabGroup
            tabContainer = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', options.BackgroundColor);
            
            if ~isempty(row)
                tabContainer.Layout.Row = row;
            end
            if ~isempty(column)
                tabContainer.Layout.Column = column;
            end
            
            % Create the TabGroup
            tabGroup = uitabgroup(tabContainer);
        end
        
        function tab = createModeTab(tabGroup, title, options)
            % Creates a tab for a specific focus mode
            arguments
                tabGroup
                title string
                options.BackgroundColor = gui.components.UIComponentFactory.COLORS.Background
                options.Tooltip string = ""
            end
            
            tab = uitab(tabGroup, 'Title', title, 'BackgroundColor', options.BackgroundColor);
            
            if options.Tooltip ~= ""
                tab.Tooltip = options.Tooltip;
            end
        end
        
        function [grid, panel] = createTabPanel(tab, title, rows, columns, options)
            % Creates a panel within a tab with a grid layout
            arguments
                tab
                title string
                rows = 1
                columns = 1
                options.BackgroundColor = gui.components.UIComponentFactory.COLORS.Background
                options.RowHeight = {'1x'}
                options.ColumnWidth = {'1x'}
                options.Padding = [10 10 10 10]
                options.RowSpacing = 10
                options.ColumnSpacing = 10
            end
            
            % Create panel inside the tab
            panel = gui.components.UIComponentFactory.createStyledPanel(tab, title, [], []);
            
            % Create grid inside the panel
            grid = uigridlayout(panel, [rows, columns]);
            grid.RowHeight = options.RowHeight;
            grid.ColumnWidth = options.ColumnWidth;
            grid.Padding = options.Padding;
            grid.RowSpacing = options.RowSpacing;
            grid.ColumnSpacing = options.ColumnSpacing;
        end
        
        %% Mode-Specific Panels
        function components = createManualFocusTab(tab, controller)
            % Creates all components for the Manual Focus tab
            
            % Create main grid layout for the tab
            manualGrid = uigridlayout(tab, [2, 1]);
            manualGrid.RowHeight = {'0.4x', '0.6x'};
            manualGrid.ColumnWidth = {'1x'};
            manualGrid.Padding = [8 8 8 8];     % Reduced padding
            manualGrid.RowSpacing = 8;          % Reduced spacing
            
            % Z Movement Controls Panel
            zControlPanel = gui.components.UIComponentFactory.createStyledPanel(manualGrid, 'Z Movement Controls', 1, 1);
            currentZLabel = gui.components.UIComponentFactory.createZControlPanel(manualGrid, zControlPanel, controller);
            
            % Monitor Button Panel
            manualActionPanel = gui.components.UIComponentFactory.createStyledPanel(manualGrid, 'Manual Actions', 2, 1);
            
            % Create grid for manual action buttons
            manualActionGrid = uigridlayout(manualActionPanel, [1, 1]);
            manualActionGrid.RowHeight = {'1x'};
            manualActionGrid.ColumnWidth = {'1x'};
            manualActionGrid.Padding = [8 8 8 8];  % Reduced padding
            
            % Create Monitor button
            monitorToggle = uibutton(manualActionGrid, 'state', ...
                'Text', '👁️ Monitor Brightness', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.LargeSize, ...
                'FontWeight', 'bold', ...
                'Tooltip', 'Start/stop real-time brightness monitoring while you manually move Z stage', ...
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.MonitorButton, ...
                'HorizontalAlignment', 'center');
            
            % Return all components
            components = struct(...
                'ZControlPanel', zControlPanel, ...
                'CurrentZLabel', currentZLabel, ...
                'ManualActionPanel', manualActionPanel, ...
                'MonitorToggle', monitorToggle);
        end
        
        function components = createAutoFocusTab(tab, controller)
            % Creates all components for the Auto Focus tab
            
            % Create main grid layout for the tab
            autoGrid = uigridlayout(tab, [2, 1]);
            autoGrid.RowHeight = {'0.6x', '0.4x'};
            autoGrid.ColumnWidth = {'1x'};
            autoGrid.Padding = [8 8 8 8];     % Reduced padding
            autoGrid.RowSpacing = 8;          % Reduced spacing
            
            % Z-Scan Parameters Panel
            paramPanel = gui.components.UIComponentFactory.createStyledPanel(autoGrid, 'Z-Scan Parameters', 1, 1);
            paramComponents = gui.components.UIComponentFactory.createScanParametersPanel(paramPanel, paramPanel, controller);
            
            % Auto Z-Scan Buttons Panel
            autoActionPanel = gui.components.UIComponentFactory.createStyledPanel(autoGrid, 'Auto Focus Actions', 2, 1);
            
            % Create grid for auto action buttons
            autoActionGrid = uigridlayout(autoActionPanel, [1, 2]);
            autoActionGrid.RowHeight = {'1x'};
            autoActionGrid.ColumnWidth = {'1x', '1x'};
            autoActionGrid.Padding = [8 8 8 8];      % Reduced padding
            autoActionGrid.ColumnSpacing = 10;       % Reduced spacing
            
            % Create Auto Z-Scan button
            zScanToggle = uibutton(autoActionGrid, 'state', ...
                'Text', '🔍 Auto Z-Scan', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.LargeSize, ...
                'FontWeight', 'bold', ...
                'Tooltip', 'Start automatic Z scan to find focus - scans through Z range and records brightness', ...
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.ScanButton, ...
                'Enable', 'off', ...
                'HorizontalAlignment', 'center');
            zScanToggle.Layout.Row = 1;
            zScanToggle.Layout.Column = 1;
            
            % Create Move to Max button
            moveToMaxButton = uibutton(autoActionGrid, ...
                'Text', '⬆️ Move to Max Focus', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.LargeSize, ...
                'FontWeight', 'bold', ...
                'Tooltip', 'Move to the Z position with maximum brightness (best focus)', ...
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.MaxFocusButton, ...
                'Enable', 'off', ...
                'HorizontalAlignment', 'center');
            moveToMaxButton.Layout.Row = 1;
            moveToMaxButton.Layout.Column = 2;
            
            % Return all components
            components = struct(...
                'StepSizeSlider', paramComponents.stepSizeSlider, ...
                'StepSizeValue', paramComponents.stepSizeValue, ...
                'PauseTimeEdit', paramComponents.pauseTimeEdit, ...
                'MetricDropDown', paramComponents.metricDropDown, ...
                'MinZEdit', paramComponents.minZEdit, ...
                'MaxZEdit', paramComponents.maxZEdit, ...
                'ZScanToggle', zScanToggle, ...
                'MoveToMaxButton', moveToMaxButton);
        end
        
        function components = createScanImageControlPanel(parent, row, column, controller)
            % Creates the ScanImage control panel with improved integration
            actionPanel = gui.components.UIComponentFactory.createStyledPanel(parent, 'ScanImage Controls', row, column, ...
                BackgroundColor=[0.94 0.96 0.98]); % Slightly different background to distinguish
            
            % Create action panel grid with improved spacing
            actionGrid = uigridlayout(actionPanel, [1, 3]);  % Changed from 2x2 to 1x3
            actionGrid.RowHeight = {'1x'};
            actionGrid.ColumnWidth = {'1x', '1x', '1x'};
            actionGrid.Padding = [8 8 8 8];        % Reduced padding
            actionGrid.ColumnSpacing = 8;          % Reduced spacing
            
            % Focus Button - using state button
            focusButton = uibutton(actionGrid, 'state', ...
                'Text', '🔄 Focus', ...            % Shortened text
                'ValueChangedFcn', [], ... % Will be set by FocusGUI
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.ActionButton, ...
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize+1, ... % Reduced font size
                'Tooltip', 'Start Focus mode in ScanImage (continuous scanning)', ...
                'HorizontalAlignment', 'center');
            focusButton.Layout.Row = 1;
            focusButton.Layout.Column = 1;
            
            % Grab Button - using state button
            grabButton = uibutton(actionGrid, 'state', ...
                'Text', '📷 Grab', ...             % Shortened text
                'Value', false, ... % Initial state is off
                'ValueChangedFcn', [], ... % Will be set by FocusGUI
                'BackgroundColor', [0.95 0.95 0.85], ...
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize+1, ... % Reduced font size
                'Tooltip', 'Grab a single frame in ScanImage (snapshot)', ...
                'HorizontalAlignment', 'center');
            grabButton.Layout.Row = 1;
            grabButton.Layout.Column = 2;
            
            % Abort Button - full width across the bottom when shown
            abortButton = uibutton(actionGrid, ...
                'Text', '❌ ABORT', ...
                'Tooltip', 'Abort all operations immediately', ...
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.EmergencyButton, ...
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize+1, ... % Reduced font size
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center');
            abortButton.Layout.Row = 1;
            abortButton.Layout.Column = 3;
            abortButton.Visible = 'off';
            
            % Return all components
            components = struct(...
                'Panel', actionPanel, ...
                'FocusButton', focusButton, ...
                'GrabButton', grabButton, ...
                'AbortButton', abortButton);
        end
        
        function [container, plotAxes, toggleButton, plotPanel] = createCollapsiblePlotPanel(parent, row, column)
            % Creates a collapsible plot panel with improved toggle button
            plotContainer = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', [0.95 0.95 0.98]);
            plotContainer.Layout.Row = row;
            plotContainer.Layout.Column = column;
            
            % Create a grid for the plot and its controls - header always visible
            plotContainerGrid = uigridlayout(plotContainer, [2, 1]);
            plotContainerGrid.RowHeight = {'fit', '1x'};
            plotContainerGrid.ColumnWidth = {'1x'};
            plotContainerGrid.Padding = [0 0 0 0];
            plotContainerGrid.RowSpacing = 0; % Reduced spacing for seamless appearance
            
            % Create a header panel with title and toggle button
            plotHeaderPanel = uipanel(plotContainerGrid, 'BorderType', 'line', 'BackgroundColor', [0.94 0.96 0.98]);
            plotHeaderPanel.Layout.Row = 1;
            plotHeaderPanel.Layout.Column = 1;
            
            % Create grid for header contents
            plotHeaderGrid = uigridlayout(plotHeaderPanel, [1, 2]);  % Changed from 3 columns to 2
            plotHeaderGrid.RowHeight = {'fit'};
            plotHeaderGrid.ColumnWidth = {'1x', 'fit'};
            plotHeaderGrid.Padding = [5 5 5 5];  % Reduced padding
            plotHeaderGrid.ColumnSpacing = 5;    % Reduced spacing
            
            % Plot title with icon
            plotTitle = uilabel(plotHeaderGrid, ...
                'Text', '📊 Brightness vs. Z-Position', ...  % Combined icon and title
                'FontWeight', 'bold', ...
                'FontSize', 12);
            plotTitle.Layout.Row = 1;
            plotTitle.Layout.Column = 1;
            
            % Toggle button for plot visibility - improved styling
            toggleButton = uibutton(plotHeaderGrid, ...
                'Text', '◀', ...
                'FontSize', 14, ...
                'BackgroundColor', [0.9 0.9 0.95], ...
                'Tooltip', 'Hide plot panel');
            toggleButton.Layout.Row = 1;
            toggleButton.Layout.Column = 2;
            
            % Plot panel
            plotPanel = uipanel(plotContainerGrid, 'BorderType', 'line', 'BackgroundColor', [1 1 1]);
            plotPanel.Layout.Row = 2;
            plotPanel.Layout.Column = 1;
            
            % Create plot area
            plotAxes = gui.components.UIComponentFactory.createPlotPanel(plotPanel);
            
            % Return the container and plot axes
            container = plotContainer;
        end
    end
    
    methods (Static, Access = private)
        %% Helper Methods
        function htmlContent = buildInstructionHTML()
            % Builds HTML content for instructions
            htmlContent = [ ...
                '<html><body style="margin:0; padding:0;">' ...
                '<div style="background-color:#e6f7ff; padding:10px; border-radius:5px; border:1px solid #4da6ff;">' ...
                '<p><b style="font-size:14px; color:#0066cc;">AUTOMATIC FOCUS FINDING:</b></p>' ...
                '<p>1. Set <b>Step Size</b> (8-15μm recommended)</p>' ...
                '<p>2. Press <b>Auto Z-Scan</b> to automatically scan through Z positions</p>' ...
                '<p>3. When scan completes, press <b>Move to Max Focus</b> to jump to best focus</p>' ...
                '<p><b style="font-size:14px; color:#0066cc;">MANUAL FOCUS FINDING:</b></p>' ...
                '<p>1. Press <b>Monitor Brightness</b> to track brightness in real-time</p>' ...
                '<p>2. Use <b>Up/Down</b> buttons to move while watching the brightness plot</p>' ...
                '</div></body></html>' ...
            ];
        end
        
        function paramGrid = setupParameterGrid(paramPanel)
            % Sets up the main parameter grid layout
            paramGrid = uigridlayout(paramPanel, [6, 4]);
            paramGrid.RowHeight = {'fit', '0.3x', 'fit', 'fit', 'fit', '1x'};
            paramGrid.ColumnWidth = {'fit', '1.5x', 'fit', '1x'};
            paramGrid.Padding = [8 10 8 10];  % Reduced padding
            paramGrid.RowSpacing = 6;         % Reduced spacing
            paramGrid.ColumnSpacing = 8;      % Reduced spacing
        end
        
        function [stepSizeSlider, stepSizeValue] = createStepSizeControls(paramGrid, paramPanel, controller)
            % Creates step size slider and value display
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Step Size (µm):', 1, 1, ...
                Tooltip="Set the Z scan step size in micrometers", ...
                FontSize=gui.components.UIComponentFactory.FONTS.DefaultSize+1);
            
            % Slider container
            sliderPanel = uipanel(paramGrid, 'BorderType', 'none', 'BackgroundColor', paramPanel.BackgroundColor);
            sliderPanel.Layout.Row = 1;
            sliderPanel.Layout.Column = [2 3];
            
            [stepSizeSlider, stepSizeValue] = gui.components.UIComponentFactory.createSliderWithTicks(sliderPanel, paramGrid, controller);
        end
        
        function [stepSizeSlider, stepSizeValue] = createSliderWithTicks(sliderPanel, paramGrid, controller)
            % Creates slider with custom tick marks
            sliderGrid = uigridlayout(sliderPanel, [2, 1]);
            sliderGrid.RowHeight = {'1x', '0.3x'};
            sliderGrid.ColumnWidth = {'1x'};
            sliderGrid.Padding = [0 0 0 0];
            sliderGrid.RowSpacing = 0;
            
            stepSizeSlider = uislider(sliderGrid, ...
                'Limits', [1 50], ...
                'Value', controller.params.initialStepSize, ...
                'MajorTicks', [1 8 15 22 29 36 43 50], ...
                'MinorTicks', [], ...
                'Tooltip', 'Set the Z scan step size in micrometers (8-15μm recommended)');
            stepSizeSlider.Layout.Row = 1;
            stepSizeSlider.Layout.Column = 1;
            
            gui.components.UIComponentFactory.createTickLabels(sliderGrid);
            
            % Value display
            valuePanel = gui.components.UIComponentFactory.createValueBox(paramGrid, 1, 4);
            valueGrid = uigridlayout(valuePanel, [1, 1]);
            valueGrid.Padding = [5 5 5 5];  % Added padding for better appearance
            
            stepSizeValue = uilabel(valueGrid, ...
                'Text', num2str(controller.params.initialStepSize), ...
                'HorizontalAlignment', 'center', ...
                'FontWeight', 'bold', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.LargeSize);
        end
        
        function createTickLabels(sliderGrid)
            % Creates tick labels for slider
            tickPanel = uipanel(sliderGrid, 'BorderType', 'none');
            tickPanel.Layout.Row = 2;
            tickPanel.Layout.Column = 1;
            
            tickGrid = uigridlayout(tickPanel, [1, 8]);
            tickGrid.RowHeight = {'1x'};
            tickGrid.ColumnWidth = repmat({1}, 1, 8);
            tickGrid.Padding = [0 0 0 0];
            
            tickValues = [1, 8, 15, 22, 29, 36, 43, 50];
            for i = 1:length(tickValues)
                uilabel(tickGrid, 'Text', num2str(tickValues(i)), ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', gui.components.UIComponentFactory.FONTS.SmallSize);
            end
        end
        
        function createSeparator(paramGrid, paramPanel)
            % Creates visual separator
            separatorPanel = uipanel(paramGrid, ...
                'BorderType', 'line', ...
                'BackgroundColor', paramPanel.BackgroundColor, ...
                'HighlightColor', gui.components.UIComponentFactory.COLORS.Border);
            separatorPanel.Layout.Row = 2;
            separatorPanel.Layout.Column = [1 4];
            
            % Add section label for better organization
            sectionLabel = uilabel(paramGrid, ...
                'Text', 'Scan Settings', ...
                'FontWeight', 'bold', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize, ...
                'HorizontalAlignment', 'left');
            sectionLabel.Layout.Row = 3;
            sectionLabel.Layout.Column = 1;
        end
        
        function pauseTimeEdit = createPauseTimeControl(paramGrid, controller)
            % Creates pause time control
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Pause Time (sec):', 4, 1, ...
                Tooltip="Pause duration between Z steps (seconds)");
            
            pauseTimeEdit = gui.components.UIComponentFactory.createStyledEditField(paramGrid, 4, 2, ...
                Value=controller.scanPauseTime, Format="%.1f", ...
                Tooltip="Pause duration between Z steps (seconds)");
        end
        
        function metricDropDown = createMetricControl(paramGrid)
            % Creates brightness metric dropdown
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Brightness Metric:', 4, 3, ...
                Tooltip="Select brightness calculation method");
            
            metricDropDown = uidropdown(paramGrid, ...
                'Items', {'Mean', 'Median', 'Max', '95th Percentile'}, ...
                'Value', 'Mean', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize, ...
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.Surface, ...
                'Tooltip', 'Select method to calculate brightness (Mean is most common)');
            metricDropDown.Layout.Row = 4;
            metricDropDown.Layout.Column = 4;
        end
        
        function rangeSliderComponents = createZRangeSlider(paramGrid, controller)
            % Creates Z limit controls using a RangeSlider
            %
            % This uses the App Designer RangeSlider component for more intuitive
            % control of Z scan range limits.
            
            % Z Range section header
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Z Scan Range (µm):', 5, 1, ...
                Tooltip="Set the range for Z scanning", ...
                FontSize=gui.components.UIComponentFactory.FONTS.DefaultSize, ...
                FontWeight="bold");
            
            % Container panel for range slider components
            rangePanel = uipanel(paramGrid, 'BorderType', 'none', 'BackgroundColor', paramGrid.Parent.BackgroundColor);
            rangePanel.Layout.Row = 6;
            rangePanel.Layout.Column = [1 4];
            
            % Create grid layout for range slider components
            rangeGrid = uigridlayout(rangePanel, [2, 4]);  % Changed from 3 rows to 2
            rangeGrid.RowHeight = {'1x', 'fit'};
            rangeGrid.ColumnWidth = {'fit', '1x', 'fit', '1x'};
            rangeGrid.Padding = [5 8 5 8];       % Reduced padding
            rangeGrid.RowSpacing = 6;            % Reduced spacing
            rangeGrid.ColumnSpacing = 8;         % Reduced spacing
            
            % Create the range slider
            % Get current Z limits from controller if available
            try
                minZ = controller.getZLimit('min');
                maxZ = controller.getZLimit('max');
                
                % Use reasonable defaults if limits are infinite
                if isinf(minZ) || isnan(minZ)
                    minZ = -100;
                end
                if isinf(maxZ) || isnan(maxZ)
                    maxZ = 100;
                end
            catch
                % Default values if controller doesn't have limits
                minZ = -100;
                maxZ = 100;
            end
            
            % Create the range slider
            sliderRange = [minZ, maxZ];
            rangeSlider = uislider(rangeGrid, 'range', ...
                'Limits', sliderRange, ...
                'Value', [0, 50], ...
                'MajorTicks', linspace(sliderRange(1), sliderRange(2), 5), ...
                'MinorTicks', [], ...
                'Tooltip', 'Set the minimum and maximum Z positions for scanning', ...
                'ValueChangedFcn', @(src,event) onRangeSliderChanged(src, event, controller));
            rangeSlider.Layout.Row = 1;
            rangeSlider.Layout.Column = [1 4];
            
            % Create value display fields with set buttons next to them
            gui.components.UIComponentFactory.createStyledLabel(rangeGrid, 'Min:', 2, 1, ...  % Changed label text
                Tooltip="Minimum Z position for scanning");
            minValueField = gui.components.UIComponentFactory.createStyledEditField(rangeGrid, 2, 2, ...
                Value=rangeSlider.Value(1), Format="%.1f", ...
                Tooltip="Minimum Z position for scanning");
            
            gui.components.UIComponentFactory.createStyledLabel(rangeGrid, 'Max:', 2, 3, ...  % Changed label text
                Tooltip="Maximum Z position for scanning");
            maxValueField = gui.components.UIComponentFactory.createStyledEditField(rangeGrid, 2, 4, ...
                Value=rangeSlider.Value(2), Format="%.1f", ...
                Tooltip="Maximum Z position for scanning");
            
            % Set up callbacks for value fields
            minValueField.ValueChangedFcn = @(src,~) updateRangeSliderLow(src, rangeSlider, controller);
            maxValueField.ValueChangedFcn = @(src,~) updateRangeSliderHigh(src, rangeSlider, controller);
            
            % Create set limit buttons (moved to context menu)
            minValueField.ContextMenu = uicontextmenu(rangeGrid.Parent.Parent.Parent);
            uimenu(minValueField.ContextMenu, 'Text', 'Set to Current Z', ...
                'MenuSelectedFcn', @(~,~) setCurrentAsMin(controller, rangeSlider, minValueField));
            
            maxValueField.ContextMenu = uicontextmenu(rangeGrid.Parent.Parent.Parent);
            uimenu(maxValueField.ContextMenu, 'Text', 'Set to Current Z', ...
                'MenuSelectedFcn', @(~,~) setCurrentAsMax(controller, rangeSlider, maxValueField));
            
            % Package all components into a struct for return
            rangeSliderComponents = struct(...
                'RangeSlider', rangeSlider, ...
                'MinValueField', minValueField, ...
                'MaxValueField', maxValueField);
            
            % Nested callback functions
            function onRangeSliderChanged(src, event, controller)
                % Update edit fields when slider changes
                try
                    minValueField.Value = src.Value(1);
                    maxValueField.Value = src.Value(2);
                catch
                    % Ignore errors during update
                end
            end
            
            function updateRangeSliderLow(src, slider, controller)
                % Update slider when min edit field changes
                try
                    newMin = src.Value;
                    currentMax = slider.Value(2);
                    
                    % Ensure min < max
                    if newMin >= currentMax
                        newMin = currentMax - 1;
                        src.Value = newMin;
                    end
                    
                    slider.Value = [newMin, currentMax];
                catch
                    % Ignore errors during update
                end
            end
            
            function updateRangeSliderHigh(src, slider, controller)
                % Update slider when max edit field changes
                try
                    currentMin = slider.Value(1);
                    newMax = src.Value;
                    
                    % Ensure max > min
                    if newMax <= currentMin
                        newMax = currentMin + 1;
                        src.Value = newMax;
                    end
                    
                    slider.Value = [currentMin, newMax];
                catch
                    % Ignore errors during update
                end
            end
            
            function setCurrentAsMin(controller, slider, valueField)
                % Set current Z position as minimum
                try
                    currentZ = controller.getZ();
                    valueField.Value = currentZ;
                    updateRangeSliderLow(valueField, slider, controller);
                    
                    % Call controller to set limit in ScanImage
                    controller.setMinZLimit(currentZ);
                catch ME
                    warning('Error setting minimum Z limit: %s', ME.message);
                end
            end
            
            function setCurrentAsMax(controller, slider, valueField)
                % Set current Z position as maximum
                try
                    currentZ = controller.getZ();
                    valueField.Value = currentZ;
                    updateRangeSliderHigh(valueField, slider, controller);
                    
                    % Call controller to set limit in ScanImage
                    controller.setMaxZLimit(currentZ);
                catch ME
                    warning('Error setting maximum Z limit: %s', ME.message);
                end
            end
        end
        
        function currentZLabel = createZPositionDisplay(zControlGrid)
            % Creates Z position display
            zPosPanel = uipanel(zControlGrid, ...
                'BorderType', 'line', ...
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.Surface);
            zPosPanel.Layout.Row = 2;
            zPosPanel.Layout.Column = [1 2];
            
            zPosValueGrid = uigridlayout(zPosPanel, [1, 1]);
            zPosValueGrid.Padding = [5 5 5 5];  % Added padding
            
            currentZLabel = uilabel(zPosValueGrid, ...
                'Text', '0.0', ...
                'HorizontalAlignment', 'center', ...
                'FontWeight', 'bold', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.TitleSize, ...
                'FontColor', gui.components.UIComponentFactory.COLORS.Primary);
        end
        
        function createZMovementButtons(zControlGrid, controller)
            % Creates Z movement buttons
            upBtn = gui.components.UIComponentFactory.createStyledButton(zControlGrid, 'Move Up', 3, 1, ...
                @(~,~) controller.moveZUp(), ...
                Tooltip="Move Z stage up (decrease Z value)", ...
                BackgroundColor=[0.8 1.0 0.8], Icon="▲", ...
                HorizontalAlignment="center");
            
            downBtn = gui.components.UIComponentFactory.createStyledButton(zControlGrid, 'Move Down', 3, 2, ...
                @(~,~) controller.moveZDown(), ...
                Tooltip="Move Z stage down (increase Z value)", ...
                BackgroundColor=[0.8 0.8 1.0], Icon="▼", ...
                HorizontalAlignment="center");
        end
        
        function stylePlotAxes(axes)
            % Applies consistent styling to plot axes
            grid(axes, 'on');
            box(axes, 'on');
            xlabel(axes, 'Z (µm)', 'FontWeight', 'bold', ...  % Shortened label
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize);
            ylabel(axes, 'Brightness', 'FontWeight', 'bold', ...  % Shortened label
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize);
            title(axes, 'Z-Scan Profile', 'FontWeight', 'bold', ...  % Shortened title
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize+1);
            axes.GridAlpha = 0.3;
            axes.LineWidth = 1.2;
            axes.XLim = [0 1];
            axes.YLim = [0 1];
            axes.FontSize = gui.components.UIComponentFactory.FONTS.DefaultSize;
        end
        
        function [monitorToggle, zScanToggle, moveToMaxButton] = createScanControls(actionGrid, actionPanel, controller)
            % Creates main scanning control buttons with improved visual prominence
            scanControlsPanel = uipanel(actionGrid, ...
                'BorderType', 'none', ...
                'BackgroundColor', actionPanel.BackgroundColor);
            scanControlsPanel.Layout.Row = 1;
            scanControlsPanel.Layout.Column = [1 3];
            
            % Create grid for control buttons with more space
            scanGrid = uigridlayout(scanControlsPanel, [1, 3]);
            scanGrid.RowHeight = {'1x'};
            scanGrid.ColumnWidth = {'1x', '1x', '1x'};
            scanGrid.Padding = [3 5 3 5];           % Reduced padding
            scanGrid.ColumnSpacing = 8;             % Reduced spacing
            
            % Monitor toggle - improved styling
            monitorToggle = uibutton(scanGrid, 'state', ...
                'Text', '👁️ Monitor', ...          % Shortened text
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize+1, ... % Reduced font size
                'FontWeight', 'bold', ...
                'Tooltip', 'Start/stop real-time brightness monitoring while you manually move Z stage', ...
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.MonitorButton, ...
                'HorizontalAlignment', 'center');
            monitorToggle.Layout.Row = 1;
            monitorToggle.Layout.Column = 1;
            
            % Z-Scan toggle - improved styling for more prominence
            zScanToggle = uibutton(scanGrid, 'state', ...
                'Text', '🔍 Z-Scan', ...           % Shortened text
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize+1, ... % Reduced font size
                'FontWeight', 'bold', ...
                'Tooltip', 'Start automatic Z scan to find focus - scans through Z range and records brightness', ...
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.ScanButton, ...
                'Enable', 'off', ...
                'HorizontalAlignment', 'center');
            zScanToggle.Layout.Row = 1;
            zScanToggle.Layout.Column = 2;
            
            % Move to max button - improved styling for more prominence
            moveToMaxButton = uibutton(scanGrid, ...
                'Text', '⬆️ Max Focus', ...        % Shortened text
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize+1, ... % Reduced font size
                'FontWeight', 'bold', ...
                'Tooltip', 'Move to the Z position with maximum brightness (best focus)', ...
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.MaxFocusButton, ...
                'ButtonPushedFcn', @(~,~) controller.moveToMaxBrightness(), ...
                'Enable', 'off', ...
                'HorizontalAlignment', 'center');
            moveToMaxButton.Layout.Row = 1;
            moveToMaxButton.Layout.Column = 3;
        end
        
        function [focusButton, grabButton, abortButton] = createScanImageControls(actionGrid, controller)
            % Creates ScanImage control buttons - simplified version
            siControlsPanel = uipanel(actionGrid, ...
                'BorderType', 'line', ...
                'BackgroundColor', [0.93 0.93 0.95]);
            siControlsPanel.Layout.Row = 1;
            siControlsPanel.Layout.Column = 4;
            
            siGrid = uigridlayout(siControlsPanel, [3, 1]);
            siGrid.RowHeight = {'0.2x', '1x', '1x'};
            siGrid.ColumnWidth = {'1x'};
            siGrid.Padding = [5 5 5 5];
            siGrid.RowSpacing = 5;
            
            % Section title
            uilabel(siGrid, 'Text', 'ScanImage Controls', ...
                'HorizontalAlignment', 'center', ...
                'FontWeight', 'bold', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize);
            
            % Focus Button - using state button
            focusButton = uibutton(siGrid, 'state', ...
                'Text', '🔄 Focus Mode', ...
                'ValueChangedFcn', [], ... % Will be set by FocusGUI
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.ActionButton, ...
                'FontSize', gui.components.UIComponentFactory.FONTS.LargeSize, ...
                'Tooltip', 'Start Focus mode in ScanImage (continuous scanning)', ...
                'HorizontalAlignment', 'center');
            focusButton.Layout.Row = 2;
            focusButton.Layout.Column = 1;
            
            % Grab Button - using state button
            grabButton = uibutton(siGrid, 'state', ...
                'Text', '📷 Grab Frame', ...
                'Value', false, ... % Initial state is off
                'ValueChangedFcn', [], ... % Will be set by FocusGUI
                'BackgroundColor', [0.95 0.95 0.85], ...
                'FontSize', gui.components.UIComponentFactory.FONTS.LargeSize, ...
                'Tooltip', 'Grab a single frame in ScanImage (snapshot)', ...
                'HorizontalAlignment', 'center');
            grabButton.Layout.Row = 3;
            grabButton.Layout.Column = 1;
            
            abortButton = gui.components.UIComponentFactory.createStyledButton(siGrid, 'ABORT', [2 3], 1, ...
                @(~,~) controller.abortAllOperations(), ...
                Tooltip="Abort all operations immediately", ...
                BackgroundColor=gui.components.UIComponentFactory.COLORS.EmergencyButton, ...
                FontSize=gui.components.UIComponentFactory.FONTS.LargeSize, ...
                Icon="❌", ...
                HorizontalAlignment="center");
            abortButton.Visible = 'off';
        end
    end
end