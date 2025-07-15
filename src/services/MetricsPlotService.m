classdef MetricsPlotService < handle
    % MetricsPlotService
    %
    % Encapsulates all logic for creating, updating, and clearing plots.
    %
    % Usage:
    %   plotSvc = MetricsPlotService.getInstance();
    %   plotSvc.initialize(parentAxes);
    %   plotSvc.updateMetrics(dataStruct);
    %   plotSvc.clear();
    %
    % Public methods
    %   getInstance()             – singleton accessor
    %   initialize(parentAxes)    – bind to axes handle
    %   updateMetrics(data)       – redraw with new metric values
    %   clear()                   – clear all plots
    %
    % Example:
    %   svc = MetricsPlotService.getInstance();
    %   svc.initialize(ax);
    %   svc.updateMetrics(myMetrics);

    properties (Access=private)
        AxesHandle
        PlotLines = {}
        LastPlotUpdate = 0
    end
    properties (Constant, Access=private)
        METRIC_TYPES = {'Std Dev', 'Mean', 'Max'}
        DEFAULT_COLORS = {'#0072BD', '#D95319', '#EDB120', '#7E2F8E', '#77AC30', '#4DBEEE', '#A2142F'}
        DEFAULT_MARKERS = {'o', 's', 'd', '^', 'v', '>', '<'}
    end
    methods (Static)
        function obj = getInstance()
            persistent singleton
            if isempty(singleton)
                singleton = MetricsPlotService();
            end
            obj = singleton;
        end
    end
    methods
        function initialize(obj, parentAxes)
            obj.AxesHandle = parentAxes;
            axes = obj.AxesHandle;
            xlim(axes, [0, 1]);
            ylim(axes, [0, 1]);
            obj.PlotLines = cell(length(obj.METRIC_TYPES), 1);
            for i = 1:length(obj.METRIC_TYPES)
                colorIdx = mod(i-1, length(obj.DEFAULT_COLORS)) + 1;
                markerIdx = mod(i-1, length(obj.DEFAULT_MARKERS)) + 1;
                obj.PlotLines{i} = plot(axes, NaN, NaN, ...
                    'Color', obj.DEFAULT_COLORS{colorIdx}, ...
                    'Marker', obj.DEFAULT_MARKERS{markerIdx}, ...
                    'LineStyle', '-', ...
                    'LineWidth', 1.5, ...
                    'MarkerSize', 4, ...
                    'DisplayName', obj.METRIC_TYPES{i});
            end
            title(axes, 'Metrics vs Z Position');
            xlabel(axes, 'Z Position (μm)');
            ylabel(axes, 'Normalized Metric Value');
            legend(axes, 'Location', 'northeast');
            drawnow;
        end

        function updateMetrics(obj, metrics)
            % metrics: struct with fields Positions, Values (fields: Std_Dev, Mean, Max)
            if isempty(obj.AxesHandle) || isempty(obj.PlotLines)
                return;
            end
            positions = metrics.Positions;
            values = metrics.Values;
            if isempty(positions)
                return;
            end
            % Limit data for performance (optional, can add logic here)
            validMetrics = false;
            for i = 1:length(obj.METRIC_TYPES)
                metricType = obj.METRIC_TYPES{i};
                fieldName = strrep(metricType, ' ', '_');
                if i > length(obj.PlotLines) || ~isvalid(obj.PlotLines{i})
                    continue;
                end
                if isfield(values, fieldName)
                    xData = positions;
                    yData = values.(fieldName);
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
                    set(obj.PlotLines{i}, 'XData', xData, 'YData', yData);
                end
            end
            if validMetrics && length(positions) > 1
                obj.updateAxisLimits(positions, values);
            end
            drawnow limitrate;
        end

        function clear(obj)
            if isempty(obj.AxesHandle) || isempty(obj.PlotLines)
                return;
            end
            axes = obj.AxesHandle;
            for i = 1:length(obj.PlotLines)
                if ~isempty(obj.PlotLines{i}) && isvalid(obj.PlotLines{i})
                    set(obj.PlotLines{i}, 'XData', NaN, 'YData', NaN);
                end
            end
            xlim(axes, [0, 1]);
            ylim(axes, [0, 1]);
            title(axes, 'Metrics vs Z Position');
            xlabel(axes, 'Z Position (μm)');
            ylabel(axes, 'Normalized Metric Value');
            drawnow;
        end

        function updateAxisLimits(obj, positions, values)
            axes = obj.AxesHandle;
            xMin = min(positions);
            xMax = max(positions);
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
            for i = 1:length(obj.METRIC_TYPES)
                metricType = obj.METRIC_TYPES{i};
                fieldName = strrep(metricType, ' ', '_');
                if isfield(values, fieldName)
                    validY = values.(fieldName)(~isnan(values.(fieldName)));
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
            title(axes, 'Normalized Metrics vs Z Position');
            ylabel(axes, 'Normalized Metric Value (relative to first)');
        end
    end
end 