classdef foilview_constants < handle
    % foilview_constants - Centralized configuration and constants
    %
    % This class contains all magic numbers, default values, and configuration
    % constants used throughout the foilview application. Centralizing these
    % values improves maintainability and reduces code duplication.
    
    properties (Constant)
        % Window and UI Layout
        DEFAULT_WINDOW_SIZE = [100 100 280 360]
        WINDOW_SPACING = 20
        PLOT_MIN_WIDTH = 400
        RESIZE_THRESHOLD = 30
        MIN_WINDOW_WIDTH = 260
        MIN_WINDOW_HEIGHT = 320
        DEFAULT_WINDOW_WIDTH = 280
        DEFAULT_WINDOW_HEIGHT = 360
        PLOT_WIDTH = 400
        
        % Layout configuration constants
        MAIN_LAYOUT_ROWS = 7
        MAIN_LAYOUT_ROW_HEIGHTS = {'fit', 'fit', 'fit', 'fit', '1x', 'fit', 'fit'}
        
        % Control layout constants
        MANUAL_CONTROL_COLUMNS = 6
        AUTO_CONTROL_ROWS = 2
        AUTO_CONTROL_COLUMNS = 4
        
        % Font size constants
        BASE_FONT_SIZE = 8
        LARGE_FONT_SIZE = 10
        POSITION_FONT_SIZE = 22
        FIELD_FONT_SIZE = 9
        
        % Logo configuration
        LOGO_HEIGHT = 50  % Height in pixels for the logo
        
        % Timer Intervals (seconds)
        RESIZE_MONITOR_INTERVAL = 0.5
        POSITION_REFRESH_PERIOD = 0.2
        METRIC_REFRESH_PERIOD = 1.0
        DEFAULT_UPDATE_THROTTLE = 0.05  % 50ms minimum between updates
        DEFAULT_PLOT_THROTTLE = 0.1     % 100ms minimum between plot updates
        
        % UI Component Sizing
        FONT_SIZE_ADJUSTMENT_THRESHOLD = 5
        
        % Window positioning
        STAGE_VIEW_OFFSET_X = 20
        BOOKMARKS_VIEW_OFFSET_X = -20
        
        % Button icons and text
        BOOKMARKS_ICON_INACTIVE = '📌'
        BOOKMARKS_ICON_ACTIVE = '📌●'
        BOOKMARKS_ICON_TOOLTIP = '📌'
        
        STAGE_VIEW_ICON_INACTIVE = '📹'
        STAGE_VIEW_ICON_ACTIVE = '📹●'
        STAGE_VIEW_ICON_TOOLTIP = '📹'
        
        % Auto step direction indicators
        UP_ARROW = '▲'
        DOWN_ARROW = '▼'
        
        % Status text format strings
        AUTO_RUNNING_FORMAT = 'Sweeping %d×%.1f μm (%.1f µm total) %s...'
        AUTO_READY_FORMAT_SHORT = 'Ready: %d×%.1f μm (%.1f µm total) %s (%.1fs)'
        AUTO_READY_FORMAT_LONG = 'Ready: %d×%.1f μm (%.1f µm total) %s (%dm %.0fs)'
        
        % Time thresholds
        TIME_DISPLAY_MINUTES_THRESHOLD = 60
        
        % Direction text
        DIRECTION_UPWARD = 'upward'
        DIRECTION_DOWNWARD = 'downward'
        
        % Button text templates
        START_UP_TEXT = 'START ▲'
        START_DOWN_TEXT = 'START ▼'
        STOP_UP_TEXT = 'STOP ▲'
        STOP_DOWN_TEXT = 'STOP ▼'
        
        % Text constants
        WINDOW_TITLE = 'FoilView - Z-Stage Control'
        READY_TEXT = 'Ready'
        MANUAL_CONTROL_TITLE = 'Manual Control'
        AUTO_STEP_TITLE = 'Auto Step'
        METRICS_PLOT_TITLE = 'Metrics Plot'
        
        % Control symbols and labels
        SYMBOL_UP = '▲'
        SYMBOL_DOWN = '▼'
        SYMBOL_LEFT = '◄'
        SYMBOL_RIGHT = '►'
        SYMBOL_REFRESH = '↻'
        SYMBOL_PLOT = '📊'
        SYMBOL_BOOKMARKS = '📌'
        SYMBOL_STAGE_VIEW = '📹'
        
        % UI Color constants
        LOGO_FALLBACK_COLOR = [0.2 0.2 0.6]  % Professional blue color
        STEP_PANEL_HIGHLIGHT_COLOR = [0.8 0.8 0.8]
        STEP_FIELD_FONT_COLOR = [0.2 0.2 0.2]
        STATUS_LABEL_COLOR = [0.3 0.3 0.3]
        STATUS_DISPLAY_COLOR = [0.4 0.4 0.4]
        STATUS_UNITS_COLOR = [0.6 0.6 0.6]
        
        % Step size presets
        QUICK_STEP_DOWN_SIZE = 0.5  % μm
        QUICK_STEP_UP_SIZE = 5.0    % μm
        
        % Font scaling limits
        MIN_FONT_SCALE = 0.7
        MAX_FONT_SCALE = 1.5
        
        % Position formatting
        DEFAULT_POSITION_TEXT = '0.0 μm'
        POSITION_PRECISION_THRESHOLD = 0.1  % When to use high precision formatting
        
        % Plot configuration constants
        PLOT_MIN_AXIS_RANGE = 0.001
        PLOT_AXIS_PADDING_PERCENT = 0.05
        PLOT_Y_AXIS_MIN_PADDING = 0.05
        PLOT_LINE_WIDTH = 1.5
        PLOT_MARKER_SIZE = 4
        
        % Metric formatting constants
        METRIC_ZERO_VALUE = '0.00'
        METRIC_SMALL_THRESHOLD = 0.01
        METRIC_SMALL_PRECISION = 4
        METRIC_MEDIUM_THRESHOLD = 1.0
        METRIC_MEDIUM_PRECISION = 3
        METRIC_LARGE_PRECISION = 2
        
        % Color intensity for status indicators
        STATUS_GREEN_BASE = 0.9
        STATUS_GREEN_INTENSITY = 0.1
        STATUS_BG_RED = 0.95
        STATUS_BG_BLUE = 0.95
    end
    
    methods (Static)
        function text = getDirectionText(direction)
            % Get direction text based on numeric direction value
            if direction > 0
                text = foilview_constants.DIRECTION_UPWARD;
            else
                text = foilview_constants.DIRECTION_DOWNWARD;
            end
        end
        
        function arrow = getDirectionArrow(direction)
            % Get direction arrow based on numeric direction value
            if direction > 0
                arrow = foilview_constants.UP_ARROW;
            else
                arrow = foilview_constants.DOWN_ARROW;
            end
        end
        
        function text = getStartStopButtonText(isRunning, direction)
            % Get appropriate start/stop button text based on state and direction
            if direction > 0
                if isRunning
                    text = foilview_constants.STOP_UP_TEXT;
                else
                    text = foilview_constants.START_UP_TEXT;
                end
            else
                if isRunning
                    text = foilview_constants.STOP_DOWN_TEXT;
                else
                    text = foilview_constants.START_DOWN_TEXT;
                end
            end
        end
        
        function statusText = formatAutoStepStatus(isRunning, stepSize, numSteps, direction, delay)
            % Format auto step status text based on current state
            totalDistance = stepSize * numSteps;
            directionText = foilview_constants.getDirectionText(direction);
            
            if isRunning
                statusText = sprintf(foilview_constants.AUTO_RUNNING_FORMAT, ...
                    numSteps, stepSize, totalDistance, directionText);
            else
                totalTime = numSteps * delay;
                if totalTime < foilview_constants.TIME_DISPLAY_MINUTES_THRESHOLD
                    statusText = sprintf(foilview_constants.AUTO_READY_FORMAT_SHORT, ...
                        numSteps, stepSize, totalDistance, directionText, totalTime);
                else
                    minutes = floor(totalTime / 60);
                    seconds = mod(totalTime, 60);
                    statusText = sprintf(foilview_constants.AUTO_READY_FORMAT_LONG, ...
                        numSteps, stepSize, totalDistance, directionText, minutes, seconds);
                end
            end
        end
        
        function text = getTextConstant(fieldName)
            % Get text constant by field name
            switch fieldName
                case 'WindowTitle'
                    text = foilview_constants.WINDOW_TITLE;
                case 'Ready'
                    text = foilview_constants.READY_TEXT;
                case 'ManualControlTitle'
                    text = foilview_constants.MANUAL_CONTROL_TITLE;
                case 'AutoStepTitle'
                    text = foilview_constants.AUTO_STEP_TITLE;
                case 'MetricsPlotTitle'
                    text = foilview_constants.METRICS_PLOT_TITLE;
                otherwise
                    text = '';
            end
        end
        
        function symbol = getSymbol(symbolName)
            % Get symbol constant by name
            switch symbolName
                case 'Up'
                    symbol = foilview_constants.SYMBOL_UP;
                case 'Down'
                    symbol = foilview_constants.SYMBOL_DOWN;
                case 'Left'
                    symbol = foilview_constants.SYMBOL_LEFT;
                case 'Right'
                    symbol = foilview_constants.SYMBOL_RIGHT;
                case 'Refresh'
                    symbol = foilview_constants.SYMBOL_REFRESH;
                case 'Plot'
                    symbol = foilview_constants.SYMBOL_PLOT;
                case 'Bookmarks'
                    symbol = foilview_constants.SYMBOL_BOOKMARKS;
                case 'StageView'
                    symbol = foilview_constants.SYMBOL_STAGE_VIEW;
                otherwise
                    symbol = '';
            end
        end
    end
end 