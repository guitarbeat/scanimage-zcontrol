classdef UIEventHandlers < handle
    % UIEventHandlers - Helper class for handling UI events
    % Used by BrightnessZControlGUIv3 to handle various UI interactions
    
    methods (Static)
        function updateStepSizeValueDisplay(stepSizeValue, value)
            % Update step size value display immediately during slider movement
            try
                stepSizeValue.Text = num2str(round(value));
                drawnow;
            catch ME
                warning('Error updating step size display: %s', ME.message);
            end
        end

        function toggleScanButtons(isScanActive, controller, focusButton, grabButton, abortButton, zScanToggle, stepSizeSlider, pauseTimeEdit, metricDropDown)
            % Toggle between scan control buttons and abort button
            if isScanActive
                % Hide normal buttons, show abort
                focusButton.Visible = 'off';
                grabButton.Visible = 'off';
                abortButton.Visible = 'on';
                
                % Start the scan
                stepSize = max(1, round(stepSizeSlider.Value));
                pauseTime = pauseTimeEdit.Value;
                metricType = metricDropDown.Value;
                controller.toggleZScan(true, stepSize, pauseTime, metricType);
            else
                % Show normal buttons, hide abort
                focusButton.Visible = 'on';
                grabButton.Visible = 'on';
                abortButton.Visible = 'off';
                
                % Stop the scan
                controller.toggleZScan(false);
            end
        end
        
        function abortOperation(controller, zScanToggle, statusText)
            % Handle abort button press
            
            % Set toggle buttons to off
            zScanToggle.Value = false;
            
            % Call controller abort method
            controller.abortAllOperations();
            
            % Update status
            UIEventHandlers.updateStatus(statusText, 'Operation aborted by user');
        end

        function updatePlot(axes, zData, bData, activeChannel)
            % Update the brightness vs Z-position plot with visual markers
            try
                % Clear axes
                cla(axes);
                hold(axes, 'on');
                
                % Plot scan trace with enhanced styling
                plot(axes, zData, bData, 'b.-', 'LineWidth', 2, 'DisplayName', 'Scan Trace');
                
                % Mark scan start and end positions
                if ~isempty(zData)
                    % Start marker
                    plot(axes, zData(1), bData(1), 'go', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Scan Start');
                    % End marker
                    plot(axes, zData(end), bData(end), 'mo', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Scan End');
                    
                    % Adjust axis limits to data
                    xRange = max(zData) - min(zData);
                    yRange = max(bData) - min(bData);
                    if xRange > 0
                        axes.XLim = [min(zData) - 0.05*xRange, max(zData) + 0.05*xRange];
                    end
                    if yRange > 0
                        axes.YLim = [max(0, min(bData) - 0.05*yRange), max(bData) + 0.05*yRange];
                    end
                end
                
                % Mark brightest point with star marker
                if ~isempty(bData)
                    [maxB, maxIdx] = max(bData);
                    maxZ = zData(maxIdx);
                    plot(axes, maxZ, maxB, 'rp', 'MarkerSize', 14, 'LineWidth', 2, 'DisplayName', 'Brightest Point');
                    text(axes, maxZ, maxB, sprintf('  Max: %.2f', maxB), 'Color', 'red', 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
                end
                
                % Enhanced visual appearance
                title(axes, sprintf('Brightness vs Z-Position (Channel %d)', activeChannel), 'FontWeight', 'bold', 'FontSize', 13);
                
                % Add grid and improve appearance
                grid(axes, 'on');
                box(axes, 'on');
                axes.GridAlpha = 0.3;
                axes.LineWidth = 1.2;
                
                % Improved legend
                legend(axes, 'show', 'Location', 'best', 'FontSize', 10, 'Box', 'on');
                
                hold(axes, 'off');
                drawnow;
            catch ME
                warning('Error updating plot: %s', ME.message);
            end
        end
        
        function updateCurrentZ(currentZLabel, zValue)
            % Update current Z position display
            try
                currentZLabel.Text = sprintf('%.1f', zValue);
                drawnow;
            catch ME
                warning('Error updating Z position display: %s', ME.message);
            end
        end

        function updateStatus(statusText, message)
            % Update status text
            try
                statusText.Text = message;
                drawnow;
            catch ME
                warning('Error updating status: %s', ME.message);
            end
        end
        
        function showHelp()
            % Display help dialog with usage instructions
            helpdlg([ ...
                'HOW TO FIND THE BEST FOCUS:' newline newline ...
                '1. SET UP: Adjust the step size (how far to move at each step) and pause time.' newline newline ...
                '2. AUTOMATIC FOCUS FINDING:' newline ...
                '   a. Press "Auto Z-Scan" to automatically scan through Z positions' newline ...
                '   b. When scan completes, press "Move to Max Focus" to jump to best focus' newline newline ...
                '3. MANUAL FOCUS FINDING:' newline ...
                '   a. Press "Monitor Brightness" to start tracking brightness' newline ...
                '   b. Use Up/Down buttons to move the Z stage while watching brightness' newline ...
                '   c. The plot will show brightness changes in real-time' newline newline ...
                '4. If needed, press "Abort" to stop any operation immediately.' newline ...
            ], 'Finding Focus - Usage Guide');
        end
        
        function updateStatusBarPosition(fig, statusBar)
            % Update status bar position when window is resized
            if ishandle(fig) && ishandle(statusBar)
                statusBar.Position = [0, 0, fig.Position(3), 30];
            end
        end
    end
end 