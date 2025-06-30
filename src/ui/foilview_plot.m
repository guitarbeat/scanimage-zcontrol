classdef foilview_plot < handle
    % foilview_plot - Enhanced metrics plotting for foilview
    %
    % This class manages all aspects of the metrics plotting functionality including
    % initialization, updating, clearing, and GUI expansion/collapse for plots.
    % Enhanced with performance optimizations and robust error handling.
    
    properties (Access = private)
        App  % Reference to the main application
        MetricsPlotLines = {}
        IsPlotExpanded = false
        LastPlotUpdate = 0  % Track last update time for throttling
    end
    
    properties (Constant, Access = private)
        PLOT_WIDTH = 400  % Width of the plot panel when expanded
        DEFAULT_COLORS = {'#0072BD', '#D95319', '#EDB120', '#7E2F8E', '#77AC30', '#4DBEEE', '#A2142F'}
        DEFAULT_MARKERS = {'o', 's', 'd', '^', 'v', '>', '<'}
    end
    
    methods
        function obj = foilview_plot(app)
            % Enhanced constructor with validation
            if nargin < 1 || isempty(app)
                error('foilview_plot requires a valid app reference');
            end
            obj.App = app;
            obj.LastPlotUpdate = 0;
        end
        
        function success = initializeMetricsPlot(obj, axes)
            % Enhanced plot initialization using centralized utilities
            success = foilview_utils.safeExecuteWithReturn(@() doInitialize(), 'initializeMetricsPlot', false);
            
            function success = doInitialize()
                success = false;
                
                % Validate input
                if ~foilview_utils.validateUIComponent(axes)
                    fprintf('Invalid axes provided to initializeMetricsPlot\n');
                    return;
                end
                
                % Set initial axis limits to prevent errors
                xlim(axes, [0, 1]);
                ylim(axes, [0, 1]);
                
                % Define metric types locally to avoid class loading issues
                metricTypes = {'Std Dev', 'Mean', 'Max'};
                
                % Initialize empty plot lines with different colors and markers
                obj.MetricsPlotLines = cell(length(metricTypes), 1);
                
                for i = 1:length(metricTypes)
                    metricType = metricTypes{i};
                    colorIdx = mod(i-1, length(obj.DEFAULT_COLORS)) + 1;
                    markerIdx = mod(i-1, length(obj.DEFAULT_MARKERS)) + 1;
                    
                    obj.MetricsPlotLines{i} = plot(axes, NaN, NaN, ...
                        'Color', obj.DEFAULT_COLORS{colorIdx}, ...
                        'Marker', obj.DEFAULT_MARKERS{markerIdx}, ...
                        'LineStyle', '-', ...
                        'LineWidth', 1.5, ...  % Use standard line width
                        'MarkerSize', foilview_styling.MARKER_SIZE, ...
                        'DisplayName', metricType);
                end
                
                % Configure axes using centralized utility
                foilview_utils.configureAxes(axes, 'Metrics vs Z Position');
                
                % Create legend using utility
                foilview_utils.createLegend(axes);
                
                % Force initial draw
                drawnow;
                success = true;
            end
        end
        
        function success = clearMetricsPlot(obj, axes)
            % Enhanced plot clearing using centralized utilities
            success = foilview_utils.safeExecuteWithReturn(@() doClear(), 'clearMetricsPlot', false);
            
            function success = doClear()
                success = false;
                
                % Validate input
                if ~foilview_utils.validateUIComponent(axes)
                    return;
                end
                
                % Clear all plot lines safely
                for i = 1:length(obj.MetricsPlotLines)
                    if ~isempty(obj.MetricsPlotLines{i}) && foilview_utils.validateUIComponent(obj.MetricsPlotLines{i})
                        set(obj.MetricsPlotLines{i}, 'XData', NaN, 'YData', NaN);
                    end
                end
                
                % Reset axes limits
                xlim(axes, [0, 1]);
                ylim(axes, [0, 1]);
                
                % Configure axes using centralized utility
                foilview_utils.configureAxes(axes, 'Metrics vs Z Position');
                
                % Update display
                drawnow;
                success = true;
            end
        end
        
        function success = updateMetricsPlot(obj, axes, controller)
            % Enhanced plot updating using centralized utilities
            success = foilview_utils.safeExecuteWithReturn(@() doUpdate(), 'updateMetricsPlot', false);
            
            function success = doUpdate()
                success = false;
                
                % Throttle updates for performance using utility
                if ~foilview_utils.shouldThrottleUpdate(obj.LastPlotUpdate, foilview_utils.DEFAULT_PLOT_THROTTLE)
                    return;
                end
                obj.LastPlotUpdate = now * 24 * 3600;
                
                % Validate inputs
                if ~foilview_utils.validateUIComponent(axes) || isempty(controller)
                    return;
                end
                
                % Get metrics data from controller
                metrics = controller.getAutoStepMetrics();
                
                % Check if we have data to plot
                if isempty(metrics.Positions)
                    success = true;  % Not an error, just no data
                    return;
                end
                
                % Limit data points for performance using centralized utility
                [limitedPositions, limitedValues] = foilview_utils.limitMetricsData(metrics.Positions, metrics.Values);
                
                % Update each metric line
                validMetrics = false;
                metricTypes = {'Std Dev', 'Mean', 'Max'};  % Local definition to avoid loading issues
                for i = 1:length(metricTypes)
                    if i > length(obj.MetricsPlotLines) || ~foilview_utils.validateUIComponent(obj.MetricsPlotLines{i})
                        continue;
                    end
                    
                    metricType = metricTypes{i};
                    fieldName = strrep(metricType, ' ', '_');
                    
                    if isfield(limitedValues, fieldName)
                        % Get the data
                        xData = limitedPositions;
                        yData = limitedValues.(fieldName);
                        
                        % Remove any NaN values
                        validIdx = ~isnan(yData) & ~isnan(xData);
                        xData = xData(validIdx);
                        yData = yData(validIdx);
                        
                        % Normalize to first value if we have data
                        if ~isempty(yData)
                            firstValue = yData(1);
                            if firstValue ~= 0  % Avoid division by zero
                                yData = yData / firstValue;
                            end
                            validMetrics = true;
                        end
                        
                        % Update the line
                        set(obj.MetricsPlotLines{i}, 'XData', xData, 'YData', yData);
                    end
                end
                
                % Update axes limits only if we have valid data
                if validMetrics && length(limitedPositions) > 1
                    obj.updateAxisLimits(axes, struct('Positions', limitedPositions, 'Values', limitedValues));
                end
                
                % Force drawing update with throttling
                drawnow('limitrate');
                success = true;
            end
        end
        
        function updateAxisLimits(obj, axes, metrics)
            % Helper method to update axis limits intelligently using utilities
            foilview_utils.safeExecute(@() doUpdateLimits(), 'updateAxisLimits');
            
            function doUpdateLimits()
                % Calculate x-axis limits
                xMin = min(metrics.Positions);
                xMax = max(metrics.Positions);
                
                % Add padding for better visualization
                if abs(xMax - xMin) < 0.001
                    xMin = xMin - 1;
                    xMax = xMax + 1;
                else
                    xRange = xMax - xMin;
                    xPadding = xRange * 0.05;  % 5% padding
                    xMin = xMin - xPadding;
                    xMax = xMax + xPadding;
                end
                
                % Set x-axis limits
                xlim(axes, [xMin, xMax]);
                
                % Calculate y-axis limits across all metrics
                yValues = [];
                metricTypes = {'Std Dev', 'Mean', 'Max'};  % Local definition to avoid loading issues
                for i = 1:length(metricTypes)
                    metricType = metricTypes{i};
                    fieldName = strrep(metricType, ' ', '_');
                    if isfield(metrics.Values, fieldName)
                        validY = metrics.Values.(fieldName)(~isnan(metrics.Values.(fieldName)));
                        if ~isempty(validY)
                            % Normalize to first value
                            firstValue = validY(1);
                            if firstValue ~= 0
                                validY = validY / firstValue;
                            end
                            yValues = [yValues, validY];
                        end
                    end
                end
                
                % Set y-axis limits with padding
                if ~isempty(yValues)
                    yMin = min(yValues);
                    yMax = max(yValues);
                    
                    if abs(yMax - yMin) < 0.001
                        yMin = yMin - 0.1;
                        yMax = yMax + 0.1;
                    else
                        yRange = yMax - yMin;
                        yPadding = max(yRange * 0.1, 0.05);  % 10% padding or at least 0.05
                        yMin = yMin - yPadding;
                        yMax = yMax + yPadding;
                    end
                    
                    ylim(axes, [yMin, yMax]);
                end
                
                % Update title with range information using utility
                foilview_utils.setPlotTitle(axes, 'Normalized Metrics vs Z Position', true, ...
                    min(metrics.Positions), max(metrics.Positions));
                
                % Update y-axis label
                ylabel(axes, 'Normalized Metric Value (relative to first)', ...
                    'FontSize', foilview_styling.FONT_SIZE_NORMAL);
            end
        end
        
        function success = expandGUI(obj, uiFigure, mainPanel, plotPanel, expandButton, app)
            % Enhanced GUI expansion with dynamic sizing support
            success = foilview_utils.safeExecuteWithReturn(@() doExpand(), 'expandGUI', false);
            
            function success = doExpand()
                success = false;
                
                if obj.IsPlotExpanded
                    success = true;  % Already expanded
                    return;
                end
                
                % Validate inputs
                if ~foilview_utils.validateMultipleComponents(uiFigure, mainPanel, plotPanel)
                    return;
                end
                
                % Signal to ignore the programmatic resize
                if nargin >= 6 && ~isempty(app) && isprop(app, 'IgnoreNextResize')
                    app.IgnoreNextResize = true;
                end
                
                % Get current figure position and size
                figPos = uiFigure.Position;
                currentWidth = figPos(3);
                currentHeight = figPos(4);
                
                % Expand figure width dynamically
                newWidth = currentWidth + obj.PLOT_WIDTH + 20; % +20 for padding
                uiFigure.Position = [figPos(1), figPos(2), newWidth, figPos(4)];
                
                % Position and show the plot panel dynamically based on main window size
                plotPanelX = currentWidth + 10;
                plotPanelY = 10;
                plotPanelHeight = currentHeight - 20;
                plotPanel.Position = [plotPanelX, plotPanelY, obj.PLOT_WIDTH, plotPanelHeight];
                plotPanel.Visible = 'on';
                
                % Update button appearance
                foilview_styling.styleButton(expandButton, 'Warning', '📊 Hide Plot');
                
                obj.IsPlotExpanded = true;
                
                % Update window title
                uiFigure.Name = sprintf('%s - Plot Expanded', foilview_ui.TEXT.WindowTitle);
                success = true;
            end
        end
        
        function success = collapseGUI(obj, uiFigure, mainPanel, plotPanel, expandButton, app)
            % Enhanced GUI collapse with dynamic sizing support
            success = foilview_utils.safeExecuteWithReturn(@() doCollapse(), 'collapseGUI', false);
            
            function success = doCollapse()
                success = false;
                
                if ~obj.IsPlotExpanded
                    success = true;  % Already collapsed
                    return;
                end
                
                % Signal to ignore the programmatic resize
                if nargin >= 6 && ~isempty(app) && isprop(app, 'IgnoreNextResize')
                    app.IgnoreNextResize = true;
                end
                
                % Hide the plot panel first
                plotPanel.Visible = 'off';
                
                % Get current figure position
                figPos = uiFigure.Position;
                
                % Collapse figure width dynamically by removing plot width and padding
                originalWidth = figPos(3) - obj.PLOT_WIDTH - 20;
                uiFigure.Position = [figPos(1), figPos(2), originalWidth, figPos(4)];
                
                % Update button appearance
                foilview_styling.styleButton(expandButton, 'Primary', '📊 Show Plot');
                
                obj.IsPlotExpanded = false;
                
                % Update window title
                uiFigure.Name = foilview_ui.TEXT.WindowTitle;
                success = true;
            end
        end
        
        function expanded = getIsPlotExpanded(obj)
            expanded = obj.IsPlotExpanded;
        end
        
        function success = exportPlotData(obj, uiFigure, controller)
            % Export the current plot data to a file using centralized error handling
            success = foilview_utils.safeExecuteWithReturn(@() doExport(), 'exportPlotData', false);
            
            function success = doExport()
                success = false;
                
                metrics = controller.getAutoStepMetrics();
                if isempty(metrics.Positions)
                    uialert(uiFigure, 'No data to export. Run auto-stepping with "Record Metrics" enabled first.', 'No Data');
                    return;
                end
                
                % Ask user for filename
                [file, path] = uiputfile('*.mat', 'Save Metrics Data');
                if file == 0
                    return; % User cancelled
                end
                
                % Save the metrics data
                save(fullfile(path, file), 'metrics');
                uialert(uiFigure, sprintf('Data exported to %s', fullfile(path, file)), 'Export Complete', 'Icon', 'success');
                success = true;
            end
        end
    end
    
    methods (Access = private)

    end
end 