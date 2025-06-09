classdef BrightnessZControlGUIv3 < handle
    % BrightnessZControlGUIv3 - Creates and manages the modern GUI for Brightness Z-Control
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
        hCurrentZLabel    % Current Z position label
        hStatusBar        % Status bar panel
    end

    properties (Access = private)
        controller        % Handle to the main controller
    end

    methods
        function obj = BrightnessZControlGUIv3(controller)
            obj.controller = controller;
        end

        function create(obj)
            % Create main figure with modern styling
            fprintf('Creating modern Brightness Z-Control GUI v3...\n');
            obj.hFig = uifigure('Name', 'Brightness Z-Control v3 - Find optimal focus position', ...
                'Position', [100 100 900 700], ...  % Make slightly taller for instruction panel
                'Color', [0.95 0.95 0.98], ...
                'CloseRequestFcn', @(~,~) obj.controller.closeFigure(), ...
                'Resize', 'on');
            
            % Check if we're running in a compatible MATLAB version
            hasNewUIControls = ~verLessThan('matlab', '9.8'); % R2020a or newer
            if ~hasNewUIControls
                fprintf('Warning: Running on an older MATLAB version. Some UI features may be limited.\n');
            end
            
            fprintf('Creating modern layout...\n');

            % Create a modern grid layout with better spacing and organization
            mainGrid = uigridlayout(obj.hFig, [4, 2]);  % Added an extra row for instructions
            mainGrid.RowHeight = {'fit', 'fit', '1x', 'fit'};
            mainGrid.ColumnWidth = {'1.2x', '1x'};
            mainGrid.Padding = [15 15 15 15];
            mainGrid.RowSpacing = 10;
            mainGrid.ColumnSpacing = 15;
            
            % --- Quick Start Instructions Panel (Row 1, Col 1:2) ---
            instructPanel = gui.components.UIComponentFactory.createStyledPanel(mainGrid, '💡 HOW TO FIND FOCUS - Quick Start Guide', 1, [1 2]);
            instructGrid = uigridlayout(instructPanel, [1, 1]);
            instructGrid.Padding = [10 10 10 10];
            
            % Create instructions using component factory
            gui.components.UIComponentFactory.createInstructionPanel(instructPanel, instructGrid);

            % --- Scan Parameters Panel (Row 2, Col 1) ---
            paramPanel = gui.components.UIComponentFactory.createStyledPanel(mainGrid, 'Scan Parameters', 2, 1);
            
            % Create step size slider
            obj.hStepSizeSlider = uislider(uipanel(), ...
                'Limits', [1 50], 'Value', obj.controller.initialStepSize, ...
                'MajorTicks', [1 8 15 22 29 36 43 50], ...
                'MinorTicks', [], ...
                'Tooltip', 'Set the Z scan step size (µm)', ...
                'ValueChangingFcn', @(src,event) obj.updateStepSizeValueDisplay(event.Value), ...
                'ValueChangedFcn', @(src,event) obj.controller.updateStepSizeImmediate(event.Value));
                
            % Create value label for step size
            obj.hStepSizeValue = uilabel(uipanel());
            
            % Create edit fields
            obj.hPauseTimeEdit = uieditfield(uipanel(), 'numeric');
            obj.hMetricDropDown = uidropdown(uipanel(), ...
                'Items', {'Mean', 'Median', 'Max', '95th Percentile'}, ...
                'Tooltip', 'Select brightness metric', ...
                'FontSize', 12, ...
                'BackgroundColor', [1 1 1], ...
                'Value', 'Mean');
            obj.hMinZEdit = uieditfield(uipanel(), 'numeric');
            obj.hMaxZEdit = uieditfield(uipanel(), 'numeric');
            
            % Create scan parameters panel with component factory
            gui.components.UIComponentFactory.createScanParametersPanel(paramPanel, paramPanel, obj.controller, ...
                obj.hStepSizeSlider, obj.hStepSizeValue, obj.hPauseTimeEdit, obj.hMetricDropDown, ...
                obj.hMinZEdit, obj.hMaxZEdit);

            % --- Z Movement Controls Panel (Row 2, Col 2) ---
            zControlPanel = gui.components.UIComponentFactory.createStyledPanel(mainGrid, 'Z Movement Controls', 2, 2);
            
            % Create Z position label
            obj.hCurrentZLabel = uilabel(uipanel());
            
            % Create Z control panel with component factory
            gui.components.UIComponentFactory.createZControlPanel(zControlPanel, zControlPanel, obj.controller, obj.hCurrentZLabel);

            % --- Plot Area (Row 3, Col 1:2) ---
            plotPanel = gui.components.UIComponentFactory.createStyledPanel(mainGrid, 'Brightness vs. Z-Position', 3, [1 2]);
            
            % Create plot area with component factory
            obj.hAx = gui.components.UIComponentFactory.createPlotPanel(plotPanel);

            % --- Actions Panel (Row 4, Col 1:2) ---
            actionPanel = gui.components.UIComponentFactory.createStyledPanel(mainGrid, 'Control Actions', 4, [1 2]);
            
            % Create action buttons
            obj.hMonitorToggle = uibutton(uipanel(), 'state', ...
                'ValueChangedFcn', @(src,~) obj.controller.toggleMonitor(src.Value));
            
            obj.hZScanToggle = uibutton(uipanel(), 'state', ...
                'ValueChangedFcn', @(src,~) obj.toggleScanButtons(src.Value));
            
            obj.hFocusButton = uibutton(uipanel(), ...
                'ButtonPushedFcn', @(~,~) obj.controller.startSIFocus());
            
            obj.hGrabButton = uibutton(uipanel(), ...
                'ButtonPushedFcn', @(~,~) obj.controller.grabSIFrame());
            
            obj.hAbortButton = uibutton(uipanel(), ...
                'ButtonPushedFcn', @(~,~) obj.abortOperation());
            
            % Create action panel with component factory
            gui.components.UIComponentFactory.createActionPanel(actionPanel, actionPanel, obj.controller, ...
                obj.hMonitorToggle, obj.hZScanToggle, obj.hFocusButton, obj.hGrabButton, obj.hAbortButton);

            % --- Status Bar ---
            [obj.hStatusText, obj.hStatusBar] = gui.components.UIComponentFactory.createStatusBar(obj.hFig);
            
            % Set up figure resize callback
            obj.hFig.SizeChangedFcn = @(~,~) obj.updateStatusBarPosition();
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
        end

        function updatePlot(obj, zData, bData, activeChannel)
            % Update the brightness vs Z-position plot with visual markers
            gui.handlers.UIEventHandlers.updatePlot(obj.hAx, zData, bData, activeChannel);
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