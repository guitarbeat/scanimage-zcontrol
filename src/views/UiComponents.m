% Combined UI Components for FoilView
% This file contains all UI functionality previously split across three classes:
% - UI creation and layout
% - UI updates and state management  
% - Plot functionality and visualization

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
            
            widthScale = windowSize(3) / UiComponents.DEFAULT_WINDOW_WIDTH;
            heightScale = windowSize(4) / UiComponents.DEFAULT_WINDOW_HEIGHT;
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
                            UiComponents.adjustControlFonts(components.(fontFields{i}), overallScale);
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
        
        % ===== BOOKMARKS VIEW CREATION =====
        function bookmarksApp = createBookmarksView(controller)
            % Create a bookmarks management window
            % Returns a bookmarks app instance that can be managed separately
            
            if nargin < 1 || isempty(controller)
                error('UiComponents:NoController', ...
                      'A FoilviewController instance is required');
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

        function success = updateAllUI(app)
            success = FoilviewUtils.safeExecuteWithReturn(@() doUpdateAll(app), 'updateAllUI', false);

            function success = doUpdateAll(app)
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
            end
        end

        function functions = createUpdateFunctions(app)
            % Creates a cell array of function handles for UI updates.
            % This avoids recreating the array on every throttled update call.
            functions = {
                @() UiComponents.updatePositionDisplay(app.UIFigure, app.PositionDisplay, app.Controller), ...
                @() UiComponents.updateStatusDisplay(app.PositionDisplay, app.StatusControls, app.Controller), ...
                @() UiComponents.updateControlStates(app.ManualControls, app.AutoControls, app.Controller), ...
                @() UiComponents.updateMetricDisplay(app.MetricDisplay, app.Controller)
            };
        end

        function success = updatePositionDisplay(uiFigure, positionDisplay, controller)
            success = FoilviewUtils.safeExecuteWithReturn(@() doUpdatePosition(), 'updatePositionDisplay', false);

            function success = doUpdatePosition()
                success = false;

                if ~FoilviewUtils.validateMultipleComponents(uiFigure, positionDisplay.Label) || isempty(controller)
                    return;
                end

                positionStr = FoilviewUtils.formatPosition(controller.CurrentPosition, true);
                positionDisplay.Label.Text = positionStr;

                baseTitle = UiComponents.TEXT.WindowTitle;
                newTitle = sprintf('%s (%s)', baseTitle, FoilviewUtils.formatPosition(controller.CurrentPosition));
                uiFigure.Name = newTitle;

                success = true;
            end
        end

        function success = updateStatusDisplay(positionDisplay, statusControls, controller)
            success = FoilviewUtils.safeExecuteWithReturn(@() doUpdateStatus(), 'updateStatusDisplay', false);

            function success = doUpdateStatus()
                success = false;

                if ~FoilviewUtils.validateMultipleComponents(positionDisplay.Status, statusControls.Label) || isempty(controller)
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

        function success = updateMetricDisplay(metricDisplay, controller)
            success = FoilviewUtils.safeExecuteWithReturn(@() doUpdateMetric(), 'updateMetricDisplay', false);

            function success = doUpdateMetric()
                success = false;

                if ~FoilviewUtils.validateControlStruct(metricDisplay, {'Value'}) || isempty(controller)
                    return;
                end

                metricValue = controller.CurrentMetric;
                displayText = FoilviewUtils.formatMetricValue(metricValue);

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

        function success = updateControlStates(manualControls, autoControls, controller)
            success = FoilviewUtils.safeExecuteWithReturn(@() doUpdateControlStates(), 'updateControlStates', false);

            function success = doUpdateControlStates()
                success = false;

                if isempty(controller)
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

                    UiComponents.updateDirectionButtonStyling(autoControls, controller.AutoDirection);
                else
                    UiComponents.setControlsEnabled(autoControls, true);
                    UiComponents.updateDirectionButtonStyling(autoControls, controller.AutoDirection);
                end

                UiComponents.updateAutoStepButton(autoControls, isRunning);

                success = true;
            end
        end

        function setControlsEnabled(controls, enabled)
            FoilviewUtils.safeExecute(@() doSetControls(), 'setControlsEnabled');

            function doSetControls()
                controlFields = FoilviewUtils.getAllControlFields();
                FoilviewUtils.setControlsEnabled(controls, enabled, controlFields);
            end
        end

        function success = updateAutoStepButton(autoControls, isRunning)
            success = FoilviewUtils.safeExecuteWithReturn(@() doUpdateButton(), 'updateAutoStepButton', false);

            function success = doUpdateButton()
                success = false;

                if ~FoilviewUtils.validateControlStruct(autoControls, {'StartStopButton'})
                    return;
                end

                if isRunning
                    UiComponents.applyButtonStyle(autoControls.StartStopButton, 'Danger', 'STOP');
                else
                    UiComponents.applyButtonStyle(autoControls.StartStopButton, 'Success', 'START');
                end

                success = true;
            end
        end

        function success = updateDirectionButtonStyling(autoControls, direction)
            success = FoilviewUtils.safeExecuteWithReturn(@() doUpdateDirection(), 'updateDirectionButtonStyling', false);

            function success = doUpdateDirection()
                success = false;

                if ~FoilviewUtils.validateControlStruct(autoControls, {'DirectionButton'})
                    return;
                end

                if direction == 1
                    UiComponents.applyButtonStyle(autoControls.DirectionButton, 'Success', '▲ UP');
                else
                    UiComponents.applyButtonStyle(autoControls.DirectionButton, 'Warning', '▼ DOWN');
                end

                % Update toggle switch to match direction
                if isfield(autoControls, 'DirectionSwitch') && ~isempty(autoControls.DirectionSwitch)
                    if direction == 1
                        autoControls.DirectionSwitch.Value = 'Up';
                    else
                        autoControls.DirectionSwitch.Value = 'Down';
                    end
                end

                success = true;
            end
        end
        
        function applyButtonStyle(button, style, text)
            if ~isvalid(button)
                return;
            end
            
            % Capitalize first letter of style for consistency with COLORS struct
            styleName = [upper(style(1)), lower(style(2:end))];

            if isfield(UiComponents.COLORS, styleName)
                button.BackgroundColor = UiComponents.COLORS.(styleName);
            else
                button.BackgroundColor = UiComponents.COLORS.Primary; % Default style
            end

            button.FontColor = [1 1 1]; % White text for all styled buttons
            if nargin > 2 && ~isempty(text)
                button.Text = text;
            end
        end
    end
end
