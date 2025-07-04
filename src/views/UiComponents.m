% Combined UI Components for FoilView
% This file contains all UI functionality previously split across three classes:
% - UI creation and layout
% - UI updates and state management  
% - Plot functionality and visualization

classdef ui_components < handle
    
    properties (Constant, Access = public)
        MIN_WINDOW_WIDTH = 280
        MIN_WINDOW_HEIGHT = 380
        DEFAULT_WINDOW_WIDTH = 320
        DEFAULT_WINDOW_HEIGHT = 420
        PLOT_WIDTH = 400
        
        COLORS = struct(...
            'Background', [0.95 0.95 0.95], ...
            'Primary', [0.2 0.6 0.9], ...
            'Success', [0.2 0.7 0.3], ...
            'Warning', [0.9 0.6 0.2], ...
            'Danger', [0.9 0.3 0.3], ...
            'Light', [0.98 0.98 0.98], ...
            'TextMuted', [0.5 0.5 0.5])
        
        TEXT = struct(...
            'WindowTitle', 'FoilView - Z-Stage Control', ...
            'Ready', 'Ready')
    end
    
    methods (Static)
        function components = createAllComponents(app)
            creator = ui_components();
            components = struct();
            
            [components.UIFigure, components.MainPanel, components.MainLayout] = ...
                creator.createMainWindow(app);
            
            components.PositionDisplay = creator.createPositionDisplay(components.MainLayout);
            components.MetricDisplay = creator.createMetricDisplay(components.MainLayout);
            components.StatusControls = creator.createStatusBar(components.MainLayout);
            components.ManualControls = creator.createManualControlContainer(components.MainLayout, app);
            components.AutoControls = creator.createAutoStepContainer(components.MainLayout, app);
            components.MetricsPlotControls = creator.createMetricsPlotArea(components.UIFigure, app);
            components.MetricsPlotControls.ExpandButton = creator.createExpandButton(components.MainLayout, app);
            
            components.UIFigure.Visible = 'on';
        end
        
        function adjustPlotPosition(uiFigure, plotPanel, plotWidth)
            if ~isvalid(uiFigure) || ~isvalid(plotPanel)
                return;
            end
            
            figPos = uiFigure.Position;
            currentHeight = figPos(4);
            expandedWidth = figPos(3);
            mainWindowWidth = expandedWidth - plotWidth - 20;
            
            plotPanelX = mainWindowWidth + 10;
            plotPanelY = 10;
            plotPanelHeight = currentHeight - 20;
            
            plotPanel.Position = [plotPanelX, plotPanelY, plotWidth, plotPanelHeight];
        end
        
        function adjustFontSizes(components, windowSize)
            if nargin < 2 || isempty(windowSize)
                return;
            end
            
            widthScale = windowSize(3) / ui_components.DEFAULT_WINDOW_WIDTH;
            heightScale = windowSize(4) / ui_components.DEFAULT_WINDOW_HEIGHT;
            overallScale = min(max(sqrt(widthScale * heightScale), 0.7), 1.5);
            
            if isfield(components, 'PositionDisplay') && isfield(components.PositionDisplay, 'Label')
                baseFontSize = 28;
                newFontSize = max(round(baseFontSize * overallScale), 18);
                try
                    components.PositionDisplay.Label.FontSize = newFontSize;
                catch
                end
            end
            
            if overallScale ~= 1.0
                try
                    fontFields = {'AutoControls', 'ManualControls', 'MetricDisplay', 'StatusControls'};
                    for i = 1:length(fontFields)
                        if isfield(components, fontFields{i})
                            ui_components.adjustControlFonts(components.(fontFields{i}), overallScale);
                        end
                    end
                catch
                end
            end
        end
        
        function adjustControlFonts(controlStruct, scale)
            if ~isstruct(controlStruct) || scale == 1.0
                return;
            end
            
            fields = fieldnames(controlStruct);
            for i = 1:length(fields)
                try
                    obj = controlStruct.(fields{i});
                    if isvalid(obj) && isprop(obj, 'FontSize')
                        currentSize = obj.FontSize;
                        newSize = max(round(currentSize * scale), 8);
                        newSize = min(newSize, 16);
                        obj.FontSize = newSize;
                    end
                catch
                    continue;
                end
            end
        end
        
        function functions = createUpdateFunctions(app)
            % Creates a cell array of function handles for UI updates.
            % This avoids recreating the array on every throttled update call.
            functions = {
                @() ui_components.updatePositionDisplay(app.UIFigure, app.PositionDisplay, app.Controller), ...
                @() ui_components.updateStatusDisplay(app.PositionDisplay, app.StatusControls, app.Controller), ...
                @() ui_components.updateControlStates(app.ManualControls, app.AutoControls, app.Controller), ...
                @() ui_components.updateMetricDisplay(app.MetricDisplay, app.Controller)
            };
        end
        
        % ===== BOOKMARKS VIEW CREATION =====
        function bookmarksApp = createBookmarksView(controller)
            % Create a bookmarks management window
            % Returns a bookmarks app instance that can be managed separately
            
            if nargin < 1 || isempty(controller)
                error('ui_components:NoController', ...
                      'A foilview_controller instance is required');
            end
            
            % Create the bookmarks app instance using the new class
            bookmarksApp = BookmarksView(controller);
        end
        
        % ===== STAGE VIEW CREATION =====
        function stageViewApp = createStageView()
            % Create a stage view window
            % Returns a stage view app instance that can be managed separately
            
            % Create the stage view app instance using the new class
            stageViewApp = StageView();
        end
        
        % ===== UI UPDATE METHODS (formerly foilview_updater) =====
        function success = updateAllUI(app)
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateAll(app), 'updateAllUI', false);
            
            function success = doUpdateAll(app)
                persistent lastUpdateTime updateFunctions;
                if isempty(lastUpdateTime)
                    lastUpdateTime = 0;
                    updateFunctions = ui_components.createUpdateFunctions(app);
                end
                
                if ~foilview_utils.shouldThrottleUpdate(lastUpdateTime)
                    success = true;
                    return;
                end
                lastUpdateTime = posixtime(datetime('now'));
                                
                success = foilview_utils.batchUIUpdate(updateFunctions);
            end
        end
        
        function success = updatePositionDisplay(uiFigure, positionDisplay, controller)
            success = foilview_utils.safeExecuteWithReturn(@() doUpdatePosition(), 'updatePositionDisplay', false);
            
            function success = doUpdatePosition()
                success = false;
                
                if ~foilview_utils.validateMultipleComponents(uiFigure, positionDisplay.Label) || isempty(controller)
                    return;
                end
                
                positionStr = foilview_utils.formatPosition(controller.CurrentPosition, true);
                positionDisplay.Label.Text = positionStr;
                
                baseTitle = ui_components.TEXT.WindowTitle;
                newTitle = sprintf('%s (%s)', baseTitle, foilview_utils.formatPosition(controller.CurrentPosition));
                uiFigure.Name = newTitle;
                
                success = true;
            end
        end
        
        function success = updateStatusDisplay(positionDisplay, statusControls, controller)
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateStatus(), 'updateStatusDisplay', false);
            
            function success = doUpdateStatus()
                success = false;
                
                if ~foilview_utils.validateMultipleComponents(positionDisplay.Status, statusControls.Label) || isempty(controller)
                    return;
                end
                
                if controller.IsAutoRunning
                    progressText = sprintf('Auto-stepping: %d/%d', controller.CurrentStep, controller.TotalSteps);
                    positionDisplay.Status.Text = progressText;
                    positionDisplay.Status.FontColor = [0.1 0.1 0.1];  % primary text color
                else
                    positionDisplay.Status.Text = 'Ready';
                    positionDisplay.Status.FontColor = [0.5 0.5 0.5];  % muted text color
                end
                
                if controller.SimulationMode
                    statusText = sprintf('ScanImage: Simulation (%s)', controller.StatusMessage);
                    statusControls.Label.Text = statusText;
                    statusControls.Label.FontColor = [0.9 0.6 0.2];  % warning color
                else
                    statusText = sprintf('ScanImage: %s', controller.StatusMessage);
                    statusControls.Label.Text = statusText;
                    statusControls.Label.FontColor = [0.2 0.7 0.3];  % success color
                end
                
                success = true;
            end
        end
        
        function success = updateControlStates(manualControls, autoControls, controller)
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateControlStates(), 'updateControlStates', false);
            
            function success = doUpdateControlStates()
                success = false;
                
                if isempty(controller)
                    return;
                end
                
                isRunning = controller.IsAutoRunning;
                
                ui_components.setControlsEnabled(manualControls, ~isRunning);
                
                if isRunning
                    foilview_utils.setControlEnabled(autoControls, false, 'StepField');
                    foilview_utils.setControlEnabled(autoControls, false, 'StepsField');
                    foilview_utils.setControlEnabled(autoControls, false, 'DelayField');
                    
                    foilview_utils.setControlEnabled(autoControls, true, 'DirectionButton');
                    foilview_utils.setControlEnabled(autoControls, true, 'StartStopButton');
                    
                    ui_components.updateDirectionButtonStyling(autoControls, controller.AutoDirection);
                else
                    ui_components.setControlsEnabled(autoControls, true);
                    ui_components.updateDirectionButtonStyling(autoControls, controller.AutoDirection);
                end
                
                ui_components.updateAutoStepButton(autoControls, isRunning);
                
                success = true;
            end
        end
        
        function setControlsEnabled(controls, enabled)
            foilview_utils.safeExecute(@() doSetControls(), 'setControlsEnabled');
            
            function doSetControls()
                controlFields = foilview_utils.getAllControlFields();
                foilview_utils.setControlsEnabled(controls, enabled, controlFields);
            end
        end
        
        function success = updateAutoStepButton(autoControls, isRunning)
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateButton(), 'updateAutoStepButton', false);
            
            function success = doUpdateButton()
                success = false;
                
                if ~foilview_utils.validateControlStruct(autoControls, {'StartStopButton'})
                    return;
                end
                
                if isRunning
                    ui_components.applyButtonStyle(autoControls.StartStopButton, 'Danger', 'STOP');
                else
                    ui_components.applyButtonStyle(autoControls.StartStopButton, 'Success', 'START');
                end
                
                success = true;
            end
        end
        
        function success = updateDirectionButtonStyling(autoControls, direction)
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateDirection(), 'updateDirectionButtonStyling', false);
            
            function success = doUpdateDirection()
                success = false;
                
                if ~foilview_utils.validateControlStruct(autoControls, {'DirectionButton'})
                    return;
                end
                
                if direction == 1
                    ui_components.applyButtonStyle(autoControls.DirectionButton, 'Success', '▲ UP');
                else
                    ui_components.applyButtonStyle(autoControls.DirectionButton, 'Warning', '▼ DOWN');
                end
                
                success = true;
            end
        end
        
        function success = updateMetricDisplay(metricDisplay, controller)
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateMetric(), 'updateMetricDisplay', false);
            
            function success = doUpdateMetric()
                success = false;
                
                if ~foilview_utils.validateControlStruct(metricDisplay, {'Value'}) || isempty(controller)
                    return;
                end
                
                metricValue = controller.CurrentMetric;
                displayText = foilview_utils.formatMetricValue(metricValue);
                
                if isnan(metricValue)
                    textColor = [0.5 0.5 0.5];  % TEXT_MUTED_COLOR
                    bgColor = [0.98 0.98 0.98];  % LIGHT_COLOR
                else
                    textColor = [0 0 0];
                    if metricValue > 0
                        intensity = min(1, metricValue / 100);
                        greenComponent = 0.9 + 0.1 * intensity;
                        bgColor = [0.95 greenComponent 0.95];
                    else
                        bgColor = [0.98 0.98 0.98];  % LIGHT_COLOR
                    end
                end
                
                metricDisplay.Value.Text = displayText;
                metricDisplay.Value.FontColor = textColor;
                metricDisplay.Value.BackgroundColor = bgColor;
                
                success = true;
            end
        end
        
        function success = updatePlotExpansionState(plotControls, isExpanded)
            success = foilview_utils.safeExecuteWithReturn(@() doUpdateExpansion(), 'updatePlotExpansionState', false);
            
            function success = doUpdateExpansion()
                success = false;
                
                if ~foilview_utils.validateControlStruct(plotControls, {'ExpandButton'})
                    return;
                end
                
                if isExpanded
                    ui_components.applyButtonStyle(plotControls.ExpandButton, 'Warning', '📊 Hide Plot');
                else
                    ui_components.applyButtonStyle(plotControls.ExpandButton, 'Primary', '📊 Show Plot');
                end
                
                success = true;
            end
        end
        
        function success = batchUpdate(updateFunctions)
            success = foilview_utils.batchUIUpdate(updateFunctions);
        end
    end
    
    % ===== PLOT FUNCTIONALITY (formerly foilview_plot) =====
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
        function obj = ui_components(app)
            if nargin >= 1 && ~isempty(app)
                obj.App = app;
                obj.LastPlotUpdate = 0;
            end
        end
        
        function success = initializeMetricsPlot(obj, axes)
            success = foilview_utils.safeExecuteWithReturn(@() doInitialize(), 'initializeMetricsPlot', false);
            
            function success = doInitialize()
                success = false;
                
                if ~foilview_utils.validateUIComponent(axes)
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
                        'LineWidth', foilview_utils.UI_STYLE.LINE_WIDTH, ...
                        'MarkerSize', foilview_utils.UI_STYLE.MARKER_SIZE, ...
                        'DisplayName', metricType);
                end
                
                foilview_utils.configureAxes(axes, 'Metrics vs Z Position');
                foilview_utils.createLegend(axes);
                
                drawnow;
                success = true;
            end
        end
        
        function success = clearMetricsPlot(obj, axes)
            success = foilview_utils.safeExecuteWithReturn(@() doClear(), 'clearMetricsPlot', false);
            
            function success = doClear()
                success = false;
                
                if ~foilview_utils.validateUIComponent(axes)
                    return;
                end
                
                for i = 1:length(obj.MetricsPlotLines)
                    if ~isempty(obj.MetricsPlotLines{i}) && foilview_utils.validateUIComponent(obj.MetricsPlotLines{i})
                        set(obj.MetricsPlotLines{i}, 'XData', NaN, 'YData', NaN);
                    end
                end
                
                xlim(axes, [0, 1]);
                ylim(axes, [0, 1]);
                
                foilview_utils.configureAxes(axes, 'Metrics vs Z Position');
                
                drawnow;
                success = true;
            end
        end
        
        function success = updateMetricsPlot(obj, axes, controller)
            success = foilview_utils.safeExecuteWithReturn(@() doUpdate(), 'updateMetricsPlot', false);
            
            function success = doUpdate()
                success = false;
                
                if ~foilview_utils.shouldThrottleUpdate(obj.LastPlotUpdate, foilview_utils.DEFAULT_PLOT_THROTTLE)
                    return;
                end
                obj.LastPlotUpdate = posixtime(datetime('now'));
                
                if ~foilview_utils.validateUIComponent(axes) || isempty(controller)
                    return;
                end
                
                metrics = controller.getAutoStepMetrics();
                
                if isempty(metrics.Positions)
                    success = true;
                    return;
                end
                
                [limitedPositions, limitedValues] = foilview_utils.limitMetricsData(metrics.Positions, metrics.Values);
                
                validMetrics = false;
                metricTypes = {'Std Dev', 'Mean', 'Max'};
                for i = 1:length(metricTypes)
                    if i > length(obj.MetricsPlotLines) || ~foilview_utils.validateUIComponent(obj.MetricsPlotLines{i})
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
            foilview_utils.safeExecute(@() doUpdateLimits(), 'updateAxisLimits');
            
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
                
                foilview_utils.setPlotTitle(axes, 'Normalized Metrics vs Z Position', true, ...
                    min(metrics.Positions), max(metrics.Positions));
                
                ylabel(axes, 'Normalized Metric Value (relative to first)', ...
                    'FontSize', foilview_utils.UI_STYLE.FONT_SIZE_NORMAL);
            end
        end
        
        function success = expandGUI(obj, uiFigure, mainPanel, plotPanel, expandButton, app)
            success = foilview_utils.safeExecuteWithReturn(@() doExpand(), 'expandGUI', false);
            
            function success = doExpand()
                success = false;
                
                if obj.IsPlotExpanded
                    success = true;
                    return;
                end
                
                if ~foilview_utils.validateMultipleComponents(uiFigure, mainPanel, plotPanel)
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
                
                uiFigure.Name = sprintf('%s - Plot Expanded', ui_components.TEXT.WindowTitle);
                success = true;
            end
        end
        
        function success = collapseGUI(obj, uiFigure, ~, plotPanel, expandButton, app)
            success = foilview_utils.safeExecuteWithReturn(@() doCollapse(), 'collapseGUI', false);
            
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
                
                uiFigure.Name = ui_components.TEXT.WindowTitle;
                success = true;
            end
        end
        
        function expanded = getIsPlotExpanded(obj)
            expanded = obj.IsPlotExpanded;
        end
        
        function success = exportPlotData(~, uiFigure, controller)
            success = foilview_utils.safeExecuteWithReturn(@() doExport(), 'exportPlotData', false);
            
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
    
    % ===== PRIVATE UI CREATION METHODS =====
    methods (Access = private)
        function [uiFigure, mainPanel, mainLayout] = createMainWindow(obj, ~)
            uiFigure = uifigure('Visible', 'off');
            uiFigure.Units = 'pixels';
            uiFigure.Position = [100 100 obj.DEFAULT_WINDOW_WIDTH obj.DEFAULT_WINDOW_HEIGHT];
            uiFigure.Name = obj.TEXT.WindowTitle;
            uiFigure.Color = obj.COLORS.Background;
            uiFigure.Resize = 'on';
            uiFigure.AutoResizeChildren = 'on';
            uiFigure.WindowState = 'normal';
            
            mainPanel = uipanel(uiFigure);
            mainPanel.Units = 'normalized';
            mainPanel.Position = [0, 0, 1, 1];
            mainPanel.BorderType = 'none';
            mainPanel.BackgroundColor = obj.COLORS.Background;
            mainPanel.AutoResizeChildren = 'on';
            
            mainLayout = uigridlayout(mainPanel, [6, 1]);
            mainLayout.RowHeight = {'fit', '1x', 'fit', 'fit', 'fit', 'fit'};
            mainLayout.ColumnWidth = {'1x'};
            mainLayout.Padding = [8 8 8 8];
            mainLayout.RowSpacing = 6;
            mainLayout.Scrollable = 'on';
        end
        
        function metricDisplay = createMetricDisplay(obj, mainLayout)
            metricPanel = uigridlayout(mainLayout, [1, 3]);
            metricPanel.ColumnWidth = {'fit', '1x', 'fit'};
            metricPanel.Layout.Row = 1;
            
            metricDisplay = struct();
            
            metricDisplay.TypeDropdown = uidropdown(metricPanel);
            metricDisplay.TypeDropdown.Items = {'Std Dev', 'Mean', 'Max'};
            metricDisplay.TypeDropdown.Value = 'Std Dev';
            metricDisplay.TypeDropdown.FontSize = 9;
            
            metricDisplay.Value = uilabel(metricPanel);
            metricDisplay.Value.Text = 'N/A';
            metricDisplay.Value.FontSize = 12;
            metricDisplay.Value.FontWeight = 'bold';
            metricDisplay.Value.HorizontalAlignment = 'center';
            metricDisplay.Value.BackgroundColor = obj.COLORS.Light;
            
            metricDisplay.RefreshButton = uibutton(metricPanel, 'push');
            metricDisplay.RefreshButton.Text = '↻';
            metricDisplay.RefreshButton.FontSize = 11;
        end
        
        function positionDisplay = createPositionDisplay(obj, mainLayout)
            positionPanel = uigridlayout(mainLayout, [2, 1]);
            positionPanel.RowHeight = {'fit', 'fit'};
            positionPanel.RowSpacing = 5;
            positionPanel.Layout.Row = 2;
            
            positionDisplay = struct();
            
            positionDisplay.Label = uilabel(positionPanel);
            positionDisplay.Label.Text = '0.0 μm';
            positionDisplay.Label.FontSize = 28;
            positionDisplay.Label.FontWeight = 'bold';
            positionDisplay.Label.FontName = 'Courier New';
            positionDisplay.Label.HorizontalAlignment = 'center';
            positionDisplay.Label.BackgroundColor = obj.COLORS.Light;
            
            positionDisplay.Status = uilabel(positionPanel);
            positionDisplay.Status.Text = obj.TEXT.Ready;
            positionDisplay.Status.FontSize = 9;
            positionDisplay.Status.HorizontalAlignment = 'center';
            positionDisplay.Status.FontColor = obj.COLORS.TextMuted;
        end
        
        function expandButton = createExpandButton(obj, mainLayout, ~)
            expandButton = uibutton(mainLayout, 'push');
            expandButton.Layout.Row = 5;
            expandButton.Text = '📊 Show Plot';
            expandButton.FontSize = 10;
            expandButton.FontWeight = 'bold';
            expandButton.BackgroundColor = obj.COLORS.Primary;
            expandButton.FontColor = [1 1 1];
        end
        
        function statusControls = createStatusBar(obj, mainLayout)
            statusBar = uigridlayout(mainLayout, [1, 4]);
            statusBar.ColumnWidth = {'1x', 'fit', 'fit', 'fit'};
            statusBar.Layout.Row = 6;
            
            statusControls = struct();
            
            statusControls.Label = uilabel(statusBar);
            statusControls.Label.Text = 'ScanImage: Initializing...';
            statusControls.Label.FontSize = 9;
            
            statusControls.BookmarksButton = uibutton(statusBar, 'push');
            statusControls.BookmarksButton.Text = '📌';
            statusControls.BookmarksButton.FontSize = 11;
            statusControls.BookmarksButton.FontWeight = 'bold';
            statusControls.BookmarksButton.Tooltip = 'Toggle Bookmarks Window (Open/Close)';
            statusControls.BookmarksButton.BackgroundColor = obj.COLORS.Primary;
            statusControls.BookmarksButton.FontColor = [1 1 1];
            
            statusControls.StageViewButton = uibutton(statusBar, 'push');
            statusControls.StageViewButton.Text = '📹';
            statusControls.StageViewButton.FontSize = 11;
            statusControls.StageViewButton.FontWeight = 'bold';
            statusControls.StageViewButton.Tooltip = 'Toggle Stage View Camera Window (Open/Close)';
            statusControls.StageViewButton.BackgroundColor = obj.COLORS.Primary;
            statusControls.StageViewButton.FontColor = [1 1 1];
            
            statusControls.RefreshButton = uibutton(statusBar, 'push');
            statusControls.RefreshButton.Text = '↻';
            statusControls.RefreshButton.FontSize = 11;
            statusControls.RefreshButton.FontWeight = 'bold';
        end
        
        function manualControls = createManualControlContainer(obj, mainLayout, ~)
            manualPanel = uipanel(mainLayout);
            manualPanel.Title = 'Manual Control';
            manualPanel.FontSize = 9;
            manualPanel.FontWeight = 'bold';
            manualPanel.Layout.Row = 3;
            
            grid = uigridlayout(manualPanel, [1, 6]);
            grid.RowHeight = {'fit'};
            grid.ColumnWidth = {'1x', '1x', '2x', '1x', '1x', '2x'};
            grid.Padding = [6 4 6 4];
            grid.ColumnSpacing = 4;
            
            manualControls = struct();
            
            manualControls.UpButton = obj.createStyledButton(grid, 'success', '▲', [], [1, 1]);
            
            manualControls.StepDownButton = uibutton(grid, 'push');
            manualControls.StepDownButton.Text = '◄';
            manualControls.StepDownButton.FontSize = 11;
            manualControls.StepDownButton.FontWeight = 'bold';
            manualControls.StepDownButton.Layout.Row = 1;
            manualControls.StepDownButton.Layout.Column = 2;
            manualControls.StepDownButton.Tooltip = 'Decrease step size';
            manualControls.StepDownButton.BackgroundColor = obj.COLORS.TextMuted;
            manualControls.StepDownButton.FontColor = [1 1 1];
            
            stepSizePanel = uipanel(grid);
            stepSizePanel.Layout.Row = 1;
            stepSizePanel.Layout.Column = 3;
            stepSizePanel.BorderType = 'line';
            stepSizePanel.BackgroundColor = obj.COLORS.Light;
            stepSizePanel.BorderWidth = 1;
            stepSizePanel.HighlightColor = [0.8 0.8 0.8];
            
            stepSizeGrid = uigridlayout(stepSizePanel, [1, 1]);
            stepSizeGrid.Padding = [4 2 4 2];
            
            manualControls.StepSizeDisplay = uilabel(stepSizeGrid);
            manualControls.StepSizeDisplay.Text = '1.0μm';
            manualControls.StepSizeDisplay.FontSize = 9;
            manualControls.StepSizeDisplay.FontWeight = 'bold';
            manualControls.StepSizeDisplay.FontColor = [0.2 0.2 0.2];
            manualControls.StepSizeDisplay.HorizontalAlignment = 'center';
            manualControls.StepSizeDisplay.Layout.Row = 1;
            manualControls.StepSizeDisplay.Layout.Column = 1;
            
            manualControls.StepUpButton = uibutton(grid, 'push');
            manualControls.StepUpButton.Text = '►';
            manualControls.StepUpButton.FontSize = 11;
            manualControls.StepUpButton.FontWeight = 'bold';
            manualControls.StepUpButton.Layout.Row = 1;
            manualControls.StepUpButton.Layout.Column = 4;
            manualControls.StepUpButton.Tooltip = 'Increase step size';
            manualControls.StepUpButton.BackgroundColor = obj.COLORS.TextMuted;
            manualControls.StepUpButton.FontColor = [1 1 1];
            
            manualControls.DownButton = obj.createStyledButton(grid, 'warning', '▼', [], [1, 5]);
            manualControls.ZeroButton = obj.createStyledButton(grid, 'primary', 'ZERO', [], [1, 6]);
            
            manualControls.StepSizeDropdown = uidropdown(grid);
            manualControls.StepSizeDropdown.Items = foilview_utils.formatStepSizeItems(foilview_controller.STEP_SIZES);
            manualControls.StepSizeDropdown.Value = foilview_utils.formatPosition(foilview_controller.DEFAULT_STEP_SIZE);
            manualControls.StepSizeDropdown.Visible = 'off';
            
            manualControls.StepSizes = foilview_controller.STEP_SIZES;
            manualControls.CurrentStepIndex = find(manualControls.StepSizes == foilview_controller.DEFAULT_STEP_SIZE, 1);
        end
        
        function autoControls = createAutoStepContainer(obj, mainLayout, ~)
            autoPanel = uipanel(mainLayout);
            autoPanel.Title = 'Auto Step';
            autoPanel.FontSize = 9;
            autoPanel.FontWeight = 'bold';
            autoPanel.Layout.Row = 4;
            
            grid = uigridlayout(autoPanel, [2, 4]);
            grid.RowHeight = {'fit', 'fit'};
            grid.ColumnWidth = {'2x', '1x', '1x', '1x'};
            grid.Padding = [8 6 8 8];
            grid.RowSpacing = 6;
            grid.ColumnSpacing = 8;
            
            autoControls = struct();
            
            autoControls.StartStopButton = obj.createStyledButton(grid, 'success', 'START ▲', [], [1, 1]);
            
            autoControls.StepField = uieditfield(grid, 'numeric');
            autoControls.StepField.Value = foilview_controller.DEFAULT_AUTO_STEP;
            autoControls.StepField.FontSize = 10;
            autoControls.StepField.Layout.Row = 1;
            autoControls.StepField.Layout.Column = 2;
            autoControls.StepField.Tooltip = 'Step size (μm)';
            
            autoControls.StepsField = uieditfield(grid, 'numeric');
            autoControls.StepsField.Value = foilview_controller.DEFAULT_AUTO_STEPS;
            autoControls.StepsField.FontSize = 10;
            autoControls.StepsField.Layout.Row = 1;
            autoControls.StepsField.Layout.Column = 3;
            autoControls.StepsField.Tooltip = 'Number of steps';
            
            autoControls.DelayField = uieditfield(grid, 'numeric');
            autoControls.DelayField.Value = foilview_controller.DEFAULT_AUTO_DELAY;
            autoControls.DelayField.FontSize = 10;
            autoControls.DelayField.Layout.Row = 1;
            autoControls.DelayField.Layout.Column = 4;
            autoControls.DelayField.Tooltip = 'Delay between steps (seconds)';
            
            autoControls.DirectionButton = obj.createStyledButton(grid, 'success', '▲', [], [2, 4]);
            autoControls.DirectionButton.Tooltip = 'Toggle direction (Up/Down)';
            autoControls.DirectionButton.Visible = 'off';
            
            statusGrid = uigridlayout(grid, [1, 3]);
            statusGrid.Layout.Row = 2;
            statusGrid.Layout.Column = [1 4];
            statusGrid.ColumnWidth = {'fit', '1x', 'fit'};
            statusGrid.Padding = [0 0 0 0];
            statusGrid.ColumnSpacing = 4;
            
            statusLabel = uilabel(statusGrid);
            statusLabel.Text = 'Ready:';
            statusLabel.FontSize = 10;
            statusLabel.FontWeight = 'bold';
            statusLabel.FontColor = [0.3 0.3 0.3];
            statusLabel.Layout.Column = 1;
            
            autoControls.StatusDisplay = uilabel(statusGrid);
            autoControls.StatusDisplay.Text = '100.0 μm upward (5.0s)';
            autoControls.StatusDisplay.FontSize = 10;
            autoControls.StatusDisplay.FontColor = [0.4 0.4 0.4];
            autoControls.StatusDisplay.Layout.Column = 2;
            
            unitsLabel = uilabel(statusGrid);
            unitsLabel.Text = 'μm × steps @ s';
            unitsLabel.FontSize = 9;
            unitsLabel.FontColor = [0.6 0.6 0.6];
            unitsLabel.Layout.Column = 3;
        end
        
        function metricsPlotControls = createMetricsPlotArea(obj, uiFigure, ~)
            metricsPlotControls = struct();
            
            metricsPlotControls.Panel = uipanel(uiFigure);
            metricsPlotControls.Panel.Units = 'pixels';
            metricsPlotControls.Panel.Position = [obj.DEFAULT_WINDOW_WIDTH + 10, 10, obj.PLOT_WIDTH, obj.DEFAULT_WINDOW_HEIGHT - 20];
            metricsPlotControls.Panel.Title = 'Metrics Plot';
            metricsPlotControls.Panel.FontSize = 12;
            metricsPlotControls.Panel.FontWeight = 'bold';
            metricsPlotControls.Panel.Visible = 'off';
            metricsPlotControls.Panel.AutoResizeChildren = 'on';
            
            grid = uigridlayout(metricsPlotControls.Panel, [2, 2]);
            grid.RowHeight = {'1x', 'fit'};
            grid.ColumnWidth = {'1x', 'fit'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 10;
            grid.ColumnSpacing = 10;
            
            metricsPlotControls.Axes = uiaxes(grid);
            metricsPlotControls.Axes.Layout.Row = 1;
            metricsPlotControls.Axes.Layout.Column = [1 2];
            
            hold(metricsPlotControls.Axes, 'on');
            metricsPlotControls.Axes.XGrid = 'on';
            metricsPlotControls.Axes.YGrid = 'on';
            xlabel(metricsPlotControls.Axes, 'Z Position (μm)');
            ylabel(metricsPlotControls.Axes, 'Normalized Metric Value');
            title(metricsPlotControls.Axes, 'Metrics vs Z Position');
            
            metricsPlotControls.ClearButton = obj.createStyledButton(grid, 'warning', 'CLEAR', [], [2, 1]);
            metricsPlotControls.ExportButton = obj.createStyledButton(grid, 'primary', 'EXPORT', [], [2, 2]);
        end
        
        function button = createStyledButton(~, parent, style, text, callback, position)
            button = uibutton(parent, 'push');
            button.Layout.Row = position(1);
            
            if length(position) > 1
                button.Layout.Column = position(2);
            end
            
            if ~isempty(callback)
                button.ButtonPushedFcn = callback;
            end
            
            % Apply button styling using the centralized helper
            ui_components.applyButtonStyle(button, style, text);
        end
    end
    
    methods (Static, Access = private)
        function applyButtonStyle(button, style, text)
            if ~isvalid(button)
                return;
            end
            
            % Capitalize first letter of style for consistency with COLORS struct
            styleName = [upper(style(1)), lower(style(2:end))];

            if isfield(ui_components.COLORS, styleName)
                button.BackgroundColor = ui_components.COLORS.(styleName);
            else
                button.BackgroundColor = ui_components.COLORS.Primary; % Default style
            end

            button.FontColor = [1 1 1]; % White text for all styled buttons
            if nargin > 2 && ~isempty(text)
                button.Text = text;
            end
            button.FontSize = 10;
            button.FontWeight = 'bold';
        end
    end
end