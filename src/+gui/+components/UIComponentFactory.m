classdef UIComponentFactory < handle
    % UIComponentFactory - Helper class for creating UI components
    % Used by FocusGUI to create various UI elements
    
    methods (Static)
        function panel = createStyledPanel(parent, title, row, column)
            % Creates a styled panel with consistent appearance
            panel = uipanel(parent, 'Title', title, 'FontWeight', 'bold', 'FontSize', 13);
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
                'FontSize', 12, ...
                'ValueDisplayFormat', format, ...
                'BackgroundColor', [1 1 1]);
            edit.Layout.Row = row;
            edit.Layout.Column = column;
        end
        
        function btn = createStyledButton(parent, text, row, column, callback, tooltip, bgColor, fontSize)
            % Creates a styled button with consistent appearance
            if nargin < 8
                fontSize = 12;
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
            instructText = uilabel(grid, 'Text', ...
                ['<html>' ...
                 '<div style="background-color:#e6f7ff; padding:8px; border-radius:5px; border:1px solid #4da6ff;">' ...
                 '<b style="font-size:14px; color:#0066cc;">AUTOMATIC FOCUS FINDING:</b><br>' ...
                 '1️⃣ Set <b>Step Size</b> (8-15μm recommended)<br>' ...
                 '2️⃣ Press <b>Auto Z-Scan</b> to automatically scan through Z positions<br>' ...
                 '3️⃣ When scan completes, press <b>Move to Max Focus</b> to jump to best focus<br><br>' ...
                 '<b style="font-size:14px; color:#0066cc;">MANUAL FOCUS FINDING:</b><br>' ...
                 '1️⃣ Press <b>Monitor Brightness</b> to track brightness in real-time<br>' ...
                 '2️⃣ Use <b>Up/Down</b> buttons to move while watching the brightness plot' ...
                 '</div>' ...
                 '</html>'], ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
            instructText.Layout.Row = 1;
            instructText.Layout.Column = 1;
        end
        
        function [stepSizeSlider, stepSizeValue, pauseTimeEdit, metricDropDown, minZEdit, maxZEdit] = createScanParametersPanel(parent, paramPanel, controller)
            % Creates the scan parameters panel
            paramGrid = uigridlayout(paramPanel, [5, 4]);
            paramGrid.RowHeight = {'fit', 10, 'fit', 'fit', 'fit'};
            paramGrid.ColumnWidth = {'fit', '1.5x', 'fit', '1x'};
            paramGrid.Padding = [12 12 12 12];
            paramGrid.RowSpacing = 15;
            paramGrid.ColumnSpacing = 15;

            % Step Size with improved visual connection
            UIComponentFactory.createStyledLabel(paramGrid, 'Step Size (µm):', 1, 1, 'Set the Z scan step size (µm)');

            % Slider panel with better visual design
            sliderPanel = uipanel(paramGrid, 'BorderType', 'none', 'BackgroundColor', paramPanel.BackgroundColor);
            sliderPanel.Layout.Row = 1;
            sliderPanel.Layout.Column = [2 3];
            
            sliderGrid = uigridlayout(sliderPanel, [2, 1]);
            sliderGrid.RowHeight = {'1x', '0.4x'};
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
                    'HorizontalAlignment', 'center', 'FontSize', 9);
            end
            
            % Modern styled value display
            valuePanel = UIComponentFactory.createStyledValueBox(paramGrid, 1, 4);
            valueGrid = uigridlayout(valuePanel, [1, 1]);
            valueGrid.Padding = [0 0 0 0];
            
            stepSizeValue = uilabel(valueGrid, ...
                'Text', num2str(controller.initialStepSize), ...
                'HorizontalAlignment', 'center', ...
                'FontWeight', 'bold', ...
                'FontSize', 14);
            
            % Separator
            separatorPanel = uipanel(paramGrid, 'BorderType', 'line', 'BackgroundColor', paramPanel.BackgroundColor);
            separatorPanel.Layout.Row = 2;
            separatorPanel.Layout.Column = [1 4];
            separatorPanel.HighlightColor = [0.8 0.8 0.8];
            
            % Pause Time with better layout
            UIComponentFactory.createStyledLabel(paramGrid, 'Pause (s):', 3, 1, 'Pause between Z steps (seconds)');
            
            pauseTimeEdit = UIComponentFactory.createStyledEditField(paramGrid, 3, 2, controller.scanPauseTime, '%.1f', 'Pause between Z steps (seconds)');
            
            % Brightness Metric with better layout
            UIComponentFactory.createStyledLabel(paramGrid, 'Brightness Metric:', 3, 3, 'Select brightness metric');
            
            metricDropDown = uidropdown(paramGrid, ...
                'Items', {'Mean', 'Median', 'Max', '95th Percentile'}, ...
                'Tooltip', 'Select brightness metric', ...
                'FontSize', 12, ...
                'BackgroundColor', [1 1 1], ...
                'Value', 'Mean');
            metricDropDown.Layout.Row = 3;
            metricDropDown.Layout.Column = 4;

            % Min Z with better layout and visual connection
            UIComponentFactory.createStyledLabel(paramGrid, 'Min Z Position:', 4, 1, 'Set minimum Z limit (µm)');
            
            minZEdit = UIComponentFactory.createStyledEditField(paramGrid, 4, 2, [], '%.1f', 'Minimum Z limit (µm)');
            
            UIComponentFactory.createStyledButton(paramGrid, 'Set Min Z', 4, [3 4], @(~,~) controller.setMinZLimit(), ...
                'Set current position as minimum Z limit', [0.9 0.9 1.0]);

            % Max Z with better layout and visual connection
            UIComponentFactory.createStyledLabel(paramGrid, 'Max Z Position:', 5, 1, 'Set maximum Z limit (µm)');
            
            maxZEdit = UIComponentFactory.createStyledEditField(paramGrid, 5, 2, [], '%.1f', 'Maximum Z limit (µm)');
            
            UIComponentFactory.createStyledButton(paramGrid, 'Set Max Z', 5, [3 4], @(~,~) controller.setMaxZLimit(), ...
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
            UIComponentFactory.createStyledLabel(zControlGrid, 'Current Z Position (µm):', 1, [1 2], 'Current Z stage position');
            
            % Modern styled display box for Z position
            zPosPanel = uipanel(zControlGrid, 'BorderType', 'line', 'BackgroundColor', [1 1 1]);
            zPosPanel.Layout.Row = 2;
            zPosPanel.Layout.Column = [1 2];
            
            zPosValueGrid = uigridlayout(zPosPanel, [1, 1]);
            zPosValueGrid.Padding = [0 0 0 0];
            
            currentZLabel = uilabel(zPosValueGrid, 'Text', '0.0', ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 20, ...
                'FontColor', [0.2 0.2 0.7]);
            
            % Z Movement Buttons with clear labels and modern styling
            upBtn = uibutton(zControlGrid, 'Text', '▲ Up', 'FontSize', 14, 'FontWeight', 'bold', ...
                'Tooltip', 'Move Z stage up (decrease Z value)', ...
                'ButtonPushedFcn', @(~,~) controller.moveZUp(), ...
                'BackgroundColor', [0.8 1.0 0.8]);
            upBtn.Layout.Row = 3;
            upBtn.Layout.Column = 1;
            
            downBtn = uibutton(zControlGrid, 'Text', '▼ Down', 'FontSize', 14, 'FontWeight', 'bold', ...
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
            xlabel(axes, 'Z Position (µm)', 'FontWeight', 'bold', 'FontSize', 12);
            ylabel(axes, 'Brightness (a.u.)', 'FontWeight', 'bold', 'FontSize', 12);
            title(axes, 'Z-Scan Brightness Profile', 'FontWeight', 'bold', 'FontSize', 14);
            axes.GridAlpha = 0.3;
            axes.LineWidth = 1.2;
            axes.XLim = [0 1];
            axes.YLim = [0 1];
            axes.FontSize = 11;
        end
        
        function [monitorToggle, zScanToggle, focusButton, grabButton, abortButton] = createActionPanel(parent, actionPanel, controller)
            % Creates the action panel with control buttons
            actionGrid = uigridlayout(actionPanel, [1, 5]);
            actionGrid.RowHeight = {'fit'};
            actionGrid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
            actionGrid.Padding = [12 15 12 15];
            actionGrid.ColumnSpacing = 15;

            % Monitor toggle button
            monitorToggle = uibutton(actionGrid, 'state', ...
                'Text', '👁️ Monitor Brightness', 'FontSize', 13, 'FontWeight', 'bold', ...
                'Tooltip', 'Start/stop real-time brightness monitoring while you manually move Z stage', ...
                'BackgroundColor', [0.85 0.95 0.85]);
            monitorToggle.Layout.Row = 1;
            monitorToggle.Layout.Column = 1;

            % Z-scan toggle button
            zScanToggle = uibutton(actionGrid, 'state', ...
                'Text', '🔍 Auto Z-Scan', 'FontSize', 13, 'FontWeight', 'bold', ...
                'Tooltip', 'Start automatic Z scan to find focus - scans through Z range and records brightness', ...
                'BackgroundColor', [0.7 0.85 1.0]);
            zScanToggle.Layout.Row = 1;
            zScanToggle.Layout.Column = 2;

            % Move to max focus button
            UIComponentFactory.createStyledButton(actionGrid, '⬆️ Move to Max Focus', 1, 3, ...
                @(~,~) controller.moveToMaxBrightness(), ...
                'Move to the Z position with maximum brightness (best focus)', [1.0 0.85 0.85], 13);

            % Focus button
            focusButton = UIComponentFactory.createStyledButton(actionGrid, '🔄 Focus', 1, 4, ...
                @(~,~) controller.startSIFocus(), ...
                'Start Focus mode in ScanImage', [0.85 0.95 0.95], 13);

            % Grab button
            grabButton = UIComponentFactory.createStyledButton(actionGrid, '📷 Grab', 1, 5, ...
                @(~,~) controller.grabSIFrame(), ...
                'Grab a single frame in ScanImage', [0.95 0.95 0.85], 13);
            
            % Abort button (hidden initially)
            abortButton = uibutton(actionGrid, 'Text', '⛔ ABORT', 'FontSize', 13, 'FontWeight', 'bold', ...
                'Tooltip', 'Abort current operation', ...
                'BackgroundColor', [0.95 0.6 0.6], ...
                'Visible', 'off');
            abortButton.Layout.Row = 1;
            abortButton.Layout.Column = [4 5];
        end
        
        function [statusText, statusBar] = createStatusBar(fig)
            % Creates the status bar at the bottom of the figure
            statusBar = uipanel(fig, 'BorderType', 'none', 'BackgroundColor', [0.85 0.85 0.95]);
            statusBar.Position = [0, 0, fig.Position(3), 30];
            
            statusGrid = uigridlayout(statusBar, [1, 2]);
            statusGrid.RowHeight = {'1x'};
            statusGrid.ColumnWidth = {'fit', '1x'};
            statusGrid.Padding = [10 0 10 0];
            
            % Help Button
            helpBtn = uibutton(statusGrid, 'Text', '❓ Help', ...
                'Tooltip', 'Show usage guide', ...
                'FontSize', 11, ...
                'ButtonPushedFcn', @(~,~) gui.handlers.UIEventHandlers.showHelp());
            helpBtn.Layout.Row = 1;
            helpBtn.Layout.Column = 1;

            % Status text with improved styling
            statusTextPanel = uipanel(statusGrid, 'BorderType', 'none', 'BackgroundColor', [0.85 0.85 0.95]);
            statusTextPanel.Layout.Row = 1;
            statusTextPanel.Layout.Column = 2;
            
            statusTextGrid = uigridlayout(statusTextPanel, [1, 1]);
            statusTextGrid.Padding = [5 0 5 0];
            
            statusText = uilabel(statusTextGrid, 'Text', 'Ready - Press Auto Z-Scan to begin focus finding', ...
                'FontSize', 11, 'FontColor', [0.1 0.1 0.4], 'FontWeight', 'bold');
            
            % Make sure status bar stays at bottom when window is resized
            fig.AutoResizeChildren = 'off';  % Turn off auto resize before setting SizeChangedFcn
        end
    end
end 