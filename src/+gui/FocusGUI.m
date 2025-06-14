classdef FocusGUI < handle
    % FocusGUI - Creates and manages a minimal GUI for Z-control
    
    properties
        % Core properties
        controller        % Controller object for application logic
        
        % Main UI components
        hFig              % Main figure handle
        mainGrid          % Main grid layout
        
        % Control components
        hCurrentZLabel    % Current Z position display
        hZUpButton        % Z up button
        hZDownButton      % Z down button
        
        % ScanImage components
        hFocusButton      % Focus button
        hGrabButton       % Grab frame button
        hAbortButton      % Abort button
        
        % Status components
        hStatusText       % Status text label
        hStatusBar        % Status bar panel
    end

    properties (Access = private)
        focusModeActive = false  % Track if focus mode is active
        hasZData = false         % Track if we have Z position data
        previousZValue = 0       % Previous Z value for movement indicator
        statusUpdateTimer       % Timer for updating status bar position
    end

    methods
        function obj = FocusGUI(controller)
            % Constructor initializes controller
            % Wrap with adapter if controller is not already implementing the interface
            if ~isa(controller, 'gui.interfaces.ControllerInterface')
                obj.controller = gui.interfaces.ControllerAdapter(controller);
            else
                obj.controller = controller;
            end
        end

        function create(obj)
            % Create main figure and UI components using the factory pattern
            try
                % Create main figure
                obj.hFig = uifigure('Name', 'Z-Control', ...
                    'Position', [100 100 300 200], ...
                    'Color', core.AppConfig.UI_COLORS.Background, ...
                    'CloseRequestFcn', @(src,event) obj.closeFigure());
                
                % Create main grid layout
                mainGrid = uigridlayout(obj.hFig, [3, 1]);
                mainGrid.RowHeight = {'fit', 'fit', '1x'};
                mainGrid.ColumnWidth = {'1x'};
                mainGrid.Padding = [10 10 10 10];
                mainGrid.RowSpacing = 8;
                
                % Store main grid reference for later use
                obj.mainGrid = mainGrid;
                
                % --- Create Control Panel ---
                [~, controlPanel] = gui.components.UIComponentFactory.createModeTabGroup(mainGrid, 1, 1);
                
                % --- Create Z Controls ---
                manualComponents = gui.components.UIComponentFactory.createManualFocusTab(controlPanel, obj.controller);
                obj.hCurrentZLabel = manualComponents.CurrentZLabel;
                obj.hZUpButton = manualComponents.ZUpButton;
                obj.hZDownButton = manualComponents.ZDownButton;
                
                % --- Create ScanImage Controls ---
                siComponents = gui.components.UIComponentFactory.createScanImageControlPanel(mainGrid, 2, 1, obj.controller);
                obj.hFocusButton = siComponents.FocusButton;
                obj.hGrabButton = siComponents.GrabButton;
                obj.hAbortButton = siComponents.AbortButton;
                
                % --- Create Status Bar (directly in the figure, not in the grid) ---
                % Create a panel at the bottom of the figure for status
                obj.hStatusBar = uipanel(obj.hFig, ...
                    'Position', [0, 0, obj.hFig.Position(3), 24], ...
                    'BorderType', 'none', ...
                    'BackgroundColor', [0.9 0.9 0.95], ...
                    'AutoResizeChildren', 'off');
                
                obj.hStatusText = uilabel(obj.hStatusBar, ...
                    'Position', [10, 2, obj.hFig.Position(3)-20, 20], ...
                    'Text', 'Ready', ...
                    'FontSize', 10);
                
                % Create a timer for updating status bar position
                gui.GUIUtils.createStatusUpdateTimer(obj, obj.hFig, obj.hStatusBar, obj.hStatusText);
                
                % Set up keyboard shortcuts
                set(obj.hFig, 'KeyPressFcn', @(~,evt) obj.handleKeyPress(evt));
                
                % Show initial status message
                obj.updateStatus('Ready');
            catch ME
                warning('Error creating GUI: %s', ME.message);
                disp(getReport(ME));
            end
        end
        
        %% Event Handlers
        function toggleFocusMode(obj)
            % Toggle ScanImage focus mode
            try
                % Get the current state
                isActive = ~strcmp(obj.hFocusButton.Text, 'Focus');
                
                if isActive
                    % Currently active, so stop it
                    obj.controller.stopSIFocus();
                    obj.focusModeActive = false;
                    gui.GUIUtils.setUIProperty(obj.hFocusButton, 'Text', 'Focus');
                    obj.updateStatus('Focus mode stopped');
                else
                    % Currently inactive, so start it
                    obj.controller.startSIFocus();
                    obj.focusModeActive = true;
                    gui.GUIUtils.setUIProperty(obj.hFocusButton, 'Text', 'Stop Focus');
                    obj.updateStatus('Focus mode active');
                end
            catch ME
                obj.updateStatus(sprintf('Error toggling focus mode: %s', ME.message), 'error');
            end
        end
        
        function grabSIFrame(obj)
            % Grab a single frame in ScanImage
            try
                obj.controller.grabSIFrame();
                obj.updateStatus('Grabbed frame');
            catch ME
                obj.updateStatus(sprintf('Error grabbing frame: %s', ME.message), 'error');
            end
        end
        
        function abortOperation(obj)
            % Abort all ongoing operations
            try
                % Try to abort any operations
                try
                    obj.controller.abortAllOperations();
                catch
                    % If abortAllOperations doesn't exist, try individual abort operations
                    try
                        obj.controller.stopSIFocus();
                    catch
                        % Ignore errors
                    end
                end
                
                obj.updateStatus('Operations aborted');
            catch ME
                obj.updateStatus(sprintf('Error aborting operations: %s', ME.message), 'error');
            end
        end
        
        function updateStatus(obj, message, messageType)
            % Update status text with optional type-based styling
            if nargin < 3
                messageType = 'info';
            end
            
            try
                gui.GUIUtils.updateStatusBar(obj.hStatusBar, obj.hStatusText, message, messageType);
            catch
                % Silently handle errors to prevent breaking the UI
            end
        end
        
        function updateZPosition(obj)
            % Update the current Z position display
            try
                currentZ = obj.controller.getZ();
                newText = sprintf('Current Z: %.2f', currentZ);
                
                % Update movement indicator
                if obj.hasZData
                    if currentZ > obj.previousZValue
                        newText = [newText ' ↑'];
                    elseif currentZ < obj.previousZValue
                        newText = [newText ' ↓'];
                    end
                end
                
                gui.GUIUtils.setUIProperty(obj.hCurrentZLabel, 'Text', newText);
                obj.previousZValue = currentZ;
                obj.hasZData = true;
            catch ME
                obj.updateStatus(sprintf('Error updating Z position: %s', ME.message), 'warning');
            end
        end
        
        function updatePlot(obj)
            % Placeholder for updatePlot method - will be implemented later
            % This stub exists to maintain API compatibility
        end
        
        function closeFigure(obj)
            % Handle figure close request
            try
                % Stop any active operations
                obj.abortOperation();
                
                % Clean up the status update timer
                core.CoreUtils.cleanupTimer(obj.statusUpdateTimer);
                
                % Close the figure
                if ~isempty(obj.hFig) && isvalid(obj.hFig)
                    delete(obj.hFig);
                end
            catch ME
                warning('Error closing figure: %s', ME.message);
                % Force close if needed
                if ~isempty(obj.hFig) && isvalid(obj.hFig)
                    delete(obj.hFig);
                end
            end
        end
        
        function handleKeyPress(obj, evt)
            % Handle keyboard shortcuts
            switch evt.Key
                case 'uparrow'
                    obj.controller.moveZUp();
                case 'downarrow'
                    obj.controller.moveZDown();
            end
        end
    end
end 
end 