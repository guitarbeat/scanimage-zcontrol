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
            fprintf('Creating minimal Z-Control GUI...\n');
            
            try
                % Create main figure
                obj.hFig = uifigure('Name', 'Z-Control', ...
                    'Position', [100 100 300 200], ...
                    'Color', [0.95 0.95 0.98], ...
                    'CloseRequestFcn', @(~,~) obj.closeFigure());
                
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
                
                % Use a timer for updating status bar position instead of SizeChangedFcn
                % This avoids the warning about SizeChangedFcn and AutoResizeChildren
                t = timer('ExecutionMode', 'fixedRate', ...
                          'Period', 0.5, ...
                          'TimerFcn', @(~,~) obj.updateStatusBarPosition());
                start(t);
                
                % Store the timer in a property so we can stop it when closing
                obj.statusUpdateTimer = t;
                
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
                    obj.hFocusButton.Text = 'Focus';
                    obj.updateStatus('Focus mode stopped');
                else
                    % Currently inactive, so start it
                    obj.controller.startSIFocus();
                    obj.focusModeActive = true;
                    obj.hFocusButton.Text = 'Stop Focus';
                    obj.updateStatus('Focus mode active');
                end
            catch ME
                obj.updateStatus(sprintf('Error toggling focus mode: %s', ME.message));
            end
        end
        
        function grabSIFrame(obj)
            % Grab a single frame in ScanImage
            try
                obj.controller.grabSIFrame();
                obj.updateStatus('Grabbed frame');
            catch ME
                obj.updateStatus(sprintf('Error grabbing frame: %s', ME.message));
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
                obj.updateStatus(sprintf('Error aborting operations: %s', ME.message));
            end
        end
        
        function updateStatus(obj, message)
            % Update status text
            try
                obj.hStatusText.Text = message;
                drawnow;
            catch ME
                % Silently handle errors to prevent breaking the UI
                fprintf('Status update error: %s\n', ME.message);
            end
        end
        
        function updateZPosition(obj)
            % Update the current Z position display
            try
                currentZ = obj.controller.getZ();
                obj.hCurrentZLabel.Text = sprintf('Current Z: %.2f', currentZ);
                
                % Update movement indicator
                if obj.hasZData
                    if currentZ > obj.previousZValue
                        obj.hCurrentZLabel.Text = [obj.hCurrentZLabel.Text ' ↑'];
                    elseif currentZ < obj.previousZValue
                        obj.hCurrentZLabel.Text = [obj.hCurrentZLabel.Text ' ↓'];
                    end
                end
                
                obj.previousZValue = currentZ;
                obj.hasZData = true;
            catch ME
                warning('Error updating Z position: %s', ME.message);
            end
        end
        
        function closeFigure(obj)
            % Handle figure close request
            try
                % Stop any active operations
                obj.abortOperation();
                
                % Stop and delete the status update timer
                if ~isempty(obj.statusUpdateTimer) && isvalid(obj.statusUpdateTimer)
                    stop(obj.statusUpdateTimer);
                    delete(obj.statusUpdateTimer);
                end
                
                % Close the figure
                delete(obj.hFig);
            catch ME
                warning('Error closing figure: %s', ME.message);
                % Force close if needed
                if ishandle(obj.hFig)
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
        
        function updateStatusBarPosition(obj)
            % Update status bar position when figure is resized
            if ~isempty(obj.hStatusBar) && isvalid(obj.hStatusBar)
                obj.hStatusBar.Position = [0, 0, obj.hFig.Position(3), 24];
                
                if ~isempty(obj.hStatusText) && isvalid(obj.hStatusText)
                    obj.hStatusText.Position = [10, 2, obj.hFig.Position(3)-20, 20];
                end
            end
        end
    end
end 