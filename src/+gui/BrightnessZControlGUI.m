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
                'Position', [100 100 700 520], ...
                'Color', [0.97 0.97 0.97], ...
                'CloseRequestFcn', @(~,~) obj.controller.closeFigure(), ...
                'Resize', 'on');

            % Remove Dev Tools panel and related controls
            % Expand plot area and adjust grid layout
            mainGrid = uigridlayout(obj.hFig, [4, 2]);
            mainGrid.RowHeight = {'fit', 50, '1x', 30};
            mainGrid.ColumnWidth = {'2x', '1x'};
            mainGrid.Padding = [10 10 10 10];
            mainGrid.RowSpacing = 5;
            mainGrid.ColumnSpacing = 10;

            % --- Scan Parameters Panel (Row 1, Col 1:2) ---
            paramPanel = uipanel(mainGrid, 'Title', 'Scan Parameters', 'FontWeight', 'bold');
            paramPanel.Layout.Row = 1;
            paramPanel.Layout.Column = [1 2];
            paramGrid = uigridlayout(paramPanel, [2, 5]);
            paramGrid.RowHeight = {22, 22};
            paramGrid.ColumnWidth = {'fit','fit','fit','fit','fit'};
            paramGrid.Padding = [5 5 5 5];
            paramGrid.RowSpacing = 2;
            paramGrid.ColumnSpacing = 5;

            % Step Size
            lbl = uilabel(paramGrid, 'Text', 'Step Size:', 'Tooltip', 'Set the Z scan step size (µm)');
            lbl.Layout.Row = 1;
            lbl.Layout.Column = 1;

            obj.hStepSizeSlider = uislider(paramGrid, ...
                'Limits', [1 50], 'Value', obj.controller.initialStepSize, ...
                'Tooltip', 'Set the Z scan step size (µm)', ...
                'ValueChangingFcn', @(src,event) obj.controller.updateStepSizeImmediate(event.Value));
            obj.hStepSizeSlider.Layout.Row = 1;
            obj.hStepSizeSlider.Layout.Column = 2;

            obj.hStepSizeValue = uilabel(paramGrid, 'Text', num2str(obj.controller.initialStepSize));
            obj.hStepSizeValue.Layout.Row = 1;
            obj.hStepSizeValue.Layout.Column = 3;

            lbl = uilabel(paramGrid, 'Text', 'Pause (s):', 'Tooltip', 'Pause between Z steps (seconds)');
            lbl.Layout.Row = 2;
            lbl.Layout.Column = 1;
            obj.hPauseTimeEdit = uieditfield(paramGrid, 'text', ...
                'Value', num2str(obj.controller.scanPauseTime), 'Tooltip', 'Pause between Z steps (seconds)');
            obj.hPauseTimeEdit.Layout.Row = 2;
            obj.hPauseTimeEdit.Layout.Column = 2;

            % Min Z
            lbl = uilabel(paramGrid, 'Text', 'Min Z:', 'Tooltip', 'Set minimum Z limit');
            lbl.Layout.Row = 2;
            lbl.Layout.Column = 3;
            obj.hMinZEdit = uieditfield(paramGrid, 'numeric', 'Tooltip', 'Minimum Z limit');
            obj.hMinZEdit.Layout.Row = 2;
            obj.hMinZEdit.Layout.Column = 4;
            btn = uibutton(paramGrid, 'Text', 'Set Min Z', 'Tooltip', 'Set minimum Z limit', ...
                'ButtonPushedFcn', @(~,~) obj.controller.setMinZLimit());
            btn.Layout.Row = 2;
            btn.Layout.Column = 5;

            % Max Z
            lbl = uilabel(paramGrid, 'Text', 'Max Z:', 'Tooltip', 'Set maximum Z limit');
            lbl.Layout.Row = 3;
            lbl.Layout.Column = 3;
            obj.hMaxZEdit = uieditfield(paramGrid, 'numeric', 'Tooltip', 'Maximum Z limit');
            obj.hMaxZEdit.Layout.Row = 3;
            obj.hMaxZEdit.Layout.Column = 4;
            btn = uibutton(paramGrid, 'Text', 'Set Max Z', 'Tooltip', 'Set maximum Z limit', ...
                'ButtonPushedFcn', @(~,~) obj.controller.setMaxZLimit());
            btn.Layout.Row = 3;
            btn.Layout.Column = 5;

            % Brightness Metric
            lbl = uilabel(paramGrid, 'Text', 'Brightness Metric:', 'Tooltip', 'Select brightness metric');
            lbl.Layout.Row = 4;
            lbl.Layout.Column = 1;
            obj.hMetricDropDown = uidropdown(paramGrid, ...
                'Items', {'Mean', 'Median', 'Max', '95th Percentile'}, ...
                'Tooltip', 'Select brightness metric', ...
                'Value', 'Mean');
            obj.hMetricDropDown.Layout.Row = 4;
            obj.hMetricDropDown.Layout.Column = 2;

            % --- Actions Panel (Row 2, Col 2) ---
            actionPanel = uipanel(mainGrid, 'Title', 'Actions', 'FontWeight', 'bold');
            actionPanel.Layout.Row = 2;
            actionPanel.Layout.Column = 2;
            actionGrid = uigridlayout(actionPanel, [1, 3]);
            actionGrid.RowHeight = {'1x'};
            actionGrid.ColumnWidth = {'1x','1x','1x'};

            % Monitor Button
            obj.hMonitorToggle = uibutton(actionGrid, 'state', ...
                'Text', 'Monitor', 'FontSize', 11, ...
                'Tooltip', 'Start/stop brightness monitoring', ...
                'ValueChangedFcn', @(src,~) obj.controller.toggleMonitor(src.Value));
            obj.hMonitorToggle.Layout.Row = 1;
            obj.hMonitorToggle.Layout.Column = 1;

            % Z-Scan Button
            obj.hZScanToggle = uibutton(actionGrid, 'state', ...
                'Text', 'Z-Scan', 'FontSize', 11, ...
                'Tooltip', 'Start/stop Z scanning', ...
                'ValueChangedFcn', @(src,~) obj.controller.toggleZScan(src.Value));
            obj.hZScanToggle.Layout.Row = 1;
            obj.hZScanToggle.Layout.Column = 2;

            % Move to Max Button
            btn = uibutton(actionGrid, 'Text', 'Move to Max', 'FontSize', 11, ...
                'Tooltip', 'Move to the Z position with maximum brightness', ...
                'ButtonPushedFcn', @(~,~) obj.controller.moveToMaxBrightness());
            btn.Layout.Row = 1;
            btn.Layout.Column = 3;

            % --- Help Button (bottom right) ---
            btn = uibutton(mainGrid, 'Text', 'Help', ...
                'Tooltip', 'Show usage guide', ...
                'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) helpdlg([ ...
                    '1. Set step size and pause time.' newline ...
                    '2. Use Monitor and Z-Scan to acquire data.' newline ...
                    '3. Move to Max to go to brightest Z.' newline ...
                    '4. Dev Tools: run quick tests.' ...
                ], 'Usage Guide'));
            btn.Layout.Row = 4;
            btn.Layout.Column = 1;

             % --- Plot Area (Row 3, Col 1) ---
            plotPanel = uipanel(mainGrid, 'Title', 'Brightness vs. Z-Position', 'FontWeight', 'bold');
            plotPanel.Layout.Row = 3;
            plotPanel.Layout.Column = [1 2]; % Span both columns
            obj.hAx = uiaxes(plotPanel);

            % --- Status Bar (Row 4, Col 1:2) ---
            obj.hStatusText = uilabel(mainGrid, 'Text', 'Ready.', 'FontColor', [0.1 0.1 0.4]);
            obj.hStatusText.Layout.Row = 4;
            obj.hStatusText.Layout.Column = 2;
        end

        function updatePlot(obj, zData, bData, activeChannel)
             % Update the brightness vs Z-position plot with visual markers
            try
                % Clear axes
                cla(obj.hAx);
                hold(obj.hAx, 'on');
                
                % Plot scan trace
                plot(obj.hAx, zData, bData, 'b.-', 'DisplayName', 'Scan Trace');
                
                % Mark scan start and end positions
                if ~isempty(zData)
                    % Start marker
                    plot(obj.hAx, zData(1), bData(1), 'go', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Scan Start');
                    % End marker
                    plot(obj.hAx, zData(end), bData(end), 'mo', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Scan End');
                end
                
                % Mark brightest point
                if ~isempty(bData)
                    [maxB, maxIdx] = max(bData);
                    maxZ = zData(maxIdx);
                    plot(obj.hAx, maxZ, maxB, 'rp', 'MarkerSize', 14, 'LineWidth', 2, 'DisplayName', 'Brightest Point');
                    text(obj.hAx, maxZ, maxB, sprintf('  Max: %.2f', maxB), 'Color', 'red', 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
                end
                
                % Labels and legend
                title(obj.hAx, sprintf('Brightness vs Z-Position (Channel %d)', activeChannel), 'FontWeight', 'bold');
                xlabel(obj.hAx, 'Z Position (µm)');
                ylabel(obj.hAx, 'Brightness (a.u.)');
                grid(obj.hAx, 'on');
                legend(obj.hAx, 'show', 'Location', 'best');
                hold(obj.hAx, 'off');
                drawnow;
            catch ME
                warning('Error updating plot: %s', ME.message);
            end
        end

        function updateStatus(obj, message)
            % Update status text
            try
                set(obj.hStatusText, 'String', message);
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