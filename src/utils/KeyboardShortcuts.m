classdef KeyboardShortcuts
    % Keyboard shortcuts for FoilView application
    
    methods (Static)
        function setupShortcuts(app)
            % Set up keyboard shortcuts for the main application
            app.UIFigure.KeyPressFcn = @(src, event) KeyboardShortcuts.handleKeyPress(app, event);
        end
        
        function handleKeyPress(app, event)
            % Handle keyboard shortcuts
            switch event.Key
                case 'uparrow'
                    if ~app.Controller.IsAutoRunning
                        app.onUpButtonPushed();
                    end
                case 'downarrow'
                    if ~app.Controller.IsAutoRunning
                        app.onDownButtonPushed();
                    end
                case 'space'
                    if strcmp(event.Modifier, 'control')
                        app.onStartStopButtonPushed();
                    end
                case 'r'
                    if strcmp(event.Modifier, 'control')
                        app.onRefreshButtonPushed();
                    end
                case 'z'
                    if strcmp(event.Modifier, 'control')
                        app.onZeroButtonPushed();
                    end
            end
        end
    end
end