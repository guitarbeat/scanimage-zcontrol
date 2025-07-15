classdef PlotManager < handle
    % Manages the metrics plot in the FoilView application.
    % This class now delegates all plotting logic to MetricsPlotService.

    properties (Access = private)
        App
        MetricsPlotService
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

        function success = expandGUI(~, uiFigure, mainPanel, plotPanel, expandButton, app)
            % Retain expand/collapse logic as UI wiring only
            success = false;
            if ~isvalid(uiFigure) || ~isvalid(mainPanel) || ~isvalid(plotPanel)
                return;
            end
            if nargin >= 6 && ~isempty(app) && isprop(app, 'IgnoreNextResize')
                app.IgnoreNextResize = true;
            end
            figPos = uiFigure.Position;
            currentWidth = figPos(3);
            currentHeight = figPos(4);
            newWidth = currentWidth + 400 + 20;
            uiFigure.Position = [figPos(1), figPos(2), newWidth, figPos(4)];
            plotPanelX = currentWidth + 10;
            plotPanelY = 10;
            plotPanelHeight = currentHeight - 20;
            plotPanel.Position = [plotPanelX, plotPanelY, 400, plotPanelHeight];
            plotPanel.Visible = 'on';
            expandButton.BackgroundColor = [0.9 0.6 0.2];
            expandButton.FontColor = [1 1 1];
            expandButton.Text = '📊 Hide Plot';
            expandButton.FontSize = 10;
            expandButton.FontWeight = 'bold';
            uiFigure.Name = sprintf('%s - Plot Expanded', UiComponents.TEXT.WindowTitle);
            success = true;
        end

        function success = collapseGUI(~, uiFigure, ~, plotPanel, expandButton, app)
            % Retain collapse logic as UI wiring only
            if nargin >= 6 && ~isempty(app) && isprop(app, 'IgnoreNextResize')
                app.IgnoreNextResize = true;
            end
            plotPanel.Visible = 'off';
            figPos = uiFigure.Position;
            originalWidth = figPos(3) - 400 - 20;
            uiFigure.Position = [figPos(1), figPos(2), originalWidth, figPos(4)];
            expandButton.BackgroundColor = [0.2 0.6 0.9];
            expandButton.FontColor = [1 1 1];
            expandButton.Text = '📊 Show Plot';
            expandButton.FontSize = 10;
            expandButton.FontWeight = 'bold';
            uiFigure.Name = UiComponents.TEXT.WindowTitle;
            success = true;
        end

        function expanded = getIsPlotExpanded(~)
            % This can be tracked in the app or UI state if needed
            expanded = false;
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