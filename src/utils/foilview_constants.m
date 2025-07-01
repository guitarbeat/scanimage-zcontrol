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
        MIN_WINDOW_WIDTH = 400
        MIN_WINDOW_HEIGHT = 200
        
        % Timer Intervals (seconds)
        RESIZE_MONITOR_INTERVAL = 0.5
        POSITION_REFRESH_PERIOD = 0.2
        METRIC_REFRESH_PERIOD = 1.0
        
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
    end
end 