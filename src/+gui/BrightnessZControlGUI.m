classdef BrightnessZControlGUI < handle
    % BrightnessZControlGUI - Creates and manages the GUI for Brightness Z-Control

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
        hAdvParamPanel  % Advanced parameters panel
    end

    properties (Access = private)
        controller % Handle to the main controller
    end

    methods
        function obj = BrightnessZControlGUI(controller)
            obj.controller = controller;
        end

        function create(obj)
            % Create main figure with compact, grid-based layout
            obj.hFig = uifigure('Name', 'Brightness Z-Control', ...
                'Position', [100 100 700 550], ...
                'Color', [0.97 0.97 0.97], ...
                'CloseRequestFcn', @(~,~) obj.controller.closeFigure(), ...
                'Resize', 'on');

            % Create a more efficient grid layout with better spacing
            mainGrid = uigridlayout(obj.hFig, [5, 1]);
            mainGrid.RowHeight = {'fit', 'fit', 'fit', '1x', 32};
            mainGrid.ColumnWidth = {'1x'};
            mainGrid.Padding = [10 10 10 10];
            mainGrid.RowSpacing = 8;
            mainGrid.ColumnSpacing = 0;

            % --- Scan Parameters Panel (Row 1) ---
            paramPanel = uipanel(mainGrid, 'Title', 'Scan Parameters', 'FontWeight', 'bold', 'FontSize', 12);
            paramPanel.Layout.Row = 1;
            paramPanel.Layout.Column = 1;
            
            paramGrid = uigridlayout(paramPanel, [4, 4]);
            paramGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
            paramGrid.ColumnWidth = {'fit', '1x', '0.6x', '0.6x'};
            paramGrid.Padding = [10 10 10 10];
            paramGrid.RowSpacing = 12;
            paramGrid.ColumnSpacing = 15;

            % Step Size
            lbl = uilabel(paramGrid, 'Text', 'Step Size:', 'FontWeight', 'bold', ...
                'Tooltip', 'Set the Z scan step size (µm)');
            lbl.Layout.Row = 1;
            lbl.Layout.Column = 1;

            sliderPanel = uipanel(paramGrid, 'BorderType', 'none', 'BackgroundColor', [0.97 0.97 0.97]);
            sliderPanel.Layout.Row = 1;
            sliderPanel.Layout.Column = 2;
            
            sliderGrid = uigridlayout(sliderPanel, [2, 1]);
            sliderGrid.RowHeight = {'1x', '0.5x'};
            sliderGrid.ColumnWidth = {'1x'};
            sliderGrid.Padding = [0 0 0 0];
            sliderGrid.RowSpacing = 0;
            
            obj.hStepSizeSlider = uislider(sliderGrid, ...
                'Limits', [1 50], 'Value', obj.controller.initialStepSize, ...
                'MajorTicks', [1 8 15 22 29 36 43 50], ...
                'MinorTicks', [], ...
                'Tooltip', 'Set the Z scan step size (µm)', ...
                'ValueChangingFcn', @(src,event) obj.controller.updateStepSizeImmediate(event.Value));
            obj.hStepSizeSlider.Layout.Row = 1;
            obj.hStepSizeSlider.Layout.Column = 1;
            
            % Add tick labels - using individual labels for better alignment
            tickGrid = uigridlayout(sliderGrid, [1, 8]);
            tickGrid.RowHeight = {'1x'};
            tickGrid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x'};
            tickGrid.Padding = [0 0 0 0];
            tickGrid.ColumnSpacing = 0;
            tickGrid.Layout.Row = 2;
            tickGrid.Layout.Column = 1;
            
            % Create individual labels for each tick mark
            tickValues = [1, 8, 15, 22, 29, 36, 43, 50];
            for i = 1:length(tickValues)
                lbl = uilabel(tickGrid, 'Text', num2str(tickValues(i)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 8);
                lbl.Layout.Row = 1;
                lbl.Layout.Column = i;
            end

            valuePanel = uipanel(paramGrid, 'BorderType', 'none', 'BackgroundColor', [0.97 0.97 0.97]);
            valuePanel.Layout.Row = 1;
            valuePanel.Layout.Column = 3;
            
            valueGrid = uigridlayout(valuePanel, [1, 1]);
            valueGrid.RowHeight = {'1x'};
            valueGrid.ColumnWidth = {'1x'};
            valueGrid.Padding = [0 0 0 0];
            
            obj.hStepSizeValue = uilabel(valueGrid, 'Text', num2str(obj.controller.initialStepSize), ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 12);
            obj.hStepSizeValue.Layout.Row = 1;
            obj.hStepSizeValue.Layout.Column = 1;

            % Z Movement Controls
            zMovementPanel = uipanel(paramGrid, 'BorderType', 'none', 'BackgroundColor', [0.97 0.97 0.97]);
            zMovementPanel.Layout.Row = 1;
            zMovementPanel.Layout.Column = 4;
            
            % Add a title/label at the top of the panel
            uilabel(zMovementPanel, 'Text', 'Z Movement:', 'FontWeight', 'bold', ...
                'Tooltip', 'Move the Z stage up or down', ...
                'Position', [5 45 90 20]);
            
            % Z Movement Buttons Panel
            zMovementBtns = uigridlayout(zMovementPanel, [2, 1]);
            zMovementBtns.RowHeight = {'1x', '1x'};
            zMovementBtns.ColumnWidth = {'1x'};
            zMovementBtns.Padding = [10 20 10 5];
            zMovementBtns.RowSpacing = 5;
            
            % Up Arrow Button (Z decrease in ScanImage)
            btn = uibutton(zMovementBtns, 'Text', '▲', 'FontSize', 14, 'FontWeight', 'bold', ...
                'Tooltip', 'Move Z stage up', ...
                'ButtonPushedFcn', @(~,~) obj.controller.moveZUp(), ...
                'BackgroundColor', [0.8 1.0 0.8]);
            btn.Layout.Row = 1;
            btn.Layout.Column = 1;
            
            % Down Arrow Button (Z increase in ScanImage)
            btn = uibutton(zMovementBtns, 'Text', '▼', 'FontSize', 14, 'FontWeight', 'bold', ...
                'Tooltip', 'Move Z stage down', ...
                'ButtonPushedFcn', @(~,~) obj.controller.moveZDown(), ...
                'BackgroundColor', [0.8 0.8 1.0]);
            btn.Layout.Row = 2;
            btn.Layout.Column = 1;

            % Pause Time and Brightness Metric
            lbl = uilabel(paramGrid, 'Text', 'Pause (s):', 'FontWeight', 'bold', ...
                'Tooltip', 'Pause between Z steps (seconds)');
            lbl.Layout.Row = 2;
            lbl.Layout.Column = 1;
            
            obj.hPauseTimeEdit = uieditfield(paramGrid, 'numeric', ...
                'Value', obj.controller.scanPauseTime, ...
                'Tooltip', 'Pause between Z steps (seconds)', ...
                'HorizontalAlignment', 'center', ...
                'ValueDisplayFormat', '%.1f');
            obj.hPauseTimeEdit.Layout.Row = 2;
            obj.hPauseTimeEdit.Layout.Column = 2;
            
            lbl = uilabel(paramGrid, 'Text', 'Brightness Metric:', 'FontWeight', 'bold', ...
                'Tooltip', 'Select brightness metric');
            lbl.Layout.Row = 2;
            lbl.Layout.Column = 3;
            
            obj.hMetricDropDown = uidropdown(paramGrid, ...
                'Items', {'Mean', 'Median', 'Max', '95th Percentile'}, ...
                'Tooltip', 'Select brightness metric', ...
                'Value', 'Mean');
            obj.hMetricDropDown.Layout.Row = 2;
            obj.hMetricDropDown.Layout.Column = 4;

            % Min Z
            lbl = uilabel(paramGrid, 'Text', 'Min Z:', 'FontWeight', 'bold', ...
                'Tooltip', 'Set minimum Z limit');
            lbl.Layout.Row = 3;
            lbl.Layout.Column = 1;
            
            minZPanel = uipanel(paramGrid, 'BorderType', 'none', 'BackgroundColor', [0.97 0.97 0.97]);
            minZPanel.Layout.Row = 3;
            minZPanel.Layout.Column = 2;
            
            minZGrid = uigridlayout(minZPanel, [1, 2]);
            minZGrid.RowHeight = {'1x'};
            minZGrid.ColumnWidth = {'1x', '1.2x'};
            minZGrid.Padding = [0 0 0 0];
            minZGrid.ColumnSpacing = 10;
            
            obj.hMinZEdit = uieditfield(minZGrid, 'numeric', ...
                'Tooltip', 'Minimum Z limit', ...
                'HorizontalAlignment', 'center', ...
                'ValueDisplayFormat', '%.1f');
            obj.hMinZEdit.Layout.Row = 1;
            obj.hMinZEdit.Layout.Column = 1;
            
            btn = uibutton(minZGrid, 'Text', 'Set Min Z', ...
                'Tooltip', 'Set minimum Z limit', ...
                'ButtonPushedFcn', @(~,~) obj.controller.setMinZLimit(), ...
                'BackgroundColor', [0.9 0.9 1.0]);
            btn.Layout.Row = 1;
            btn.Layout.Column = 2;

            % Max Z
            lbl = uilabel(paramGrid, 'Text', 'Max Z:', 'FontWeight', 'bold', ...
                'Tooltip', 'Set maximum Z limit');
            lbl.Layout.Row = 4;
            lbl.Layout.Column = 1;
            
            maxZPanel = uipanel(paramGrid, 'BorderType', 'none', 'BackgroundColor', [0.97 0.97 0.97]);
            maxZPanel.Layout.Row = 4;
            maxZPanel.Layout.Column = 2;
            
            maxZGrid = uigridlayout(maxZPanel, [1, 2]);
            maxZGrid.RowHeight = {'1x'};
            maxZGrid.ColumnWidth = {'1x', '1.2x'};
            maxZGrid.Padding = [0 0 0 0];
            maxZGrid.ColumnSpacing = 10;
            
            obj.hMaxZEdit = uieditfield(maxZGrid, 'numeric', ...
                'Tooltip', 'Maximum Z limit', ...
                'HorizontalAlignment', 'center', ...
                'ValueDisplayFormat', '%.1f');
            obj.hMaxZEdit.Layout.Row = 1;
            obj.hMaxZEdit.Layout.Column = 1;
            
            btn = uibutton(maxZGrid, 'Text', 'Set Max Z', ...
                'Tooltip', 'Set maximum Z limit', ...
                'ButtonPushedFcn', @(~,~) obj.controller.setMaxZLimit(), ...
                'BackgroundColor', [0.9 0.9 1.0]);
            btn.Layout.Row = 1;
            btn.Layout.Column = 2;

            % --- Additional Parameters Panel (Row 2) ---
            obj.hAdvParamPanel = uipanel(mainGrid, 'Title', 'Additional Parameters', 'FontWeight', 'bold', 'FontSize', 12);
            obj.hAdvParamPanel.Layout.Row = 2;
            obj.hAdvParamPanel.Layout.Column = 1;
            
            advParamGrid = uigridlayout(obj.hAdvParamPanel, [1, 2]);
            advParamGrid.RowHeight = {'fit'};
            advParamGrid.ColumnWidth = {'1x', '1x'};
            advParamGrid.Padding = [10 10 10 10];
            
            % Placeholder for future parameters - left side
            leftParamPanel = uipanel(advParamGrid, 'BorderType', 'none', 'BackgroundColor', [0.97 0.97 0.97]);
            leftParamPanel.Layout.Row = 1;
            leftParamPanel.Layout.Column = 1;
            
            % Placeholder - right side
            rightParamPanel = uipanel(advParamGrid, 'BorderType', 'none', 'BackgroundColor', [0.97 0.97 0.97]);
            rightParamPanel.Layout.Row = 1;
            rightParamPanel.Layout.Column = 2;
            
            % Add a note about extensibility
            txt = uilabel(leftParamPanel, 'Text', 'Additional parameters can be added here', ...
                'Position', [10 5 250 20], 'FontColor', [0.5 0.5 0.5]);
            
            % --- Actions Panel (Row 3) ---
            actionPanel = uipanel(mainGrid, 'Title', 'Actions', 'FontWeight', 'bold', 'FontSize', 12);
            actionPanel.Layout.Row = 3;
            actionPanel.Layout.Column = 1;
            
            actionGrid = uigridlayout(actionPanel, [1, 5]);
            actionGrid.RowHeight = {'fit'};
            actionGrid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
            actionGrid.Padding = [10 10 10 10];
            actionGrid.ColumnSpacing = 15;

            % Monitor Button with icon and text
            obj.hMonitorToggle = uibutton(actionGrid, 'state', ...
                'Text', '👁️ Monitor', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Tooltip', 'Start/stop brightness monitoring', ...
                'ValueChangedFcn', @(src,~) obj.controller.toggleMonitor(src.Value), ...
                'BackgroundColor', [0.8 0.9 0.8]);
            obj.hMonitorToggle.Layout.Row = 1;
            obj.hMonitorToggle.Layout.Column = 1;

            % Z-Scan Button with icon and text
            obj.hZScanToggle = uibutton(actionGrid, 'state', ...
                'Text', '🔍 Z-Scan', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Tooltip', 'Start/stop Z scanning', ...
                'ValueChangedFcn', @(src,~) obj.toggleScanButtons(src.Value), ...
                'BackgroundColor', [0.8 0.8 0.9]);
            obj.hZScanToggle.Layout.Row = 1;
            obj.hZScanToggle.Layout.Column = 2;

            % Move to Max Button with icon and text
            btn = uibutton(actionGrid, 'Text', '⬆️ Move to Max', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Tooltip', 'Move to the Z position with maximum brightness', ...
                'ButtonPushedFcn', @(~,~) obj.controller.moveToMaxBrightness(), ...
                'BackgroundColor', [0.9 0.8 0.8]);
            btn.Layout.Row = 1;
            btn.Layout.Column = 3;

            % Focus Button (from ScanImage)
            obj.hFocusButton = uibutton(actionGrid, 'Text', '🔄 Focus', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Tooltip', 'Start Focus mode in ScanImage', ...
                'ButtonPushedFcn', @(~,~) obj.controller.startSIFocus(), ...
                'BackgroundColor', [0.8 0.9 0.9]);
            obj.hFocusButton.Layout.Row = 1;
            obj.hFocusButton.Layout.Column = 4;

            % Grab Button (from ScanImage)
            obj.hGrabButton = uibutton(actionGrid, 'Text', '📷 Grab', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Tooltip', 'Grab a single frame in ScanImage', ...
                'ButtonPushedFcn', @(~,~) obj.controller.grabSIFrame(), ...
                'BackgroundColor', [0.9 0.9 0.8]);
            obj.hGrabButton.Layout.Row = 1;
            obj.hGrabButton.Layout.Column = 5;
            
            % Abort Button (hidden initially)
            obj.hAbortButton = uibutton(actionGrid, 'Text', '⛔ ABORT', 'FontSize', 12, 'FontWeight', 'bold', ...
                'Tooltip', 'Abort current operation', ...
                'ButtonPushedFcn', @(~,~) obj.abortOperation(), ...
                'BackgroundColor', [1.0 0.7 0.7], ...
                'Visible', 'off');
            obj.hAbortButton.Layout.Row = 1;
            obj.hAbortButton.Layout.Column = {[4 5]};

            % --- Plot Area (Row 4, Col 1:2) ---
            plotPanel = uipanel(mainGrid, 'Title', 'Brightness vs. Z-Position', 'FontWeight', 'bold', 'FontSize', 12);
            plotPanel.Layout.Row = 4;
            plotPanel.Layout.Column = 1;
            
            plotGrid = uigridlayout(plotPanel, [1, 1]);
            plotGrid.Padding = [10 10 10 10];
            
            obj.hAx = uiaxes(plotGrid);
            obj.hAx.Layout.Row = 1;
            obj.hAx.Layout.Column = 1;
            
            % Initial plot setup
            grid(obj.hAx, 'on');
            box(obj.hAx, 'on');
            xlabel(obj.hAx, 'Z Position (µm)', 'FontWeight', 'bold');
            ylabel(obj.hAx, 'Brightness (a.u.)', 'FontWeight', 'bold');
            obj.hAx.XLim = [0 1];
            obj.hAx.YLim = [0 1];

            % --- Status Bar (Row 5) ---
            statusGrid = uigridlayout(mainGrid, [1, 2]);
            statusGrid.RowHeight = {'1x'};
            statusGrid.ColumnWidth = {'fit', '1x'};
            statusGrid.Padding = [10 0 10 0];
            statusGrid.Layout.Row = 5;
            statusGrid.Layout.Column = 1;
            
            % Help Button
            btn = uibutton(statusGrid, 'Text', '❓ Help', ...
                'Tooltip', 'Show usage guide', ...
                'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) helpdlg([ ...
                    '1. Set step size and pause time.' newline ...
                    '2. Use Monitor to watch brightness in real-time.' newline ...
                    '3. Use Z-Scan to automatically scan through Z positions.' newline ...
                    '4. Move to Max to go to brightest Z position.' newline ...
                    '5. Use Focus and Grab buttons to control ScanImage.' newline ...
                    '6. Press Abort to stop any operation immediately.' newline ...
                ], 'Usage Guide'));
            btn.Layout.Row = 1;
            btn.Layout.Column = 1;

            % Status text with background panel for better visibility
            statusPanel = uipanel(statusGrid, 'BorderType', 'none');
            statusPanel.Layout.Row = 1;
            statusPanel.Layout.Column = 2;
            statusPanel.BackgroundColor = [0.95 0.95 1.0];
            
            % Use a grid layout for the status text for better resizing
            statusTextGrid = uigridlayout(statusPanel, [1, 1]);
            statusTextGrid.RowHeight = {'1x'};
            statusTextGrid.ColumnWidth = {'1x'};
            statusTextGrid.Padding = [10 0 10 0];
            
            obj.hStatusText = uilabel(statusTextGrid, 'Text', 'Ready', 'FontSize', 11, ...
                'FontColor', [0.1 0.1 0.4], 'FontWeight', 'bold');
            obj.hStatusText.Layout.Row = 1;
            obj.hStatusText.Layout.Column = 1;
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