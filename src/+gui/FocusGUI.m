classdef FocusGUI < handle
    % FocusGUI - Creates and manages the modern GUI for FocalSweep
    % Inspired by modern React-based UI with enhanced styling and functionality
    %
    % This class has been refactored to use helper classes:
    % - gui.components.UIComponentFactory: For creating UI components
    % - gui.handlers.UIEventHandlers: For handling UI events

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
    end

    methods
        function obj = FocusGUI(controller)
            obj.controller = controller;
        end

        function create(obj)
            % Create main figure with modern styling
            fprintf('Creating FocalSweep GUI...\n');
            obj.hFig = uifigure('Name', 'FocalSweep - Find optimal focus position', ...
                'Position', [100 100 900 600], ...  % Reduced height from 700 to 600
                'Color', [0.95 0.95 0.98], ...
                'CloseRequestFcn', @(~,~) obj.controller.closeFigure(), ...
                'Resize', 'on');
            
            % Check if we're running in a compatible MATLAB version
            hasNewUIControls = ~verLessThan('matlab', '9.8'); % R2020a or newer
            if ~hasNewUIControls
                fprintf('Warning: Running on an older MATLAB version. Some UI features may be limited.\n');
            end

            % Create a more compact grid layout
            mainGrid = uigridlayout(obj.hFig, [3, 2]);  % Reduced from 4 to 3 rows by combining instruction with params
            mainGrid.RowHeight = {'fit', '1x', '0.4x'};  % Use proportional units
            mainGrid.ColumnWidth = {'1.2x', '1x'};  % Use proportional units
            mainGrid.Padding = [10 10 10 10];  % Reduced padding
            mainGrid.RowSpacing = 8;  % Reduced spacing
            mainGrid.ColumnSpacing = 10;  % Reduced spacing
            
            % --- Parameters Panel with Instructions (Row 1, Col 1-2) ---
            paramContainer = uipanel(mainGrid, 'BorderType', 'none', 'BackgroundColor', [0.95 0.95 0.98]);
            paramContainer.Layout.Row = 1;
            paramContainer.Layout.Column = [1 2];
            
            paramGrid = uigridlayout(paramContainer, [1, 2]);
            paramGrid.RowHeight = {'fit'};
            paramGrid.ColumnWidth = {'1.2x', '1x'};
            paramGrid.Padding = [0 0 0 0];
            paramGrid.ColumnSpacing = 10;
            
            % --- Scan Parameters Panel (Row 1, Col 1 of paramGrid) ---
            paramPanel = gui.components.UIComponentFactory.createStyledPanel(paramGrid, 'Scan Parameters', 1, 1);
            
            % --- Z Movement Controls Panel (Row 1, Col 2 of paramGrid) ---
            zControlPanel = gui.components.UIComponentFactory.createStyledPanel(paramGrid, 'Z Movement Controls', 1, 2);
            
            % --- Plot Area (Row 2, Col 1:2) ---
            plotPanel = gui.components.UIComponentFactory.createStyledPanel(mainGrid, 'Brightness vs. Z-Position', 2, [1 2]);
            
            % Create plot area with component factory
            obj.hAx = gui.components.UIComponentFactory.createPlotPanel(plotPanel);

            % --- Actions Panel (Row 3, Col 1:2) ---
            actionPanel = gui.components.UIComponentFactory.createStyledPanel(mainGrid, 'Control Actions', 3, [1 2]);
            
            % Now create all panels and components
            [obj.hStepSizeSlider, obj.hStepSizeValue, obj.hPauseTimeEdit, obj.hMetricDropDown, obj.hMinZEdit, obj.hMaxZEdit] = ...
                gui.components.UIComponentFactory.createScanParametersPanel(paramPanel, paramPanel, obj.controller);
                
            obj.hCurrentZLabel = gui.components.UIComponentFactory.createZControlPanel(zControlPanel, zControlPanel, obj.controller);
            
            [obj.hMonitorToggle, obj.hZScanToggle, obj.hFocusButton, obj.hGrabButton, obj.hAbortButton, obj.hMoveToMaxButton] = ...
                gui.components.UIComponentFactory.createActionPanel(actionPanel, actionPanel, obj.controller);
                
            % Set up event handlers
            obj.hStepSizeSlider.ValueChangingFcn = @(src,event) obj.updateStepSizeValueDisplay(event.Value);
            obj.hStepSizeSlider.ValueChangedFcn = @(src,event) obj.controller.updateStepSizeImmediate(event.Value);
            obj.hMonitorToggle.ValueChangedFcn = @(src,~) obj.controller.toggleMonitor(src.Value);
            obj.hZScanToggle.ValueChangedFcn = @(src,~) obj.toggleScanButtons(src.Value);
            
            % The focus button callback needs to be set here because we're not using the factory's built-in callback
            obj.hFocusButton.ButtonPushedFcn = @(~,~) obj.toggleFocusMode();
            obj.hGrabButton.ButtonPushedFcn = @(~,~) obj.controller.grabSIFrame();
            obj.hAbortButton.ButtonPushedFcn = @(~,~) obj.abortOperation();
            
            % Add min/max Z change callbacks to update Auto Z-Scan button state
            obj.hMinZEdit.ValueChangedFcn = @(~,~) obj.updateButtonStates();
            obj.hMaxZEdit.ValueChangedFcn = @(~,~) obj.updateButtonStates();

            % --- Status Bar ---
            [obj.hStatusText, obj.hStatusBar] = gui.components.UIComponentFactory.createStatusBar(obj.hFig);
            
            % Set up figure resize callback
            obj.hFig.AutoResizeChildren = 'off';  % Disable auto resize before setting SizeChangedFcn
            obj.hFig.SizeChangedFcn = @(~,~) obj.updateStatusBarPosition();
            
            % Initialize button states
            obj.updateButtonStates();
        end
        
        function toggleFocusMode(obj)
            % Toggle focus mode and update UI
            obj.focusModeActive = ~obj.focusModeActive;
            
            if obj.focusModeActive
                % Start focus mode in ScanImage
                obj.controller.startSIFocus();
                
                % Show abort button instead of focus/grab buttons
                obj.hFocusButton.Visible = 'off';
                obj.hGrabButton.Visible = 'off';
                obj.hAbortButton.Visible = 'on';
                
                % Update Z-scan button state
                obj.updateButtonStates();
                
                % Start monitoring if not already active
                if ~obj.hMonitorToggle.Value
                    obj.hMonitorToggle.Value = true;
                    obj.controller.toggleMonitor(true);
                end
            else
                % Reset UI
                obj.hFocusButton.Visible = 'on';
                obj.hGrabButton.Visible = 'on';
                obj.hAbortButton.Visible = 'off';
                
                % Update Z-scan button state
                obj.updateButtonStates();
            end
        end
        
        function updateButtonStates(obj)
            % Update enabled/disabled state of buttons based on conditions
            
            % Auto Z-Scan should be enabled only when:
            % 1. Min and Max Z are set
            % 2. Focus mode is active
            minZValid = ~isempty(obj.hMinZEdit.Value) && ~isnan(obj.hMinZEdit.Value);
            maxZValid = ~isempty(obj.hMaxZEdit.Value) && ~isnan(obj.hMaxZEdit.Value);
            rangeValid = minZValid && maxZValid && (obj.hMaxZEdit.Value > obj.hMinZEdit.Value);
            
            if rangeValid && obj.focusModeActive
                obj.hZScanToggle.Enable = 'on';
            else
                obj.hZScanToggle.Enable = 'off';
            end
            
            % Move to Max Focus should be enabled only when we have Z data
            if obj.hasZData
                obj.hMoveToMaxButton.Enable = 'on';
            else
                obj.hMoveToMaxButton.Enable = 'off';
            end
        end
        
        function updateStepSizeValueDisplay(obj, value)
            % Update step size value display immediately during slider movement
            gui.handlers.UIEventHandlers.updateStepSizeValueDisplay(obj.hStepSizeValue, value);
        end

        function toggleScanButtons(obj, isScanActive)
            % Toggle between scan control buttons and abort button
            gui.handlers.UIEventHandlers.toggleScanButtons(isScanActive, obj.controller, ...
                obj.hFocusButton, obj.hGrabButton, obj.hAbortButton, obj.hZScanToggle, ...
                obj.hStepSizeSlider, obj.hPauseTimeEdit, obj.hMetricDropDown);
        end
        
        function abortOperation(obj)
            % Handle abort button press
            gui.handlers.UIEventHandlers.abortOperation(obj.controller, obj.hZScanToggle, obj.hStatusText);
            
            % Reset focus mode
            obj.focusModeActive = false;
            obj.hFocusButton.Visible = 'on';
            obj.hGrabButton.Visible = 'on';
            obj.hAbortButton.Visible = 'off';
            
            % Update button states
            obj.updateButtonStates();
        end

        function updatePlot(obj, zData, bData, activeChannel)
            % Update the brightness vs Z-position plot with visual markers
            gui.handlers.UIEventHandlers.updatePlot(obj.hAx, zData, bData, activeChannel);
            
            % Update hasZData flag based on data
            obj.hasZData = ~isempty(zData) && length(zData) > 1;
            
            % Update Move to Max button state
            obj.updateButtonStates();
        end
        
        function updateCurrentZ(obj, zValue)
            % Update current Z position display
            gui.handlers.UIEventHandlers.updateCurrentZ(obj.hCurrentZLabel, zValue);
        end

        function updateStatus(obj, message)
            % Update status text
            gui.handlers.UIEventHandlers.updateStatus(obj.hStatusText, message);
        end
        
        function updateStatusBarPosition(obj)
            % Update status bar position when window is resized
            gui.handlers.UIEventHandlers.updateStatusBarPosition(obj.hFig, obj.hStatusBar);
        end
        
        function showHelp(obj)
            % Display help dialog with usage instructions
            gui.handlers.UIEventHandlers.showHelp();
        end

        function delete(obj)
            % Destructor to clean up figure
            if ishandle(obj.hFig)
                delete(obj.hFig);
            end
        end
    end
end 