classdef FocusGUI < handle
    % FocusGUI - Creates and manages the GUI for FocalSweep Z-focusing
    % Uses the updated component architecture with:
    % - TabGroup for mode separation (Manual/Auto focus)
    % - Collapsible plot panel
    % - Factory pattern for component creation
    % - Handler pattern for event processing
    % - Utility functions for common operations

    properties
        % Core properties
        controller        % Controller object for application logic (implements ControllerInterface)
        layoutManager     % Responsive layout manager
        mainGrid          % Main grid layout
        verbosity = 1     % Verbosity level for logging
        
        % Main UI components
        hFig              % Main figure handle
        tabGroup          % Mode TabGroup
        manualTab         % Manual focus tab
        autoTab           % Auto focus tab
        
        % Plot components
        hAx               % Plot axes handle
        plotToggleButton  % Plot visibility toggle button
        plotPanel         % Plot panel for showing/hiding 
        isPlotExpanded = true % Track if plot panel is expanded
        
        % Manual focus components
        hCurrentZLabel    % Current Z position display
        hMonitorToggle    % Monitor toggle button
        
        % Auto focus components
        hStepSizeSlider   % Step size slider
        hStepSizeValue    % Step size display
        hPauseTimeEdit    % Pause time edit field
        hMetricDropDown   % Metric dropdown
        hMinZEdit         % Min Z edit field
        hMaxZEdit         % Max Z edit field
        hZScanToggle      % Z-scan toggle button
        hMoveToMaxButton  % Move to max button
        
        % ScanImage components
        hFocusButton      % Focus button
        hGrabButton       % Grab frame button
        hAbortButton      % Abort button
        
        % Status components
        hStatusText       % Status text label
        hStatusBar        % Status bar panel
        helpButton        % Help button
    end

    properties (Access = private)
        focusModeActive = false  % Track if focus mode is active
        hasZData = false         % Track if we have Z position data
        previousZValue = 0       % Previous Z value for movement indicator
    end

    methods
        function obj = FocusGUI(controller)
            % Constructor initializes controller and verbosity
            % Wrap with adapter if controller is not already implementing the interface
            if ~isa(controller, 'gui.interfaces.ControllerInterface')
                obj.controller = gui.interfaces.ControllerAdapter(controller);
            else
                obj.controller = controller;
            end
            
            % Inherit verbosity from controller if available
            try
                if isfield(controller, 'verbosity')
                    obj.verbosity = controller.verbosity;
                end
            catch
                % Use default verbosity (0) if not available
            end
        end

        function create(obj)
            % Create main figure and UI components using the factory pattern
            if obj.verbosity > 0
                fprintf('Creating FocalSweep GUI...\n');
            end
            
            try
                % Create main figure
                obj.hFig = uifigure('Name', 'FocalSweep - Automated Z-Focus Finder', ...
                    'Position', [100 100 850 600], ...  % Reduced size from 950x700
                    'Color', [0.95 0.95 0.98], ...
                    'CloseRequestFcn', @(~,~) obj.closeFigure(), ...
                    'Resize', 'on');
                
                % Check MATLAB version for compatibility
                hasNewUIControls = ~verLessThan('matlab', '9.8'); % R2020a or newer
                if ~hasNewUIControls && obj.verbosity > 0
                    fprintf('Warning: Running on an older MATLAB version. Some UI features may be limited.\n');
                end

                % Create main grid layout
                mainGrid = uigridlayout(obj.hFig, [3, 2]);
                mainGrid.RowHeight = {'fit', '1x', 'fit'};
                mainGrid.ColumnWidth = {'1.5x', '1x'};  % Changed from 1.7x to 1.5x
                mainGrid.Padding = [10 10 10 10];       % Reduced from 20 20 20 20
                mainGrid.RowSpacing = 8;                % Reduced from 18
                mainGrid.ColumnSpacing = 10;            % Reduced from 20
                
                % Store main grid reference for later use
                obj.mainGrid = mainGrid;
                
                % --- Create TabGroup for Focus Modes ---
                obj.tabGroup = gui.components.UIComponentFactory.createModeTabGroup(mainGrid, [1 2], 1);
                
                % --- Create Manual Focus Tab ---
                obj.manualTab = gui.components.UIComponentFactory.createModeTab(obj.tabGroup, 'Manual Focus');
                manualComponents = gui.components.UIComponentFactory.createManualFocusTab(obj.manualTab, obj.controller);
                obj.hCurrentZLabel = manualComponents.CurrentZLabel;
                obj.hMonitorToggle = manualComponents.MonitorToggle;
                
                % --- Create Auto Focus Tab ---
                obj.autoTab = gui.components.UIComponentFactory.createModeTab(obj.tabGroup, 'Auto Focus');
                autoComponents = gui.components.UIComponentFactory.createAutoFocusTab(obj.autoTab, obj.controller);
                obj.hStepSizeSlider = autoComponents.StepSizeSlider;
                obj.hStepSizeValue = autoComponents.StepSizeValue;
                obj.hPauseTimeEdit = autoComponents.PauseTimeEdit;
                obj.hMetricDropDown = autoComponents.MetricDropDown;
                obj.hMinZEdit = autoComponents.MinZEdit;
                obj.hMaxZEdit = autoComponents.MaxZEdit;
                obj.hZScanToggle = autoComponents.ZScanToggle;
                obj.hMoveToMaxButton = autoComponents.MoveToMaxButton;
                
                % --- Create Collapsible Plot Panel ---
                [~, obj.hAx, obj.plotToggleButton, obj.plotPanel] = gui.components.UIComponentFactory.createCollapsiblePlotPanel(mainGrid, [1 2], 2);
                
                % --- Create ScanImage Controls ---
                siComponents = gui.components.UIComponentFactory.createScanImageControlPanel(mainGrid, 3, [1 2], obj.controller);
                obj.hFocusButton = siComponents.FocusButton;
                obj.hGrabButton = siComponents.GrabButton;
                obj.hAbortButton = siComponents.AbortButton;
                
                % --- Create Status Bar ---
                [obj.hStatusText, obj.hStatusBar] = gui.components.UIComponentFactory.createStatusBar(obj.hFig);
                
                % Improve status bar visibility
                obj.hStatusBar.BackgroundColor = [0.9 0.9 0.95];
                
                % Add Help button to status bar
                obj.helpButton = uibutton(obj.hStatusBar, ...
                    'Text', '❓ Help', ...
                    'Position', [obj.hFig.Position(3)-70, 2, 60, 20], ...
                    'BackgroundColor', [0.9 0.9 0.95], ...
                    'FontSize', 10, ...
                    'ButtonPushedFcn', @(~,~) obj.showHelp());
                
                % Set up event handlers
                obj.setupEventHandlers();
                
                % Register plot container with layout manager
                plotContainer = findobj(obj.hFig, 'Type', 'uipanel', 'Tag', 'PlotContainer');
                if isempty(plotContainer)
                    % If not tagged yet, find plot panel containing axes
                    plotContainer = obj.plotPanel;
                    if ~isempty(plotContainer)
                        plotContainer.Tag = 'PlotContainer';
                    end
                end
                
                if ~isempty(plotContainer) && ~isempty(obj.layoutManager)
                    obj.layoutManager.registerPlotContainer(plotContainer, obj.isPlotExpanded);
                end
                
                % Initialize UI state
                obj.updateButtonStates();
                
                % Default to Manual Focus tab
                obj.tabGroup.SelectedTab = obj.manualTab;
                
                % Add tab change callback
                obj.tabGroup.SelectionChangedFcn = @(src,~) obj.tabChanged(src);
                
                % Show initial status message
                obj.updateStatus('Ready - Select Manual or Auto Focus tab to begin');
            catch ME
                if obj.verbosity > 0
                    warning('Error creating GUI: %s', ME.message);
                    disp(getReport(ME));
                end
            end
        end
        
        function setupEventHandlers(obj)
            % Set up all event handlers and callbacks
            try
                % Control event handlers
                obj.hStepSizeSlider.ValueChangingFcn = @(src,event) obj.updateStepSizeValueDisplay(event.Value);
                obj.hStepSizeSlider.ValueChangedFcn = @(src,event) obj.controller.updateStepSizeImmediate(event.Value);
                obj.hMonitorToggle.ValueChangedFcn = @(src,~) obj.monitorToggleChanged(src.Value);
                obj.hZScanToggle.ValueChangedFcn = @(src,~) obj.toggleScanButtons(src.Value);
                obj.hMoveToMaxButton.ButtonPushedFcn = @(~,~) obj.moveToMaxBrightness();
                
                % ScanImage control handlers
                obj.hFocusButton.ValueChangedFcn = @(src,~) obj.toggleFocusMode(src.Value);
                obj.hGrabButton.ValueChangedFcn = @(src,~) obj.grabSIFrame(src);
                obj.hAbortButton.ButtonPushedFcn = @(~,~) obj.abortOperation();
                
                % Z limit change handlers
                obj.hMinZEdit.ValueChangedFcn = @(~,~) obj.updateButtonStates();
                obj.hMaxZEdit.ValueChangedFcn = @(~,~) obj.updateButtonStates();
                
                % Plot toggle handler
                obj.plotToggleButton.ButtonPushedFcn = @(~,~) obj.togglePlotVisibility();
                
                % Create responsive layout manager
                obj.layoutManager = gui.utils.ResponsiveLayoutManager(obj.hFig);
                obj.layoutManager.registerStatusBar(obj.hStatusBar, obj.helpButton);
            catch ME
                if obj.verbosity > 0
                    warning('Error setting up event handlers: %s', ME.message);
                end
            end
        end
        
        function tabChanged(obj, tabGroup)
            % Handle tab selection changed event
            try
                % Create UI struct for handlers
                ui = struct(...
                    'StatusText', obj.hStatusText, ...
                    'MinZEdit', obj.hMinZEdit, ...
                    'MaxZEdit', obj.hMaxZEdit, ...
                    'ZScanToggle', obj.hZScanToggle, ...
                    'MonitorToggle', obj.hMonitorToggle);
                
                % Use the event handler to process tab change
                gui.handlers.UIEventHandlers.handleTabChanged(tabGroup, obj.controller, ui);
            catch ME
                if obj.verbosity > 0
                    warning('Error handling tab change: %s', ME.message);
                end
            end
        end

        %% Event Handlers
        function monitorToggleChanged(obj, isActive)
            % Handle monitor toggle state change
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
        
        function toggleFocusMode(obj, isActive)
            % Toggle focus mode in ScanImage
            obj.focusModeActive = isActive;
            
            if obj.focusModeActive
                % Start focus mode in ScanImage
                obj.startSIFocus();
                
                % Show abort button instead of grab button
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
                % Stop focus in ScanImage
                try
                    % Try to stop focus mode in ScanImage
                    if isfield(obj.controller, 'hSI') && ~isempty(obj.controller.hSI) && ...
                       isfield(obj.controller.hSI, 'acqState') && ...
                       isfield(obj.controller.hSI.acqState, 'acquiringFocus') && ...
                       obj.controller.hSI.acqState.acquiringFocus
                        obj.controller.hSI.abort();
                    end
                catch
                    % Ignore errors when stopping focus
                end
                
                % Reset UI
                gui.utils.GUIUtils.setVisibility(obj.hGrabButton, true);
                gui.utils.GUIUtils.setVisibility(obj.hAbortButton, false);
                
                % Update status
                obj.updateStatus('Focus mode stopped');
                
                % Update Z-scan button state
                obj.updateButtonStates();
            end
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
        
        function moveToMaxBrightness(obj)
            % Move to max brightness with visual feedback
            obj.updateStatus('Moving to position of maximum brightness...', Severity="info");
            obj.controller.moveToMaxBrightness();
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
        
        function grabSIFrame(obj, btnHandle)
            % Grab a single frame in ScanImage using state button
            try
                % Make sure ScanImage is available
                hSI = obj.controller.hSI;
                if isempty(hSI) || ~isvalid(hSI)
                    obj.updateStatus('ScanImage handle not available. Cannot grab frame.');
                    if nargin > 1 && isobject(btnHandle) && isvalid(btnHandle)
                        btnHandle.Value = false; % Reset button state
                    end
                    return;
                end
                
                % Show abort button
                gui.utils.GUIUtils.setVisibility(obj.hFocusButton, false);
                gui.utils.GUIUtils.setVisibility(obj.hAbortButton, true);
                
                % Stop Focus mode if it's running
                if isfield(hSI, 'acqState') && isfield(hSI.acqState, 'acquiringFocus') && hSI.acqState.acquiringFocus
                    hSI.abort();
                    pause(0.2); % Give time for focus to stop
                    
                    % Update focus button state if it was on
                    if obj.hFocusButton.Value
                        obj.hFocusButton.Value = false;
                        obj.focusModeActive = false;
                    end
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
                        if nargin > 1 && isobject(btnHandle) && isvalid(btnHandle)
                            btnHandle.Value = false; % Reset button state
                        end
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
                gui.utils.GUIUtils.setVisibility(obj.hAbortButton, false);
                
                % Reset grab button state after acquisition completes
                if nargin > 1 && isobject(btnHandle) && isvalid(btnHandle)
                    btnHandle.Value = false;
                end
            catch ME
                obj.updateStatus(sprintf('Error grabbing frame: %s', ME.message));
                
                % Restore buttons
                gui.utils.GUIUtils.setVisibility(obj.hFocusButton, true);
                gui.utils.GUIUtils.setVisibility(obj.hAbortButton, false);
                
                % Reset grab button state
                if nargin > 1 && isobject(btnHandle) && isvalid(btnHandle)
                    btnHandle.Value = false;
                end
            end
        end
        
        function togglePlotVisibility(obj)
            % Toggle plot panel visibility
            try
                % Toggle the expanded state
                obj.isPlotExpanded = ~obj.isPlotExpanded;
                
                % Get the main grid layout
                mainGrid = findobj(obj.hFig.Children, 'Type', 'uigridlayout');
                if isempty(mainGrid)
                    warning('Could not find main grid layout');
                    return;
                end
                
                % If multiple grid layouts are found, use the first one (main grid)
                if length(mainGrid) > 1
                    mainGrid = mainGrid(1);
                end
                
                % Update toggle button appearance
                if obj.isPlotExpanded
                    obj.plotToggleButton.Text = '◀';
                    obj.plotToggleButton.Tooltip = 'Hide plot panel';
                else
                    obj.plotToggleButton.Text = '▶';
                    obj.plotToggleButton.Tooltip = 'Show plot panel';
                end
                
                % Use the handler to toggle visibility
                gui.handlers.UIEventHandlers.togglePlotVisibility(mainGrid, obj.plotToggleButton, obj.isPlotExpanded, obj.plotPanel);
                
                % Update layout manager
                if ~isempty(obj.layoutManager)
                    obj.layoutManager.setPlotExpandedState(obj.isPlotExpanded);
                end
            catch ME
                warning('Error toggling plot visibility: %s', ME.message);
            end
        end
        
        %% UI Update Methods
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
            try
                % Make sure the status text component exists
                if ~isfield(obj, 'hStatusText') || isempty(obj.hStatusText)
                    % Just print to console if no status text exists
                    fprintf('Status: %s\n', message);
                    return;
                end
                
                p = inputParser;
                p.addOptional('Severity', 'info', @ischar);
                p.addOptional('FlashMessage', false, @islogical);
                p.parse(varargin{:});
                
                gui.utils.GUIUtils.updateStatus(obj.hStatusText, message, ...
                    'AddTimestamp', false, ...
                    'Severity', p.Results.Severity, ...
                    'FlashMessage', p.Results.FlashMessage);
            catch
                % If anything fails, just print to console
                fprintf('Status: %s\n', message);
            end
        end
        
        function updateStatusBarPosition(obj)
            % This method is kept for backward compatibility
            % Use layout manager to handle positioning now
            try
                if ~isempty(obj.layoutManager)
                    % No-op - layout manager handles this
                else
                    % Fall back to old method for backward compatibility
                    gui.utils.GUIUtils.updateStatusBarLayout(obj.hFig, obj.hStatusBar);
                    
                    % Also update help button position
                    if gui.utils.GUIUtils.isValidUIComponent(obj.helpButton)
                        obj.helpButton.Position = [obj.hFig.Position(3)-70, 2, 60, 20];
                    end
                end
            catch
                % Silently ignore errors
            end
        end
        
        %% ScanImage Methods
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
        
        %% Utility Methods
        function showHelp(obj)
            % Display help dialog with usage instructions
            gui.handlers.UIEventHandlers.showHelpDialog();
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
                
                % Delete GUI figure safely
                if ishandle(obj.hFig)
                    delete(obj.hFig);
                end
                
                fprintf('FocalSweep GUI closed.\n');
            catch ME
                warning('Error closing figure: %s', ME.message);
            end
        end
        
        function delete(obj)
            % Destructor to clean up figure
            if ishandle(obj.hFig)
                delete(obj.hFig);
            end
            if obj.verbosity > 1
                fprintf('FocalSweep GUI closed.\n');
            end
        end
    end
end 