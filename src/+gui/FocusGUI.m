classdef FocusGUI < handle
    % FocusGUI - Creates and manages the modern GUI for FocalSweep
    % Inspired by modern React-based UI with enhanced styling and functionality
    %
    % This class has been refactored to use helper classes:
    % - gui.components.UIComponentFactory: For creating UI components
    % - gui.handlers.UIEventHandlers: For handling UI events
    % - gui.utils.GUIUtils: For common utility functions

    properties (Access = public)
        % GUI Handles
        hFig              % Main figure handle
        hAx               % Plot axes handle
        hStatusText       % Status text label
        hStepSizeSlider   % Step size slider
        hStepSizeValue    % Step size value label
        hPauseTimeEdit    % Pause time edit field
        hMinZEdit         % Min Z edit field
        hMaxZEdit         % Max Z edit field
        hMetricDropDown   % Metric dropdown
        hMonitorToggle    % Monitor toggle button
        hZScanToggle      % Z-scan toggle button
        hFocusButton      % Focus button
        hGrabButton       % Grab button
        hAbortButton      % Abort button
        hMoveToMaxButton  % Move to max brightness button
        hCurrentZLabel    % Current Z position label
        hStatusBar        % Status bar panel
    end

    properties (Access = private)
        controller        % Handle to the main controller
        focusModeActive = false  % Track if focus mode is active
        hasZData = false         % Track if we have Z position data
        previousZValue = 0       % Previous Z value for movement indicator
        tooltipsEnabled = true   % Flag to enable/disable tooltips
        helpButton               % Help button in the status bar
        verbosity = 1            % Verbosity level (inherited from controller)
    end

    methods
        function obj = FocusGUI(controller)
            obj.controller = controller;
        end

        function create(obj)
            % Create main figure with modern styling
            fprintf('Creating FocalSweep GUI...\n');
            obj.hFig = uifigure('Name', 'FocalSweep - Automated Z-Focus Finder', ...
                'Position', [100 100 950 700], ...
                'Color', [0.95 0.95 0.98], ...
                'CloseRequestFcn', @(~,~) obj.closeFigure(), ...
                'Resize', 'on');
            
            % Check if we're running in a compatible MATLAB version
            hasNewUIControls = ~verLessThan('matlab', '9.8'); % R2020a or newer
            if ~hasNewUIControls
                fprintf('Warning: Running on an older MATLAB version. Some UI features may be limited.\n');
            end

            % Create a more compact grid layout
            mainGrid = uigridlayout(obj.hFig, [3, 2]);
            mainGrid.RowHeight = {'fit', '1x', 'fit'};
            mainGrid.ColumnWidth = {'1x', '1.5x'};
            mainGrid.Padding = [15 15 15 15];
            mainGrid.RowSpacing = 12;
            mainGrid.ColumnSpacing = 15;
            
            % --- Parameters Panel with Instructions (Row 1, Col 1) ---
            paramContainer = uipanel(mainGrid, 'BorderType', 'none', 'BackgroundColor', [0.95 0.95 0.98]);
            paramContainer.Layout.Row = 1;
            paramContainer.Layout.Column = 1;
            
            paramGrid = uigridlayout(paramContainer, [1, 2]);
            paramGrid.RowHeight = {'fit'};
            paramGrid.ColumnWidth = {'1.2x', '1x'};
            paramGrid.Padding = [0 0 0 0];
            paramGrid.ColumnSpacing = 10;
            
            % --- Scan Parameters Panel (Row 1, Col 1 of paramGrid) ---
            paramPanel = gui.components.UIComponentFactory.createStyledPanel(paramGrid, 'Z-Scan Parameters', 1, 1);
            
            % --- Z Movement Controls Panel (Row 1, Col 2 of paramGrid) ---
            zControlPanel = gui.components.UIComponentFactory.createStyledPanel(paramGrid, 'Z Movement Controls', 1, 2);
            
            % --- Plot Area (Col 2, Row 1:3) ---
            plotPanel = gui.components.UIComponentFactory.createStyledPanel(mainGrid, 'Brightness vs. Z-Position', [1 3], 2);
            
            % Create plot area with component factory
            obj.hAx = gui.components.UIComponentFactory.createPlotPanel(plotPanel);

            % --- Actions Panel (Row 3, Col 1) ---
            actionPanel = gui.components.UIComponentFactory.createStyledPanel(mainGrid, 'Control Actions', 3, 1);
            
            % Now create all panels and components
            components = gui.components.UIComponentFactory.createScanParametersPanel(paramPanel, paramPanel, obj.controller);
            obj.hStepSizeSlider = components.stepSizeSlider;
            obj.hStepSizeValue = components.stepSizeValue; 
            obj.hPauseTimeEdit = components.pauseTimeEdit;
            obj.hMetricDropDown = components.metricDropDown;
            obj.hMinZEdit = components.minZEdit;
            obj.hMaxZEdit = components.maxZEdit;
                
            obj.hCurrentZLabel = gui.components.UIComponentFactory.createZControlPanel(zControlPanel, zControlPanel, obj.controller);
            
            buttons = gui.components.UIComponentFactory.createActionPanel(actionPanel, actionPanel, obj.controller);
            obj.hMonitorToggle = buttons.monitorToggle;
            obj.hZScanToggle = buttons.zScanToggle;
            obj.hMoveToMaxButton = buttons.moveToMaxButton;
            obj.hFocusButton = buttons.focusButton;
            obj.hGrabButton = buttons.grabButton;
            obj.hAbortButton = buttons.abortButton;
            
            % Set up event handlers
            obj.hStepSizeSlider.ValueChangingFcn = @(src,event) obj.updateStepSizeValueDisplay(event.Value);
            obj.hStepSizeSlider.ValueChangedFcn = @(src,event) obj.controller.updateStepSizeImmediate(event.Value);
            obj.hMonitorToggle.ValueChangedFcn = @(src,~) obj.monitorToggleChanged(src.Value);
            obj.hZScanToggle.ValueChangedFcn = @(src,~) obj.toggleScanButtons(src.Value);
            
            % The focus button callback needs to be set here because we're not using the factory's built-in callback
            obj.hFocusButton.ButtonPushedFcn = @(~,~) obj.toggleFocusMode();
            obj.hGrabButton.ButtonPushedFcn = @(~,~) obj.controller.grabSIFrame();
            obj.hAbortButton.ButtonPushedFcn = @(~,~) obj.abortOperation();
            obj.hMoveToMaxButton.ButtonPushedFcn = @(~,~) obj.moveToMaxBrightness();
            
            % Add min/max Z change callbacks to update Auto Z-Scan button state
            obj.hMinZEdit.ValueChangedFcn = @(~,~) obj.updateButtonStates();
            obj.hMaxZEdit.ValueChangedFcn = @(~,~) obj.updateButtonStates();

            % --- Status Bar ---
            [obj.hStatusText, obj.hStatusBar] = gui.components.UIComponentFactory.createStatusBar(obj.hFig);
            
            % Add Help button to status bar
            obj.helpButton = uibutton(obj.hStatusBar, ...
                'Text', '❓ Help', ...
                'Position', [obj.hFig.Position(3)-70, 2, 60, 20], ...
                'BackgroundColor', [0.9 0.9 0.95], ...
                'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) obj.showHelp());
            
            % Set up figure resize callback
            obj.hFig.AutoResizeChildren = 'off';  % Disable auto resize before setting SizeChangedFcn
            obj.hFig.SizeChangedFcn = @(~,~) obj.updateStatusBarPosition();
            
            % Initialize button states
            obj.updateButtonStates();
            
            % Show initial status message
            obj.updateStatus('Ready - Set Z parameters and press "Monitor Brightness" to start');
        end
        
        function monitorToggleChanged(obj, isActive)
            % Handle monitor toggle state change with visual feedback
            obj.controller.toggleMonitor(isActive);
            
            % Visual feedback for button state
            gui.handlers.UIEventHandlers.setButtonVisualState(obj.hMonitorToggle, isActive);
            
            if isActive
                obj.updateStatus('Monitoring active - brightness will update in real-time');
                obj.hZScanToggle.Enable = 'on';
            else
                obj.updateStatus('Monitoring stopped');
                obj.hZScanToggle.Enable = 'off';
            end
            
            % Update button states
            obj.updateButtonStates();
        end
        
        function toggleFocusMode(obj)
            % Toggle focus mode and update UI
            obj.focusModeActive = ~obj.focusModeActive;
            
            if obj.focusModeActive
                % Start focus mode in ScanImage
                obj.startSIFocus();
                
                % Show abort button instead of focus/grab buttons
                gui.utils.GUIUtils.setVisibility(obj.hFocusButton, false);
                gui.utils.GUIUtils.setVisibility(obj.hGrabButton, false);
                gui.utils.GUIUtils.setVisibility(obj.hAbortButton, true);
                
                % Visual feedback
                obj.updateStatus('Focus mode active - ScanImage is continuously acquiring', Severity="success");
                
                % Update Z-scan button state
                obj.updateButtonStates();
                
                % Start monitoring if not already active
                if ~obj.hMonitorToggle.Value
                    obj.hMonitorToggle.Value = true;
                    obj.monitorToggleChanged(true);
                end
            else
                % Reset UI
                gui.utils.GUIUtils.setVisibility(obj.hFocusButton, true);
                gui.utils.GUIUtils.setVisibility(obj.hGrabButton, true);
                gui.utils.GUIUtils.setVisibility(obj.hAbortButton, false);
                
                % Update status
                obj.updateStatus('Focus mode stopped');
                
                % Update Z-scan button state
                obj.updateButtonStates();
            end
        end
        
        function moveToMaxBrightness(obj)
            % Move to max brightness with visual feedback
            obj.updateStatus('Moving to position of maximum brightness...', Severity="info");
            obj.controller.moveToMaxBrightness();
        end
        
        function updateButtonStates(obj)
            % Update enabled/disabled state of buttons based on conditions
            
            % Auto Z-Scan should be enabled only when:
            % 1. Min and Max Z are set
            % 2. Focus mode is active or monitoring is active
            minZValid = ~isempty(obj.hMinZEdit.Value) && ~isnan(obj.hMinZEdit.Value);
            maxZValid = ~isempty(obj.hMaxZEdit.Value) && ~isnan(obj.hMaxZEdit.Value);
            rangeValid = minZValid && maxZValid && (obj.hMaxZEdit.Value > obj.hMinZEdit.Value);
            
            if rangeValid && (obj.focusModeActive || obj.hMonitorToggle.Value)
                gui.utils.GUIUtils.toggleComponentState(obj.hZScanToggle, true);
                obj.hZScanToggle.Tooltip = 'Start automatic Z scan to find focus';
            else
                gui.utils.GUIUtils.toggleComponentState(obj.hZScanToggle, false);
                
                % Set explanatory tooltip based on the reason it's disabled
                if ~rangeValid
                    obj.hZScanToggle.Tooltip = 'Set valid Min and Max Z positions first';
                elseif ~obj.focusModeActive && ~obj.hMonitorToggle.Value
                    obj.hZScanToggle.Tooltip = 'Start Focus mode or Monitor first';
                else
                    obj.hZScanToggle.Tooltip = 'Auto Z-Scan disabled';
                end
            end
            
            % Move to Max Focus should be enabled only when we have Z data
            if obj.hasZData
                gui.utils.GUIUtils.toggleComponentState(obj.hMoveToMaxButton, true);
                obj.hMoveToMaxButton.Tooltip = 'Move to the Z position with maximum brightness (best focus)';
            else
                gui.utils.GUIUtils.toggleComponentState(obj.hMoveToMaxButton, false);
                obj.hMoveToMaxButton.Tooltip = 'Perform a Z-Scan first to find maximum brightness';
            end
        end
        
        function updateStepSizeValueDisplay(obj, value)
            % Update step size value display immediately during slider movement
            gui.handlers.UIEventHandlers.updateStepSizeDisplay(obj.hStepSizeValue, value);
        end

        function toggleScanButtons(obj, isScanActive)
            % Toggle between scan control buttons and abort button
            uiComponents = struct(...
                'FocusButton', obj.hFocusButton, ...
                'GrabButton', obj.hGrabButton, ...
                'AbortButton', obj.hAbortButton, ...
                'ZScanToggle', obj.hZScanToggle, ...
                'StepSizeSlider', obj.hStepSizeSlider, ...
                'PauseTimeEdit', obj.hPauseTimeEdit, ...
                'MetricDropDown', obj.hMetricDropDown, ...
                'StatusText', obj.hStatusText);
                
            if isScanActive
                % Start Z-scan
                scanParams = struct();
                gui.handlers.UIEventHandlers.handleScanToggle(true, ...
                    Controller=obj.controller, ...
                    UI=uiComponents, ...
                    ScanParams=scanParams);
                    
                % Visual feedback for button state
                gui.handlers.UIEventHandlers.setButtonVisualState(obj.hZScanToggle, true);
            else
                % Stop Z-scan
                gui.handlers.UIEventHandlers.handleScanToggle(false, ...
                    Controller=obj.controller, ...
                    UI=uiComponents);
                    
                % Visual feedback for button state
                gui.handlers.UIEventHandlers.setButtonVisualState(obj.hZScanToggle, false);
            end
        end
        
        function abortOperation(obj)
            % Handle abort button press
            uiComponents = struct(...
                'ZScanToggle', obj.hZScanToggle, ...
                'MonitorToggle', obj.hMonitorToggle, ...
                'StatusText', obj.hStatusText);
                
            gui.handlers.UIEventHandlers.handleAbortOperation(...
                Controller=obj.controller, ...
                UI=uiComponents, ...
                Message="OPERATION ABORTED");
            
            % Reset focus mode
            obj.focusModeActive = false;
            gui.utils.GUIUtils.setVisibility(obj.hFocusButton, true);
            gui.utils.GUIUtils.setVisibility(obj.hGrabButton, true);
            gui.utils.GUIUtils.setVisibility(obj.hAbortButton, false);
            
            % Update button states
            obj.updateButtonStates();
        end

        function updatePlot(obj, zData, bData, activeChannel)
            % Update the brightness vs Z-position plot with visual markers
            plotData = struct(...
                'zData', zData, ...
                'bData', bData, ...
                'activeChannel', activeChannel);
            
            % Get current Z position to overlay on plot    
            currentZ = [];
            try
                currentZ = obj.controller.getZ();
            catch
                % If we can't get current Z, just don't show the marker
            end
                
            gui.handlers.UIEventHandlers.updateBrightnessPlot(obj.hAx, plotData, ...
                ActiveChannel=activeChannel, ...
                ShowLegend=true, ...
                ShowMarkers=true, ...
                CurrentZ=currentZ);
            
            % Update hasZData flag based on data
            obj.hasZData = ~isempty(zData) && length(zData) > 1;
            
            % Update Move to Max button state
            obj.updateButtonStates();
        end
        
        function updateCurrentZ(obj, zValue)
            % Update current Z position display with movement indicator
            prevZ = obj.previousZValue;
            obj.previousZValue = zValue;
            
            gui.handlers.UIEventHandlers.updateCurrentZDisplay(obj.hCurrentZLabel, zValue, ...
                Format="%.1f", ...
                ColorThreshold=500, ...
                ShowMovementIndicator=true, ...
                PreviousValue=prevZ);
        end

        function updateStatus(obj, message, varargin)
            % Update status text with optional severity
            p = inputParser;
            p.addOptional('Severity', 'info', @ischar);
            p.addOptional('FlashMessage', false, @islogical);
            p.parse(varargin{:});
            
            gui.utils.GUIUtils.updateStatus(obj.hStatusText, message, ...
                'AddTimestamp', false, ...
                'Severity', p.Results.Severity, ...
                'FlashMessage', p.Results.FlashMessage);
        end
        
        function updateStatusBarPosition(obj)
            % Update status bar position when window is resized
            gui.utils.GUIUtils.updateStatusBarLayout(obj.hFig, obj.hStatusBar);
            
            % Also update help button position
            if gui.utils.GUIUtils.isValidUIComponent(obj.helpButton)
                obj.helpButton.Position = [obj.hFig.Position(3)-70, 2, 60, 20];
            end
        end
        
        function showHelp(obj)
            % Display help dialog with usage instructions
            gui.handlers.UIEventHandlers.showHelpDialog();
        end

        function delete(obj)
            % Destructor to clean up figure
            if ishandle(obj.hFig)
                delete(obj.hFig);
            end
        end

        function updateZPosition(obj)
            % Update the current Z position value and display in the GUI
            try
                % Get current Z position from controller
                currentZ = obj.controller.getZ();
                
                % Update GUI display
                try
                    obj.updateCurrentZ(currentZ);
                catch ME
                    if obj.verbosity > 1
                        warning('Error updating Z display: %s', ME.message);
                    end
                end
            catch ME
                if obj.verbosity > 0
                    warning('Error updating Z position: %s', ME.message);
                end
            end
        end

        function updateCurrentZDisplay(obj)
            % Update the current Z position display in the GUI
            try
                currentZ = obj.controller.getZ();
                obj.updateCurrentZ(currentZ);
            catch ME
                warning('Error updating Z position display: %s', ME.message);
            end
        end

        function startSIFocus(obj)
            % Start Focus mode in ScanImage
            try
                % Make sure ScanImage is available
                hSI = obj.controller.hSI;
                if isempty(hSI) || ~isvalid(hSI)
                    obj.updateStatus('ScanImage handle not available. Cannot start Focus mode.');
                    return;
                end
                
                % Check if startFocus method exists (compatibility check)
                if ~ismethod(hSI, 'startFocus')
                    % Try alternative method
                    if isfield(hSI, 'hDisplay') && ismethod(hSI.hDisplay, 'startFocus')
                        hSI.hDisplay.startFocus();
                    elseif isfield(hSI, 'startLoop')
                        hSI.startLoop();
                    else
                        obj.updateStatus('Focus function not found in ScanImage. Check ScanImage version.');
                        return;
                    end
                else
                    hSI.startFocus();
                end
                
                obj.updateStatus('Started ScanImage Focus mode');
                
                % Start monitoring if not already active
                if ~obj.hMonitorToggle.Value
                    obj.hMonitorToggle.Value = true;
                    obj.monitorToggleChanged(true);
                end
            catch ME
                obj.updateStatus(sprintf('Error starting Focus: %s', ME.message));
            end
        end
        
        function grabSIFrame(obj)
            % Grab a single frame in ScanImage
            try
                % Make sure ScanImage is available
                hSI = obj.controller.hSI;
                if isempty(hSI) || ~isvalid(hSI)
                    obj.updateStatus('ScanImage handle not available. Cannot grab frame.');
                    return;
                end
                
                % Show abort button
                gui.utils.GUIUtils.setVisibility(obj.hFocusButton, false);
                gui.utils.GUIUtils.setVisibility(obj.hGrabButton, false);
                gui.utils.GUIUtils.setVisibility(obj.hAbortButton, true);
                
                % Stop Focus mode if it's running
                if isfield(hSI, 'acqState') && isfield(hSI.acqState, 'acquiringFocus') && hSI.acqState.acquiringFocus
                    hSI.abort();
                    pause(0.2); % Give time for focus to stop
                end
                
                % Check if startGrab method exists (compatibility check)
                if ~ismethod(hSI, 'startGrab') 
                    % Try alternative method
                    if isfield(hSI, 'hDisplay') && ismethod(hSI.hDisplay, 'startGrab')
                        hSI.hDisplay.startGrab();
                    elseif isfield(hSI, 'grab')
                        hSI.grab();
                    else
                        obj.updateStatus('Grab function not found in ScanImage. Check ScanImage version.');
                        return;
                    end
                else
                    hSI.startGrab();
                end
                
                obj.updateStatus('Grabbed ScanImage frame');
                
                % Wait for grab to complete
                pause(0.5);
                obj.updateStatus('Frame acquired');
                
                % Restore buttons
                gui.utils.GUIUtils.setVisibility(obj.hFocusButton, true);
                gui.utils.GUIUtils.setVisibility(obj.hGrabButton, true);
                gui.utils.GUIUtils.setVisibility(obj.hAbortButton, false);
            catch ME
                obj.updateStatus(sprintf('Error grabbing frame: %s', ME.message));
                
                % Restore buttons
                gui.utils.GUIUtils.setVisibility(obj.hFocusButton, true);
                gui.utils.GUIUtils.setVisibility(obj.hGrabButton, true);
                gui.utils.GUIUtils.setVisibility(obj.hAbortButton, false);
            end
        end
        
        function abortAllOperations(obj)
            % Abort all ongoing operations
            try
                % Stop scanning via controller
                obj.controller.scanner.stop();
                
                % Abort any ScanImage acquisition
                hSI = obj.controller.hSI;
                if ~isempty(hSI) && isvalid(hSI)
                    % Try different abort methods based on ScanImage version
                    if ismethod(hSI, 'abort')
                        hSI.abort();
                    elseif isfield(hSI, 'hScan2D') && ismethod(hSI.hScan2D, 'stop')
                        hSI.hScan2D.stop();
                    end
                end
                
                % Keep monitoring active for safety
                if ~obj.controller.monitor.isMonitoring
                    obj.controller.monitor.start();
                    obj.hMonitorToggle.Value = true;
                end
                
                obj.updateStatus('All operations aborted');
            catch ME
                obj.updateStatus(sprintf('Error during abort: %s', ME.message));
            end
        end

        function closeFigure(obj)
            % Handle figure close request
            try
                % Stop components safely via controller
                if isfield(obj.controller, 'monitor') && ~isempty(obj.controller.monitor)
                    try
                        obj.controller.monitor.stop();
                    catch
                        % Ignore errors when stopping monitor
                    end
                end
                
                if isfield(obj.controller, 'scanner') && ~isempty(obj.controller.scanner)
                    try
                        obj.controller.scanner.stop();
                    catch
                        % Ignore errors when stopping scanner
                    end
                end
                
                % Delete GUI safely
                if ishandle(obj.hFig)
                    delete(obj.hFig);
                end
                
                % Call the controller's delete method to clean up all resources
                try
                    delete(obj.controller);
                catch ME
                    warning('Error deleting controller: %s', ME.message);
                end
                
                % Allow for creating a new instance
                fprintf('FocalSweep GUI closed and resources cleaned up.\n');
            catch ME
                warning('Error closing figure: %s', ME.message);
            end
        end
    end
end 