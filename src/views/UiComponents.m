% Combined UI Components for FoilView
% This file contains shared constants, UI adjustment utilities, 
% sub-view creation methods, and UI update functions for state management and visualization.

classdef UiComponents
    
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
        % ===== UI ADJUSTMENT UTILITIES =====
        function adjustPlotPosition(uiFigure, plotPanel, plotWidth)
            % Adjusts the position of the plot panel relative to the main figure.
            if ~isvalid(uiFigure) || ~isvalid(plotPanel)
                return;
            end
            
            figPos = uiFigure.Position;
            expandedWidth = figPos(3);
            mainWindowWidth = expandedWidth - plotWidth - 20;
            
            plotPanel.Position = [mainWindowWidth + 10, 10, plotWidth, figPos(4) - 20];
        end
        
        function adjustFontSizes(components, windowSize)
            % Scales font sizes of UI components based on window size for responsiveness.
            if nargin < 2 || isempty(windowSize)
                return;
            end
            
            widthScale = windowSize(3) / UiComponents.DEFAULT_WINDOW_WIDTH;
            heightScale = windowSize(4) / UiComponents.DEFAULT_WINDOW_HEIGHT;
            overallScale = min(max(sqrt(widthScale * heightScale), 0.7), 1.5);
            
            % Adjust position label font
            if isfield(components, 'PositionDisplay') && isfield(components.PositionDisplay, 'Label')
                baseFontSize = 28;
                newFontSize = max(round(baseFontSize * overallScale), 18);
                components.PositionDisplay.Label.FontSize = newFontSize;
            end
            
            % Adjust other controls if scale changed
            if overallScale ~= 1.0
                fontFields = {'AutoControls', 'ManualControls', 'MetricDisplay', 'StatusControls'};
                for i = 1:length(fontFields)
                    if isfield(components, fontFields{i})
                        UiComponents.adjustControlFonts(components.(fontFields{i}), overallScale);
                    end
                end
            end
        end
        
        function adjustControlFonts(controlStruct, scale)
            % Helper to scale font sizes in a control struct, clamping between 8-16.
            if ~isstruct(controlStruct) || scale == 1.0
                return;
            end
            
            fields = fieldnames(controlStruct);
            for i = 1:length(fields)
                obj = controlStruct.(fields{i});
                if isvalid(obj) && isprop(obj, 'FontSize')
                    newSize = max(round(obj.FontSize * scale), 8);
                    newSize = min(newSize, 16);
                    obj.FontSize = newSize;
                end
            end
        end
        
        % ===== SUB-VIEW CREATION =====
        function bookmarksApp = createBookmarksView(controller)
            % Creates and returns a BookmarksView instance tied to the controller.
            if nargin < 1 || isempty(controller)
                error('UiComponents:NoController', 'A FoilviewController instance is required');
            end
            bookmarksApp = BookmarksView(controller);
        end
        
        function stageViewApp = createStageView()
            % Creates and returns a StageView instance.
            stageViewApp = StageView();
        end

        % ===== UI UPDATE FUNCTIONS =====
        function success = updateAllUI(app)
            % Orchestrates all UI updates with throttling to prevent excessive calls.
            success = FoilviewUtils.safeExecuteWithReturn(@doUpdateAll, 'updateAllUI', false);

            function success = doUpdateAll()
                persistent lastUpdateTime updateFunctions;
                if isempty(lastUpdateTime)
                    lastUpdateTime = 0;
                    updateFunctions = UiComponents.createUpdateFunctions(app);
                end

                if ~FoilviewUtils.shouldThrottleUpdate(lastUpdateTime)
                    success = true;
                    return;
                end
                lastUpdateTime = posixtime(datetime('now'));

                success = FoilviewUtils.batchUIUpdate(updateFunctions);
                UiComponents.updateDirectionButtons(app);
                UiComponents.updateWindowStatusButtons(app);
            end
        end

        function functions = createUpdateFunctions(app)
            % Returns a cell array of update function handles capturing the app context.
            functions = {
                @() UiComponents.updatePositionDisplay(app.UIFigure, app.PositionDisplay, app.Controller), ...
                @() UiComponents.updateStatusDisplay(app.PositionDisplay, app.StatusControls, app.Controller), ...
                @() UiComponents.updateControlStates(app.ManualControls, app.AutoControls, app.Controller), ...
                @() UiComponents.updateMetricDisplay(app.MetricDisplay, app.Controller)
            };
        end

        function success = updatePositionDisplay(uiFigure, positionDisplay, controller)
            % Updates the position display label and window title.
            success = FoilviewUtils.safeExecuteWithReturn(@doUpdatePosition, 'updatePositionDisplay', false);

            function success = doUpdatePosition()
                if ~FoilviewUtils.validateMultipleComponents(uiFigure, positionDisplay.Label) || isempty(controller)
                    success = false;
                    return;
                end

                positionStr = FoilviewUtils.formatPosition(controller.CurrentPosition, true);
                positionDisplay.Label.Text = positionStr;

                baseTitle = UiComponents.TEXT.WindowTitle;
                uiFigure.Name = sprintf('%s (%s)', baseTitle, FoilviewUtils.formatPosition(controller.CurrentPosition));

                success = true;
            end
        end

        function success = updateStatusDisplay(positionDisplay, statusControls, controller)
            % Updates status labels for position and overall app state.
            success = FoilviewUtils.safeExecuteWithReturn(@doUpdateStatus, 'updateStatusDisplay', false);

            function success = doUpdateStatus()
                if ~FoilviewUtils.validateMultipleComponents(positionDisplay.Status, statusControls.Label) || isempty(controller)
                    success = false;
                    return;
                end

                if controller.IsAutoRunning
                    positionDisplay.Status.Text = sprintf('Auto-stepping: %d/%d', controller.CurrentStep, controller.TotalSteps);
                    positionDisplay.Status.FontColor = [0.1 0.1 0.1];
                else
                    positionDisplay.Status.Text = 'Ready';
                    positionDisplay.Status.FontColor = [0.5 0.5 0.5];
                end

                if controller.SimulationMode
                    statusControls.Label.Text = sprintf('ScanImage: Simulation (%s)', controller.StatusMessage);
                    statusControls.Label.FontColor = [0.9 0.6 0.2];
                else
                    statusControls.Label.Text = sprintf('ScanImage: %s', controller.StatusMessage);
                    statusControls.Label.FontColor = [0.2 0.7 0.3];
                end

                success = true;
            end
        end

        function success = updateMetricDisplay(metricDisplay, controller)
            % Updates the metric value display with conditional styling.
            success = FoilviewUtils.safeExecuteWithReturn(@doUpdateMetric, 'updateMetricDisplay', false);

            function success = doUpdateMetric()
                if ~FoilviewUtils.validateControlStruct(metricDisplay, {'Value'}) || isempty(controller)
                    success = false;
                    return;
                end

                metricValue = controller.CurrentMetric;
                displayText = FoilviewUtils.formatMetricValue(metricValue);

                if isnan(metricValue)
                    textColor = [0.5 0.5 0.5];
                    bgColor = [0.98 0.98 0.98];
                else
                    textColor = [0 0 0];
                    if metricValue > 0
                        intensity = min(1, metricValue / 100);
                        bgColor = [0.95 0.9 + 0.1 * intensity 0.95];
                    else
                        bgColor = [0.98 0.98 0.98];
                    end
                end

                metricDisplay.Value.Text = displayText;
                metricDisplay.Value.FontColor = textColor;
                metricDisplay.Value.BackgroundColor = bgColor;

                success = true;
            end
        end

        function success = updateControlStates(manualControls, autoControls, controller)
            % Updates enabled states and styling for manual and auto controls based on running state.
            success = FoilviewUtils.safeExecuteWithReturn(@doUpdateControlStates, 'updateControlStates', false);

            function success = doUpdateControlStates()
                if isempty(controller)
                    success = false;
                    return;
                end

                isRunning = controller.IsAutoRunning;

                UiComponents.setControlsEnabled(manualControls, ~isRunning);

                if isRunning
                    FoilviewUtils.setControlEnabled(autoControls, false, 'StepField');
                    FoilviewUtils.setControlEnabled(autoControls, false, 'StepsField');
                    FoilviewUtils.setControlEnabled(autoControls, false, 'DelayField');
                    FoilviewUtils.setControlEnabled(autoControls, false, 'DirectionSwitch');

                    FoilviewUtils.setControlEnabled(autoControls, true, 'DirectionButton');
                    FoilviewUtils.setControlEnabled(autoControls, true, 'StartStopButton');
                else
                    UiComponents.setControlsEnabled(autoControls, true);
                end

                UiComponents.updateDirectionButtonStyling(autoControls, controller.AutoDirection);
                UiComponents.updateAutoStepButton(autoControls, isRunning);

                success = true;
            end
        end

        function setControlsEnabled(controls, enabled)
            % Enables or disables all controls in the given struct.
            FoilviewUtils.safeExecute(@doSetControls, 'setControlsEnabled');

            function doSetControls()
                controlFields = FoilviewUtils.getAllControlFields();
                FoilviewUtils.setControlsEnabled(controls, enabled, controlFields);
            end
        end

        function success = updateAutoStepButton(autoControls, isRunning)
            % Updates the start/stop button text and style based on running state.
            success = FoilviewUtils.safeExecuteWithReturn(@doUpdateButton, 'updateAutoStepButton', false);

            function success = doUpdateButton()
                if ~FoilviewUtils.validateControlStruct(autoControls, {'StartStopButton'})
                    success = false;
                    return;
                end

                if isRunning
                    UiComponents.applyButtonStyle(autoControls.StartStopButton, 'danger', 'STOP');
                else
                    UiComponents.applyButtonStyle(autoControls.StartStopButton, 'success', 'START');
                end

                success = true;
            end
        end

        function success = updateDirectionButtonStyling(autoControls, direction)
            % Updates direction button style and syncs with switch.
            success = FoilviewUtils.safeExecuteWithReturn(@doUpdateDirection, 'updateDirectionButtonStyling', false);

            function success = doUpdateDirection()
                if ~FoilviewUtils.validateControlStruct(autoControls, {'DirectionButton'})
                    success = false;
                    return;
                end

                if direction == 1
                    UiComponents.applyButtonStyle(autoControls.DirectionButton, 'success', '▲ UP');
                    if isfield(autoControls, 'DirectionSwitch')
                        autoControls.DirectionSwitch.Value = 'Up';
                    end
                else
                    UiComponents.applyButtonStyle(autoControls.DirectionButton, 'warning', '▼ DOWN');
                    if isfield(autoControls, 'DirectionSwitch')
                        autoControls.DirectionSwitch.Value = 'Down';
                    end
                end

                success = true;
            end
        end
        
        function applyButtonStyle(button, style, text)
            % Applies style-based background color and optional text to a button.
            if ~isvalid(button)
                return;
            end
            
            styleName = [upper(style(1)) lower(style(2:end))];
            if isfield(UiComponents.COLORS, styleName)
                button.BackgroundColor = UiComponents.COLORS.(styleName);
            else
                button.BackgroundColor = UiComponents.COLORS.Primary;  % Fallback
            end

            button.FontColor = [1 1 1];
            if nargin > 2 && ~isempty(text)
                button.Text = text;
            end
        end

        function updateDirectionButtons(app)
            % Update direction button and start button to show current direction
            direction = app.Controller.AutoDirection;
            % Update toggle switch to match current direction
            if isfield(app.AutoControls, 'DirectionSwitch') && ~isempty(app.AutoControls.DirectionSwitch)
                if direction > 0
                    app.AutoControls.DirectionSwitch.Value = 'Up';
                else
                    app.AutoControls.DirectionSwitch.Value = 'Down';
                end
            end
            % Style direction button based on direction and running state
            if direction > 0
                app.AutoControls.DirectionButton.Text = '▲';
                baseColor = [0.2 0.7 0.3];  % success color
            else
                app.AutoControls.DirectionButton.Text = '▼';
                baseColor = [0.9 0.6 0.2];  % warning color
            end
            if app.Controller.IsAutoRunning
                app.AutoControls.DirectionButton.BackgroundColor = [0.9 0.3 0.3];  % danger color
            else
                app.AutoControls.DirectionButton.BackgroundColor = baseColor;
            end
            app.AutoControls.DirectionButton.FontColor = [1 1 1];  % white text
            app.AutoControls.DirectionButton.FontSize = 10;
            app.AutoControls.DirectionButton.FontWeight = 'bold';
            % Style start/stop button based on state and direction
            if direction > 0
                if app.Controller.IsAutoRunning
                    app.AutoControls.StartStopButton.BackgroundColor = [0.9 0.3 0.3];  % danger color
                    app.AutoControls.StartStopButton.Text = 'STOP ▲';
                else
                    app.AutoControls.StartStopButton.BackgroundColor = [0.2 0.7 0.3];  % success color
                    app.AutoControls.StartStopButton.Text = 'START ▲';
                end
            else
                if app.Controller.IsAutoRunning
                    app.AutoControls.StartStopButton.BackgroundColor = [0.9 0.3 0.3];  % danger color
                    app.AutoControls.StartStopButton.Text = 'STOP ▼';
                else
                    app.AutoControls.StartStopButton.BackgroundColor = [0.2 0.7 0.3];  % success color
                    app.AutoControls.StartStopButton.Text = 'START ▼';
                end
            end
            app.AutoControls.StartStopButton.FontColor = [1 1 1];  % white text
            app.AutoControls.StartStopButton.FontSize = 10;
            app.AutoControls.StartStopButton.FontWeight = 'bold';
        end

        function updateWindowStatusButtons(app)
            isBookmarksOpen = ~isempty(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp.UIFigure);
            isStageViewOpen = ~isempty(app.StageViewApp) && isvalid(app.StageViewApp) && isvalid(app.StageViewApp.UIFigure);

            if isBookmarksOpen
                app.StatusControls.BookmarksButton.Text = 'Close Bookmarks';
                app.StatusControls.BookmarksButton.Icon = '';
            else
                app.StatusControls.BookmarksButton.Text = 'Open Bookmarks';
                app.StatusControls.BookmarksButton.Icon = '';
            end

            if isStageViewOpen
                app.StatusControls.StageViewButton.Text = 'Close Stage View';
                app.StatusControls.StageViewButton.Icon = '';
            else
                app.StatusControls.StageViewButton.Text = 'Open Stage View';
                app.StatusControls.StageViewButton.Icon = '';
            end
        end
    end
end