classdef UIEventHandlers < handle
    % UIEventHandlers - Modern event handling system for FocusGUI
    % Provides robust, type-safe event handling with comprehensive error management
    % Uses gui.utils.GUIUtils for common operations
    
    properties (Constant, Access = private)
        % Visual styling constants
        PLOT_STYLES = struct(...
            'ScanTrace', struct('Color', [0.2 0.4 0.8], 'LineWidth', 2.5, 'Marker', '.', 'MarkerSize', 14), ...
            'StartMarker', struct('Color', [0.2 0.7 0.3], 'Marker', 'o', 'MarkerSize', 10, 'LineWidth', 2), ...
            'EndMarker', struct('Color', [0.7 0.2 0.7], 'Marker', 'o', 'MarkerSize', 10, 'LineWidth', 2), ...
            'MaxMarker', struct('Color', [0.8 0.2 0.2], 'Marker', 'p', 'MarkerSize', 16, 'LineWidth', 2.5), ...
            'CurrentMarker', struct('Color', [0.2 0.6 0.9], 'Marker', 'x', 'MarkerSize', 14, 'LineWidth', 2) ...
        );
        
        PLOT_CONFIG = struct(...
            'GridAlpha', 0.3, ...
            'LineWidth', 1.2, ...
            'FontSize', 11, ...
            'TitleFontSize', 13, ...
            'LegendFontSize', 10, ...
            'AxisMargin', 0.08 ...  % Increased margin for better visualization
        );
        
        STATUS_CONFIG = struct(...
            'StatusBarHeight', 25, ...
            'UpdateInterval', 0.1 ...
        );
        
        % Button state visual indicators
        BUTTON_STATES = struct(...
            'Active', struct('FontWeight', 'bold', 'BorderWidth', 2), ...
            'Inactive', struct('FontWeight', 'normal', 'BorderWidth', 1) ...
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
                options.HighlightChange logical = true
            end
            
            success = false;
            try
                if ~gui.utils.GUIUtils.isValidUIComponent(stepSizeValue)
                    return;
                end
                
                % Store previous value for highlighting changes
                if options.HighlightChange && isfield(stepSizeValue, 'Text')
                    prevValue = str2double(stepSizeValue.Text);
                else
                    prevValue = value;
                end
                
                formattedValue = sprintf(options.Format, round(value));
                stepSizeValue.Text = formattedValue;
                
                % Highlight if value changed significantly
                if options.HighlightChange && abs(prevValue - value) > 1
                    originalColor = stepSizeValue.FontColor;
                    stepSizeValue.FontColor = [0.8 0.2 0.2]; % Highlight in red
                    pause(0.2);
                    stepSizeValue.FontColor = originalColor;
                end
                
                if options.EnableDrawnow
                    drawnow limitrate;
                end
                success = true;
                
            catch ME
                gui.utils.GUIUtils.logError('updateStepSizeDisplay', ME);
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
                options.ShowMovementIndicator logical = false
                options.PreviousValue double = []
            end
            
            success = false;
            try
                if ~gui.utils.GUIUtils.isValidUIComponent(currentZLabel)
                    return;
                end
                
                % Format the value
                formattedValue = sprintf(options.Format, zValue);
                
                % Add movement indicator arrow if requested
                if options.ShowMovementIndicator && ~isempty(options.PreviousValue)
                    if zValue > options.PreviousValue
                        formattedValue = [formattedValue ' ▼']; % Down arrow (Z increases)
                    elseif zValue < options.PreviousValue
                        formattedValue = [formattedValue ' ▲']; % Up arrow (Z decreases)
                    end
                end
                
                currentZLabel.Text = formattedValue;
                
                % Color coding based on threshold
                if ~isempty(options.ColorThreshold)
                    if abs(zValue) > options.ColorThreshold
                        currentZLabel.FontColor = [0.8 0.2 0.2]; % Red for extreme values
                    else
                        currentZLabel.FontColor = [0.2 0.4 0.8]; % Blue for normal values
                    end
                end
                
                if options.EnableDrawnow
                    drawnow limitrate;
                end
                success = true;
                
            catch ME
                gui.utils.GUIUtils.logError('updateCurrentZDisplay', ME);
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
                options.FlashMessage logical = false
            end
            
            % Delegate to GUIUtils
            try
                gui.utils.GUIUtils.updateStatus(statusText, message, ...
                    'AddTimestamp', options.AddTimestamp, ...
                    'Severity', options.Severity, ...
                    'EnableDrawnow', options.EnableDrawnow, ...
                    'FlashMessage', options.FlashMessage);
                success = true;
            catch ME
                gui.utils.GUIUtils.logError('updateStatusDisplay', ME);
                success = false;
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
                    success = gui.handlers.UIEventHandlers.startScanOperation(params);
                else
                    success = gui.handlers.UIEventHandlers.stopScanOperation(params);
                end
                
            catch ME
                gui.utils.GUIUtils.logError('handleScanToggle', ME);
                gui.handlers.UIEventHandlers.updateStatusDisplay(params.UI.StatusText, ...
                    "Error during scan toggle operation", Severity="error", FlashMessage=true);
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
                if isfield(params.UI, 'ZScanToggle') && gui.utils.GUIUtils.isValidUIComponent(params.UI.ZScanToggle)
                    params.UI.ZScanToggle.Value = false;
                end
                
                if isfield(params.UI, 'MonitorToggle') && gui.utils.GUIUtils.isValidUIComponent(params.UI.MonitorToggle)
                    params.UI.MonitorToggle.Value = false;
                end
                
                % Call controller abort
                if ismethod(params.Controller, 'abortAllOperations')
                    params.Controller.abortAllOperations();
                end
                
                % Update status
                if isfield(params.UI, 'StatusText')
                    gui.handlers.UIEventHandlers.updateStatusDisplay(params.UI.StatusText, params.Message, ...
                        Severity="warning", FlashMessage=true);
                end
                
                success = true;
                
            catch ME
                gui.utils.GUIUtils.logError('handleAbortOperation', ME);
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
                options.CurrentZ double = []
                options.ShowGrid logical = true
            end
            
            success = false;
            try
                if ~gui.utils.GUIUtils.isValidUIComponent(axes)
                    return;
                end
                
                % Validate plot data
                if ~gui.handlers.UIEventHandlers.isValidPlotData(plotData)
                    return;
                end
                
                % Clear and prepare axes
                cla(axes);
                hold(axes, 'on');
                
                % Plot main trace
                gui.handlers.UIEventHandlers.plotScanTrace(axes, plotData);
                
                % Add markers if requested
                if options.ShowMarkers
                    gui.handlers.UIEventHandlers.addPlotMarkers(axes, plotData);
                    
                    % Add current Z position marker if provided
                    if ~isempty(options.CurrentZ)
                        gui.handlers.UIEventHandlers.addCurrentZMarker(axes, options.CurrentZ, plotData);
                    end
                end
                
                % Add annotations if requested
                if options.ShowAnnotations
                    gui.handlers.UIEventHandlers.addPlotAnnotations(axes, plotData, options.CurrentZ);
                end
                
                % Configure axes appearance
                gui.handlers.UIEventHandlers.configurePlotAppearance(axes, plotData, options);
                
                % Auto-scale if requested
                if options.AutoScale
                    gui.handlers.UIEventHandlers.autoScalePlot(axes, plotData, options.CurrentZ);
                end
                
                hold(axes, 'off');
                drawnow limitrate;
                success = true;
                
            catch ME
                gui.utils.GUIUtils.logError('updateBrightnessPlot', ME);
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
                options.VisualFeedback logical = true
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
                    if gui.utils.GUIUtils.isValidUIComponent(component)
                        if options.VisualFeedback
                            gui.handlers.UIEventHandlers.setComponentStateWithVisualFeedback(component, state);
                        else
                            gui.handlers.UIEventHandlers.setComponentState(component, state);
                        end
                    end
                end
                
                success = true;
                
            catch ME
                gui.utils.GUIUtils.logError('toggleUIState', ME);
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
            
            % Delegate to GUIUtils
            try
                gui.utils.GUIUtils.updateStatusBarLayout(figureHandle, statusBar, options.Height);
                success = true;
            catch ME
                gui.utils.GUIUtils.logError('updateStatusBarLayout', ME);
                success = false;
            end
        end
        
        %% Button State Visual Feedback
        function success = setButtonVisualState(button, isActive)
            % Sets visual appearance of button based on active/inactive state
            arguments
                button
                isActive logical
            end
            
            success = false;
            try
                if ~gui.utils.GUIUtils.isValidUIComponent(button)
                    return;
                end
                
                if isActive
                    button.FontWeight = gui.handlers.UIEventHandlers.BUTTON_STATES.Active.FontWeight;
                    if isprop(button, 'BorderWidth')
                        button.BorderWidth = gui.handlers.UIEventHandlers.BUTTON_STATES.Active.BorderWidth;
                    end
                else
                    button.FontWeight = gui.handlers.UIEventHandlers.BUTTON_STATES.Inactive.FontWeight;
                    if isprop(button, 'BorderWidth')
                        button.BorderWidth = gui.handlers.UIEventHandlers.BUTTON_STATES.Inactive.BorderWidth;
                    end
                end
                
                success = true;
                
            catch ME
                gui.utils.GUIUtils.logError('setButtonVisualState', ME);
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
                    content = gui.handlers.UIEventHandlers.buildHelpContent();
                end
                
                helpdlg(content, options.DialogTitle);
                
            catch ME
                gui.utils.GUIUtils.logError('showHelpDialog', ME);
            end
        end
        
        %% Tab Management Methods
        function success = handleTabChanged(tabGroup, controller, ui, options)
            % Handles tab changed events with proper state management
            arguments
                tabGroup
                controller
                ui struct
                options.UpdateStatus logical = true
                options.DefaultTab string = ""
            end
            
            success = false;
            try
                if ~gui.utils.GUIUtils.isValidUIComponent(tabGroup)
                    return;
                end
                
                % Get selected tab
                selectedTab = tabGroup.SelectedTab;
                if isempty(selectedTab)
                    if options.DefaultTab ~= ""
                        % Try to select default tab
                        gui.utils.GUIUtils.selectTabByName(tabGroup, options.DefaultTab);
                        selectedTab = tabGroup.SelectedTab;
                    end
                    
                    if isempty(selectedTab)
                        return;
                    end
                end
                
                tabName = selectedTab.Title;
                
                % Update UI based on selected tab
                switch tabName
                    case 'Manual Focus'
                        success = gui.handlers.UIEventHandlers.activateManualFocusTab(controller, ui, ...
                            'UpdateStatus', options.UpdateStatus);
                    case 'Auto Focus'
                        success = gui.handlers.UIEventHandlers.activateAutoFocusTab(controller, ui, ...
                            'UpdateStatus', options.UpdateStatus);
                    otherwise
                        if options.UpdateStatus && isfield(ui, 'StatusText')
                            gui.handlers.UIEventHandlers.updateStatusDisplay(ui.StatusText, ...
                                sprintf("Unknown tab selected: %s", tabName), Severity="warning");
                        end
                end
                
            catch ME
                gui.utils.GUIUtils.logError('handleTabChanged', ME);
            end
        end
        
        function success = activateManualFocusTab(controller, ui, options)
            % Activates the Manual Focus tab and updates UI accordingly
            arguments
                controller
                ui struct
                options.UpdateStatus logical = true
            end
            
            success = false;
            try
                % Show status message
                if options.UpdateStatus && isfield(ui, 'StatusText')
                    gui.handlers.UIEventHandlers.updateStatusDisplay(ui.StatusText, ...
                        "Manual Focus mode - Use Z controls and monitor brightness in real-time", ...
                        Severity="info");
                end
                
                success = true;
                
            catch ME
                gui.utils.GUIUtils.logError('activateManualFocusTab', ME);
            end
        end
        
        function success = activateAutoFocusTab(controller, ui, options)
            % Activates the Auto Focus tab and updates UI accordingly
            arguments
                controller
                ui struct
                options.UpdateStatus logical = true
            end
            
            success = false;
            try
                % Show status message
                if options.UpdateStatus && isfield(ui, 'StatusText')
                    gui.handlers.UIEventHandlers.updateStatusDisplay(ui.StatusText, ...
                        "Auto Focus mode - Set scan parameters and run Z-scan to find focus", ...
                        Severity="info");
                end
                
                % Check Z limits to see if Auto-Scan button should be enabled
                if isfield(ui, 'MinZEdit') && isfield(ui, 'MaxZEdit') && isfield(ui, 'ZScanToggle')
                    minZValid = ~isempty(ui.MinZEdit.Value) && ~isnan(ui.MinZEdit.Value);
                    maxZValid = ~isempty(ui.MaxZEdit.Value) && ~isnan(ui.MaxZEdit.Value);
                    rangeValid = minZValid && maxZValid && (ui.MaxZEdit.Value > ui.MinZEdit.Value);
                    
                    % Enable/disable Z-Scan button based on Z limits
                    if rangeValid
                        gui.utils.GUIUtils.toggleComponentState(ui.ZScanToggle, true);
                    else
                        gui.utils.GUIUtils.toggleComponentState(ui.ZScanToggle, false);
                    end
                end
                
                success = true;
                
            catch ME
                gui.utils.GUIUtils.logError('activateAutoFocusTab', ME);
            end
        end
        
        %% Plot Panel Methods
        function success = togglePlotVisibility(mainGrid, plotToggleButton, isExpanded, plotPanel)
            % Toggles plot panel visibility with animation effect
            arguments
                mainGrid
                plotToggleButton
                isExpanded logical
                plotPanel = [] % Optional plotPanel to hide/show
            end
            
            success = false;
            try
                if ~gui.utils.GUIUtils.isValidUIComponent(mainGrid) || ...
                   ~gui.utils.GUIUtils.isValidUIComponent(plotToggleButton)
                    return;
                end
                
                % Set column widths based on expanded state
                if isExpanded
                    % Expand plot area
                    mainGrid.ColumnWidth = {'1.5x', '1x'};  % Changed from 1.7x to 1.5x
                    plotToggleButton.Text = '◀';
                    plotToggleButton.Tooltip = 'Hide plot panel';
                    
                    % Show plot panel if provided
                    if ~isempty(plotPanel) && gui.utils.GUIUtils.isValidUIComponent(plotPanel)
                        plotPanel.Visible = 'on';
                    end
                else
                    % Collapse plot area - but keep header visible for toggle button
                    mainGrid.ColumnWidth = {'1x', '0.2x'};  % Changed from 0.3x to 0.2x
                    plotToggleButton.Text = '▶';
                    plotToggleButton.Tooltip = 'Show plot panel';
                    
                    % Hide plot panel if provided
                    if ~isempty(plotPanel) && gui.utils.GUIUtils.isValidUIComponent(plotPanel)
                        plotPanel.Visible = 'off';
                    end
                end
                
                % Refresh layout
                drawnow;
                success = true;
                
            catch ME
                gui.utils.GUIUtils.logError('togglePlotVisibility', ME);
            end
        end
    end
    
    methods (Static)
        %% Validation Methods
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
        
        %% Utility Methods
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
        
        function setComponentStateWithVisualFeedback(component, state)
            % Sets component state with visual feedback
            originalBgColor = [];
            if isprop(component, 'BackgroundColor')
                originalBgColor = component.BackgroundColor;
            end
            
            % Apply state change
            gui.handlers.UIEventHandlers.setComponentState(component, state);
            
            % Visual feedback for enable/disable
            if strcmp(state, 'enable') && ~isempty(originalBgColor)
                % Flash green for enable
                component.BackgroundColor = [0.8 1.0 0.8];
                pause(0.1);
                component.BackgroundColor = originalBgColor;
            elseif strcmp(state, 'disable') && ~isempty(originalBgColor)
                % Flash red for disable
                component.BackgroundColor = [1.0 0.8 0.8];
                pause(0.1);
                component.BackgroundColor = originalBgColor;
            end
        end
        
        function content = buildHelpContent()
            % Builds help dialog content
            content = [ ...
                'HOW TO FIND THE BEST FOCUS:' newline newline ...
                '1. SET UP: Adjust the step size (how far to move at each step) and pause time.' newline newline ...
                '2. AUTOMATIC FOCUS FINDING:' newline ...
                '   a. Press "Auto Z-Scan" to automatically scan through Z positions' newline ...
                '   b. When scan completes, press "Move to Max Focus" to jump to best focus' newline ...
                '3. MANUAL FOCUS FINDING:' newline ...
                '   a. Press "Monitor Brightness" to start tracking brightness' newline ...
                '   b. Use Up/Down buttons to move the Z stage while watching brightness' newline ...
                '   c. The plot will show brightness changes in real-time' newline newline ...
                '4. PLOT MARKERS:' newline ...
                '   • Red diamond (◆): Optimal focus position (highest brightness)' newline ...
                '   • Green circle (○): Scan start position' newline ...
                '   • Purple circle (○): Scan end position' newline ...
                '   • Blue X (×): Current Z position' newline newline ...
                '5. CONTROLS:' newline ...
                '   • "Monitor Brightness": Tracks image brightness without moving' newline ...
                '   • "Auto Z-Scan": Automatically scans through Z positions' newline ...
                '   • "Move to Max Focus": Moves to the position of maximum brightness' newline ...
                '   • "Focus Mode": Starts continuous scanning in ScanImage' newline ...
                '   • "Grab Frame": Takes a single image in ScanImage' newline ...
                '   • "ABORT": Stops all operations immediately' newline newline ...
                '6. TIPS:' newline ...
                '   • Use 8-15μm step sizes for more precise focus finding' newline ...
                '   • Larger step sizes (20-30μm) are good for initial rough scans' newline ...
                '   • Increase pause time if images appear noisy or inconsistent' newline ...
                '   • The "Current Z Position" display shows movement direction (▲/▼)' newline ...
            ];
        end
        
        function toggleScanButtons(ui, isScanActive)
            % Toggles scan button visibility
            if isScanActive
                % Show abort, hide others
                if isfield(ui, 'FocusButton') && gui.utils.GUIUtils.isValidUIComponent(ui.FocusButton)
                    ui.FocusButton.Visible = 'off';
                end
                if isfield(ui, 'GrabButton') && gui.utils.GUIUtils.isValidUIComponent(ui.GrabButton)
                    ui.GrabButton.Visible = 'off';
                end
                if isfield(ui, 'AbortButton') && gui.utils.GUIUtils.isValidUIComponent(ui.AbortButton)
                    ui.AbortButton.Visible = 'on';
                end
                
                % Disable settings controls during scan
                if isfield(ui, 'StepSizeSlider') && gui.utils.GUIUtils.isValidUIComponent(ui.StepSizeSlider)
                    ui.StepSizeSlider.Enable = 'off';
                end
                if isfield(ui, 'PauseTimeEdit') && gui.utils.GUIUtils.isValidUIComponent(ui.PauseTimeEdit)
                    ui.PauseTimeEdit.Enable = 'off';
                end
                if isfield(ui, 'MetricDropDown') && gui.utils.GUIUtils.isValidUIComponent(ui.MetricDropDown)
                    ui.MetricDropDown.Enable = 'off';
                end
            else
                % Show normal buttons, hide abort
                if isfield(ui, 'FocusButton') && gui.utils.GUIUtils.isValidUIComponent(ui.FocusButton)
                    ui.FocusButton.Visible = 'on';
                end
                if isfield(ui, 'GrabButton') && gui.utils.GUIUtils.isValidUIComponent(ui.GrabButton)
                    ui.GrabButton.Visible = 'on';
                end
                if isfield(ui, 'AbortButton') && gui.utils.GUIUtils.isValidUIComponent(ui.AbortButton)
                    ui.AbortButton.Visible = 'off';
                end
                
                % Re-enable settings controls after scan
                if isfield(ui, 'StepSizeSlider') && gui.utils.GUIUtils.isValidUIComponent(ui.StepSizeSlider)
                    ui.StepSizeSlider.Enable = 'on';
                end
                if isfield(ui, 'PauseTimeEdit') && gui.utils.GUIUtils.isValidUIComponent(ui.PauseTimeEdit)
                    ui.PauseTimeEdit.Enable = 'on';
                end
                if isfield(ui, 'MetricDropDown') && gui.utils.GUIUtils.isValidUIComponent(ui.MetricDropDown)
                    ui.MetricDropDown.Enable = 'on';
                end
            end
        end
    end
    
    methods (Static, Access = private)
        %% Scan Operation Helpers
        function success = startScanOperation(params)
            % Starts scan operation with parameter validation
            success = false;
            try
                % Show abort button, hide others
                gui.handlers.UIEventHandlers.toggleScanButtons(params.UI, true);
                
                % Extract and validate scan parameters
                scanParams = gui.handlers.UIEventHandlers.extractScanParameters(params);
                
                % Visual feedback that scan is starting
                if isfield(params.UI, 'StatusText')
                    gui.handlers.UIEventHandlers.updateStatusDisplay(params.UI.StatusText, ...
                        sprintf("Starting Z-Scan with step size %d μm", scanParams.stepSize), ...
                        Severity="info");
                end
                
                % Start the scan through controller
                if ismethod(params.Controller, 'toggleZScan')
                    params.Controller.toggleZScan(true, scanParams.stepSize, ...
                        scanParams.pauseTime, scanParams.metricType);
                    success = true;
                end
                
            catch ME
                gui.utils.GUIUtils.logError('startScanOperation', ME);
            end
        end
        
        function success = stopScanOperation(params)
            % Stops scan operation
            success = false;
            try
                % Restore normal button visibility
                gui.handlers.UIEventHandlers.toggleScanButtons(params.UI, false);
                
                % Visual feedback that scan is stopping
                if isfield(params.UI, 'StatusText')
                    gui.handlers.UIEventHandlers.updateStatusDisplay(params.UI.StatusText, ...
                        "Stopping Z-Scan...", Severity="info");
                end
                
                % Stop the scan through controller
                if ismethod(params.Controller, 'toggleZScan')
                    params.Controller.toggleZScan(false);
                    
                    % Confirmation that scan stopped
                    if isfield(params.UI, 'StatusText')
                        gui.handlers.UIEventHandlers.updateStatusDisplay(params.UI.StatusText, ...
                            "Z-Scan stopped. Use 'Move to Max Focus' to go to best position.", ...
                            Severity="success");
                    end
                    
                    success = true;
                end
                
            catch ME
                gui.utils.GUIUtils.logError('stopScanOperation', ME);
            end
        end
        
    end
    
    methods (Static)
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
        
        %% Plotting Helpers
        function plotScanTrace(axes, plotData)
            % Plots the main scan trace
            style = gui.handlers.UIEventHandlers.PLOT_STYLES.ScanTrace;
            plot(axes, plotData.zData, plotData.bData, ...
                'Color', style.Color, ...
                'LineWidth', style.LineWidth, ...
                'Marker', style.Marker, ...
                'MarkerSize', style.MarkerSize, ...
                'DisplayName', 'Brightness Scan');
        end
        
        function addPlotMarkers(axes, plotData)
            % Adds start, end, and maximum markers to plot
            if isempty(plotData.zData)
                return;
            end
            
            % Start marker
            startStyle = gui.handlers.UIEventHandlers.PLOT_STYLES.StartMarker;
            plot(axes, plotData.zData(1), plotData.bData(1), ...
                'Color', startStyle.Color, ...
                'Marker', startStyle.Marker, ...
                'MarkerSize', startStyle.MarkerSize, ...
                'LineWidth', startStyle.LineWidth, ...
                'LineStyle', 'none', ...
                'DisplayName', 'Scan Start');
            
            % End marker
            endStyle = gui.handlers.UIEventHandlers.PLOT_STYLES.EndMarker;
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
            maxStyle = gui.handlers.UIEventHandlers.PLOT_STYLES.MaxMarker;
            plot(axes, maxZ, maxB, ...
                'Color', maxStyle.Color, ...
                'Marker', maxStyle.Marker, ...
                'MarkerSize', maxStyle.MarkerSize, ...
                'LineWidth', maxStyle.LineWidth, ...
                'LineStyle', 'none', ...
                'DisplayName', 'Optimal Focus');
        end
        
        function addCurrentZMarker(axes, currentZ, plotData)
            % Adds marker for current Z position if within plot range
            if isempty(plotData.zData) || isempty(plotData.bData)
                return;
            end
            
            % Only add marker if current Z is within the range of data
            minZ = min(plotData.zData);
            maxZ = max(plotData.zData);
            
            if currentZ >= minZ && currentZ <= maxZ
                % Interpolate brightness at current Z
                currentB = interp1(plotData.zData, plotData.bData, currentZ, 'linear');
                
                if ~isnan(currentB)
                    % Plot current Z marker
                    currentStyle = gui.handlers.UIEventHandlers.PLOT_STYLES.CurrentMarker;
                    plot(axes, currentZ, currentB, ...
                        'Color', currentStyle.Color, ...
                        'Marker', currentStyle.Marker, ...
                        'MarkerSize', currentStyle.MarkerSize, ...
                        'LineWidth', currentStyle.LineWidth, ...
                        'LineStyle', 'none', ...
                        'DisplayName', 'Current Position');
                end
            end
        end
        
        function addPlotAnnotations(axes, plotData, currentZ)
            % Adds text annotations to plot
            if isempty(plotData.bData)
                return;
            end
            
            % Add annotation for maximum brightness
            [maxB, maxIdx] = max(plotData.bData);
            maxZ = plotData.zData(maxIdx);
            
            text(axes, maxZ, maxB, sprintf('  Max: %.1f @ Z=%.1f', maxB, maxZ), ...
                'Color', gui.handlers.UIEventHandlers.PLOT_STYLES.MaxMarker.Color, ...
                'FontWeight', 'bold', ...
                'VerticalAlignment', 'bottom', ...
                'HorizontalAlignment', 'left', ...
                'FontSize', gui.handlers.UIEventHandlers.PLOT_CONFIG.FontSize);
            
            % Add annotation for current Z if provided
            if ~isempty(currentZ)
                % Only add annotation if current Z is within the range of data
                minZ = min(plotData.zData);
                maxZ = max(plotData.zData);
                
                if currentZ >= minZ && currentZ <= maxZ
                    % Interpolate brightness at current Z
                    currentB = interp1(plotData.zData, plotData.bData, currentZ, 'linear');
                    
                    if ~isnan(currentB)
                        text(axes, currentZ, currentB, sprintf('  Current: Z=%.1f', currentZ), ...
                            'Color', gui.handlers.UIEventHandlers.PLOT_STYLES.CurrentMarker.Color, ...
                            'FontWeight', 'bold', ...
                            'VerticalAlignment', 'top', ...
                            'HorizontalAlignment', 'left', ...
                            'FontSize', gui.handlers.UIEventHandlers.PLOT_CONFIG.FontSize);
                    end
                end
            end
        end
        
        function configurePlotAppearance(axes, plotData, options)
            % Configures plot appearance and styling
            config = gui.handlers.UIEventHandlers.PLOT_CONFIG;
            
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
            if options.ShowGrid
                grid(axes, 'on');
            else
                grid(axes, 'off');
            end
            box(axes, 'on');
            axes.GridAlpha = config.GridAlpha;
            axes.LineWidth = config.LineWidth;
            axes.FontSize = config.FontSize;
            
            % Legend
            if options.ShowLegend && ~isempty(plotData.zData)
                legend(axes, 'show', 'Location', 'best', ...
                    'FontSize', config.LegendFontSize, 'Box', 'on');
            end
        end
        
        function autoScalePlot(axes, plotData, currentZ)
            % Auto-scales plot axes with margin
            if isempty(plotData.zData) || isempty(plotData.bData)
                return;
            end
            
            margin = gui.handlers.UIEventHandlers.PLOT_CONFIG.AxisMargin;
            
            % Determine Z range, potentially including current Z position
            minZ = min(plotData.zData);
            maxZ = max(plotData.zData);
            
            if ~isempty(currentZ) && (currentZ < minZ || currentZ > maxZ)
                % Include current Z in range if it's outside the data range
                minZ = min(minZ, currentZ);
                maxZ = max(maxZ, currentZ);
            end
            
            % X-axis scaling
            zRange = maxZ - minZ;
            if zRange > 0
                axes.XLim = [minZ - margin*zRange, maxZ + margin*zRange];
            end
            
            % Y-axis scaling
            yRange = max(plotData.bData) - min(plotData.bData);
            if yRange > 0
                axes.YLim = [max(0, min(plotData.bData) - margin*yRange), ...
                            max(plotData.bData) + margin*yRange];
            else
                % If there's no range, create one around the value
                axes.YLim = [max(0, min(plotData.bData)*0.9), min(plotData.bData)*1.1];
            end
        end
    end
end