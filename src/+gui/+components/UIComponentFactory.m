classdef UIComponentFactory < handle
    % UIComponentFactory - Helper class for creating UI components
    % Used by FocusGUI to create various UI elements
    
    methods (Static)
        function panel = createStyledPanel(parent, title, row, column)
            % Creates a styled panel with consistent appearance
            panel = uipanel(parent, 'Title', title, 'FontWeight', 'bold', 'FontSize', 11);
            panel.BackgroundColor = [0.96 0.96 0.98];
            panel.Layout.Row = row;
            panel.Layout.Column = column;
        end
        
        function label = createStyledLabel(parent, text, row, column, tooltip)
            % Creates a styled label with consistent appearance
            label = uilabel(parent, 'Text', text, 'FontWeight', 'bold', ...
                'Tooltip', tooltip);
            label.Layout.Row = row;
            label.Layout.Column = column;
        end
        
        function edit = createStyledEditField(parent, row, column, value, format, tooltip)
            % Creates a styled edit field with consistent appearance
            edit = uieditfield(parent, 'numeric', ...
                'Value', value, ...
                'Tooltip', tooltip, ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 11, ...
                'ValueDisplayFormat', format, ...
                'AllowEmpty', 'on', ...
                'BackgroundColor', [1 1 1]);
            edit.Layout.Row = row;
            edit.Layout.Column = column;
        end
        
        function btn = createStyledButton(parent, text, row, column, callback, tooltip, bgColor, fontSize)
            % Creates a styled button with consistent appearance
            if nargin < 8
                fontSize = 11;
            end
            if nargin < 7
                bgColor = [0.9 0.9 0.95];
            end
            
            btn = uibutton(parent, 'Text', text, ...
                'FontSize', fontSize, 'FontWeight', 'bold', ...
                'Tooltip', tooltip, ...
                'ButtonPushedFcn', callback, ...
                'BackgroundColor', bgColor);
            btn.Layout.Row = row;
            btn.Layout.Column = column;
        end
        
        function panel = createStyledValueBox(parent, row, column)
            % Creates a styled value box with consistent appearance
            panel = uipanel(parent, 'BorderType', 'line', 'BackgroundColor', [1 1 1]);
            panel.Layout.Row = row;
            panel.Layout.Column = column;
        end
        
        function createInstructionPanel(parent, grid)
            % Creates the instruction panel with quick start guide
            % Create HTML content as a simple string rather than an array
            htmlContent = [ ...
                '<html>' ...
                '<body style="margin:0; padding:0;">' ...
                '<div style="background-color:#e6f7ff; padding:10px; border-radius:5px; border:1px solid #4da6ff;">' ...
                '<p><b style="font-size:14px; color:#0066cc;">AUTOMATIC FOCUS FINDING:</b></p>' ...
                '<p>1. Set <b>Step Size</b> (8-15μm recommended)</p>' ...
                '<p>2. Press <b>Auto Z-Scan</b> to automatically scan through Z positions</p>' ...
                '<p>3. When scan completes, press <b>Move to Max Focus</b> to jump to best focus</p>' ...
                '<p><b style="font-size:14px; color:#0066cc;">MANUAL FOCUS FINDING:</b></p>' ...
                '<p>1. Press <b>Monitor Brightness</b> to track brightness in real-time</p>' ...
                '<p>2. Use <b>Up/Down</b> buttons to move while watching the brightness plot</p>' ...
                '</div>' ...
                '</body>' ...
                '</html>' ...
            ];
            
            % Create the label with HTML content
            instructText = uilabel(grid, ...
                'Text', htmlContent, ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'top', ...
                'Interpreter', 'html');
            instructText.Layout.Row = 1;
            instructText.Layout.Column = 1;
        end
        
        function [stepSizeSlider, stepSizeValue, pauseTimeEdit, metricDropDown, minZEdit, maxZEdit] = createScanParametersPanel(parent, paramPanel, controller)
            % Creates the scan parameters panel
            paramGrid = uigridlayout(paramPanel, [5, 4]);
            paramGrid.RowHeight = {'fit', 5, 'fit', 'fit', 'fit'};  % Reduced row spacing
            paramGrid.ColumnWidth = {'fit', '1.5x', 'fit', '1x'};
            paramGrid.Padding = [8 8 8 8];  % Reduced padding
            paramGrid.RowSpacing = 8;  % Reduced row spacing
            paramGrid.ColumnSpacing = 10;  % Reduced column spacing

            % Step Size with improved visual connection
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Step Size (µm):', 1, 1, 'Set the Z scan step size (µm)');

            % Slider panel with better visual design
            sliderPanel = uipanel(paramGrid, 'BorderType', 'none', 'BackgroundColor', paramPanel.BackgroundColor);
            sliderPanel.Layout.Row = 1;
            sliderPanel.Layout.Column = [2 3];
            
            sliderGrid = uigridlayout(sliderPanel, [2, 1]);
            sliderGrid.RowHeight = {'1x', '0.3x'};  % Reduced tick height
            sliderGrid.ColumnWidth = {'1x'};
            sliderGrid.Padding = [0 0 0 0];
            sliderGrid.RowSpacing = 0;
            
            % Modern styled slider
            stepSizeSlider = uislider(sliderGrid, ...
                'Limits', [1 50], ...
                'Value', controller.initialStepSize, ...
                'MajorTicks', [1 8 15 22 29 36 43 50], ...
                'MinorTicks', [], ...
                'Tooltip', 'Set the Z scan step size (µm)');
            stepSizeSlider.Layout.Row = 1;
            stepSizeSlider.Layout.Column = 1;
            
            % Tick labels with proper spacing
            tickPanel = uipanel(sliderGrid, 'BorderType', 'none', 'BackgroundColor', paramPanel.BackgroundColor);
            tickPanel.Layout.Row = 2;
            tickPanel.Layout.Column = 1;
            
            tickGrid = uigridlayout(tickPanel, [1, 8]);
            tickGrid.RowHeight = {'1x'};
            tickGrid.ColumnWidth = repmat({1}, 1, 8);
            tickGrid.Padding = [0 0 0 0];
            tickGrid.ColumnSpacing = 0;
            
            % Individual tick labels for perfect alignment
            tickValues = [1, 8, 15, 22, 29, 36, 43, 50];
            for i = 1:length(tickValues)
                uilabel(tickGrid, 'Text', num2str(tickValues(i)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 8);  
            end
            
            % Modern styled value display
            valuePanel = gui.components.UIComponentFactory.createStyledValueBox(paramGrid, 1, 4);
            valueGrid = uigridlayout(valuePanel, [1, 1]);
            valueGrid.Padding = [0 0 0 0];
            
            stepSizeValue = uilabel(valueGrid, ...
                'Text', num2str(controller.initialStepSize), ...
                'HorizontalAlignment', 'center', ...
                'FontWeight', 'bold', ...
                'FontSize', 12);
            
            % Separator
            separatorPanel = uipanel(paramGrid, 'BorderType', 'line', 'BackgroundColor', paramPanel.BackgroundColor);
            separatorPanel.Layout.Row = 2;
            separatorPanel.Layout.Column = [1 4];
            separatorPanel.HighlightColor = [0.8 0.8 0.8];
            
            % Pause Time with better layout
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Pause (s):', 3, 1, 'Pause between Z steps (seconds)');
            
            pauseTimeEdit = gui.components.UIComponentFactory.createStyledEditField(paramGrid, 3, 2, controller.scanPauseTime, '%.1f', 'Pause between Z steps (seconds)');
            
            % Brightness Metric with better layout
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Brightness Metric:', 3, 3, 'Select brightness metric');
            
            metricDropDown = uidropdown(paramGrid, ...
                'Items', {'Mean', 'Median', 'Max', '95th Percentile'}, ...
                'Tooltip', 'Select brightness metric', ...
                'FontSize', 11, ...  % Reduced font size
                'BackgroundColor', [1 1 1], ...
                'Value', 'Mean');
            metricDropDown.Layout.Row = 3;
            metricDropDown.Layout.Column = 4;

            % Min Z with better layout and visual connection
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Min Z Position:', 4, 1, 'Set minimum Z limit (µm)');
            
            minZEdit = gui.components.UIComponentFactory.createStyledEditField(paramGrid, 4, 2, 0, '%.1f', 'Minimum Z limit (µm)');
            
            gui.components.UIComponentFactory.createStyledButton(paramGrid, 'Set Min Z', 4, [3 4], @(~,~) controller.setMinZLimit(), ...
                'Set current position as minimum Z limit', [0.9 0.9 1.0]);

            % Max Z with better layout and visual connection
            gui.components.UIComponentFactory.createStyledLabel(paramGrid, 'Max Z Position:', 5, 1, 'Set maximum Z limit (µm)');
            
            maxZEdit = gui.components.UIComponentFactory.createStyledEditField(paramGrid, 5, 2, 100, '%.1f', 'Maximum Z limit (µm)');
            
            gui.components.UIComponentFactory.createStyledButton(paramGrid, 'Set Max Z', 5, [3 4], @(~,~) controller.setMaxZLimit(), ...
                'Set current position as maximum Z limit', [0.9 0.9 1.0]);
        end
        
        function currentZLabel = createZControlPanel(parent, zControlPanel, controller)
            % Creates the Z control panel with movement buttons
            zControlGrid = uigridlayout(zControlPanel, [3, 2]);
            zControlGrid.RowHeight = {'fit', '1x', 'fit'};
            zControlGrid.ColumnWidth = {'1x', '1x'};
            zControlGrid.Padding = [12 12 12 12];
            zControlGrid.RowSpacing = 10;
            zControlGrid.ColumnSpacing = 15;
            
            % Current Z Position Display with modern styling
            gui.components.UIComponentFactory.createStyledLabel(zControlGrid, 'Current Z Position (µm):', 1, [1 2], 'Current Z stage position');
            
            % Modern styled display box for Z position
            zPosPanel = uipanel(zControlGrid, 'BorderType', 'line', 'BackgroundColor', [1 1 1]);
            zPosPanel.Layout.Row = 2;
            zPosPanel.Layout.Column = [1 2];
            
            zPosValueGrid = uigridlayout(zPosPanel, [1, 1]);
            zPosValueGrid.Padding = [0 0 0 0];
            
            currentZLabel = uilabel(zPosValueGrid, 'Text', '0.0', ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 15, ...
                'FontColor', [0.2 0.2 0.7]);
            
            % Z Movement Buttons with clear labels and modern styling
            upBtn = uibutton(zControlGrid, 'Text', '▲ Up', 'FontSize', 11, 'FontWeight', 'bold', ...
                'Tooltip', 'Move Z stage up (decrease Z value)', ...
                'ButtonPushedFcn', @(~,~) controller.moveZUp(), ...
                'BackgroundColor', [0.8 1.0 0.8]);
            upBtn.Layout.Row = 3;
            upBtn.Layout.Column = 1;
            
            downBtn = uibutton(zControlGrid, 'Text', '▼ Down', 'FontSize', 11, 'FontWeight', 'bold', ...
                'Tooltip', 'Move Z stage down (increase Z value)', ...
                'ButtonPushedFcn', @(~,~) controller.moveZDown(), ...
                'BackgroundColor', [0.8 0.8 1.0]);
            downBtn.Layout.Row = 3;
            downBtn.Layout.Column = 2;
        end
        
        function axes = createPlotPanel(plotPanel)
            % Creates the plot panel for brightness vs Z-position
            plotGrid = uigridlayout(plotPanel, [1, 1]);
            plotGrid.Padding = [15 15 15 15];
            
            axes = uiaxes(plotGrid);
            
            % Initial plot setup with better styling
            grid(axes, 'on');
            box(axes, 'on');
            xlabel(axes, 'Z Position (µm)', 'FontWeight', 'bold', 'FontSize', 11);
            ylabel(axes, 'Brightness (a.u.)', 'FontWeight', 'bold', 'FontSize', 11);
            title(axes, 'Z-Scan Brightness Profile', 'FontWeight', 'bold', 'FontSize', 12);
            axes.GridAlpha = 0.3;
            axes.LineWidth = 1.2;
            axes.XLim = [0 1];
            axes.YLim = [0 1];
            axes.FontSize = 11;
        end
        
        function [monitorToggle, zScanToggle, focusButton, grabButton, abortButton, moveToMaxButton] = createActionPanel(parent, actionPanel, controller)
            % Creates the action panel with control buttons
            actionGrid = uigridlayout(actionPanel, [1, 4]);
            actionGrid.RowHeight = {'1x'};
            actionGrid.ColumnWidth = {'1x', '1x', '1x', '0.6x'};  % Use proportional units
            actionGrid.Padding = [12 15 12 15];
            actionGrid.ColumnSpacing = 15;

            % --- Left side: Basic scanning controls (Col 1-3) ---
            scanControlsPanel = uipanel(actionGrid, 'BorderType', 'none', 'BackgroundColor', actionPanel.BackgroundColor);
            scanControlsPanel.Layout.Row = 1;
            scanControlsPanel.Layout.Column = [1 3];
            
            scanGrid = uigridlayout(scanControlsPanel, [1, 3]);
            scanGrid.RowHeight = {'1x'};
            scanGrid.ColumnWidth = {'1x', '1x', '1x'};  % Use proportional units
            scanGrid.Padding = [0 0 0 0];
            scanGrid.ColumnSpacing = 15;

            % Monitor toggle button
            monitorToggle = uibutton(scanGrid, 'state', ...
                'Text', '👁️ Monitor Brightness', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Tooltip', 'Start/stop real-time brightness monitoring while you manually move Z stage', ...
                'BackgroundColor', [0.85 0.95 0.85]);
            monitorToggle.Layout.Row = 1;
            monitorToggle.Layout.Column = 1;

            % Z-scan toggle button (disabled by default)
            zScanToggle = uibutton(scanGrid, 'state', ...
                'Text', '🔍 Auto Z-Scan', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Tooltip', 'Start automatic Z scan to find focus - scans through Z range and records brightness', ...
                'BackgroundColor', [0.7 0.85 1.0], ...
                'Enable', 'off');  % Disabled until conditions are met
            zScanToggle.Layout.Row = 1;
            zScanToggle.Layout.Column = 2;

            % Move to max focus button (disabled by default)
            moveToMaxButton = gui.components.UIComponentFactory.createStyledButton(scanGrid, '⬆️ Move to Max Focus', 1, 3, ...
                @(~,~) controller.moveToMaxBrightness(), ...
                'Move to the Z position with maximum brightness (best focus)', [1.0 0.85 0.85], 13);
            moveToMaxButton.Enable = 'off';  % Disabled until data is available

            % --- Right side: ScanImage controls (Col 4) ---
            siControlsPanel = uipanel(actionGrid, 'BorderType', 'line', 'BackgroundColor', [0.93 0.93 0.95]);
            siControlsPanel.Layout.Row = 1;
            siControlsPanel.Layout.Column = 4;
            
            siGrid = uigridlayout(siControlsPanel, [3, 1]);
            siGrid.RowHeight = {'0.2x', '1x', '1x'};
            siGrid.ColumnWidth = {'1x'};
            siGrid.Padding = [5 5 5 5];
            siGrid.RowSpacing = 5;
            
            % Title for the section
            titleLabel = uilabel(siGrid, 'Text', 'ScanImage Controls', ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 11);
            titleLabel.Layout.Row = 1;
            titleLabel.Layout.Column = 1;

            % Focus button
            focusButton = uibutton(siGrid, ...
                'Text', '🔄 Focus Mode', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Tooltip', 'Start Focus mode in ScanImage', ...
                'ButtonPushedFcn', @(~,~) controller.startSIFocus(), ...
                'BackgroundColor', [0.85 0.95 0.95]);
            focusButton.Layout.Row = 2;
            focusButton.Layout.Column = 1;

            % Grab button
            grabButton = uibutton(siGrid, ...
                'Text', '📷 Grab Frame', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Tooltip', 'Grab a single frame in ScanImage', ...
                'ButtonPushedFcn', @(~,~) controller.grabSIFrame(), ...
                'BackgroundColor', [0.95 0.95 0.85]);
            grabButton.Layout.Row = 3;
            grabButton.Layout.Column = 1;
            
            % Abort button (initially hidden)
            abortButton = uibutton(siGrid, ...
                'Text', '❌ Abort', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Tooltip', 'Abort all operations', ...
                'ButtonPushedFcn', @(~,~) controller.abortAllOperations(), ...
                'BackgroundColor', [1.0 0.7 0.7], ...
                'Visible', 'off');
            abortButton.Layout.Row = [2 3];
            abortButton.Layout.Column = 1;
        end
        
        function [statusText, statusBar] = createStatusBar(hFig)
            % Creates a modern status bar at the bottom of the figure
            statusBar = uipanel(hFig, 'BorderType', 'none', ...
                'BackgroundColor', [0.92 0.92 0.95], ...
                'Position', [0 0 hFig.Position(3) 25]);
            
            statusText = uilabel(statusBar, ...
                'Text', 'Ready', ...
                'Position', [10 4 statusBar.Position(3)-20 18], ...
                'FontSize', 11, ...
                'FontColor', [0.3 0.3 0.3]);
            
            % Add a line at the top of the status bar
            uipanel(statusBar, 'BorderType', 'line', ...
                'HighlightColor', [0.7 0.7 0.7], ...
                'Position', [0 24 statusBar.Position(3) 1]);
        end
    end
end 