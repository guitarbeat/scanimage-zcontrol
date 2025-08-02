%==============================================================================
% BOOKMARKSVIEW.M
%==============================================================================
% Bookmarks view UI class for Foilview application.
%
% This class implements the bookmarks view, providing visualization and
% management of position bookmarks within the Foilview application. It
% supports adding, removing, and navigating to bookmarks, as well as
% integration with controller and service layers.
%
% Key Features:
%   - Visualization and management of position bookmarks
%   - Add, remove, and navigate to bookmarks
%   - Integration with controller and service layers
%   - UI layout and style management
%
% Dependencies:
%   - BookmarkManager: Bookmark storage and retrieval
%   - FoilviewController: Main controller
%   - MATLAB App Designer: UI components
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   view = BookmarksView(app, controller);
%
%==============================================================================

classdef BookmarksView < handle
    % Manages the Position Bookmarks window (XYZ)

    properties (Access = public)
        UIFigure
    end

    properties (Access = private)
        Controller
        UpdateTimer
        
        % UI Components
        MainLayout
        CurrentPositionLabel
        MarkField
        MarkButton
        PositionList
        GoToButton
        DeleteButton
        StatusLabel
        
        % * Debounce flag to prevent double mark
        IsMarking logical = false;
    end

    methods
        function obj = BookmarksView(controller)
            % Constructor: Creates the Bookmarks window and initializes components
            if nargin < 1 || isempty(controller)
                error('BookmarksView:NoController', 'A valid controller instance is required.');
            end
            obj.Controller = controller;

            obj.createUI();
            obj.setupCallbacks();
            obj.updateUI();
            obj.startUpdateTimer();
        end

        function delete(obj)
            % Destructor: Cleans up all resources
            obj.stopUpdateTimer();

            % Delete the figure if it exists and is valid, breaking recursion
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                obj.UIFigure.CloseRequestFcn = ''; % Prevent recursion
                delete(obj.UIFigure);
            end
        end
    end

    methods (Access = private)
        function createUI(obj)
            % Create and configure all bookmarks UI components

            % Main Figure
            obj.UIFigure = uifigure('Visible', 'off');
            obj.UIFigure.Name = 'Position Bookmarks (XYZ)';
            obj.UIFigure.Position = [400 300 350 400];
            obj.UIFigure.AutoResizeChildren = 'on';
            obj.UIFigure.Resize = 'on';

            % Main Layout
            obj.MainLayout = uigridlayout(obj.UIFigure);
            obj.MainLayout.ColumnWidth = {'1x'};
            obj.MainLayout.RowHeight = {'fit', 'fit', 'fit', '1x', 'fit', 'fit'};
            obj.MainLayout.Padding = [15 15 15 15];
            obj.MainLayout.RowSpacing = 10;

            % Current Position Display
            obj.CurrentPositionLabel = uilabel(obj.MainLayout);
            obj.CurrentPositionLabel.Text = 'Current: X:0.0, Y:0.0, Z:0.0 μm';
            obj.CurrentPositionLabel.FontSize = 11;
            obj.CurrentPositionLabel.FontWeight = 'bold';
            obj.CurrentPositionLabel.HorizontalAlignment = 'center';
            obj.CurrentPositionLabel.BackgroundColor = [0.95 0.95 0.95];
            obj.CurrentPositionLabel.Layout.Row = 1;
            obj.CurrentPositionLabel.Layout.Column = 1;

            % Mark new position section
            markLayout = uigridlayout(obj.MainLayout);
            markLayout.ColumnWidth = {'1x', 'fit'};
            markLayout.RowHeight = {'fit'};
            markLayout.Layout.Row = 2;
            markLayout.Layout.Column = 1;
            markLayout.ColumnSpacing = 10;

            obj.MarkField = uieditfield(markLayout, 'text');
            obj.MarkField.Placeholder = 'Label (optional - auto-generated if empty)';
            obj.MarkField.FontSize = 10;
            obj.MarkField.Layout.Row = 1;
            obj.MarkField.Layout.Column = 1;

            obj.MarkButton = uibutton(markLayout, 'push');
            obj.MarkButton.Tooltip = 'Mark current XYZ position (auto-generates label if empty)';
            obj.MarkButton.Layout.Row = 1;
            obj.MarkButton.Layout.Column = 2;
            obj.MarkButton.BackgroundColor = [0.2 0.6 0.9];  % primary color
            obj.MarkButton.FontColor = [1 1 1];  % white text
            obj.MarkButton.Text = 'MARK';
            obj.MarkButton.FontSize = 10;
            obj.MarkButton.FontWeight = 'bold';

            % Instructions
            instructLabel = uilabel(obj.MainLayout);
            instructLabel.Text = 'Saved Positions:';
            instructLabel.FontSize = 10;
            instructLabel.FontWeight = 'bold';
            instructLabel.Layout.Row = 3;
            instructLabel.Layout.Column = 1;

            % Position List
            obj.PositionList = uilistbox(obj.MainLayout);
            obj.PositionList.FontSize = 10;
            obj.PositionList.FontName = 'Courier New';
            obj.PositionList.Layout.Row = 4;
            obj.PositionList.Layout.Column = 1;
            obj.PositionList.Items = {};

            % Control buttons
            buttonLayout = uigridlayout(obj.MainLayout);
            buttonLayout.ColumnWidth = {'1x', '1x'};
            buttonLayout.RowHeight = {'fit'};
            buttonLayout.Layout.Row = 5;
            buttonLayout.Layout.Column = 1;
            buttonLayout.ColumnSpacing = 10;

            obj.GoToButton = uibutton(buttonLayout, 'push');
            obj.GoToButton.Enable = 'off';
            obj.GoToButton.Layout.Row = 1;
            obj.GoToButton.Layout.Column = 1;
            obj.GoToButton.BackgroundColor = [0.2 0.7 0.3];  % success color
            obj.GoToButton.FontColor = [1 1 1];  % white text
            obj.GoToButton.Text = 'GO TO';
            obj.GoToButton.FontSize = 10;
            obj.GoToButton.FontWeight = 'bold';

            obj.DeleteButton = uibutton(buttonLayout, 'push');
            obj.DeleteButton.Enable = 'off';
            obj.DeleteButton.Layout.Row = 1;
            obj.DeleteButton.Layout.Column = 2;
            obj.DeleteButton.BackgroundColor = [0.9 0.3 0.3];  % danger color
            obj.DeleteButton.FontColor = [1 1 1];  % white text
            obj.DeleteButton.Text = 'DELETE';
            obj.DeleteButton.FontSize = 10;
            obj.DeleteButton.FontWeight = 'bold';

            % Status Label
            obj.StatusLabel = uilabel(obj.MainLayout);
            obj.StatusLabel.Text = 'Ready';
            obj.StatusLabel.FontSize = 9;
            obj.StatusLabel.HorizontalAlignment = 'center';
            obj.StatusLabel.FontColor = [0.5 0.5 0.5];
            obj.StatusLabel.Layout.Row = 6;
            obj.StatusLabel.Layout.Column = 1;

            % Make figure visible
            obj.UIFigure.Visible = 'on';
        end

        function setupCallbacks(obj)
            % Set up all UI callback functions

            % Main window
            obj.UIFigure.CloseRequestFcn = @(~,~) delete(obj);

            % Control callbacks
            obj.MarkButton.ButtonPushedFcn = @(~,~) obj.onMarkButtonPushed();
            obj.PositionList.ValueChangedFcn = @(~,~) obj.onPositionListChanged();
            obj.GoToButton.ButtonPushedFcn = @(~,~) obj.onGoToButtonPushed();
            obj.DeleteButton.ButtonPushedFcn = @(~,~) obj.onDeleteButtonPushed();

            % Enter key in mark field
            obj.MarkField.ValueChangedFcn = @(~,~) obj.onMarkFieldChanged();
        end

        function updateUI(obj)
            % Update all UI elements
            obj.updatePositionDisplay();
            obj.updateBookmarksList();
            obj.updateButtonStates();
        end

        function updatePositionDisplay(obj)
            % Update current position display
            if ~isempty(obj.Controller) && isvalid(obj.Controller)
                try
                    currentX = obj.Controller.CurrentXPosition;
                    currentY = obj.Controller.CurrentYPosition;
                    currentZ = obj.Controller.CurrentPosition;
                    obj.CurrentPositionLabel.Text = sprintf('Current: X:%.1f, Y:%.1f, Z:%.1f μm', ...
                        currentX, currentY, currentZ);
                catch
                    obj.CurrentPositionLabel.Text = 'Current: N/A';
                end
            end
        end

        function updateBookmarksList(obj)
            % Update the bookmarks list display
            if ~isempty(obj.Controller) && isvalid(obj.Controller)
                try
                    bookmarks = obj.Controller.BookmarkManager.MarkedPositions;
                    if isempty(bookmarks.Labels)
                        obj.PositionList.Items = {};
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
                        obj.PositionList.Items = items;
                    end
                catch
                    obj.PositionList.Items = {'Error loading bookmarks'};
                end
            end
            obj.updateButtonStates();
        end

        function updateButtonStates(obj)
            % Update button enable states based on selection
            hasSelection = ~isempty(obj.PositionList.Value);
            obj.GoToButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
            obj.DeleteButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
        end

        function onMarkButtonPushed(obj)
            % * Debounce: prevent double-trigger
            if obj.IsMarking
                return;
            end
            obj.IsMarking = true;
            cleanupObj = onCleanup(@() setMarkingFalse(obj));
            label = strtrim(obj.MarkField.Value);

            % Auto-generate label if empty
            if isempty(label)
                label = obj.generateAutoLabel();
            end

            try
                if isempty(obj.Controller) || ~isvalid(obj.Controller)
                    obj.showStatus('Error: No controller connection', true);
                    return;
                end

                % Use the controller's validation function for consistency
                obj.Controller.markCurrentPositionWithValidation(obj.UIFigure, label, ...
                    @() obj.updateBookmarksList());

                % Clear the input field
                obj.MarkField.Value = '';
                obj.showStatus(sprintf('Position marked: %s', label));

            catch ME
                obj.showStatus(sprintf('Error: %s', ME.message), true);
            end
        end

        function onGoToButtonPushed(obj)
            % Handle go to button press
            obj.goToSelectedBookmark();
        end

        function onDeleteButtonPushed(obj)
            % Handle delete button press
            obj.deleteSelectedBookmark();
        end

        function onPositionListChanged(obj)
            % Handle position list selection change
            obj.updateButtonStates();
        end

        function onMarkFieldChanged(obj)
            % If user presses enter in the mark field, treat as button push
            obj.onMarkButtonPushed();
        end

        function startUpdateTimer(obj)
            % Start a timer to periodically update the UI
            obj.UpdateTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', 1, ... % Update every second
                'TimerFcn', @(~,~) obj.updateUI());
            start(obj.UpdateTimer);
        end

        function stopUpdateTimer(obj)
            % Stop and delete the update timer
            if ~isempty(obj.UpdateTimer) && isvalid(obj.UpdateTimer)
                stop(obj.UpdateTimer);
                delete(obj.UpdateTimer);
                obj.UpdateTimer = [];
            end
        end

        function showStatus(obj, message, isError)
            % Show status message with optional error styling
            if nargin < 3
                isError = false;
            end

            obj.StatusLabel.Text = message;
            if isError
                obj.StatusLabel.FontColor = [0.8 0.2 0.2];
            else
                obj.StatusLabel.FontColor = [0.2 0.6 0.2];
            end

            % Reset color after a delay
            pause(0.1);
            drawnow;
            resetTimer = timer('StartDelay', 3, 'TimerFcn', @(~,~) obj.resetStatus(), 'ExecutionMode', 'singleShot');
            start(resetTimer);
        end

        function resetStatus(obj)
            % Reset status label to default
            if isvalid(obj.StatusLabel)
                obj.StatusLabel.Text = 'Ready';
                obj.StatusLabel.FontColor = [0.5 0.5 0.5];
            end
        end

        function label = generateAutoLabel(obj)
            % Generate an auto-numbered bookmark label
            if ~isempty(obj.Controller) && isvalid(obj.Controller)
                existingLabels = obj.Controller.BookmarkManager.getLabels();

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
                        label = sprintf('Bookmark %d_%s', bookmarkNum, datetime('now', 'Format', 'HHmmss'));
                        break;
                    end
                end
            else
                % Fallback if controller not available
                label = sprintf('Bookmark %s', datetime('now', 'Format', 'HH:mm:ss'));
            end
        end

        function index = getSelectedIndex(obj)
            % Extract the index number from the selected list item
            selectedValue = obj.PositionList.Value;
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

        function goToSelectedBookmark(obj)
            % Handle go to button press
            if ~isempty(obj.PositionList.Value)
                try
                    % Extract index from the selected item
                    index = obj.getSelectedIndex();
                    if ~isempty(index)
                        obj.Controller.goToMarkedPositionWithValidation(index);
                        obj.showStatus(sprintf('Moving to position %d', index));
                    end
                catch ME
                    obj.showStatus(sprintf('Error moving to position: %s', ME.message), true);
                end
            end
        end

        function deleteSelectedBookmark(obj)
            % Handle delete button press
            if ~isempty(obj.PositionList.Value)
                try
                    % Extract index from the selected item
                    index = obj.getSelectedIndex();
                    if ~isempty(index)
                        obj.Controller.deleteMarkedPositionWithValidation(index, ...
                            @() obj.updateBookmarksList());
                        obj.showStatus(sprintf('Deleted position %d', index));
                    end
                catch ME
                    obj.showStatus(sprintf('Error deleting position: %s', ME.message), true);
                end
            end
        end
    end
end

% * Helper function to reset debounce flag
function setMarkingFalse(obj)
    if isvalid(obj)
        obj.IsMarking = false;
    end
end
