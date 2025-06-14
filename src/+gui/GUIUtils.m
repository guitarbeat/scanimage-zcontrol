classdef GUIUtils < handle
    % GUIUtils - Utility functions for GUI operations
    %
    % This class provides common utility functions for GUI handling,
    % including status updates, component validation, and layout management.
    
    methods (Static)
        function updateStatusBar(hStatusBar, hStatusText, message, messageType)
            % Updates status bar text with optional type-based styling
            %
            % Parameters:
            %   hStatusBar - Handle to status bar panel
            %   hStatusText - Handle to status text label
            %   message - Text message to display
            %   messageType - Optional type (info, warning, error, success)
            
            if nargin < 4 || isempty(messageType)
                messageType = 'info';
            end
            
            try
                if isempty(hStatusText) || ~isvalid(hStatusText)
                    return;
                end
                
                % Set text
                hStatusText.Text = message;
                
                % Apply type-specific styling
                switch lower(messageType)
                    case 'error'
                        hStatusText.FontColor = core.AppConfig.UI_COLORS.Danger;
                        if ~isempty(hStatusBar) && isvalid(hStatusBar)
                            hStatusBar.BackgroundColor = [1 0.9 0.9];
                        end
                    case 'warning'
                        hStatusText.FontColor = core.AppConfig.UI_COLORS.Warning;
                        if ~isempty(hStatusBar) && isvalid(hStatusBar)
                            hStatusBar.BackgroundColor = [1 0.95 0.9];
                        end
                    case 'success'
                        hStatusText.FontColor = core.AppConfig.UI_COLORS.Success;
                        if ~isempty(hStatusBar) && isvalid(hStatusBar)
                            hStatusBar.BackgroundColor = [0.9 1 0.9];
                        end
                    otherwise % info
                        hStatusText.FontColor = core.AppConfig.UI_COLORS.Text;
                        if ~isempty(hStatusBar) && isvalid(hStatusBar)
                            hStatusBar.BackgroundColor = [0.9 0.9 0.95];
                        end
                end
                
                drawnow;
            catch
                % Silently ignore errors in status updates
            end
        end
        
        function cleanupTimers(timersList)
            % Clean up multiple timers safely
            %
            % Parameters:
            %   timersList - Cell array or struct of timer handles
            
            if iscell(timersList)
                % Handle cell array of timers
                for i = 1:length(timersList)
                    if ~isempty(timersList{i})
                        core.CoreUtils.cleanupTimer(timersList{i});
                    end
                end
            elseif isstruct(timersList)
                % Handle struct of timers
                fields = fieldnames(timersList);
                for i = 1:length(fields)
                    if ~isempty(timersList.(fields{i}))
                        core.CoreUtils.cleanupTimer(timersList.(fields{i}));
                    end
                end
            end
        end
        
        function result = getUIProperty(component, propertyName, defaultValue)
            % Safely get a property value from a UI component
            %
            % Parameters:
            %   component - UI component handle
            %   propertyName - Name of property to get
            %   defaultValue - Default value if property doesn't exist or component is invalid
            %
            % Returns:
            %   result - Property value or default
            
            result = defaultValue;
            
            try
                if isempty(component) || ~isvalid(component)
                    return;
                end
                
                if isprop(component, propertyName)
                    result = component.(propertyName);
                end
            catch
                % Return default on any error
            end
        end
        
        function setUIProperty(component, propertyName, value)
            % Safely set a property value on a UI component
            %
            % Parameters:
            %   component - UI component handle
            %   propertyName - Name of property to set
            %   value - Value to set property to
            
            try
                if isempty(component) || ~isvalid(component)
                    return;
                end
                
                if isprop(component, propertyName)
                    component.(propertyName) = value;
                end
            catch
                % Silently ignore errors
            end
        end
        
        function hComponent = findComponentByTag(parent, tag)
            % Find a component by tag under a parent
            %
            % Parameters:
            %   parent - Parent figure or container
            %   tag - Tag to search for
            %
            % Returns:
            %   hComponent - Handle to component or empty if not found
            
            hComponent = [];
            
            try
                if isempty(parent) || ~isvalid(parent)
                    return;
                end
                
                % Find all components with matching tag
                hComponent = findall(parent, 'Tag', tag);
                
                % Return first match or empty
                if ~isempty(hComponent)
                    hComponent = hComponent(1);
                end
            catch
                % Return empty on any error
                hComponent = [];
            end
        end
        
        function updateAfterResize(figHandle, statusBar, statusText)
            % Update component positions after figure resize
            %
            % Parameters:
            %   figHandle - Handle to the figure
            %   statusBar - Handle to status bar panel
            %   statusText - Handle to status text label
            
            try
                if ~isempty(figHandle) && isvalid(figHandle) && ...
                   ~isempty(statusBar) && isvalid(statusBar)
                    
                    % Update status bar to span the width of the figure
                    statusBar.Position = [0, 0, figHandle.Position(3), 24];
                    
                    % Update status text to fit within the status bar
                    if ~isempty(statusText) && isvalid(statusText)
                        statusText.Position = [10, 2, statusBar.Position(3)-20, 20];
                    end
                end
            catch
                % Silently ignore errors in resize handling
            end
        end
        
        function createStatusUpdateTimer(obj, figHandle, statusBar, statusText)
            % Create a timer to update status bar position after resize
            %
            % Parameters:
            %   obj - Object to store the timer in
            %   figHandle - Handle to the figure
            %   statusBar - Handle to status bar panel
            %   statusText - Handle to status text label
            
            try
                % Create and start timer
                t = timer('ExecutionMode', 'fixedRate', ...
                          'Period', 0.5, ...
                          'TimerFcn', @(~,~) gui.GUIUtils.updateAfterResize(figHandle, statusBar, statusText));
                start(t);
                
                % Store timer in object property
                if ~isempty(obj)
                    gui.GUIUtils.setUIProperty(obj, 'statusUpdateTimer', t);
                end
            catch ME
                warning('Error creating status update timer: %s', ME.message);
            end
        end
    end
end 