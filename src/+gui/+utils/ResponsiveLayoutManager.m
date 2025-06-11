classdef ResponsiveLayoutManager < handle
    % ResponsiveLayoutManager - Manages responsive UI layouts
    % Handles window resize events and adjusts UI components accordingly
    
    properties (Access = private)
        figureHandle         % Handle to main figure
        componentsToResize   % Map of components that need resizing
        statusBar            % Handle to status bar
        plotContainer        % Handle to plot container
        plotExpanded         % Current plot expanded state
        minFigureSize        % Minimum allowed figure size
        resizeInProgress     % Flag to prevent recursive resizing
    end
    
    methods
        function obj = ResponsiveLayoutManager(figureHandle)
            % Constructor initializes the layout manager
            obj.figureHandle = figureHandle;
            obj.componentsToResize = containers.Map();
            obj.resizeInProgress = false;
            obj.minFigureSize = [600, 400];  % Minimum width, height
            
            % Disable auto-resize to handle it manually first
            obj.figureHandle.AutoResizeChildren = 'off';
            
            % Then set up resize callback
            obj.figureHandle.SizeChangedFcn = @(src,evt) obj.handleResize(src,evt);
        end
        
        function registerStatusBar(obj, statusBar, helpButton)
            % Register status bar for responsive positioning
            obj.statusBar = statusBar;
            if nargin > 2
                obj.registerComponent('helpButton', helpButton, 'bottomRight');
            end
        end
        
        function registerPlotContainer(obj, plotContainer, isExpanded)
            % Register plot container for responsive sizing
            obj.plotContainer = plotContainer;
            obj.plotExpanded = isExpanded;
        end
        
        function registerComponent(obj, id, component, position)
            % Register a component for responsive positioning
            % position can be: 'bottomLeft', 'bottomRight', 'topLeft', 'topRight', 'fill'
            % or a function handle for custom positioning
            if ~isKey(obj.componentsToResize, id)
                obj.componentsToResize(id) = struct('component', component, 'position', position);
            else
                obj.componentsToResize(id).component = component;
                obj.componentsToResize(id).position = position;
            end
        end
        
        function setPlotExpandedState(obj, isExpanded)
            % Update plot expanded state
            obj.plotExpanded = isExpanded;
            obj.handleResize();  % Update layout
        end
    end
    
    methods (Access = private)
        function handleResize(obj, ~, ~)
            % Handle window resize event
            % Prevents recursive resizing
            if obj.resizeInProgress
                return;
            end
            
            obj.resizeInProgress = true;
            try
                % Enforce minimum figure size
                figPos = obj.figureHandle.Position;
                if figPos(3) < obj.minFigureSize(1) || figPos(4) < obj.minFigureSize(2)
                    newWidth = max(figPos(3), obj.minFigureSize(1));
                    newHeight = max(figPos(4), obj.minFigureSize(2));
                    obj.figureHandle.Position(3:4) = [newWidth, newHeight];
                end
                
                % Update status bar position
                obj.updateStatusBarPosition();
                
                % Update registered components
                obj.updateComponentPositions();
                
                % Update plot container if registered
                obj.updatePlotContainerLayout();
                
                % Force redraw
                drawnow limitrate;
            catch ME
                warning('ResponsiveLayoutManager:ResizeError', 'Error during resize: %s', ME.message);
            end
            
            obj.resizeInProgress = false;
        end
        
        function updateStatusBarPosition(obj)
            % Update status bar to match figure width
            if ~isempty(obj.statusBar) && isvalid(obj.statusBar)
                figWidth = obj.figureHandle.Position(3);
                statusHeight = 25;  % Fixed height
                obj.statusBar.Position = [0, 0, figWidth, statusHeight];
                
                % Update status text width
                statusTexts = findobj(obj.statusBar, 'Type', 'uilabel');
                if ~isempty(statusTexts)
                    statusTexts(1).Position(3) = figWidth - 80;  % Leave room for help button
                end
            end
        end
        
        function updateComponentPositions(obj)
            % Update positions of all registered components
            keys = obj.componentsToResize.keys;
            figPos = obj.figureHandle.Position;
            figWidth = figPos(3);
            figHeight = figPos(4);
            
            for i = 1:length(keys)
                id = keys{i};
                compInfo = obj.componentsToResize(id);
                
                % Skip if component is invalid
                if ~isvalid(compInfo.component)
                    continue;
                end
                
                % Get current position
                compPos = compInfo.component.Position;
                
                % Apply positioning strategy
                if ischar(compInfo.position)
                    switch compInfo.position
                        case 'bottomLeft'
                            compPos(1:2) = [5, 5];
                        case 'bottomRight'
                            compPos(1:2) = [figWidth - compPos(3) - 5, 5];
                        case 'topLeft'
                            compPos(1:2) = [5, figHeight - compPos(4) - 5];
                        case 'topRight'
                            compPos(1:2) = [figWidth - compPos(3) - 5, figHeight - compPos(4) - 5];
                        case 'fill'
                            compPos = [5, 5, figWidth-10, figHeight-10];
                    end
                elseif isa(compInfo.position, 'function_handle')
                    % Call custom positioning function
                    compPos = compInfo.position(figWidth, figHeight, compPos);
                end
                
                % Update position
                compInfo.component.Position = compPos;
            end
        end
        
        function updatePlotContainerLayout(obj)
            % Update plot container layout if registered
            if ~isempty(obj.plotContainer) && isvalid(obj.plotContainer) && ...
               isa(obj.plotContainer.Parent, 'uigridlayout')
                
                mainGrid = obj.plotContainer.Parent;
                figWidth = obj.figureHandle.Position(3);
                
                % Set column widths based on expanded state
                if obj.plotExpanded
                    % Wide plot area when expanded
                    if figWidth < 800
                        mainGrid.ColumnWidth = {'1.3x', '1x'};
                    else
                        mainGrid.ColumnWidth = {'1.5x', '1x'};
                    end
                else
                    % Narrow plot area when collapsed
                    mainGrid.ColumnWidth = {'1x', '0.2x'};
                end
            end
        end
    end
end 