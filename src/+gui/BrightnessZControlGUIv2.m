classdef BrightnessZControlGUIv2 < handle
    % BrightnessZControlGUIv2 - Creates and manages the GUI for Brightness Z-Control
    % Improved version with better layout and visual design

    properties (Access = public)
        % GUI Handles
        hFig            % Main figure handle
        hAx             % Plot axes handle
        hStatusText     % Status text label
        hStepSizeSlider % Step size slider
        hStepSizeValue  % Step size value label
        hPauseTimeEdit  % Pause time edit field
        hMinZEdit       % Min Z edit field
        hMaxZEdit       % Max Z edit field
        hMetricDropDown % Metric dropdown
        hMonitorToggle  % Monitor toggle button
        hZScanToggle    % Z-scan toggle button
        hFocusButton    % Focus button
        hGrabButton     % Grab button
        hAbortButton    % Abort button
        hCurrentZLabel  % Current Z position label
    end

    properties (Access = private)
        controller % Handle to the main controller
    end

    methods
        function obj = BrightnessZControlGUIv2(controller)
            obj.controller = controller;
        end

        function create(obj)
            % Create main figure with compact, grid-based layout
            fprintf('Creating main figure...\n');
            obj.hFig = uifigure('Name', 'Brightness Z-Control v2', ...
                'Position', [100 100 900 650], ...
                'Color', [0.96 0.96 0.98], ...
                'CloseRequestFcn', @(~,~) obj.controller.closeFigure(), ...
                'Resize', 'on');
            
            % Check if we're running in a compatible MATLAB version
            hasNewUIControls = ~verLessThan('matlab', '9.8'); % R2020a or newer
            if ~hasNewUIControls
                fprintf('Warning: Running on an older MATLAB version. Some UI features may be limited.\n');
            end
            
            fprintf('Creating layout...\n');

            % Create a more efficient grid layout with better spacing
            mainGrid = uigridlayout(obj.hFig, [3, 2]);
            mainGrid.RowHeight = {'fit', '1x', 'fit'};
            mainGrid.ColumnWidth = {'1.2x', '1x'};
            mainGrid.Padding = [15 15 15 15];
            mainGrid.RowSpacing = 10;
            mainGrid.ColumnSpacing = 15;

            % --- Scan Parameters Panel (Row 1, Col 1) ---
            paramPanel = uipanel(mainGrid, 'Title', 'Scan Parameters', 'FontWeight', 'bold', 'FontSize', 13);
            paramPanel.BackgroundColor = [0.96 0.96 0.98];
            paramPanel.Layout.Row = 1;
            paramPanel.Layout.Column = 1;
            
            paramGrid = uigridlayout(paramPanel, [5, 4]);
            paramGrid.RowHeight = {'fit', 5, 'fit', 'fit', 'fit'};
            paramGrid.ColumnWidth = {'fit', '1.5x', 'fit', '1x'};
            paramGrid.Padding = [12 12 12 12];
            paramGrid.RowSpacing = 15;
            paramGrid.ColumnSpacing = 15;

            % Step Size with improved visual connection
            lbl = uilabel(paramGrid, 'Text', 'Step Size (µm):', 'FontWeight', 'bold', ...
                'Tooltip', 'Set the Z scan step size (µm)');
            lbl.Layout.Row = 1;
            lbl.Layout.Column = 1;

            % Slider panel with better visual design
            sliderPanel = uipanel(paramGrid, 'BorderType', 'none', 'BackgroundColor', paramPanel.BackgroundColor);
            sliderPanel.Layout.Row = 1;
            sliderPanel.Layout.Column = [2 3];
            
            sliderGrid = uigridlayout(sliderPanel, [2, 1]);
            sliderGrid.RowHeight = {'1x', '0.4x'};
            sliderGrid.ColumnWidth = {'1x'};
            sliderGrid.Padding = [0 0 0 0];
            sliderGrid.RowSpacing = 0;
            
            % Slider with improved appearance
            obj.hStepSizeSlider = uislider(sliderGrid, ...
                'Limits', [1 50], 'Value', obj.controller.initialStepSize, ...
                'MajorTicks', [1 8 15 22 29 36 43 50], ...
                'MinorTicks', [], ...
                'Tooltip', 'Set the Z scan step size (µm)', ...
                'ValueChangingFcn', @(src,event) obj.updateStepSizeValueDisplay(event.Value), ...
                'ValueChangedFcn', @(src,event) obj.controller.updateStepSizeImmediate(event.Value));
            obj.hStepSizeSlider.Layout.Row = 1;
            obj.hStepSizeSlider.Layout.Column = 1;
            
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
            
            % Step size value with better visual integration
            valuePanel = uipanel(paramGrid, 'BorderType', 'line', 'BackgroundColor', [1 1 1]);
            valuePanel.Layout.Row = 1;
            valuePanel.Layout.Column = 4;
            
            % Use a grid for the step size value to avoid absolute positioning issues
            valueGrid = uigridlayout(valuePanel, [1, 1]);
            valueGrid.Padding = [0 0 0 0];
            
            obj.hStepSizeValue = uilabel(valueGrid, 'Text', num2str(obj.controller.initialStepSize), ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 14);
            obj.hStepSizeValue.Layout.Row = 1;
            obj.hStepSizeValue.Layout.Column = 1;

            % Separator
            separatorPanel = uipanel(paramGrid, 'BorderType', 'line', 'BackgroundColor', paramPanel.BackgroundColor);
            separatorPanel.Layout.Row = 2;
            separatorPanel.Layout.Column = [1 4];
            separatorPanel.HighlightColor = [0.8 0.8 0.8];
            
            % Pause Time with better layout
            lbl = uilabel(paramGrid, 'Text', 'Pause (s):', 'FontWeight', 'bold', ...
                'Tooltip', 'Pause between Z steps (seconds)');
            lbl.Layout.Row = 3;
            lbl.Layout.Column = 1;
            
            obj.hPauseTimeEdit = uieditfield(paramGrid, 'numeric', ...
                'Value', obj.controller.scanPauseTime, ...
                'Tooltip', 'Pause between Z steps (seconds)', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 12, ...
                'ValueDisplayFormat', '%.1f', ...
                'BackgroundColor', [1 1 1]);
            obj.hPauseTimeEdit.Layout.Row = 3;
            obj.hPauseTimeEdit.Layout.Column = 2;
            
            % Brightness Metric with better layout
            lbl = uilabel(paramGrid, 'Text', 'Brightness Metric:', 'FontWeight', 'bold', ...
                'Tooltip', 'Select brightness metric');
            lbl.Layout.Row = 3;
            lbl.Layout.Column = 3;
            
            obj.hMetricDropDown = uidropdown(paramGrid, ...
                'Items', {'Mean', 'Median', 'Max', '95th Percentile'}, ...
                'Tooltip', 'Select brightness metric', ...
                'FontSize', 12, ...
                'BackgroundColor', [1 1 1], ...
                'Value', 'Mean');
            obj.hMetricDropDown.Layout.Row = 3;
            obj.hMetricDropDown.Layout.Column = 4;

            % Min Z with better layout and visual connection
            lbl = uilabel(paramGrid, 'Text', 'Min Z Position:', 'FontWeight', 'bold', ...
                'Tooltip', 'Set minimum Z limit (µm)');
            lbl.Layout.Row = 4;
            lbl.Layout.Column = 1;
            
            obj.hMinZEdit = uieditfield(paramGrid, 'numeric', ...
                'Tooltip', 'Minimum Z limit (µm)', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 12, ...
                'BackgroundColor', [1 1 1], ...
                'ValueDisplayFormat', '%.1f');
            obj.hMinZEdit.Layout.Row = 4;
            obj.hMinZEdit.Layout.Column = 2;
            
            btn = uibutton(paramGrid, 'Text', 'Set Min Z', ...
                'Tooltip', 'Set current position as minimum Z limit', ...
                'ButtonPushedFcn', @(~,~) obj.controller.setMinZLimit(), ...
                'FontSize', 12, ...
                'BackgroundColor', [0.9 0.9 1.0]);
            btn.Layout.Row = 4;
            btn.Layout.Column = [3 4];

            % Max Z with better layout and visual connection
            lbl = uilabel(paramGrid, 'Text', 'Max Z Position:', 'FontWeight', 'bold', ...
                'Tooltip', 'Set maximum Z limit (µm)');
            lbl.Layout.Row = 5;
            lbl.Layout.Column = 1;
            
            obj.hMaxZEdit = uieditfield(paramGrid, 'numeric', ...
                'Tooltip', 'Maximum Z limit (µm)', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 12, ...
                'BackgroundColor', [1 1 1], ...
                'ValueDisplayFormat', '%.1f');
            obj.hMaxZEdit.Layout.Row = 5;
            obj.hMaxZEdit.Layout.Column = 2;
            
            btn = uibutton(paramGrid, 'Text', 'Set Max Z', ...
                'Tooltip', 'Set current position as maximum Z limit', ...
                'ButtonPushedFcn', @(~,~) obj.controller.setMaxZLimit(), ...
                'FontSize', 12, ...
                'BackgroundColor', [0.9 0.9 1.0]);
            btn.Layout.Row = 5;
            btn.Layout.Column = [3 4];

            % --- Z Movement Controls Panel (Row 1, Col 2) ---
            zControlPanel = uipanel(mainGrid, 'Title', 'Z Movement Controls', 'FontWeight', 'bold', 'FontSize', 13);
            zControlPanel.BackgroundColor = [0.96 0.96 0.98];
            zControlPanel.Layout.Row = 1;
            zControlPanel.Layout.Column = 2;
            
            zControlGrid = uigridlayout(zControlPanel, [3, 2]);
            zControlGrid.RowHeight = {'fit', '1x', 'fit'};
            zControlGrid.ColumnWidth = {'1x', '1x'};
            zControlGrid.Padding = [12 12 12 12];
            zControlGrid.RowSpacing = 10;
            zControlGrid.ColumnSpacing = 15;
            
            % Current Z Position Display
            lbl = uilabel(zControlGrid, 'Text', 'Current Z Position (µm):', 'FontWeight', 'bold');
            lbl.Layout.Row = 1;
            lbl.Layout.Column = [1 2];
            
            zPosPanel = uipanel(zControlGrid, 'BorderType', 'line', 'BackgroundColor', [1 1 1]);
            zPosPanel.Layout.Row = 2;
            zPosPanel.Layout.Column = [1 2];
            
            % Use a grid for the current Z value to avoid absolute positioning issues
            zPosValueGrid = uigridlayout(zPosPanel, [1, 1]);
            zPosValueGrid.Padding = [0 0 0 0];
            
            obj.hCurrentZLabel = uilabel(zPosValueGrid, 'Text', '0.0', ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 20, ...
                'FontColor', [0.2 0.2 0.7]);
            obj.hCurrentZLabel.Layout.Row = 1;
            obj.hCurrentZLabel.Layout.Column = 1;
            
            % Z Movement Buttons with clear labels
            upBtn = uibutton(zControlGrid, 'Text', '▲ Up', 'FontSize', 14, 'FontWeight', 'bold', ...
                'Tooltip', 'Move Z stage up (decrease Z value)', ...
                'ButtonPushedFcn', @(~,~) obj.controller.moveZUp(), ...
                'BackgroundColor', [0.8 1.0 0.8]);
            upBtn.Layout.Row = 3;
            upBtn.Layout.Column = 1;
            
            downBtn = uibutton(zControlGrid, 'Text', '▼ Down', 'FontSize', 14, 'FontWeight', 'bold', ...
                'Tooltip', 'Move Z stage down (increase Z value)', ...
                'ButtonPushedFcn', @(~,~) obj.controller.moveZDown(), ...
                'BackgroundColor', [0.8 0.8 1.0]);
            downBtn.Layout.Row = 3;
            downBtn.Layout.Column = 2;

            % --- Plot Area (Row 2, Col 1:2) ---
            plotPanel = uipanel(mainGrid, 'Title', 'Brightness vs. Z-Position', 'FontWeight', 'bold', 'FontSize', 13);
            plotPanel.BackgroundColor = [0.96 0.96 0.98];
            plotPanel.Layout.Row = 2;
            plotPanel.Layout.Column = [1 2];
            
            plotGrid = uigridlayout(plotPanel, [1, 1]);
            plotGrid.Padding = [15 15 15 15];
            
            obj.hAx = uiaxes(plotGrid);
            obj.hAx.Layout.Row = 1;
            obj.hAx.Layout.Column = 1;
            
            % Initial plot setup with better styling
            grid(obj.hAx, 'on');
            box(obj.hAx, 'on');
            xlabel(obj.hAx, 'Z Position (µm)', 'FontWeight', 'bold', 'FontSize', 12);
            ylabel(obj.hAx, 'Brightness (a.u.)', 'FontWeight', 'bold', 'FontSize', 12);
            title(obj.hAx, 'Z-Scan Brightness Profile', 'FontWeight', 'bold', 'FontSize', 14);
            obj.hAx.GridAlpha = 0.3;
            obj.hAx.LineWidth = 1.2;
            obj.hAx.XLim = [0 1];
            obj.hAx.YLim = [0 1];
            obj.hAx.FontSize = 11;

            % --- Actions Panel (Row 3, Col 1:2) ---
            actionPanel = uipanel(mainGrid, 'Title', 'Control Actions', 'FontWeight', 'bold', 'FontSize', 13);
            actionPanel.BackgroundColor = [0.96 0.96 0.98];
            actionPanel.Layout.Row = 3;
            actionPanel.Layout.Column = [1 2];
            
            actionGrid = uigridlayout(actionPanel, [1, 5]);
            actionGrid.RowHeight = {'fit'};
            actionGrid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
            actionGrid.Padding = [12 15 12 15];
            actionGrid.ColumnSpacing = 15;

            % Monitor Button with improved styling
            obj.hMonitorToggle = uibutton(actionGrid, 'state', ...
                'Text', '👁️ Monitor', 'FontSize', 13, 'FontWeight', 'bold', ...
                'Tooltip', 'Start/stop brightness monitoring', ...
                'ValueChangedFcn', @(src,~) obj.controller.toggleMonitor(src.Value), ...
                'BackgroundColor', [0.85 0.95 0.85]);
            obj.hMonitorToggle.Layout.Row = 1;
            obj.hMonitorToggle.Layout.Column = 1;

            % Z-Scan Button with improved styling
            obj.hZScanToggle = uibutton(actionGrid, 'state', ...
                'Text', '🔍 Z-Scan', 'FontSize', 13, 'FontWeight', 'bold', ...
                'Tooltip', 'Start/stop Z scanning', ...
                'ValueChangedFcn', @(src,~) obj.toggleScanButtons(src.Value), ...
                'BackgroundColor', [0.85 0.85 0.95]);
            obj.hZScanToggle.Layout.Row = 1;
            obj.hZScanToggle.Layout.Column = 2;

            % Move to Max Button with improved styling
            btn = uibutton(actionGrid, 'Text', '⬆️ Move to Max', 'FontSize', 13, 'FontWeight', 'bold', ...
                'Tooltip', 'Move to the Z position with maximum brightness', ...
                'ButtonPushedFcn', @(~,~) obj.controller.moveToMaxBrightness(), ...
                'BackgroundColor', [0.95 0.85 0.85]);
            btn.Layout.Row = 1;
            btn.Layout.Column = 3;

            % Focus Button with improved styling
            obj.hFocusButton = uibutton(actionGrid, 'Text', '🔄 Focus', 'FontSize', 13, 'FontWeight', 'bold', ...
                'Tooltip', 'Start Focus mode in ScanImage', ...
                'ButtonPushedFcn', @(~,~) obj.controller.startSIFocus(), ...
                'BackgroundColor', [0.85 0.95 0.95]);
            obj.hFocusButton.Layout.Row = 1;
            obj.hFocusButton.Layout.Column = 4;

            % Grab Button with improved styling
            obj.hGrabButton = uibutton(actionGrid, 'Text', '📷 Grab', 'FontSize', 13, 'FontWeight', 'bold', ...
                'Tooltip', 'Grab a single frame in ScanImage', ...
                'ButtonPushedFcn', @(~,~) obj.controller.grabSIFrame(), ...
                'BackgroundColor', [0.95 0.95 0.85]);
            obj.hGrabButton.Layout.Row = 1;
            obj.hGrabButton.Layout.Column = 5;
            
            % Abort Button (hidden initially) with improved styling
            obj.hAbortButton = uibutton(actionGrid, 'Text', '⛔ ABORT', 'FontSize', 13, 'FontWeight', 'bold', ...
                'Tooltip', 'Abort current operation', ...
                'ButtonPushedFcn', @(~,~) obj.abortOperation(), ...
                'BackgroundColor', [0.95 0.7 0.7], ...
                'Visible', 'off');
            obj.hAbortButton.Layout.Row = 1;
            obj.hAbortButton.Layout.Column = [4 5];

            % --- Status Bar (Outside main grid) ---
            statusBar = uipanel(obj.hFig, 'BorderType', 'none', 'BackgroundColor', [0.92 0.92 1.0]);
            statusBar.Position = [0, 0, obj.hFig.Position(3), 30];
            
            statusGrid = uigridlayout(statusBar, [1, 2]);
            statusGrid.RowHeight = {'1x'};
            statusGrid.ColumnWidth = {'fit', '1x'};
            statusGrid.Padding = [10 0 10 0];
            
            % Help Button
            btn = uibutton(statusGrid, 'Text', '❓ Help', ...
                'Tooltip', 'Show usage guide', ...
                'FontSize', 11, ...
                'ButtonPushedFcn', @(~,~) helpdlg([ ...
                    '1. Set step size and pause time.' newline ...
                    '2. Use Z Movement buttons to position the sample.' newline ...
                    '3. Use Monitor to watch brightness in real-time.' newline ...
                    '4. Use Z-Scan to automatically scan through Z positions.' newline ...
                    '5. Move to Max to go to brightest Z position.' newline ...
                    '6. Use Focus and Grab buttons to control ScanImage.' newline ...
                    '7. Press Abort to stop any operation immediately.' newline ...
                ], 'Usage Guide'));
            btn.Layout.Row = 1;
            btn.Layout.Column = 1;

            % Status text with improved styling
            statusTextPanel = uipanel(statusGrid, 'BorderType', 'none', 'BackgroundColor', [0.92 0.92 1.0]);
            statusTextPanel.Layout.Row = 1;
            statusTextPanel.Layout.Column = 2;
            
            % Use a grid for the status text to avoid absolute positioning issues
            statusTextGrid = uigridlayout(statusTextPanel, [1, 1]);
            statusTextGrid.Padding = [5 0 5 0];
            
            obj.hStatusText = uilabel(statusTextGrid, 'Text', 'Ready', 'FontSize', 11, ...
                'FontColor', [0.1 0.1 0.4], 'FontWeight', 'bold');
            obj.hStatusText.Layout.Row = 1;
            obj.hStatusText.Layout.Column = 1;
            
            % Make sure status bar stays at bottom when window is resized
            obj.hFig.AutoResizeChildren = 'off';  % Turn off auto resize before setting SizeChangedFcn
            obj.hFig.SizeChangedFcn = @(~,~) obj.updateStatusBarPosition();
        end
        
        function updateStatusBarPosition(obj)
            % Update status bar position when window is resized
            if ishandle(obj.hFig)
                % Find the status bar panel (first child that is a panel with BorderType 'none')
                for i = 1:length(obj.hFig.Children)
                    if isa(obj.hFig.Children(i), 'matlab.ui.container.Panel') && ...
                       strcmp(obj.hFig.Children(i).BorderType, 'none')
                        % Update status bar position
                        obj.hFig.Children(i).Position = [0, 0, obj.hFig.Position(3), 30];
                        break;
                    end
                end
            end
        end
        
        function updateStepSizeValueDisplay(obj, value)
            % Update step size value display immediately during slider movement
            try
                obj.hStepSizeValue.Text = num2str(round(value));
                drawnow;
            catch ME
                warning('Error updating step size display: %s', ME.message);
            end
        end

        function toggleScanButtons(obj, isScanActive)
            % Toggle between scan control buttons and abort button
            if isScanActive
                % Hide normal buttons, show abort
                obj.hFocusButton.Visible = 'off';
                obj.hGrabButton.Visible = 'off';
                obj.hAbortButton.Visible = 'on';
                
                % Start the scan
                stepSize = max(1, round(obj.hStepSizeSlider.Value));
                pauseTime = obj.hPauseTimeEdit.Value;
                metricType = obj.hMetricDropDown.Value;
                obj.controller.toggleZScan(true, stepSize, pauseTime, metricType);
            else
                % Show normal buttons, hide abort
                obj.hFocusButton.Visible = 'on';
                obj.hGrabButton.Visible = 'on';
                obj.hAbortButton.Visible = 'off';
                
                % Stop the scan
                obj.controller.toggleZScan(false);
            end
        end
        
        function abortOperation(obj)
            % Handle abort button press
            
            % Set toggle buttons to off
            obj.hZScanToggle.Value = false;
            obj.toggleScanButtons(false);
            
            % Call controller abort method
            obj.controller.abortAllOperations();
            
            % Update status
            obj.updateStatus('Operation aborted by user');
        end

        function updatePlot(obj, zData, bData, activeChannel)
            % Update the brightness vs Z-position plot with visual markers
            try
                % Clear axes
                cla(obj.hAx);
                hold(obj.hAx, 'on');
                
                % Plot scan trace
                plot(obj.hAx, zData, bData, 'b.-', 'LineWidth', 1.5, 'DisplayName', 'Scan Trace');
                
                % Mark scan start and end positions
                if ~isempty(zData)
                    % Start marker
                    plot(obj.hAx, zData(1), bData(1), 'go', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Scan Start');
                    % End marker
                    plot(obj.hAx, zData(end), bData(end), 'mo', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Scan End');
                    
                    % Adjust axis limits to data
                    xRange = max(zData) - min(zData);
                    yRange = max(bData) - min(bData);
                    if xRange > 0
                        obj.hAx.XLim = [min(zData) - 0.05*xRange, max(zData) + 0.05*xRange];
                    end
                    if yRange > 0
                        obj.hAx.YLim = [max(0, min(bData) - 0.05*yRange), max(bData) + 0.05*yRange];
                    end
                end
                
                % Mark brightest point
                if ~isempty(bData)
                    [maxB, maxIdx] = max(bData);
                    maxZ = zData(maxIdx);
                    plot(obj.hAx, maxZ, maxB, 'rp', 'MarkerSize', 14, 'LineWidth', 2, 'DisplayName', 'Brightest Point');
                    text(obj.hAx, maxZ, maxB, sprintf('  Max: %.2f', maxB), 'Color', 'red', 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
                end
                
                % Enhance visual appearance
                title(obj.hAx, sprintf('Brightness vs Z-Position (Channel %d)', activeChannel), 'FontWeight', 'bold', 'FontSize', 12);
                
                % Add grid and improve appearance
                grid(obj.hAx, 'on');
                box(obj.hAx, 'on');
                obj.hAx.GridAlpha = 0.3;
                obj.hAx.LineWidth = 1.2;
                
                % Improved legend
                legend(obj.hAx, 'show', 'Location', 'best', 'FontSize', 9, 'Box', 'on');
                
                hold(obj.hAx, 'off');
                drawnow;
            catch ME
                warning('Error updating plot: %s', ME.message);
            end
        end
        
        function updateCurrentZ(obj, zValue)
            % Update current Z position display
            try
                obj.hCurrentZLabel.Text = sprintf('%.1f', zValue);
                drawnow;
            catch ME
                warning('Error updating Z position display: %s', ME.message);
            end
        end

        function updateStatus(obj, message)
            % Update status text
            try
                obj.hStatusText.Text = message;
                drawnow;
            catch ME
                warning('Error updating status: %s', ME.message);
            end
        end

        function delete(obj)
            % Destructor to clean up figure
            if ishandle(obj.hFig)
                delete(obj.hFig);
            end
        end
    end
end 