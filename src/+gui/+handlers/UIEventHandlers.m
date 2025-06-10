classdef UIEventHandlers < handle
    % UIEventHandlers - Modern event handling system for FocusGUI
    % Provides robust, type-safe event handling with comprehensive error management
    
    properties (Constant, Access = private)
        % Visual styling constants
        PLOT_STYLES = struct(...
            'ScanTrace', struct('Color', [0.2 0.4 0.8], 'LineWidth', 2, 'Marker', '.', 'MarkerSize', 12), ...
            'StartMarker', struct('Color', [0.2 0.7 0.3], 'Marker', 'o', 'MarkerSize', 10, 'LineWidth', 2), ...
            'EndMarker', struct('Color', [0.7 0.2 0.7], 'Marker', 'o', 'MarkerSize', 10, 'LineWidth', 2), ...
            'MaxMarker', struct('Color', [0.8 0.2 0.2], 'Marker', 'p', 'MarkerSize', 14, 'LineWidth', 2) ...
        );
        
        PLOT_CONFIG = struct(...
            'GridAlpha', 0.3, ...
            'LineWidth', 1.2, ...
            'FontSize', 11, ...
            'TitleFontSize', 13, ...
            'LegendFontSize', 10, ...
            'AxisMargin', 0.05 ...
        );
        
        STATUS_CONFIG = struct(...
            'StatusBarHeight', 25, ...
            'UpdateInterval', 0.1 ...
        );
    end
    
    methods (Static)
        %% Component Update Methods
        function success = updateStepSizeDisplay(stepSizeValue, value, options)
            % Updates step size value display with validation and formatting
            arguments
                stepSizeValue
                value double {mustBePositive, mustBeFinite}
                options.Format string = "%.0f"
                options.EnableDrawnow logical = true
            end
            
            success = false;
            try
                if ~UIEventHandlers.isValidUIComponent(stepSizeValue)
                    return;
                end
                
                formattedValue = sprintf(options.Format, round(value));
                stepSizeValue.Text = formattedValue;
                
                if options.EnableDrawnow
                    drawnow limitrate;
                end
                success = true;
                
            catch ME
                UIEventHandlers.logError('updateStepSizeDisplay', ME);
            end
        end
        
        function success = updateCurrentZDisplay(currentZLabel, zValue, options)
            % Updates current Z position display with formatting options
            arguments
                currentZLabel
                zValue double {mustBeFinite}
                options.Format string = "%.1f"
                options.EnableDrawnow logical = true
                options.ColorThreshold double = []
            end
            
            success = false;
            try
                if ~UIEventHandlers.isValidUIComponent(currentZLabel)
                    return;
                end
                
                formattedValue = sprintf(options.Format, zValue);
                currentZLabel.Text = formattedValue;
                
                % Optional color coding based on threshold
                if ~isempty(options.ColorThreshold)
                    if abs(zValue) > options.ColorThreshold
                        currentZLabel.FontColor = [0.8 0.2 0.2]; % Red for extreme values
                    else
                        currentZLabel.FontColor = [0.2 0.2 0.7]; % Blue for normal values
                    end
                end
                
                if options.EnableDrawnow
                    drawnow limitrate;
                end
                success = true;
                
            catch ME
                UIEventHandlers.logError('updateCurrentZDisplay', ME);
            end
        end
        
        function success = updateStatusDisplay(statusText, message, options)
            % Updates status text with timestamp and severity options
            arguments
                statusText
                message string
                options.AddTimestamp logical = false
                options.Severity string {mustBeMember(options.Severity, ["info", "warning", "error", "success"])} = "info"
                options.EnableDrawnow logical = true
            end
            
            success = false;
            try
                if ~UIEventHandlers.isValidUIComponent(statusText)
                    return;
                end
                
                % Format message with optional timestamp
                if options.AddTimestamp
                    timestamp = string(datetime('now', 'Format', 'HH:mm:ss'));
                    displayMessage = sprintf('[%s] %s', timestamp, message);
                else
                    displayMessage = message;
                end
                
                statusText.Text = displayMessage;
                
                % Set color based on severity
                statusText.FontColor = UIEventHandlers.getSeverityColor(options.Severity);
                
                if options.EnableDrawnow
                    drawnow limitrate;
                end
                success = true;
                
            catch ME
                UIEventHandlers.logError('updateStatusDisplay', ME);
            end
        end
        
        %% Scan Control Methods
        function success = handleScanToggle(isScanActive, params)
            % Handles scan button toggle with comprehensive parameter validation
            arguments
                isScanActive logical
                params.Controller
                params.UI struct
                params.ScanParams struct = struct()
            end
            
            success = false;
            try
                if isScanActive
                    success = UIEventHandlers.startScanOperation(params);
                else
                    success = UIEventHandlers.stopScanOperation(params);
                end
                
            catch ME
                UIEventHandlers.logError('handleScanToggle', ME);
                UIEventHandlers.updateStatusDisplay(params.UI.StatusText, ...
                    "Error during scan toggle operation", Severity="error");
            end
        end
        
        function success = handleAbortOperation(params)
            % Handles abort operation with proper cleanup
            arguments
                params.Controller
                params.UI struct
                params.Message string = "Operation aborted by user"
            end
            
            success = false;
            try
                % Reset UI state
                if isfield(params.UI, 'ZScanToggle') && UIEventHandlers.isValidUIComponent(params.UI.ZScanToggle)
                    params.UI.ZScanToggle.Value = false;
                end
                
                if isfield(params.UI, 'MonitorToggle') && UIEventHandlers.isValidUIComponent(params.UI.MonitorToggle)
                    params.UI.MonitorToggle.Value = false;
                end
                
                % Call controller abort
                if ismethod(params.Controller, 'abortAllOperations')
                    params.Controller.abortAllOperations();
                end
                
                % Update status
                if isfield(params.UI, 'StatusText')
                    UIEventHandlers.updateStatusDisplay(params.UI.StatusText, params.Message, Severity="warning");
                end
                
                success = true;
                
            catch ME
                UIEventHandlers.logError('handleAbortOperation', ME);
            end
        end
        
        %% Plotting Methods
        function success = updateBrightnessPlot(axes, plotData, options)
            % Updates brightness vs Z-position plot with enhanced visualization
            arguments
                axes
                plotData struct
                options.ActiveChannel double = 1
                options.ShowLegend logical = true
                options.ShowMarkers logical = true
                options.ShowAnnotations logical = true
                options.AutoScale logical = true
            end
            
            success = false;
            try
                if ~UIEventHandlers.isValidUIComponent(axes)
                    return;
                end
                
                % Validate plot data
                if ~UIEventHandlers.isValidPlotData(plotData)
                    return;
                end
                
                % Clear and prepare axes
                cla(axes);
                hold(axes, 'on');
                
                % Plot main trace
                UIEventHandlers.plotScanTrace(axes, plotData);
                
                % Add markers if requested
                if options.ShowMarkers
                    UIEventHandlers.addPlotMarkers(axes, plotData);
                end
                
                % Add annotations if requested
                if options.ShowAnnotations
                    UIEventHandlers.addPlotAnnotations(axes, plotData);
                end
                
                % Configure axes appearance
                UIEventHandlers.configurePlotAppearance(axes, plotData, options);
                
                % Auto-scale if requested
                if options.AutoScale
                    UIEventHandlers.autoScalePlot(axes, plotData);
                end
                
                hold(axes, 'off');
                drawnow limitrate;
                success = true;
                
            catch ME
                UIEventHandlers.logError('updateBrightnessPlot', ME);
            end
        end
        
        %% UI State Management
        function success = toggleUIState(uiComponents, state, options)
            % Toggles UI component states with batch operations
            arguments
                uiComponents struct
                state string {mustBeMember(state, ["enable", "disable", "show", "hide"])}
                options.ComponentFilter string = ""
                options.ExcludeComponents string = ""
            end
            
            success = false;
            try
                componentNames = fieldnames(uiComponents);
                
                % Apply filters
                if options.ComponentFilter ~= ""
                    componentNames = componentNames(contains(componentNames, options.ComponentFilter, 'IgnoreCase', true));
                end
                
                if options.ExcludeComponents ~= ""
                    componentNames = componentNames(~contains(componentNames, options.ExcludeComponents, 'IgnoreCase', true));
                end
                
                % Apply state changes
                for i = 1:length(componentNames)
                    component = uiComponents.(componentNames{i});
                    if UIEventHandlers.isValidUIComponent(component)
                        UIEventHandlers.setComponentState(component, state);
                    end
                end
                
                success = true;
                
            catch ME
                UIEventHandlers.logError('toggleUIState', ME);
            end
        end
        
        %% Window Management
        function success = updateStatusBarLayout(figureHandle, statusBar, options)
            % Updates status bar layout with window resize handling
            arguments
                figureHandle
                statusBar
                options.Height double = UIEventHandlers.STATUS_CONFIG.StatusBarHeight
                options.BringToFront logical = true
            end
            
            success = false;
            try
                if ~UIEventHandlers.isValidUIComponent(figureHandle) || ...
                   ~UIEventHandlers.isValidUIComponent(statusBar)
                    return;
                end
                
                % Update position
                figPos = figureHandle.Position;
                statusBar.Position = [0, 0, figPos(3), options.Height];
                
                % Bring to front if requested
                if options.BringToFront
                    uistack(statusBar, 'top');
                end
                
                success = true;
                
            catch ME
                UIEventHandlers.logError('updateStatusBarLayout', ME);
            end
        end
        
        %% Help and Documentation
        function showHelpDialog(options)
            % Displays comprehensive help dialog
            arguments
                options.DialogTitle string = "Focus Finding - Usage Guide"
                options.CustomContent string = ""
            end
            
            try
                if options.CustomContent ~= ""
                    content = options.CustomContent;
                else
                    content = UIEventHandlers.buildHelpContent();
                end
                
                helpdlg(content, options.DialogTitle);
                
            catch ME
                UIEventHandlers.logError('showHelpDialog', ME);
            end
        end
    end
    
    methods (Static, Access = private)
        %% Validation Methods
        function isValid = isValidUIComponent(component)
            % Validates UI component handle
            isValid = ~isempty(component) && isvalid(component) && ishandle(component);
        end
        
        function isValid = isValidPlotData(plotData)
            % Validates plot data structure
            isValid = isstruct(plotData) && ...
                      isfield(plotData, 'zData') && ...
                      isfield(plotData, 'bData') && ...
                      isnumeric(plotData.zData) && ...
                      isnumeric(plotData.bData) && ...
                      length(plotData.zData) == length(plotData.bData) && ...
                      ~isempty(plotData.zData);
        end
        
        %% Scan Operation Helpers
        function success = startScanOperation(params)
            % Starts scan operation with parameter validation
            success = false;
            try
                % Show abort button, hide others
                UIEventHandlers.toggleScanButtons(params.UI, true);
                
                % Extract and validate scan parameters
                scanParams = UIEventHandlers.extractScanParameters(params);
                
                % Start the scan through controller
                if ismethod(params.Controller, 'toggleZScan')
                    params.Controller.toggleZScan(true, scanParams.stepSize, ...
                        scanParams.pauseTime, scanParams.metricType);
                    success = true;
                end
                
            catch ME
                UIEventHandlers.logError('startScanOperation', ME);
            end
        end
        
        function success = stopScanOperation(params)
            % Stops scan operation
            success = false;
            try
                % Restore normal button visibility
                UIEventHandlers.toggleScanButtons(params.UI, false);
                
                % Stop the scan through controller
                if ismethod(params.Controller, 'toggleZScan')
                    params.Controller.toggleZScan(false);
                    success = true;
                end
                
            catch ME
                UIEventHandlers.logError('stopScanOperation', ME);
            end
        end
        
        function scanParams = extractScanParameters(params)
            % Extracts and validates scan parameters from UI
            scanParams = struct();
            
            % Step size
            if isfield(params.UI, 'StepSizeSlider')
                scanParams.stepSize = max(1, round(params.UI.StepSizeSlider.Value));
            else
                scanParams.stepSize = 10; % Default
            end
            
            % Pause time
            if isfield(params.UI, 'PauseTimeEdit')
                scanParams.pauseTime = max(0, params.UI.PauseTimeEdit.Value);
            else
                scanParams.pauseTime = 0.5; % Default
            end
            
            % Metric type
            if isfield(params.UI, 'MetricDropDown')
                scanParams.metricType = params.UI.MetricDropDown.Value;
            else
                scanParams.metricType = 'Mean'; % Default
            end
        end
        
        function toggleScanButtons(ui, isScanActive)
            % Toggles scan button visibility
            if isScanActive
                % Show abort, hide others
                if isfield(ui, 'FocusButton') && UIEventHandlers.isValidUIComponent(ui.FocusButton)
                    ui.FocusButton.Visible = 'off';
                end
                if isfield(ui, 'GrabButton') && UIEventHandlers.isValidUIComponent(ui.GrabButton)
                    ui.GrabButton.Visible = 'off';
                end
                if isfield(ui, 'AbortButton') && UIEventHandlers.isValidUIComponent(ui.AbortButton)
                    ui.AbortButton.Visible = 'on';
                end
            else
                % Show normal buttons, hide abort
                if isfield(ui, 'FocusButton') && UIEventHandlers.isValidUIComponent(ui.FocusButton)
                    ui.FocusButton.Visible = 'on';
                end
                if isfield(ui, 'GrabButton') && UIEventHandlers.isValidUIComponent(ui.GrabButton)
                    ui.GrabButton.Visible = 'on';
                end
                if isfield(ui, 'AbortButton') && UIEventHandlers.isValidUIComponent(ui.AbortButton)
                    ui.AbortButton.Visible = 'off';
                end
            end
        end
        
        %% Plotting Helpers
        function plotScanTrace(axes, plotData)
            % Plots the main scan trace
            style = UIEventHandlers.PLOT_STYLES.ScanTrace;
            plot(axes, plotData.zData, plotData.bData, ...
                'Color', style.Color, ...
                'LineWidth', style.LineWidth, ...
                'Marker', style.Marker, ...
                'MarkerSize', style.MarkerSize, ...
                'DisplayName', 'Scan Trace');
        end
        
        function addPlotMarkers(axes, plotData)
            % Adds start, end, and maximum markers to plot
            if isempty(plotData.zData)
                return;
            end
            
            % Start marker
            startStyle = UIEventHandlers.PLOT_STYLES.StartMarker;
            plot(axes, plotData.zData(1), plotData.bData(1), ...
                'Color', startStyle.Color, ...
                'Marker', startStyle.Marker, ...
                'MarkerSize', startStyle.MarkerSize, ...
                'LineWidth', startStyle.LineWidth, ...
                'LineStyle', 'none', ...
                'DisplayName', 'Scan Start');
            
            % End marker
            endStyle = UIEventHandlers.PLOT_STYLES.EndMarker;
            plot(axes, plotData.zData(end), plotData.bData(end), ...
                'Color', endStyle.Color, ...
                'Marker', endStyle.Marker, ...
                'MarkerSize', endStyle.MarkerSize, ...
                'LineWidth', endStyle.LineWidth, ...
                'LineStyle', 'none', ...
                'DisplayName', 'Scan End');
            
            % Maximum marker
            [maxB, maxIdx] = max(plotData.bData);
            maxZ = plotData.zData(maxIdx);
            maxStyle = UIEventHandlers.PLOT_STYLES.MaxMarker;
            plot(axes, maxZ, maxB, ...
                'Color', maxStyle.Color, ...
                'Marker', maxStyle.Marker, ...
                'MarkerSize', maxStyle.MarkerSize, ...
                'LineWidth', maxStyle.LineWidth, ...
                'LineStyle', 'none', ...
                'DisplayName', 'Brightest Point');
        end
        
        function addPlotAnnotations(axes, plotData)
            % Adds text annotations to plot
            if isempty(plotData.bData)
                return;
            end
            
            [maxB, maxIdx] = max(plotData.bData);
            maxZ = plotData.zData(maxIdx);
            
            text(axes, maxZ, maxB, sprintf('  Max: %.2f', maxB), ...
                'Color', UIEventHandlers.PLOT_STYLES.MaxMarker.Color, ...
                'FontWeight', 'bold', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', UIEventHandlers.PLOT_CONFIG.FontSize);
        end
        
        function configurePlotAppearance(axes, plotData, options)
            % Configures plot appearance and styling
            config = UIEventHandlers.PLOT_CONFIG;
            
            % Title
            channelText = '';
            if isfield(plotData, 'activeChannel')
                channelText = sprintf(' (Channel %d)', plotData.activeChannel);
            elseif options.ActiveChannel > 0
                channelText = sprintf(' (Channel %d)', options.ActiveChannel);
            end
            
            title(axes, ['Brightness vs Z-Position' channelText], ...
                'FontWeight', 'bold', ...
                'FontSize', config.TitleFontSize);
            
            % Grid and box
            grid(axes, 'on');
            box(axes, 'on');
            axes.GridAlpha = config.GridAlpha;
            axes.LineWidth = config.LineWidth;
            axes.FontSize = config.FontSize;
            
            % Legend
            if options.ShowLegend
                legend(axes, 'show', 'Location', 'best', ...
                    'FontSize', config.LegendFontSize, 'Box', 'on');
            end
        end
        
        function autoScalePlot(axes, plotData)
            % Auto-scales plot axes with margin
            if isempty(plotData.zData) || isempty(plotData.bData)
                return;
            end
            
            margin = UIEventHandlers.PLOT_CONFIG.AxisMargin;
            
            % X-axis scaling
            xRange = max(plotData.zData) - min(plotData.zData);
            if xRange > 0
                axes.XLim = [min(plotData.zData) - margin*xRange, ...
                            max(plotData.zData) + margin*xRange];
            end
            
            % Y-axis scaling
            yRange = max(plotData.bData) - min(plotData.bData);
            if yRange > 0
                axes.YLim = [max(0, min(plotData.bData) - margin*yRange), ...
                            max(plotData.bData) + margin*yRange];
            end
        end
        
        %% Utility Methods
        function color = getSeverityColor(severity)
            % Returns color based on message severity
            switch severity
                case "info"
                    color = [0.3 0.3 0.3];
                case "success"
                    color = [0.2 0.7 0.3];
                case "warning"
                    color = [0.9 0.6 0.1];
                case "error"
                    color = [0.8 0.2 0.2];
                otherwise
                    color = [0.3 0.3 0.3];
            end
        end
        
        function setComponentState(component, state)
            % Sets component state (enable/disable, show/hide)
            switch state
                case "enable"
                    component.Enable = 'on';
                case "disable"
                    component.Enable = 'off';
                case "show"
                    component.Visible = 'on';
                case "hide"
                    component.Visible = 'off';
            end
        end
        
        function content = buildHelpContent()
            % Builds help dialog content
            content = [ ...
                'HOW TO FIND THE BEST FOCUS:' newline newline ...
                '1. SET UP: Adjust the step size (how far to move at each step) and pause time.' newline newline ...
                '2. AUTOMATIC FOCUS FINDING:' newline ...
                '   a. Press "Auto Z-Scan" to automatically scan through Z positions' newline ...
                '   b. When scan completes, press "Move to Max Focus" to jump to best focus' newline newline ...
                '3. MANUAL FOCUS FINDING:' newline ...
                '   a. Press "Monitor Brightness" to start tracking brightness' newline ...
                '   b. Use Up/Down buttons to move the Z stage while watching brightness' newline ...
                '   c. The plot will show brightness changes in real-time' newline newline ...
                '4. CONTROLS:' newline ...
                '   • Red markers show the brightest point found' newline ...
                '   • Green/purple markers show scan start/end points' newline ...
                '   • Press "Abort" to stop any operation immediately' newline newline ...
                '5. TIPS:' newline ...
                '   • Use smaller step sizes (8-15μm) for more precise scanning' newline ...
                '   • Increase pause time if the system needs more settling time' newline ...
            ];
        end
        
        function logError(functionName, ME)
            % Logs errors with context information
            warning('UIEventHandlers:%s:Error', functionName, ...
                'Error in %s: %s', functionName, ME.message);
        end
    end
end