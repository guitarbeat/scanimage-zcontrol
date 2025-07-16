classdef PlotManager < handle
    % Manages the metrics plot in the FoilView application.
    % This class now delegates all plotting logic to MetricsPlotService.

    properties (Access = private)
        App
        MetricsPlotService
        IsPlotExpanded = false
        OriginalWindowSize = []
    end

    methods
        function obj = PlotManager(app)
            if nargin >= 1 && ~isempty(app)
                obj.App = app;
            end
            obj.MetricsPlotService = MetricsPlotService.getInstance();
        end

        function success = initializeMetricsPlot(obj, axes)
            obj.MetricsPlotService.initialize(axes);
            success = true;
        end

        function success = clearMetricsPlot(obj, ~)
            obj.MetricsPlotService.clear();
            success = true;
        end

        function success = updateMetricsPlot(obj, ~, controller)
            metrics = controller.getAutoStepMetrics();
            obj.MetricsPlotService.updateMetrics(metrics);
            success = true;
        end

        function success = expandGUI(obj, uiFigure, mainPanel, plotPanel, expandButton, app)
            % Expand GUI to show plot - adaptive to current window size
            success = false;
            if ~isvalid(uiFigure) || ~isvalid(mainPanel) || ~isvalid(plotPanel)
                return;
            end
            
            % Set ignore resize flag if app has the method
            if nargin >= 6 && ~isempty(app) && ismethod(app, 'setIgnoreNextResize')
                app.setIgnoreNextResize(true);
            end
            
            figPos = uiFigure.Position;
            % Store the original window size before expanding
            obj.OriginalWindowSize = figPos;
            
            currentWidth = figPos(3);
            currentHeight = figPos(4);
            
            % Calculate plot width based on current window size (adaptive)
            plotWidth = min(400, max(300, currentWidth * 0.6)); % Between 300-400px, or 60% of window
            spacing = 10;
            
            % Expand window to accommodate plot
            newWidth = currentWidth + plotWidth + spacing;
            uiFigure.Position = [figPos(1), figPos(2), newWidth, figPos(4)];
            
            % Constrain main panel to left portion only (prevent overlap with plot)
            if isvalid(mainPanel)
                % Main panel should only occupy the original width area
                mainPanelWidthRatio = currentWidth / newWidth;
                mainPanel.Position = [0, 0, mainPanelWidthRatio, 1];
            end
            
            % Position plot panel to the right of the main content
            plotPanelX = currentWidth + spacing/2;
            plotPanelY = 10;
            plotPanelHeight = currentHeight - 20;
            plotPanel.Position = [plotPanelX, plotPanelY, plotWidth, plotPanelHeight];
            plotPanel.Visible = 'on';
            
            % Update button appearance
            expandButton.BackgroundColor = [0.9 0.6 0.2];
            expandButton.FontColor = [1 1 1];
            expandButton.Text = '📊 Hide Plot';
            expandButton.FontSize = 10;
            expandButton.FontWeight = 'bold';
            
            % Update window title
            uiFigure.Name = sprintf('%s - Plot Expanded', UiComponents.TEXT.WindowTitle);
            
            obj.IsPlotExpanded = true;
            success = true;
        end

        function success = collapseGUI(obj, uiFigure, mainPanel, plotPanel, expandButton, app)
            % Retain collapse logic as UI wiring only
            success = false;
            if ~isvalid(uiFigure) || ~isvalid(plotPanel)
                return;
            end
            
            % Update state FIRST to prevent resize monitor interference
            obj.IsPlotExpanded = false;
            
            % Set ignore resize flag BEFORE making changes
            if nargin >= 6 && ~isempty(app) && ismethod(app, 'setIgnoreNextResize')
                app.setIgnoreNextResize(true);
            end
            
            % Hide the plot panel
            plotPanel.Visible = 'off';
            
            % Restore to the original window size (adaptive)
            figPos = uiFigure.Position;
            if ~isempty(obj.OriginalWindowSize) && length(obj.OriginalWindowSize) >= 4
                % Use the stored original size for perfect restoration
                newPosition = obj.OriginalWindowSize;
            else
                % Fallback: use a reasonable default width
                collapsedWidth = max(UiComponents.DEFAULT_WINDOW_WIDTH, figPos(3) * 0.4);
                newPosition = [figPos(1), figPos(2), collapsedWidth, figPos(4)];
            end
            
            % Force the window to the collapsed size
            uiFigure.Position = newPosition;
            
            % Force the main panel to recalculate its layout
            if isvalid(mainPanel)
                % Temporarily disable auto-resize to force recalculation
                mainPanel.AutoResizeChildren = 'off';
                drawnow;
                mainPanel.AutoResizeChildren = 'on';
                drawnow;
                
                % Force the main panel to fill the window
                mainPanel.Position = [0, 0, 1, 1];
                drawnow;
            end
            
            % Force refresh of the main layout if available through app
            if nargin >= 6 && ~isempty(app) && isfield(app, 'MainLayout') && isvalid(app.MainLayout)
                % Force the grid layout to recalculate by toggling a property
                currentPadding = app.MainLayout.Padding;
                app.MainLayout.Padding = currentPadding + [1 1 1 1];
                drawnow;
                app.MainLayout.Padding = currentPadding;
                drawnow;
            end
            
            % Update button appearance
            expandButton.BackgroundColor = [0.2 0.6 0.9];
            expandButton.FontColor = [1 1 1];
            expandButton.Text = '📊 Show Plot';
            expandButton.FontSize = 10;
            expandButton.FontWeight = 'bold';
            
            % Update window title
            uiFigure.Name = UiComponents.TEXT.WindowTitle;
            
            % Final refresh to ensure everything is properly laid out
            drawnow;
            pause(0.05);
            drawnow;
            
            success = true;
        end

        function expanded = getIsPlotExpanded(obj)
            % Returns the current state of the plot (expanded or collapsed)
            expanded = obj.IsPlotExpanded;
        end

        function originalSize = getOriginalWindowSize(obj)
            % Returns the original window size stored before plot expansion
            originalSize = obj.OriginalWindowSize;
        end

        function success = exportPlotData(~, uiFigure, controller)
            metrics = controller.getAutoStepMetrics();
            if isempty(metrics.Positions)
                uialert(uiFigure, 'No data to export. Run auto-stepping with "Record Metrics" enabled first.', 'No Data');
                success = false;
                return;
            end
            [file, path] = uiputfile('*.mat', 'Save Metrics Data');
            if file == 0
                success = false;
                return;
            end
            save(fullfile(path, file), 'metrics');
            uialert(uiFigure, sprintf('Data exported to %s', fullfile(path, file)), 'Export Complete', 'Icon', 'success');
            success = true;
        end
    end
end 