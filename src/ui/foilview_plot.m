classdef foilview_plot < handle
    % foilview_plot - Enhanced metrics plotting for foilview
    %
    % This class manages all aspects of the metrics plotting functionality including
    % initialization, updating, clearing, and GUI expansion/collapse for plots.
    % Refactored for better maintainability and reduced complexity.
    
    properties (Access = private)
        App  % Reference to the main application
        MetricsPlotLines = {}
        IsPlotExpanded = false
        LastPlotUpdate = 0  % Track last update time for throttling
        OriginalFigureWidth = []  % Store figure width before expansion
    end
    
    properties (Constant, Access = private)
        % Plot configuration constants
        PLOT_WIDTH = foilview_constants.PLOT_WIDTH
        PLOT_PADDING = 20 % If not in constants, keep here
        MIN_AXIS_RANGE = foilview_constants.PLOT_MIN_AXIS_RANGE
        AXIS_PADDING_PERCENT = foilview_constants.PLOT_AXIS_PADDING_PERCENT
        Y_AXIS_MIN_PADDING = foilview_constants.PLOT_Y_AXIS_MIN_PADDING
        
        % Visual styling constants
        DEFAULT_COLORS = {[0 0.447 0.741], [0.851 0.325 0.098], [0.929 0.694 0.125], ...
                         [0.494 0.184 0.556], [0.466 0.674 0.188], [0.302 0.745 0.933], ...
                         [0.635 0.078 0.184]}
        DEFAULT_MARKERS = {'o', 's', 'd', '^', 'v', '>', '<'}
        
        % Metric type definitions
        METRIC_TYPES = {'Std Dev', 'Mean', 'Max'}
        
        % Plot properties
        LINE_WIDTH = foilview_constants.PLOT_LINE_WIDTH
        MARKER_SIZE = foilview_constants.PLOT_MARKER_SIZE
    end
    
    methods
        function obj = foilview_plot(app)
            % Constructor with enhanced validation
            obj.validateConstructorInput(app);
            obj.App = app;
            obj.LastPlotUpdate = 0;
        end
        
        function success = initializeMetricsPlot(obj, axes)
            % Initialize plot with improved error handling and modularity
            success = obj.safeExecuteOperation(@() obj.doInitializePlot(axes), 'initializeMetricsPlot');
        end
        
        function success = clearMetricsPlot(obj, axes)
            % Clear plot with centralized error handling
            success = obj.safeExecuteOperation(@() obj.doClearPlot(axes), 'clearMetricsPlot');
        end
        
        function success = updateMetricsPlot(obj, axes, controller)
            % Update plot with improved performance and error handling
            success = obj.safeExecuteOperation(@() obj.doUpdatePlot(axes, controller), 'updateMetricsPlot');
        end
        
        function success = expandGUI(obj, uiFigure, mainPanel, plotPanel, expandButton, app)
            % Expand GUI with dynamic sizing support
            success = obj.safeExecuteOperation(@() obj.doExpandGUI(uiFigure, mainPanel, plotPanel, expandButton, app), 'expandGUI');
        end
        
        function success = collapseGUI(obj, uiFigure, mainPanel, plotPanel, expandButton, app)
            % Collapse GUI with dynamic sizing support
            success = obj.safeExecuteOperation(@() obj.doCollapseGUI(uiFigure, mainPanel, plotPanel, expandButton, app), 'collapseGUI');
        end
        
        function expanded = getIsPlotExpanded(obj)
            % Get expansion state
            expanded = obj.IsPlotExpanded;
        end
        
        function success = exportPlotData(obj, uiFigure, controller)
            % Export plot data with enhanced error handling
            success = obj.safeExecuteOperation(@() obj.doExportData(uiFigure, controller), 'exportPlotData');
        end
    end
    
    methods (Access = private)
        %% Core Operation Methods
        
        function success = doInitializePlot(obj, axes)
            % Core plot initialization logic
            if ~obj.validateAxes(axes)
                success = false;
                return;
            end
            
            obj.setupInitialAxisLimits(axes);
            obj.createPlotLines(axes);
            obj.configureAxesAppearance(axes);
            
            drawnow;
            success = true;
        end
        
        function success = doClearPlot(obj, axes)
            % Core plot clearing logic
            if ~obj.validateAxes(axes)
                success = false;
                return;
            end
            
            obj.clearPlotLines();
            obj.resetAxisLimits(axes);
            obj.configureAxesAppearance(axes);
            
            drawnow;
            success = true;
        end
        
        function success = doUpdatePlot(obj, axes, controller)
            % Core plot update logic with performance optimization
            if ~obj.shouldUpdatePlot() || ~obj.validatePlotInputs(axes, controller)
                success = ~obj.validatePlotInputs(axes, controller); % false if invalid, true if just throttled
                return;
            end
            
            obj.updateTimestamp();
            
            metrics = controller.getAutoStepMetrics();
            if obj.isMetricsEmpty(metrics)
                success = true;
                return;
            end
            
            [limitedPositions, limitedValues] = obj.getLimitedMetricsData(metrics);
            validMetrics = obj.updatePlotLines(limitedPositions, limitedValues);
            
            if validMetrics
                obj.updateAxisLimits(axes, struct('Positions', limitedPositions, 'Values', limitedValues));
            end
            
            drawnow('limitrate');
            success = true;
        end
        
        function success = doExpandGUI(obj, uiFigure, mainPanel, plotPanel, ~, app)
            % Core GUI expansion logic
            if obj.IsPlotExpanded
                success = true;
                return;
            end
            
            if ~obj.validateGUIComponents(uiFigure, mainPanel, plotPanel)
                success = false;
                return;
            end
            
            obj.setIgnoreResize(app, true);
            obj.expandFigureWidth(uiFigure);
            obj.positionPlotPanel(plotPanel, uiFigure);
            
            obj.IsPlotExpanded = true;
            success = true;
        end
        
        function success = doCollapseGUI(obj, uiFigure, mainPanel, plotPanel, ~, app)
            % Core GUI collapse logic
            if ~obj.IsPlotExpanded
                success = true;
                return;
            end
            
            obj.setIgnoreResize(app, true);
            plotPanel.Visible = 'off';
            obj.restoreFigureWidth(uiFigure);
            
            obj.IsPlotExpanded = false;
            success = true;
        end
        
        function success = doExportData(obj, uiFigure, controller)
            % Core export logic
            metrics = controller.getAutoStepMetrics();
            if obj.isMetricsEmpty(metrics)
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
        
        %% Validation Methods
        
        function validateConstructorInput(obj, app)
            % Validate constructor input
            if nargin < 1 || isempty(app)
                error('foilview_plot requires a valid app reference');
            end
        end
        
        function valid = validateAxes(obj, axes)
            % Validate axes component
            valid = ~isempty(axes) && isvalid(axes);
            if ~valid
                fprintf('Invalid axes provided\n');
            end
        end
        
        function valid = validatePlotInputs(obj, axes, controller)
            % Validate plot update inputs
            valid = obj.validateAxes(axes) && ~isempty(controller);
        end
        
        function valid = validateGUIComponents(obj, uiFigure, mainPanel, plotPanel)
            % Validate GUI components for expand/collapse operations
            components = {uiFigure, mainPanel, plotPanel};
            valid = all(cellfun(@(c) ~isempty(c) && isvalid(c), components));
        end
        
        %% Plot Configuration Methods
        
        function setupInitialAxisLimits(obj, axes)
            % Set initial axis limits to prevent errors
            xlim(axes, [0, 1]);
            ylim(axes, [0, 1]);
        end
        
        function createPlotLines(obj, axes)
            % Create empty plot lines for each metric type
            obj.MetricsPlotLines = cell(length(obj.METRIC_TYPES), 1);
            
            for i = 1:length(obj.METRIC_TYPES)
                obj.MetricsPlotLines{i} = obj.createSinglePlotLine(axes, i, obj.METRIC_TYPES{i});
            end
        end
        
        function line = createSinglePlotLine(obj, axes, index, metricType)
            % Create a single plot line with styling
            colorIdx = mod(index-1, length(obj.DEFAULT_COLORS)) + 1;
            markerIdx = mod(index-1, length(obj.DEFAULT_MARKERS)) + 1;
            
            line = plot(axes, NaN, NaN, ...
                'Color', obj.DEFAULT_COLORS{colorIdx}, ...
                'Marker', obj.DEFAULT_MARKERS{markerIdx}, ...
                'LineStyle', '-', ...
                'LineWidth', obj.LINE_WIDTH, ...
                'MarkerSize', obj.MARKER_SIZE, ...
                'DisplayName', metricType);
        end
        
        function configureAxesAppearance(obj, axes)
            % Configure axes labels, grid, and legend
            xlabel(axes, 'Z Position (μm)');
            ylabel(axes, 'Normalized Metric Value');
            title(axes, 'Metrics vs Z Position');
            grid(axes, 'on');
            legend(axes, 'Location', 'northeast');
        end
        
        function clearPlotLines(obj)
            % Clear all plot line data safely
            for i = 1:length(obj.MetricsPlotLines)
                if obj.isValidPlotLine(i)
                    set(obj.MetricsPlotLines{i}, 'XData', NaN, 'YData', NaN);
                end
            end
        end
        
        function resetAxisLimits(obj, axes)
            % Reset axes to default limits
            xlim(axes, [0, 1]);
            ylim(axes, [0, 1]);
        end
        
        %% Update Logic Methods
        
        function shouldUpdate = shouldUpdatePlot(obj)
            % Check if plot should be updated based on throttling
            shouldUpdate = foilview_utils.shouldThrottleUpdate(obj.LastPlotUpdate, foilview_utils.DEFAULT_PLOT_THROTTLE);
        end
        
        function updateTimestamp(obj)
            % Update the last update timestamp
            obj.LastPlotUpdate = now * 24 * 3600;
        end
        
        function empty = isMetricsEmpty(obj, metrics)
            % Check if metrics data is empty
            empty = isempty(metrics.Positions);
        end
        
        function [limitedPositions, limitedValues] = getLimitedMetricsData(obj, metrics)
            % Get limited metrics data for performance
            [limitedPositions, limitedValues] = foilview_utils.limitMetricsData(metrics.Positions, metrics.Values);
        end
        
        function validMetrics = updatePlotLines(obj, limitedPositions, limitedValues)
            % Update all plot lines with new data
            validMetrics = false;
            
            for i = 1:length(obj.METRIC_TYPES)
                if obj.updateSinglePlotLine(i, limitedPositions, limitedValues)
                    validMetrics = true;
                end
            end
        end
        
        function updated = updateSinglePlotLine(obj, index, limitedPositions, limitedValues)
            % Update a single plot line
            updated = false;
            
            if ~obj.isValidPlotLine(index)
                return;
            end
            
            metricType = obj.METRIC_TYPES{index};
            fieldName = obj.getFieldName(metricType);
            
            if ~isfield(limitedValues, fieldName)
                return;
            end
            
            [xData, yData] = obj.prepareLineData(limitedPositions, limitedValues.(fieldName));
            
            if ~isempty(yData)
                set(obj.MetricsPlotLines{index}, 'XData', xData, 'YData', yData);
                updated = true;
            end
        end
        
        function [xData, yData] = prepareLineData(obj, positions, values)
            % Prepare and normalize line data
            % Remove NaN values
            validIdx = ~isnan(positions);
            xData = positions(validIdx);
            yData = xData;
            
            % Normalize to first value if we have data
            if ~isempty(yData)
                firstValue = yData(1);
                if firstValue ~= 0
                    yData = yData / firstValue;
                end
            end
        end
        
        function valid = isValidPlotLine(obj, index)
            % Check if plot line at index is valid
            valid = index <= length(obj.MetricsPlotLines) && ...
                    ~isempty(obj.MetricsPlotLines{index}) && ...
                    foilview_utils.validateUIComponent(obj.MetricsPlotLines{index});
        end
        
        function fieldName = getFieldName(obj, metricType)
            % Convert metric type to field name
            fieldName = strrep(metricType, ' ', '_');
        end
        
        %% Axis Management Methods
        
        function updateAxisLimits(obj, axes, metrics)
            % Update axis limits intelligently
            obj.updateXAxisLimits(axes, metrics.Positions);
            obj.updateYAxisLimits(axes, metrics.Values);
            obj.updateAxisLabelsAndTitle(axes, metrics.Positions);
        end
        
        function updateXAxisLimits(obj, axes, positions)
            % Calculate and set x-axis limits
            xMin = min(positions);
            xMax = max(positions);
            
            [xMin, xMax] = obj.addAxisPadding(xMin, xMax, obj.AXIS_PADDING_PERCENT);
            xlim(axes, [xMin, xMax]);
        end
        
        function updateYAxisLimits(obj, axes, values)
            % Calculate and set y-axis limits
            yValues = obj.collectNormalizedYValues(values);
            
            if ~isempty(yValues)
                yMin = min(yValues);
                yMax = max(yValues);
                
                [yMin, yMax] = obj.addAxisPadding(yMin, yMax, 0.1, obj.Y_AXIS_MIN_PADDING);
                ylim(axes, [yMin, yMax]);
            end
        end
        
        function yValues = collectNormalizedYValues(obj, values)
            % Collect and normalize all y-values across metrics
            yValues = [];
            
            for i = 1:length(obj.METRIC_TYPES)
                metricType = obj.METRIC_TYPES{i};
                fieldName = obj.getFieldName(metricType);
                
                if isfield(values, fieldName)
                    validY = values.(fieldName)(~isnan(values.(fieldName)));
                    if ~isempty(validY)
                        normalizedY = obj.normalizeToFirstValue(validY);
                        yValues = [yValues, normalizedY];
                    end
                end
            end
        end
        
        function normalized = normalizeToFirstValue(obj, values)
            % Normalize values to first non-zero value
            firstValue = values(1);
            if firstValue ~= 0
                normalized = values / firstValue;
            else
                normalized = values;
            end
        end
        
        function [minVal, maxVal] = addAxisPadding(obj, minVal, maxVal, paddingPercent, minPadding)
            % Add padding to axis limits
            if nargin < 5
                minPadding = 0;
            end
            
            if abs(maxVal - minVal) < obj.MIN_AXIS_RANGE
                padding = 1;
                minVal = minVal - padding;
                maxVal = maxVal + padding;
            else
                range = maxVal - minVal;
                padding = max(range * paddingPercent, minPadding);
                minVal = minVal - padding;
                maxVal = maxVal + padding;
            end
        end
        
        function updateAxisLabelsAndTitle(obj, axes, positions)
            % Update axis labels and title with range information
            foilview_utils.setPlotTitle(axes, 'Normalized Metrics vs Z Position', true, ...
                min(positions), max(positions));
            
            fonts = foilview_styling.getFonts();
            ylabel(axes, 'Normalized Metric Value (relative to first)', ...
                'FontSize', fonts.SizeBase);
        end
        
        %% GUI Management Methods
        
        function setIgnoreResize(obj, ~, ignore)
            % Set ignore resize flag if available
            if nargin >= 2 && ~isempty(obj.App) && isprop(obj.App, 'IgnoreNextResize')
                obj.App.IgnoreNextResize = ignore;
            end
        end
        
        function expandFigureWidth(obj, uiFigure)
            % Expand figure width and store original
            figPos = uiFigure.Position;
            obj.OriginalFigureWidth = figPos(3);
            
            newWidth = figPos(3) + obj.PLOT_WIDTH + obj.PLOT_PADDING;
            uiFigure.Position = [figPos(1), figPos(2), newWidth, figPos(4)];
        end
        
        function positionPlotPanel(obj, plotPanel, uiFigure)
            % Position plot panel within expanded window
            figPos = uiFigure.Position;
            
            plotPanelX = obj.OriginalFigureWidth + 10;
            plotPanelY = 10;
            plotPanelHeight = figPos(4) - 20;
            
            plotPanel.Position = [plotPanelX, plotPanelY, obj.PLOT_WIDTH, plotPanelHeight];
            plotPanel.Visible = 'on';
        end
        
        function restoreFigureWidth(obj, uiFigure)
            % Restore original figure width
            figPos = uiFigure.Position;
            
            if ~isempty(obj.OriginalFigureWidth)
                newWidth = obj.OriginalFigureWidth;
            else
                newWidth = figPos(3) - obj.PLOT_WIDTH - obj.PLOT_PADDING;
            end
            
            uiFigure.Position = [figPos(1), figPos(2), newWidth, figPos(4)];
        end
        
        %% Utility Methods
        
        function success = safeExecuteOperation(obj, operation, operationName)
            % Centralized error handling for all operations
            try
                success = operation();
            catch ME
                fprintf('Error in %s: %s\n', operationName, ME.message);
                success = false;
            end
        end
    end
end 