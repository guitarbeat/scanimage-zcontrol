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
            'Small', 5, ...
            'Medium', 10, ...
            'Large', 15, ...
            'XLarge', 20 ...
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
            
            [components.minZEdit, components.maxZEdit] = ...
                gui.components.UIComponentFactory.createZLimitControls(paramGrid, controller);
        end
        
        function currentZLabel = createZControlPanel(parent, zControlPanel, controller)
            % Creates Z-axis control panel
            zControlGrid = uigridlayout(zControlPanel, [3, 2]);
            zControlGrid.RowHeight = {'fit', '1x', 'fit'};
            zControlGrid.ColumnWidth = {'1x', '1x'};
            zControlGrid.Padding = [12 12 12 12];
            zControlGrid.RowSpacing = gui.components.UIComponentFactory.SPACING.Medium;
            zControlGrid.ColumnSpacing = gui.components.UIComponentFactory.SPACING.Large;
            
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
            plotGrid.Padding = [15 15 15 15];
            
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
            paramGrid = uigridlayout(paramPanel, [5, 4]);
            paramGrid.RowHeight = {'fit', 5, 'fit', 'fit', 'fit'};
            paramGrid.ColumnWidth = {'fit', '1.5x', 'fit', '1x'};
            paramGrid.Padding = [12 12 12 12];  % Increased padding for better spacing
            paramGrid.RowSpacing = 10;  % Increased spacing
            paramGrid.ColumnSpacing = 12;  % Increased spacing
        end
        
        function [stepSizeSlider, stepSizeValue] = createStepSizeControls(paramGrid, paramPanel, controller)
            % Creates step size slider and value display
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Step Size (µm):', 1, 1, ...
                Tooltip="Set the Z scan step size in micrometers");
            
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
                'Value', controller.initialStepSize, ...
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
                'Text', num2str(controller.initialStepSize), ...
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
        end
        
        function pauseTimeEdit = createPauseTimeControl(paramGrid, controller)
            % Creates pause time control
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Pause Time (sec):', 3, 1, ...
                Tooltip="Pause duration between Z steps (seconds)");
            
            pauseTimeEdit = gui.components.UIComponentFactory.createStyledEditField(paramGrid, 3, 2, ...
                Value=controller.scanPauseTime, Format="%.1f", ...
                Tooltip="Pause duration between Z steps (seconds)");
        end
        
        function metricDropDown = createMetricControl(paramGrid)
            % Creates brightness metric dropdown
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Brightness Metric:', 3, 3, ...
                Tooltip="Select brightness calculation method");
            
            metricDropDown = uidropdown(paramGrid, ...
                'Items', {'Mean', 'Median', 'Max', '95th Percentile'}, ...
                'Value', 'Mean', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize, ...
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.Surface, ...
                'Tooltip', 'Select method to calculate brightness (Mean is most common)');
            metricDropDown.Layout.Row = 3;
            metricDropDown.Layout.Column = 4;
        end
        
        function [minZEdit, maxZEdit] = createZLimitControls(paramGrid, controller)
            % Creates Z limit controls
            % Min Z
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Min Z Position (µm):', 4, 1, ...
                Tooltip="Set minimum Z limit (µm)");
            minZEdit = gui.components.UIComponentFactory.createStyledEditField(paramGrid, 4, 2, ...
                Value=0, Format="%.1f", Tooltip="Minimum Z limit (µm)");
            gui.components.UIComponentFactory.createStyledButton(paramGrid, 'Set Min Z', 4, [3 4], ...
                @(~,~) controller.setMinZLimit(), ...
                Tooltip="Set current position as minimum Z limit", ...
                BackgroundColor=[0.9 0.9 1.0], ...
                HorizontalAlignment="center");
            
            % Max Z
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Max Z Position (µm):', 5, 1, ...
                Tooltip="Set maximum Z limit (µm)");
            maxZEdit = gui.components.UIComponentFactory.createStyledEditField(paramGrid, 5, 2, ...
                Value=100, Format="%.1f", Tooltip="Maximum Z limit (µm)");
            gui.components.UIComponentFactory.createStyledButton(paramGrid, 'Set Max Z', 5, [3 4], ...
                @(~,~) controller.setMaxZLimit(), ...
                Tooltip="Set current position as maximum Z limit", ...
                BackgroundColor=[0.9 0.9 1.0], ...
                HorizontalAlignment="center");
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
            xlabel(axes, 'Z Position (µm)', 'FontWeight', 'bold', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize);
            ylabel(axes, 'Brightness (a.u.)', 'FontWeight', 'bold', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.DefaultSize);
            title(axes, 'Z-Scan Brightness Profile', 'FontWeight', 'bold', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.LargeSize);
            axes.GridAlpha = 0.3;
            axes.LineWidth = 1.2;
            axes.XLim = [0 1];
            axes.YLim = [0 1];
            axes.FontSize = gui.components.UIComponentFactory.FONTS.DefaultSize;
        end
        
        function [monitorToggle, zScanToggle, moveToMaxButton] = createScanControls(actionGrid, actionPanel, controller)
            % Creates main scanning control buttons
            scanControlsPanel = uipanel(actionGrid, ...
                'BorderType', 'none', ...
                'BackgroundColor', actionPanel.BackgroundColor);
            scanControlsPanel.Layout.Row = 1;
            scanControlsPanel.Layout.Column = [1 3];
            
            scanGrid = uigridlayout(scanControlsPanel, [1, 3]);
            scanGrid.RowHeight = {'1x'};
            scanGrid.ColumnWidth = {'1x', '1x', '1x'};
            scanGrid.Padding = [0 0 0 0];
            scanGrid.ColumnSpacing = 15;
            
            monitorToggle = uibutton(scanGrid, 'state', ...
                'Text', '👁️ Monitor Brightness', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.LargeSize, ...
                'FontWeight', 'bold', ...
                'Tooltip', 'Start/stop real-time brightness monitoring while you manually move Z stage', ...
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.MonitorButton, ...
                'HorizontalAlignment', 'center');
            monitorToggle.Layout.Row = 1;
            monitorToggle.Layout.Column = 1;
            
            zScanToggle = uibutton(scanGrid, 'state', ...
                'Text', '🔍 Auto Z-Scan', ...
                'FontSize', gui.components.UIComponentFactory.FONTS.LargeSize, ...
                'FontWeight', 'bold', ...
                'Tooltip', 'Start automatic Z scan to find focus - scans through Z range and records brightness', ...
                'BackgroundColor', gui.components.UIComponentFactory.COLORS.ScanButton, ...
                'Enable', 'off', ...
                'HorizontalAlignment', 'center');
            zScanToggle.Layout.Row = 1;
            zScanToggle.Layout.Column = 2;
            
            moveToMaxButton = gui.components.UIComponentFactory.createStyledButton(scanGrid, 'Move to Max Focus', 1, 3, ...
                @(~,~) controller.moveToMaxBrightness(), ...
                Tooltip="Move to the Z position with maximum brightness (best focus)", ...
                BackgroundColor=gui.components.UIComponentFactory.COLORS.MaxFocusButton, ...
                FontSize=gui.components.UIComponentFactory.FONTS.LargeSize, ...
                Enable="off", Icon="⬆️", ...
                HorizontalAlignment="center");
        end
        
        function [focusButton, grabButton, abortButton] = createScanImageControls(actionGrid, controller)
            % Creates ScanImage control buttons
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
            
            focusButton = gui.components.UIComponentFactory.createStyledButton(siGrid, 'Focus Mode', 2, 1, ...
                @(~,~) controller.startSIFocus(), ...
                Tooltip="Start Focus mode in ScanImage (continuous scanning)", ...
                BackgroundColor=gui.components.UIComponentFactory.COLORS.ActionButton, ...
                FontSize=gui.components.UIComponentFactory.FONTS.LargeSize, ...
                Icon="🔄", ...
                HorizontalAlignment="center");
            
            grabButton = gui.components.UIComponentFactory.createStyledButton(siGrid, 'Grab Frame', 3, 1, ...
                @(~,~) controller.grabSIFrame(), ...
                Tooltip="Grab a single frame in ScanImage (snapshot)", ...
                BackgroundColor=[0.95 0.95 0.85], ...
                FontSize=gui.components.UIComponentFactory.FONTS.LargeSize, ...
                Icon="📷", ...
                HorizontalAlignment="center");
            
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