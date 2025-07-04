classdef PlotManager < handle
    % Manages the metrics plot in the FoilView application.
    % This class handles the creation, updating, and user interactions
    % with the metrics plot, such as expanding, collapsing, and exporting data.

    properties (Access = private)
        App
        MetricsPlotLines = {}
        IsPlotExpanded = false
        LastPlotUpdate = 0
    end

    properties (Constant, Access = private)
        PLOT_WIDTH_CONST = 400
        DEFAULT_COLORS = {'#0072BD', '#D95319', '#EDB120', '#7E2F8E', '#77AC30', '#4DBEEE', '#A2142F'}
        DEFAULT_MARKERS = {'o', 's', 'd', '^', 'v', '>', '<'}
    end

    methods
        function obj = PlotManager(app)
            if nargin >= 1 && ~isempty(app)
                obj.App = app;
                obj.LastPlotUpdate = 0;
            end
        end

        function success = initializeMetricsPlot(obj, axes)
            success = FoilviewUtils.safeExecuteWithReturn(@() doInitialize(), 'initializeMetricsPlot', false);

            function success = doInitialize()
                success = false;

                if ~FoilviewUtils.validateUIComponent(axes)
                    fprintf('Invalid axes provided to initializeMetricsPlot\n');
                    return;
                end

                xlim(axes, [0, 1]);
                ylim(axes, [0, 1]);

                metricTypes = {'Std Dev', 'Mean', 'Max'};
                obj.MetricsPlotLines = cell(length(metricTypes), 1);

                for i = 1:length(metricTypes)
                    metricType = metricTypes{i};
                    colorIdx = mod(i-1, length(obj.DEFAULT_COLORS)) + 1;
                    markerIdx = mod(i-1, length(obj.DEFAULT_MARKERS)) + 1;

                    obj.MetricsPlotLines{i} = plot(axes, NaN, NaN, ...
                        'Color', obj.DEFAULT_COLORS{colorIdx}, ...
                        'Marker', obj.DEFAULT_MARKERS{markerIdx}, ...
                        'LineStyle', '-', ...
                        'LineWidth', FoilviewUtils.UI_STYLE.LINE_WIDTH, ...
                        'MarkerSize', FoilviewUtils.UI_STYLE.MARKER_SIZE, ...
                        'DisplayName', metricType);
                end

                FoilviewUtils.configureAxes(axes, 'Metrics vs Z Position');
                FoilviewUtils.createLegend(axes);

                drawnow;
                success = true;
            end
        end

        function success = clearMetricsPlot(obj, axes)
            success = FoilviewUtils.safeExecuteWithReturn(@() doClear(), 'clearMetricsPlot', false);

            function success = doClear()
                success = false;

                if ~FoilviewUtils.validateUIComponent(axes)
                    return;
                end

                for i = 1:length(obj.MetricsPlotLines)
                    if ~isempty(obj.MetricsPlotLines{i}) && FoilviewUtils.validateUIComponent(obj.MetricsPlotLines{i})
                        set(obj.MetricsPlotLines{i}, 'XData', NaN, 'YData', NaN);
                    end
                end

                xlim(axes, [0, 1]);
                ylim(axes, [0, 1]);

                FoilviewUtils.configureAxes(axes, 'Metrics vs Z Position');

                drawnow;
                success = true;
            end
        end

        function success = updateMetricsPlot(obj, axes, controller)
            success = FoilviewUtils.safeExecuteWithReturn(@() doUpdate(), 'updateMetricsPlot', false);

            function success = doUpdate()
                success = false;

                if ~FoilviewUtils.shouldThrottleUpdate(obj.LastPlotUpdate, FoilviewUtils.DEFAULT_PLOT_THROTTLE)
                    return;
                end
                obj.LastPlotUpdate = posixtime(datetime('now'));

                if ~FoilviewUtils.validateUIComponent(axes) || isempty(controller)
                    return;
                end

                metrics = controller.getAutoStepMetrics();

                if isempty(metrics.Positions)
                    success = true;
                    return;
                end

                [limitedPositions, limitedValues] = FoilviewUtils.limitMetricsData(metrics.Positions, metrics.Values);

                validMetrics = false;
                metricTypes = {'Std Dev', 'Mean', 'Max'};
                for i = 1:length(metricTypes)
                    if i > length(obj.MetricsPlotLines) || ~FoilviewUtils.validateUIComponent(obj.MetricsPlotLines{i})
                        continue;
                    end

                    metricType = metricTypes{i};
                    fieldName = strrep(metricType, ' ', '_');

                    if isfield(limitedValues, fieldName)
                        xData = limitedPositions;
                        yData = limitedValues.(fieldName);

                        validIdx = ~isnan(yData) & ~isnan(xData);
                        xData = xData(validIdx);
                        yData = yData(validIdx);

                        if ~isempty(yData)
                            firstValue = yData(1);
                            if firstValue ~= 0
                                yData = yData / firstValue;
                            end
                            validMetrics = true;
                        end

                        set(obj.MetricsPlotLines{i}, 'XData', xData, 'YData', yData);
                    end
                end

                if validMetrics && length(limitedPositions) > 1
                    obj.updateAxisLimits(axes, struct('Positions', limitedPositions, 'Values', limitedValues));
                end

                drawnow limitrate;
                success = true;
            end
        end

        function updateAxisLimits(~, axes, metrics)
            FoilviewUtils.safeExecute(@() doUpdateLimits(), 'updateAxisLimits');

            function doUpdateLimits()
                xMin = min(metrics.Positions);
                xMax = max(metrics.Positions);

                if abs(xMax - xMin) < 0.001
                    xMin = xMin - 1;
                    xMax = xMax + 1;
                else
                    xRange = xMax - xMin;
                    xPadding = xRange * 0.05;
                    xMin = xMin - xPadding;
                    xMax = xMax + xPadding;
                end

                xlim(axes, [xMin, xMax]);

                yValues = [];
                metricTypes = {'Std Dev', 'Mean', 'Max'};
                for i = 1:length(metricTypes)
                    metricType = metricTypes{i};
                    fieldName = strrep(metricType, ' ', '_');
                    if isfield(metrics.Values, fieldName)
                        validY = metrics.Values.(fieldName)(~isnan(metrics.Values.(fieldName)));
                        if ~isempty(validY)
                            firstValue = validY(1);
                            if firstValue ~= 0
                                validY = validY / firstValue;
                            end
                            yValues = [yValues, validY]; %#ok<AGROW>
                        end
                    end
                end

                if ~isempty(yValues)
                    yMin = min(yValues);
                    yMax = max(yValues);

                    if abs(yMax - yMin) < 0.001
                        yMin = yMin - 0.1;
                        yMax = yMax + 0.1;
                    else
                        yRange = yMax - yMin;
                        yPadding = max(yRange * 0.1, 0.05);
                        yMin = yMin - yPadding;
                        yMax = yMax + yPadding;
                    end

                    ylim(axes, [yMin, yMax]);
                end

                FoilviewUtils.setPlotTitle(axes, 'Normalized Metrics vs Z Position', true, ...
                    min(metrics.Positions), max(metrics.Positions));

                ylabel(axes, 'Normalized Metric Value (relative to first)', ...
                    'FontSize', FoilviewUtils.UI_STYLE.FONT_SIZE_NORMAL);
            end
        end

        function success = expandGUI(obj, uiFigure, mainPanel, plotPanel, expandButton, app)
            success = FoilviewUtils.safeExecuteWithReturn(@() doExpand(), 'expandGUI', false);

            function success = doExpand()
                success = false;

                if obj.IsPlotExpanded
                    success = true;
                    return;
                end

                if ~FoilviewUtils.validateMultipleComponents(uiFigure, mainPanel, plotPanel)
                    return;
                end

                if nargin >= 6 && ~isempty(app) && isprop(app, 'IgnoreNextResize')
                    app.IgnoreNextResize = true;
                end

                figPos = uiFigure.Position;
                currentWidth = figPos(3);
                currentHeight = figPos(4);

                newWidth = currentWidth + obj.PLOT_WIDTH_CONST + 20;
                uiFigure.Position = [figPos(1), figPos(2), newWidth, figPos(4)];

                plotPanelX = currentWidth + 10;
                plotPanelY = 10;
                plotPanelHeight = currentHeight - 20;
                plotPanel.Position = [plotPanelX, plotPanelY, obj.PLOT_WIDTH_CONST, plotPanelHeight];
                plotPanel.Visible = 'on';

                expandButton.BackgroundColor = [0.9 0.6 0.2];  % warning color
                expandButton.FontColor = [1 1 1];  % white text
                expandButton.Text = '📊 Hide Plot';
                expandButton.FontSize = 10;
                expandButton.FontWeight = 'bold';

                obj.IsPlotExpanded = true;

                uiFigure.Name = sprintf('%s - Plot Expanded', UiComponents.TEXT.WindowTitle);
                success = true;
            end
        end

        function success = collapseGUI(obj, uiFigure, ~, plotPanel, expandButton, app)
            success = FoilviewUtils.safeExecuteWithReturn(@() doCollapse(), 'collapseGUI', false);

            function success = doCollapse()
                if ~obj.IsPlotExpanded
                    success = true;
                    return;
                end

                if nargin >= 6 && ~isempty(app) && isprop(app, 'IgnoreNextResize')
                    app.IgnoreNextResize = true;
                end

                plotPanel.Visible = 'off';

                figPos = uiFigure.Position;
                originalWidth = figPos(3) - obj.PLOT_WIDTH_CONST - 20;
                uiFigure.Position = [figPos(1), figPos(2), originalWidth, figPos(4)];

                expandButton.BackgroundColor = [0.2 0.6 0.9];  % primary color
                expandButton.FontColor = [1 1 1];  % white text
                expandButton.Text = '📊 Show Plot';
                expandButton.FontSize = 10;
                expandButton.FontWeight = 'bold';

                obj.IsPlotExpanded = false;

                uiFigure.Name = UiComponents.TEXT.WindowTitle;
                success = true;
            end
        end

        function expanded = getIsPlotExpanded(obj)
            expanded = obj.IsPlotExpanded;
        end

        function success = exportPlotData(~, uiFigure, controller)
            success = FoilviewUtils.safeExecuteWithReturn(@() doExport(), 'exportPlotData', false);

            function success = doExport()
                success = false;

                metrics = controller.getAutoStepMetrics();
                if isempty(metrics.Positions)
                    uialert(uiFigure, 'No data to export. Run auto-stepping with "Record Metrics" enabled first.', 'No Data');
                    return;
                end

                [file, path] = uiputfile('*.mat', 'Save Metrics Data');
                if file == 0
                    return;
                end

                save(fullfile(path, file), 'metrics');
                uialert(uiFigure, sprintf('Data exported to %s', fullfile(path, file)), 'Export Complete', 'Icon', 'success');
                success = true;
            end
        end
    end
end 