classdef bookmarksview < matlab.apps.AppBase
    % bookmarksview - Position Bookmarks Management Application
    %
    % This MATLAB App provides a dedicated window for managing Z-stage position
    % bookmarks. It works in conjunction with the main foilview application to
    % provide position marking, navigation, and bookmark management capabilities.
    %
    % Key Features:
    %   - Mark current positions with custom labels
    %   - Navigate to saved positions with a single click
    %   - Delete unwanted bookmarks
    %   - Real-time position display
    %   - Integration with main foilview controller
    %
    % Usage:
    %   app = bookmarksview(controller);    % Launch with controller reference
    %   delete(app);                        % Clean shutdown when done
    
    %% Public Properties - UI Components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainLayout                  matlab.ui.container.GridLayout
        
        % Bookmark Controls
        MarkField                   matlab.ui.control.EditField
        MarkButton                  matlab.ui.control.Button
        PositionList                matlab.ui.control.ListBox
        GoToButton                  matlab.ui.control.Button
        DeleteButton                matlab.ui.control.Button
        
        % Status Display
        StatusLabel                 matlab.ui.control.Label
        CurrentPositionLabel        matlab.ui.control.Label
    end
    
    %% Private Properties - Controller Integration
    properties (Access = private)
        % Reference to main controller
        Controller                  foilview_controller
        
        % Update timer for position display
        UpdateTimer
    end
    
    %% Constructor and Destructor
    methods (Access = public)
        function app = bookmarksview(controller)
            % bookmarksview Constructor
            % 
            % Creates and initializes the Bookmarks Management application
            %
            % Args:
            %   controller - Reference to the main foilview_controller
            %
            % Initialization sequence:
            %   1. Store controller reference
            %   2. Create UI components
            %   3. Set up event handlers
            %   4. Initialize display
            %   5. Start update timer
            %   6. Register app with MATLAB
            
            if nargin < 1 || isempty(controller)
                error('bookmarksview:NoController', ...
                      'A foilview_controller instance is required');
            end
            
            % Store controller reference
            app.Controller = controller;
            
            % Create UI components
            app.createUIComponents();
            
            % Set up callbacks
            app.setupCallbacks();
            
            % Initialize display
            app.updateUI();
            
            % Start update timer for position display
            app.startUpdateTimer();
            
            % Register app
            registerApp(app, app.UIFigure);
            
            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            % bookmarksview Destructor
            %
            % Performs clean shutdown including:
            %   - Stopping update timer
            %   - Closing UI figure
            
            app.cleanup();
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
    
    %% UI Creation Methods
    methods (Access = private)
        function createUIComponents(app)
            % Create and configure all UI components
            
            % Main Figure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = 'Position Bookmarks (XYZ)';
            app.UIFigure.Position = [400 300 350 400];
            app.UIFigure.AutoResizeChildren = 'on';
            app.UIFigure.Resize = 'on';
            
            % Main Layout
            app.MainLayout = uigridlayout(app.UIFigure);
            app.MainLayout.ColumnWidth = {'1x'};
            app.MainLayout.RowHeight = {'fit', 'fit', 'fit', '1x', 'fit', 'fit'};
            app.MainLayout.Padding = [15 15 15 15];
            app.MainLayout.RowSpacing = 10;
            
            % Current Position Display
            app.CurrentPositionLabel = uilabel(app.MainLayout);
            app.CurrentPositionLabel.Text = 'Current: X:0.0, Y:0.0, Z:0.0 μm';
            app.CurrentPositionLabel.FontSize = 11;
            app.CurrentPositionLabel.FontWeight = 'bold';
            app.CurrentPositionLabel.HorizontalAlignment = 'center';
            app.CurrentPositionLabel.BackgroundColor = [0.95 0.95 0.95];
            app.CurrentPositionLabel.Layout.Row = 1;
            app.CurrentPositionLabel.Layout.Column = 1;
            
            % Mark new position section
            markLayout = uigridlayout(app.MainLayout);
            markLayout.ColumnWidth = {'1x', 'fit'};
            markLayout.RowHeight = {'fit'};
            markLayout.Layout.Row = 2;
            markLayout.Layout.Column = 1;
            markLayout.ColumnSpacing = 10;
            
            app.MarkField = uieditfield(markLayout, 'text');
            app.MarkField.Placeholder = 'Label (optional - auto-generated if empty)';
            app.MarkField.FontSize = 10;
            app.MarkField.Layout.Row = 1;
            app.MarkField.Layout.Column = 1;
            
            app.MarkButton = uibutton(markLayout, 'push');
            app.MarkButton.Text = 'MARK';
            app.MarkButton.FontSize = 10;
            app.MarkButton.FontWeight = 'bold';
            app.MarkButton.BackgroundColor = [0.2 0.6 0.9];
            app.MarkButton.FontColor = [1 1 1];
            app.MarkButton.Tooltip = 'Mark current XYZ position (auto-generates label if empty)';
            app.MarkButton.Layout.Row = 1;
            app.MarkButton.Layout.Column = 2;
            
            % Instructions
            instructLabel = uilabel(app.MainLayout);
            instructLabel.Text = 'Saved Positions:';
            instructLabel.FontSize = 10;
            instructLabel.FontWeight = 'bold';
            instructLabel.Layout.Row = 3;
            instructLabel.Layout.Column = 1;
            
            % Position List
            app.PositionList = uilistbox(app.MainLayout);
            app.PositionList.FontSize = 10;
            app.PositionList.FontName = 'Courier New';
            app.PositionList.Layout.Row = 4;
            app.PositionList.Layout.Column = 1;
            app.PositionList.Items = {};
            
            % Control buttons
            buttonLayout = uigridlayout(app.MainLayout);
            buttonLayout.ColumnWidth = {'1x', '1x'};
            buttonLayout.RowHeight = {'fit'};
            buttonLayout.Layout.Row = 5;
            buttonLayout.Layout.Column = 1;
            buttonLayout.ColumnSpacing = 10;
            
            app.GoToButton = uibutton(buttonLayout, 'push');
            app.GoToButton.Text = 'GO TO';
            app.GoToButton.FontSize = 10;
            app.GoToButton.FontWeight = 'bold';
            app.GoToButton.BackgroundColor = [0.2 0.7 0.3];
            app.GoToButton.FontColor = [1 1 1];
            app.GoToButton.Enable = 'off';
            app.GoToButton.Layout.Row = 1;
            app.GoToButton.Layout.Column = 1;
            
            app.DeleteButton = uibutton(buttonLayout, 'push');
            app.DeleteButton.Text = 'DELETE';
            app.DeleteButton.FontSize = 10;
            app.DeleteButton.FontWeight = 'bold';
            app.DeleteButton.BackgroundColor = [0.9 0.3 0.3];
            app.DeleteButton.FontColor = [1 1 1];
            app.DeleteButton.Enable = 'off';
            app.DeleteButton.Layout.Row = 1;
            app.DeleteButton.Layout.Column = 2;
            
            % Status Label
            app.StatusLabel = uilabel(app.MainLayout);
            app.StatusLabel.Text = 'Ready';
            app.StatusLabel.FontSize = 9;
            app.StatusLabel.HorizontalAlignment = 'center';
            app.StatusLabel.FontColor = [0.5 0.5 0.5];
            app.StatusLabel.Layout.Row = 6;
            app.StatusLabel.Layout.Column = 1;
            
            % Make figure visible
            app.UIFigure.Visible = 'on';
        end
        
        function setupCallbacks(app)
            % Set up all UI callback functions
            
            % Main window
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @app.onWindowClose, true);
            
            % Control callbacks
            app.MarkButton.ButtonPushedFcn = createCallbackFcn(app, @app.onMarkButtonPushed, true);
            app.PositionList.ValueChangedFcn = createCallbackFcn(app, @app.onPositionListChanged, true);
            app.GoToButton.ButtonPushedFcn = createCallbackFcn(app, @app.onGoToButtonPushed, true);
            app.DeleteButton.ButtonPushedFcn = createCallbackFcn(app, @app.onDeleteButtonPushed, true);
            
            % Enter key in mark field
            app.MarkField.ValueChangedFcn = createCallbackFcn(app, @app.onMarkFieldChanged, true);
        end
        
        function startUpdateTimer(app)
            % Start timer to update position display
            app.UpdateTimer = timer('ExecutionMode', 'fixedRate', ...
                                   'Period', 0.5, ...
                                   'TimerFcn', @(~,~) app.updatePositionDisplay());
            start(app.UpdateTimer);
        end
    end
    
    %% UI Update Methods
    methods (Access = private)
        function updateUI(app)
            % Update all UI elements
            app.updatePositionDisplay();
            app.updateBookmarksList();
            app.updateButtonStates();
        end
        
        function updatePositionDisplay(app)
            % Update current position display
            if ~isempty(app.Controller) && isvalid(app.Controller)
                try
                    currentX = app.Controller.CurrentXPosition;
                    currentY = app.Controller.CurrentYPosition;
                    currentZ = app.Controller.CurrentPosition;
                    app.CurrentPositionLabel.Text = sprintf('Current: X:%.1f, Y:%.1f, Z:%.1f μm', ...
                                                           currentX, currentY, currentZ);
                catch
                    app.CurrentPositionLabel.Text = 'Current: N/A';
                end
            end
        end
        
        function updateBookmarksList(app)
            % Update the bookmarks list display
            if ~isempty(app.Controller) && isvalid(app.Controller)
                try
                    bookmarks = app.Controller.MarkedPositions;
                    if isempty(bookmarks.Labels)
                        app.PositionList.Items = {};
                    else
                        items = cell(length(bookmarks.Labels), 1);
                        for i = 1:length(bookmarks.Labels)
                            label = bookmarks.Labels{i};
                            xPos = bookmarks.XPositions(i);
                            yPos = bookmarks.YPositions(i);
                            zPos = bookmarks.ZPositions(i);
                            
                            if isempty(label)
                                items{i} = sprintf('%d: X:%.1f, Y:%.1f, Z:%.1f μm', i, xPos, yPos, zPos);
                            else
                                items{i} = sprintf('%d: X:%.1f, Y:%.1f, Z:%.1f μm (%s)', i, xPos, yPos, zPos, label);
                            end
                        end
                        app.PositionList.Items = items;
                    end
                catch
                    app.PositionList.Items = {'Error loading bookmarks'};
                end
            end
            app.updateButtonStates();
        end
        
        function updateButtonStates(app)
            % Update button enable states based on selection
            hasSelection = ~isempty(app.PositionList.Value);
            app.GoToButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
            app.DeleteButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
        end
    end
    
    %% UI Event Handlers
    methods (Access = private)
        function onMarkButtonPushed(app, varargin)
            % Handle mark button press
            label = strtrim(app.MarkField.Value);
            
            % Auto-generate label if empty
            if isempty(label)
                label = app.generateAutoLabel();
            end
            
            try
                if isempty(app.Controller) || ~isvalid(app.Controller)
                    app.showStatus('Error: No controller connection', true);
                    return;
                end
                
                % Use the foilview_logic function for consistency
                foilview_logic.markCurrentPosition(app.UIFigure, app.Controller, label, ...
                    @() app.updateBookmarksList());
                
                % Clear the input field
                app.MarkField.Value = '';
                app.showStatus(sprintf('Position marked: %s', label));
                
            catch ME
                app.showStatus(sprintf('Error marking position: %s', ME.message), true);
            end
        end
        
        function onGoToButtonPushed(app, varargin)
            % Handle go to button press
            selectedValue = app.PositionList.Value;
            if ~isempty(selectedValue)
                try
                    % Extract index from the selected item
                    index = app.getSelectedIndex();
                    if ~isempty(index)
                        foilview_logic.goToMarkedPosition(app.Controller, index);
                        app.showStatus(sprintf('Moving to position %d', index));
                    end
                catch ME
                    app.showStatus(sprintf('Error moving to position: %s', ME.message), true);
                end
            end
        end
        
        function onDeleteButtonPushed(app, varargin)
            % Handle delete button press
            selectedValue = app.PositionList.Value;
            if ~isempty(selectedValue)
                try
                    % Extract index from the selected item
                    index = app.getSelectedIndex();
                    if ~isempty(index)
                        foilview_logic.deleteMarkedPosition(app.Controller, index, ...
                            @() app.updateBookmarksList());
                        app.showStatus(sprintf('Deleted position %d', index));
                    end
                catch ME
                    app.showStatus(sprintf('Error deleting position: %s', ME.message), true);
                end
            end
        end
        
        function onPositionListChanged(app, varargin)
            % Handle position list selection change
            app.updateButtonStates();
        end
        
        function onMarkFieldChanged(app, varargin)
            % Handle enter key in mark field (same as clicking mark button)
            % Now works even with empty field since auto-generation is available
            app.onMarkButtonPushed();
        end
        
        function onWindowClose(app, varargin)
            % Handle window close
            app.cleanup();
            delete(app);
        end
    end
    
    %% Helper Methods
    methods (Access = private)
        function index = getSelectedIndex(app)
            % Extract the index number from the selected list item
            selectedValue = app.PositionList.Value;
            if isempty(selectedValue)
                index = [];
                return;
            end
            
            % Parse the index from the beginning of the string (format: "1: ...")
            tokens = regexp(selectedValue, '^(\d+):', 'tokens');
            if ~isempty(tokens)
                index = str2double(tokens{1}{1});
            else
                index = [];
            end
        end
        
        function showStatus(app, message, isError)
            % Show status message with optional error styling
            if nargin < 3
                isError = false;
            end
            
            app.StatusLabel.Text = message;
            if isError
                app.StatusLabel.FontColor = [0.8 0.2 0.2];
            else
                app.StatusLabel.FontColor = [0.2 0.6 0.2];
            end
            
            % Reset color after a delay
            pause(0.1);
            drawnow;
            timer('StartDelay', 3, 'TimerFcn', @(~,~) app.resetStatus(), ...
                  'ExecutionMode', 'singleShot');
        end
        
        function resetStatus(app)
            % Reset status label to default
            if isvalid(app.StatusLabel)
                app.StatusLabel.Text = 'Ready';
                app.StatusLabel.FontColor = [0.5 0.5 0.5];
            end
        end
        
        function label = generateAutoLabel(app)
            % Generate an auto-numbered bookmark label
            if ~isempty(app.Controller) && isvalid(app.Controller)
                existingLabels = app.Controller.MarkedPositions.Labels;
                
                % Find the next available bookmark number
                bookmarkNum = 1;
                while true
                    candidateLabel = sprintf('Bookmark %d', bookmarkNum);
                    
                    % Check if this label already exists
                    if ~any(strcmp(existingLabels, candidateLabel))
                        label = candidateLabel;
                        break;
                    end
                    
                    bookmarkNum = bookmarkNum + 1;
                    
                    % Safety check to prevent infinite loop
                    if bookmarkNum > 1000
                        label = sprintf('Bookmark %d_%s', bookmarkNum, datestr(now, 'HHMMSS'));
                        break;
                    end
                end
            else
                % Fallback if controller not available
                label = sprintf('Bookmark %s', datestr(now, 'HH:MM:SS'));
            end
        end
        
        function cleanup(app)
            % Clean up resources
            
            % Stop update timer
            if ~isempty(app.UpdateTimer) && isvalid(app.UpdateTimer)
                stop(app.UpdateTimer);
                delete(app.UpdateTimer);
                app.UpdateTimer = [];
            end
        end
    end
end 