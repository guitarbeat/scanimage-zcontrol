classdef GUIUtils
    % GUIUtils - Common utility functions for GUI components
    %
    % This class provides shared utility methods to reduce code duplication
    % across GUI components and handlers.
    
    methods (Static)
        function isValid = isValidUIComponent(component)
            % Validates that a UI component handle is valid
            % Returns true if the component exists, is not empty, and is a valid handle
            try
                isValid = ~isempty(component) && isvalid(component) && ishandle(component);
            catch
                isValid = false;
            end
        end
        
        function updateStatus(statusText, message, varargin)
            % Updates status text with timestamp and severity options
            %
            % Parameters:
            %   statusText - Handle to status text UI component
            %   message - String message to display
            %   varargin - Optional name/value pairs:
            %     'AddTimestamp' - Add timestamp to message (default: false)
            %     'Severity' - Severity level: "info", "warning", "error", "success" (default: "info")
            %     'EnableDrawnow' - Call drawnow after update (default: true)
            %     'FlashMessage' - Flash message for attention (default: false)
            
            p = inputParser;
            p.addParameter('AddTimestamp', false, @islogical);
            p.addParameter('Severity', 'info', @ischar);
            p.addParameter('EnableDrawnow', true, @islogical);
            p.addParameter('FlashMessage', false, @islogical);
            p.parse(varargin{:});
            
            options = p.Results;
            
            try
                if ~gui.utils.GUIUtils.isValidUIComponent(statusText)
                    return;
                end
                
                % Format message with optional timestamp
                if options.AddTimestamp
                    timestamp = string(datetime('now', 'Format', 'HH:mm:ss'));
                    displayMessage = sprintf('[%s] %s', timestamp, message);
                else
                    displayMessage = message;
                end
                
                % Add severity indicator icon
                switch options.Severity
                    case "error"
                        displayMessage = ['⛔ ' displayMessage];
                    case "warning"
                        displayMessage = ['⚠️ ' displayMessage];
                    case "success"
                        displayMessage = ['✅ ' displayMessage];
                    case "info"
                        displayMessage = ['ℹ️ ' displayMessage];
                end
                
                statusText.Text = displayMessage;
                
                % Set color based on severity
                statusText.FontColor = gui.utils.GUIUtils.getSeverityColor(options.Severity);
                
                % Flash message for attention if requested
                if options.FlashMessage
                    originalColor = statusText.FontColor;
                    for i = 1:2
                        statusText.FontColor = [0.9 0.1 0.1];  % Bright red
                        pause(0.1);
                        statusText.FontColor = originalColor;
                        pause(0.1);
                    end
                end
                
                if options.EnableDrawnow
                    drawnow limitrate;
                end
                
            catch ME
                gui.utils.GUIUtils.logError('updateStatus', ME);
            end
        end
        
        function color = getSeverityColor(severity)
            % Returns color based on message severity
            switch severity
                case "info"
                    color = [0.3 0.3 0.3];
                case "success"
                    color = [0.2 0.7 0.3];
                case "warning"
                    color = [0.9 0.6 0.1];
                case "error"
                    color = [0.8 0.2 0.2];
                otherwise
                    color = [0.3 0.3 0.3];
            end
        end
        
        function logError(functionName, ME)
            % Logs errors with context information
            fprintf('[ERROR] %s: %s\n', functionName, ME.message);
            disp(getReport(ME, 'basic'));
        end
        
        function toggleComponentState(component, enable)
            % Toggle enable state of a component with visual feedback
            if ~gui.utils.GUIUtils.isValidUIComponent(component)
                return;
            end
            
            % Store original background color for restoration
            originalBgColor = [];
            if isprop(component, 'BackgroundColor')
                originalBgColor = component.BackgroundColor;
            end
            
            % Set the enable state
            if enable
                component.Enable = 'on';
                
                % Flash green for enable if we have a background color
                if ~isempty(originalBgColor)
                    component.BackgroundColor = [0.8 1.0 0.8];
                    pause(0.1);
                    component.BackgroundColor = originalBgColor;
                end
            else
                component.Enable = 'off';
                
                % Flash red for disable if we have a background color
                if ~isempty(originalBgColor)
                    component.BackgroundColor = [1.0 0.8 0.8];
                    pause(0.1);
                    component.BackgroundColor = originalBgColor;
                end
            end
        end
        
        function setVisibility(component, visible)
            % Set visibility state of a component
            if gui.utils.GUIUtils.isValidUIComponent(component)
                if visible
                    component.Visible = 'on';
                else
                    component.Visible = 'off';
                end
            end
        end
        
        function updateStatusBarLayout(figureHandle, statusBar, height)
            % Updates status bar layout to match figure size
            % 
            % Parameters:
            %   figureHandle - Handle to the figure
            %   statusBar - Handle to the status bar panel
            %   height - Height of the status bar in pixels (default: 25)
            
            if nargin < 3
                height = 25;
            end
            
            try
                if ~gui.utils.GUIUtils.isValidUIComponent(figureHandle) || ...
                   ~gui.utils.GUIUtils.isValidUIComponent(statusBar)
                    return;
                end
                
                % Update position
                figPos = figureHandle.Position;
                statusBar.Position = [0, 0, figPos(3), height];
                
                % Note: Removed uistack call as it's not supported in uifigure
                
            catch ME
                gui.utils.GUIUtils.logError('updateStatusBarLayout', ME);
            end
        end
    end
end 