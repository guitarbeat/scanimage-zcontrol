%==============================================================================
% UiComponents - Centralized UI Component Definitions
%==============================================================================
%
% Purpose:
%   Provides centralized definitions for all UI components, constants, and styling
%   used throughout the FoilView application. This class serves as the single
%   source of truth for UI configuration and ensures consistency across the app.
%
% Key Features:
%   - Centralized UI component definitions
%   - Modular and reusable component structures
%   - Property and event configuration
%   - Integration with controller and service layers
%   - Consistent color scheme and styling
%
% Dependencies:
%   - MATLAB App Designer: UI components
%   - FoilviewUtils: UI style constants
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   components = UiComponents.create();
%
%==============================================================================

classdef UiComponents

    properties (Constant, Access = public)
        % ===== WINDOW DIMENSIONS =====
        MIN_WINDOW_WIDTH = 500
        MIN_WINDOW_HEIGHT = 400
        PLOT_WIDTH = 400
        TOOLS_WINDOW_WIDTH = 280
        TOOLS_WINDOW_HEIGHT = 250
        TOOLS_WINDOW_OFFSET = 20

        % ===== LAYOUT CONSTANTS =====
        % Common dimensions
        BUTTON_HEIGHT = 30

        % Standard padding and spacing
        STANDARD_PADDING = [2 2 2 2]
        STANDARD_SPACING = 2
        TIGHT_PADDING = [1 1 1 1]
        TIGHT_SPACING = 1
        LOOSE_PADDING = [4 4 4 4]
        LOOSE_SPACING = 4

        % Main layout
        MAIN_PADDING = [1 1 1 1]
        MAIN_ROW_SPACING = 1
        MAIN_ROW_HEIGHTS = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit'}

        % Status bar
        STATUS_BAR_COLUMN_WIDTHS = {'1x', 40, 40, 40, 40, 40}
        STATUS_BAR_PADDING = [8 8 8 8]
        STATUS_BAR_SPACING = 4

        % Control panels
        CONTROL_GRID_PADDING = [2 2 2 2]
        CONTROL_GRID_SPACING = 4
        CONTROL_COLUMN_SPACING = 8

        % Standard column and row configurations
        STANDARD_COLUMN_WIDTHS = {'1x', 'fit'}
        FIT_EXPAND_COLUMNS = {'fit', '1x'}
        FIT_EXPAND_ROWS = {'fit', '1x'}
        ALL_FIT_ROWS = {'fit', 'fit'}
        THREE_FIT_ROWS = {'fit', 'fit', 'fit'}

        % Plot area
        PLOT_PANEL_OFFSET = 10
        PLOT_PANEL_MARGIN = 20
        PLOT_GRID_PADDING = [10 10 10 10]
        PLOT_GRID_SPACING = 10

        % Font sizes - Unified for consistency
        POSITION_DISPLAY_FONT_SIZE = 28  % Large position display
        CARD_TITLE_FONT_SIZE = 11        % Card headers
        CONTROL_FONT_SIZE = 10           % All controls (buttons, fields, dropdowns, labels)

        % ===== MODERN COLOR SCHEME =====
        COLORS = struct(...
            'Background', [0.96 0.97 0.98], ...         % Light blue-gray background
            'Primary', [0.13 0.45 0.82], ...            % Modern blue
            'PrimaryHover', [0.10 0.35 0.72], ...       % Darker blue for emphasis
            'Success', [0.16 0.68 0.38], ...            % Modern green
            'SuccessHover', [0.12 0.58 0.28], ...       % Darker green
            'Warning', [0.95 0.61 0.07], ...            % Modern orange
            'WarningHover', [0.85 0.51 0.02], ...       % Darker orange
            'Danger', [0.86 0.24 0.24], ...             % Modern red
            'DangerHover', [0.76 0.14 0.14], ...        % Darker red
            'Light', [0.98 0.99 1.0], ...               % Very light blue tint
            'TextMuted', [0.45 0.55 0.65], ...          % Blue-tinted muted text
            'Card', [1.0 1.0 1.0], ...                  % Pure white cards
            'CardBorder', [0.90 0.92 0.95], ...         % Subtle card borders
            'Border', [0.88 0.88 0.9], ...
            'Accent', [0.67 0.13 0.82], ...             % Purple accent
            'Info', [0.11 0.63 0.95], ...               % Bright info blue
            'White', [1 1 1], ...
            'Black', [0 0 0], ...
            'DarkText', [0.15 0.15 0.15], ...           % Softer dark text
            'LightBackground', [0.98 0.98 0.98], ...
            'MetricBackground', [0.95 0.9 0.95], ...
            'PlotBackground', [0.98 0.98 0.98], ...
            'PlotGrid', [0.9 0.9 0.9], ...
            'PlotLine', [0.13 0.45 0.82], ...
            'PlotMarker', [0.86 0.24 0.24], ...
            'StatusGood', [0.16 0.68 0.38], ...         % Green for good status
            'StatusWarning', [0.95 0.61 0.07], ...      % Orange for warnings
            'StatusError', [0.86 0.24 0.24], ...        % Red for errors
            'ButtonShadow', [0.85 0.87 0.90] ...        % Button shadow color
        )

        % ===== BUTTON STYLES =====
        BUTTON_STYLES = struct(...
            'Primary', struct(...
                'BackgroundColor', [0.13 0.45 0.82], ...
                'FontColor', [1 1 1], ...
                'FontWeight', 'bold' ...
            ), ...
            'Secondary', struct(...
                'BackgroundColor', [0.96 0.97 0.98], ...
                'FontColor', [0.15 0.15 0.15], ...
                'FontWeight', 'normal' ...
            ), ...
            'Success', struct(...
                'BackgroundColor', [0.16 0.68 0.38], ...
                'FontColor', [1 1 1], ...
                'FontWeight', 'bold' ...
            ), ...
            'Warning', struct(...
                'BackgroundColor', [0.95 0.61 0.07], ...
                'FontColor', [1 1 1], ...
                'FontWeight', 'bold' ...
            ), ...
            'Danger', struct(...
                'BackgroundColor', [0.86 0.24 0.24], ...
                'FontColor', [1 1 1], ...
                'FontWeight', 'bold' ...
            ), ...
            'Info', struct(...
                'BackgroundColor', [0.11 0.63 0.95], ...
                'FontColor', [1 1 1], ...
                'FontWeight', 'bold' ...
            ), ...
            'Muted', struct(...
                'BackgroundColor', [0.96 0.97 0.98], ...
                'FontColor', [0.45 0.55 0.65], ...
                'FontWeight', 'normal' ...
            ) ...
        )

        % ===== TEXT STYLES =====
        TEXT_STYLES = struct(...
            'Title', struct(...
                'FontSize', 14, ...
                'FontWeight', 'bold', ...
                'FontColor', [0.15 0.15 0.15] ...
            ), ...
            'Subtitle', struct(...
                'FontSize', 12, ...
                'FontWeight', 'normal', ...
                'FontColor', [0.45 0.55 0.65] ...
            ), ...
            'Body', struct(...
                'FontSize', 10, ...
                'FontWeight', 'normal', ...
                'FontColor', [0.15 0.15 0.15] ...
            ), ...
            'Caption', struct(...
                'FontSize', 9, ...
                'FontWeight', 'normal', ...
                'FontColor', [0.45 0.55 0.65] ...
            ) ...
        )

        % ===== COMPONENT DIMENSIONS =====
        DIMENSIONS = struct(...
            'ButtonHeight', 30, ...
            'ButtonWidth', 80, ...
            'InputHeight', 25, ...
            'LabelHeight', 20, ...
            'CardPadding', [10 10 10 10], ...
            'CardSpacing', 5, ...
            'PanelPadding', [5 5 5 5], ...
            'PanelSpacing', 3 ...
        )

        % ===== ANIMATION SETTINGS =====
        ANIMATION = struct(...
            'Duration', 0.2, ...
            'Easing', 'ease-in-out', ...
            'HoverDelay', 0.1, ...
            'TransitionDelay', 0.05 ...
        )

        % ===== TEXT CONSTANTS =====
        TEXT = struct(...
            'WindowTitle', 'FoilView', ...
            'Ready', '✓ Ready', ...
            'Loading', 'Loading...', ...
            'Error', 'Error', ...
            'Success', 'Success', ...
            'Warning', 'Warning', ...
            'Info', 'Info' ...
        )
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
            % Respects system font scaling preferences by using relative scaling only.
            if nargin < 2 || isempty(windowSize)
                return;
            end

            % Calculate responsive scaling factor with gentler limits
            widthScale = windowSize(3) / UiComponents.MIN_WINDOW_WIDTH;
            heightScale = windowSize(4) / UiComponents.MIN_WINDOW_HEIGHT;
            overallScale = min(max(sqrt(widthScale * heightScale), 0.8), 1.5);

            % Scale position display with unified constant, preserving system scaling
            if isfield(components, 'PositionDisplay') && isfield(components.PositionDisplay, 'Label')
                % Get current font size to respect any system scaling already applied
                currentSize = components.PositionDisplay.Label.FontSize;
                if currentSize == 0 || isempty(currentSize)
                    currentSize = UiComponents.POSITION_DISPLAY_FONT_SIZE;
                end
                
                % Apply relative scaling without hard limits
                newFontSize = round(currentSize * overallScale);
                components.PositionDisplay.Label.FontSize = newFontSize;
            end

            % Scale all control components uniformly
            controlFields = {'AutoControls', 'ManualControls', 'MetricDisplay', 'StatusControls'};
            for i = 1:length(controlFields)
                if isfield(components, controlFields{i})
                    UiComponents.adjustControlFonts(components.(controlFields{i}), overallScale);
                end
            end
        end

        function adjustControlFonts(controlStruct, scale)
            % Applies uniform font scaling to all controls, preserving system font scaling.
            if ~isstruct(controlStruct) || scale == 1.0
                return;
            end

            fields = fieldnames(controlStruct);
            for i = 1:length(fields)
                obj = controlStruct.(fields{i});
                if isa(obj, 'handle') && ~isempty(obj) && isvalid(obj) && isprop(obj, 'FontSize')
                    % Get current font size to respect system scaling
                    currentSize = obj.FontSize;
                    if currentSize == 0 || isempty(currentSize)
                        currentSize = UiComponents.CONTROL_FONT_SIZE;
                    end
                    
                    % Apply relative scaling without hard limits
                    obj.FontSize = round(currentSize * scale);
                elseif isstruct(obj)
                    UiComponents.adjustControlFonts(obj, scale);
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
        
        function toolsWindow = createToolsWindow(mainWindowHandle)
            % Creates and returns a ToolsWindow instance.
            toolsWindow = ToolsWindow(mainWindowHandle);
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
                % Add direction button update
                UiComponents.updateDirectionButtons(app);
                % Add auto step status display update
                UiComponents.updateAutoStepStatusDisplay(app);
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
            % Updates status labels for position and overall app state with enhanced styling.
            success = FoilviewUtils.safeExecuteWithReturn(@doUpdateStatus, 'updateStatusDisplay', false);

            function success = doUpdateStatus()
                if ~FoilviewUtils.validateMultipleComponents(positionDisplay.Status, statusControls.Label) || isempty(controller)
                    success = false;
                    return;
                end

                [statusText, statusColor] = UiComponents.getPositionStatusInfo(controller);
                positionDisplay.Status.Text = statusText;
                positionDisplay.Status.FontColor = statusColor;

                [systemText, systemColor] = UiComponents.getSystemStatusInfo(controller);
                statusControls.Label.Text = systemText;
                statusControls.Label.FontColor = systemColor;

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
                [textColor, bgColor] = UiComponents.getMetricDisplayColors(metricValue);

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
                    FoilviewUtils.setControlEnabled(autoControls, false, 'StepsField');
                    FoilviewUtils.setControlEnabled(autoControls, false, 'DelayField');
                    FoilviewUtils.setControlEnabled(autoControls, false, 'DirectionSwitch');

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

                [style, ~] = UiComponents.getButtonStateStyle(isRunning);
                UiComponents.applyButtonStyle(autoControls.StartStopButton, style);

                success = true;
            end
        end

        function success = updateDirectionButtonStyling(autoControls, direction)
            % Updates direction switch to match current direction.
            success = FoilviewUtils.safeExecuteWithReturn(@doUpdateDirection, 'updateDirectionButtonStyling', false);

            function success = doUpdateDirection()
                if ~FoilviewUtils.validateControlStruct(autoControls, {'DirectionSwitch'})
                    success = false;
                    return;
                end

                directionValue = UiComponents.getDirectionValue(direction);
                if isfield(autoControls, 'DirectionSwitch') && isvalid(autoControls.DirectionSwitch)
                    autoControls.DirectionSwitch.Value = directionValue;
                end

                success = true;
            end
        end

        function applyButtonStyle(button, styleName)
            % Apply a predefined button style to a UI button
            % 
            % Inputs:
            %   button: UIButton object to style
            %   styleName: String name of style ('Primary', 'Secondary', etc.)
            
            % Convert to title case for case-insensitive matching
            styleNameTitle = UiComponents.toTitleCase(styleName);
            
            if isfield(UiComponents.BUTTON_STYLES, styleNameTitle)
                style = UiComponents.BUTTON_STYLES.(styleNameTitle);
                button.BackgroundColor = style.BackgroundColor;
                button.FontColor = style.FontColor;
                button.FontWeight = style.FontWeight;
            else
                warning('UiComponents:InvalidStyle', 'Unknown button style: %s (tried: %s)', styleName, styleNameTitle);
            end
        end

        function applyTextStyle(label, styleName)
            % Apply a predefined text style to a UI label
            % 
            % Inputs:
            %   label: UILabel object to style
            %   styleName: String name of style ('Title', 'Subtitle', etc.)
            
            if isfield(UiComponents.TEXT_STYLES, styleName)
                style = UiComponents.TEXT_STYLES.(styleName);
                label.FontSize = style.FontSize;
                label.FontWeight = style.FontWeight;
                label.FontColor = style.FontColor;
            else
                warning('UiComponents:InvalidStyle', 'Unknown text style: %s', styleName);
            end
        end

        function color = getColor(colorName)
            % Get a color from the color scheme
            % 
            % Inputs:
            %   colorName: String name of color
            % 
            % Returns:
            %   color: RGB color array [r g b]
            
            if isfield(UiComponents.COLORS, colorName)
                color = UiComponents.COLORS.(colorName);
            else
                warning('UiComponents:InvalidColor', 'Unknown color: %s', colorName);
                color = [0 0 0]; % Default to black
            end
        end

        function updateDirectionButtons(app)
            % Update direction switch and start button to show current direction with enhanced styling
            direction = app.Controller.AutoDirection;
            isRunning = app.Controller.IsAutoRunning;

            % Update toggle switch to match current direction
            directionValue = UiComponents.getDirectionValue(direction);
            if isfield(app.AutoControls, 'DirectionSwitch') && ~isempty(app.AutoControls.DirectionSwitch) && isvalid(app.AutoControls.DirectionSwitch)
                app.AutoControls.DirectionSwitch.Value = directionValue;
            end

            % Get enhanced direction-specific values with better icons
            [dirSymbol, ~] = UiComponents.getDirectionSymbols(direction);

            % Style start/stop button with enhanced direction indicator
            if isfield(app.AutoControls, 'StartStopButton') && ~isempty(app.AutoControls.StartStopButton) && isvalid(app.AutoControls.StartStopButton)
                if isRunning
                    buttonText = sprintf('⏹ STOP %s', dirSymbol);
                    startStopColor = UiComponents.COLORS.Danger;
                else
                    buttonText = sprintf('▶ START %s', dirSymbol);
                    startStopColor = UiComponents.COLORS.Success;
                end
                UiComponents.styleDirectionButton(app.AutoControls.StartStopButton, buttonText, startStopColor);
            end
        end

        function styleDirectionButton(button, text, backgroundColor)
            % Helper method to apply consistent styling to direction-related buttons
            % Preserves existing font size to respect system scaling
            if ~isvalid(button)
                return;
            end

            button.Text = text;
            button.BackgroundColor = backgroundColor;
            button.FontColor = UiComponents.COLORS.White;
            % Only set font size if it hasn't been set (preserves responsive scaling)
            if button.FontSize == 0 || isempty(button.FontSize)
                button.FontSize = UiComponents.CONTROL_FONT_SIZE;
            end
            button.FontWeight = 'bold';
        end

        function updateAutoStepStatusDisplay(~)
            % Updates the status display for auto step controls based on current settings
            % This function is called but doesn't update a display since there's no StatusDisplay field
            % The status is shown in the position display instead
            return;
        end

        % ===== HELPER METHODS =====
        function directionValue = getDirectionValue(direction)
            % Converts numeric direction to string value for UI controls.
            if direction == 1
                directionValue = 'Up';
            else
                directionValue = 'Down';
            end
        end

        function [dirSymbol, dirText] = getDirectionSymbols(direction)
            % Returns direction symbols and text for UI display.
            if direction > 0
                dirSymbol = '▲';
                dirText = 'UP';
            else
                dirSymbol = '▼';
                dirText = 'DOWN';
            end
        end

        function [style, text] = getButtonStateStyle(isRunning)
            % Returns appropriate style and text for start/stop button based on running state.
            if isRunning
                style = 'danger';
                text = 'STOP';
            else
                style = 'success';
                text = 'START';
            end
        end

        function [statusText, statusColor] = getPositionStatusInfo(controller)
            % Returns position status text and color based on controller state.
            if controller.IsAutoRunning
                statusText = sprintf('▶ Auto-stepping: %d/%d', controller.CurrentStep, controller.TotalSteps);
                statusColor = UiComponents.COLORS.Primary;
            else
                statusText = '✓ Ready';
                statusColor = UiComponents.COLORS.StatusGood;
            end
        end

        function [systemText, systemColor] = getSystemStatusInfo(controller)
            % Returns system status text and color based on controller state.
            if controller.SimulationMode
                systemText = sprintf('⚠ ScanImage: Simulation (%s)', controller.StatusMessage);
                systemColor = UiComponents.COLORS.StatusWarning;
            else
                systemText = sprintf('✓ ScanImage: %s', controller.StatusMessage);
                systemColor = UiComponents.COLORS.StatusGood;
            end
        end

        function [textColor, bgColor] = getMetricDisplayColors(metricValue)
            % Returns appropriate text and background colors for metric display based on value.
            if isnan(metricValue)
                textColor = UiComponents.COLORS.TextMuted;
                bgColor = UiComponents.COLORS.LightBackground;
            else
                textColor = UiComponents.COLORS.Black;
                if metricValue > 0
                    intensity = min(1, metricValue / 100);
                    bgColor = [0.95 0.9 + 0.1 * intensity 0.95];
                else
                    bgColor = UiComponents.COLORS.LightBackground;
                end
            end
        end
        
        function titleCase = toTitleCase(str)
            % Convert a string to title case for case-insensitive matching
            % 
            % Inputs:
            %   str: Input string (e.g., 'primary', 'SUCCESS')
            % 
            % Returns:
            %   titleCase: Title case string (e.g., 'Primary', 'Success')
            
            if isempty(str)
                titleCase = '';
                return;
            end
            
            % Convert to lowercase first, then capitalize first letter
            strLower = lower(str);
            if length(strLower) > 1
                titleCase = [upper(strLower(1)) strLower(2:end)];
            else
                titleCase = upper(strLower);
            end
        end
    end
end