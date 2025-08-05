%==============================================================================
% TOOLSWINDOW.M
%==============================================================================
% Tools window UI class for Foilview application.
%
% This class implements the tools window, providing access to advanced
% features, diagnostics, and developer utilities within the Foilview
% application. It is designed for extensibility and integration with the
% main application UI.
%
% Key Features:
%   - Access to advanced and developer tools
%   - Diagnostic and logging utilities
%   - Integration with main application UI
%   - Extensible layout for future tools
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
%   toolsWin = ToolsWindow(app);
%
%==============================================================================

classdef ToolsWindow < handle
    % TOOLS WINDOW - Separate window for FoilView tools and utilities
    %
    % RESPONSIBILITY: Standalone tools window management
    % - Creates and manages a separate tools window
    % - Handles tool button interactions
    % - Maintains window positioning relative to main window
    % - Provides toggle functionality for show/hide
    %
    % TOOLS INCLUDED:
    % - Bookmarks: Toggle bookmarks view
    % - Camera: Toggle stage view/camera
    % - Joystick: Toggle MJC3 joystick control
    % - Refresh: Refresh position and status
    % - Metadata: Toggle metadata logging
    
    properties (Access = private)
        UIFigure
        MainPanel
        ToolsGrid
        IsVisible = false
        MainWindowHandle
    end
    
    properties (Access = public)
        % Tool button references for external access
        ShowFoilViewButton
        BookmarksButton
        StageViewButton
        MJC3Button
        RefreshButton
        MetadataButton
        
        % View app references
        BookmarksViewApp
        StageViewApp
        MJC3ViewApp
    end
    
    methods
        function obj = ToolsWindow(mainWindowHandle)
            % Constructor - creates the tools window
            if nargin > 0
                obj.MainWindowHandle = mainWindowHandle;
            end
            obj.createToolsWindow();
        end
        
        function show(obj)
            % Show the tools window
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                obj.positionRelativeToMain(); % Position before showing
                obj.UIFigure.Visible = 'on';
                obj.IsVisible = true;
            end
        end
        
        function hide(obj)
            % Hide the tools window
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                obj.UIFigure.Visible = 'off';
                obj.IsVisible = false;
            end
        end
        
        function toggle(obj)
            % Toggle tools window visibility
            if obj.IsVisible
                obj.hide();
            else
                obj.show();
            end
        end
        
        function visible = isVisible(obj)
            % Check if tools window is visible
            visible = obj.IsVisible && ~isempty(obj.UIFigure) && isvalid(obj.UIFigure) && strcmp(obj.UIFigure.Visible, 'on');
        end
        
        function updatePosition(obj)
            % Update position relative to main window (called when main window moves)
            if obj.IsVisible
                obj.positionRelativeToMain();
            end
        end
        
        function pos = getPosition(obj)
            % Get the current position of the tools window
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                pos = obj.UIFigure.Position;
            else
                pos = [0 0 0 0];
            end
        end
        
        function delete(obj)
            % Cleanup when object is deleted
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                delete(obj.UIFigure);
            end
        end
        
        % ===== CALLBACK METHODS =====
        function onShowFoilViewButtonPressed(obj, ~, ~)
            % Callback for Show FoilView button
            try
                % Show the main FoilView interface
                if ~isempty(obj.MainWindowHandle) && isvalid(obj.MainWindowHandle)
                    obj.MainWindowHandle.Visible = 'on';
                    % Update button text to indicate it's now open
                    obj.ShowFoilViewButton.Text = '🚀 FoilView Open';
                end
            catch ME
                FoilviewUtils.logException('ToolsWindow.onShowFoilViewButtonPressed', ME);
            end
        end
        
        function onBookmarksButtonPressed(obj, ~, ~)
            % Callback for Bookmarks button
            try
                % Toggle bookmarks view
                if isempty(obj.BookmarksViewApp) || ~isvalid(obj.BookmarksViewApp)
                    obj.BookmarksViewApp = BookmarksView();
                    obj.BookmarksViewApp.show();
                else
                    if obj.BookmarksViewApp.isVisible()
                        obj.BookmarksViewApp.hide();
                    else
                        obj.BookmarksViewApp.show();
                    end
                end
            catch ME
                FoilviewUtils.logException('ToolsWindow.onBookmarksButtonPressed', ME);
            end
        end
        
        function onStageViewButtonPressed(obj, ~, ~)
            % Callback for Stage View button
            try
                % Toggle stage view
                if isempty(obj.StageViewApp) || ~isvalid(obj.StageViewApp)
                    obj.StageViewApp = StageView();
                    obj.StageViewApp.show();
                else
                    if obj.StageViewApp.isVisible()
                        obj.StageViewApp.hide();
                    else
                        obj.StageViewApp.show();
                    end
                end
            catch ME
                FoilviewUtils.logException('ToolsWindow.onStageViewButtonPressed', ME);
            end
        end
        
        function onMJC3ButtonPressed(obj, ~, ~)
            % Callback for MJC3 Joystick button
            try
                % Toggle MJC3 joystick control
                if isempty(obj.MJC3ViewApp) || ~isvalid(obj.MJC3ViewApp)
                    obj.MJC3ViewApp = MJC3View();
                    obj.MJC3ViewApp.show();
                else
                    if obj.MJC3ViewApp.isVisible()
                        obj.MJC3ViewApp.hide();
                    else
                        obj.MJC3ViewApp.show();
                    end
                end
            catch ME
                FoilviewUtils.logException('ToolsWindow.onMJC3ButtonPressed', ME);
            end
        end
        
        function onRefreshButtonPressed(obj, ~, ~)
            % Callback for Refresh button
            try
                % Refresh position and status
                FoilviewUtils.logInfo('ToolsWindow: Refreshing position and status...');
                % Add refresh logic here
            catch ME
                FoilviewUtils.logException('ToolsWindow.onRefreshButtonPressed', ME);
            end
        end
        
        function onMetadataButtonPressed(obj, ~, ~)
            % Callback for Metadata button
            try
                % Toggle metadata logging
                FoilviewUtils.logInfo('ToolsWindow: Toggling metadata logging...');
                % Add metadata toggle logic here
            catch ME
                FoilviewUtils.logException('ToolsWindow.onMetadataButtonPressed', ME);
            end
        end
    end
    
    methods (Access = private)
        function createToolsWindow(obj)
            % Create the tools window UI
            obj.createMainFigure();
            obj.createMainPanel();
            obj.createToolsLayout();
            obj.createToolButtons();
        end
        
        function createMainFigure(obj)
            % Create the main figure for tools window
            obj.UIFigure = uifigure('Visible', 'off');
            obj.UIFigure.Units = 'pixels';
            obj.UIFigure.Position = [100 100 UiComponents.TOOLS_WINDOW_WIDTH UiComponents.TOOLS_WINDOW_HEIGHT]; % Temporary position
            obj.UIFigure.Name = 'FoilView - Main Interface';
            obj.UIFigure.Color = UiComponents.COLORS.Background;
            obj.UIFigure.Resize = 'off';  % Fixed size tools window
            obj.UIFigure.WindowStyle = 'normal';
            obj.UIFigure.MenuBar = 'none';
            obj.UIFigure.ToolBar = 'none';
            obj.UIFigure.CloseRequestFcn = @(~,~) obj.hide(); % Hide instead of close
        end
        
        function createMainPanel(obj)
            % Create the main panel
            obj.MainPanel = uipanel(obj.UIFigure);
            obj.MainPanel.Units = 'normalized';
            obj.MainPanel.Position = [0, 0, 1, 1];
            obj.MainPanel.BorderType = 'none';
            obj.MainPanel.BackgroundColor = UiComponents.COLORS.Background;
            obj.MainPanel.AutoResizeChildren = 'on';
        end
        
        function createToolsLayout(obj)
            % Create the grid layout for tools
            obj.ToolsGrid = uigridlayout(obj.MainPanel, [4, 2]); % 4 rows, 2 columns
            obj.ToolsGrid.RowHeight = {'1x', '1x', '1x', '1x'};
            obj.ToolsGrid.ColumnWidth = {'1x', '1x'};
            obj.ToolsGrid.Padding = UiComponents.STANDARD_PADDING;
            obj.ToolsGrid.RowSpacing = UiComponents.STANDARD_SPACING;
            obj.ToolsGrid.ColumnSpacing = UiComponents.STANDARD_SPACING;
        end
        
        function createToolButtons(obj)
            % Create all tool buttons
            
            % Row 1: Main FoilView Interface (spans both columns, very prominent)
            obj.ShowFoilViewButton = obj.createToolButton('🚀 Launch FoilView', 'Open Main FoilView Interface', 1, [1 2]);
            obj.ShowFoilViewButton.FontSize = UiComponents.CONTROL_FONT_SIZE + 4; % Make it very prominent
            UiComponents.applyButtonStyle(obj.ShowFoilViewButton, 'success'); % Green color
            obj.ShowFoilViewButton.ButtonPushedFcn = @(src, event) obj.onShowFoilViewButtonPressed(src, event);
            
            % Row 2: Bookmarks and Camera
            obj.BookmarksButton = obj.createToolButton('📍 Bookmarks', 'Toggle Bookmarks (Open/Close)', 2, 1);
            obj.BookmarksButton.ButtonPushedFcn = @(src, event) obj.onBookmarksButtonPressed(src, event);
            
            obj.StageViewButton = obj.createToolButton('📷 Camera', 'Toggle Camera (Open/Close)', 2, 2);
            obj.StageViewButton.ButtonPushedFcn = @(src, event) obj.onStageViewButtonPressed(src, event);
            
            % Row 3: Joystick and Refresh
            obj.MJC3Button = obj.createToolButton('🕹️ Joystick', 'Toggle MJC3 Joystick Control (Open/Close)', 3, 1);
            obj.MJC3Button.ButtonPushedFcn = @(src, event) obj.onMJC3ButtonPressed(src, event);
            
            obj.RefreshButton = obj.createToolButton('↻ Refresh', 'Refresh position and status', 3, 2);
            obj.RefreshButton.ButtonPushedFcn = @(src, event) obj.onRefreshButtonPressed(src, event);
            
            % Row 4: Metadata (centered, spans both columns)
            obj.MetadataButton = obj.createToolButton('⚙ Metadata', 'Metadata Logging', 4, [1 2]);
            obj.MetadataButton.ButtonPushedFcn = @(src, event) obj.onMetadataButtonPressed(src, event);
        end
        
        function button = createToolButton(obj, text, tooltip, row, column)
            % Create a standardized tool button
            button = uibutton(obj.ToolsGrid, 'push');
            button.Text = text;
            button.FontSize = UiComponents.CONTROL_FONT_SIZE;
            button.FontWeight = 'bold';
            button.Tooltip = tooltip;
            button.Layout.Row = row;
            button.Layout.Column = column;
            
            % Apply consistent styling
            UiComponents.applyButtonStyle(button, 'primary');
        end
        
        function positionRelativeToMain(obj)
            % Position tools window relative to main window or center if main is hidden
            if isempty(obj.MainWindowHandle) || ~isvalid(obj.MainWindowHandle)
                obj.centerOnScreen();
                return;
            end
            
            try
                % If main window is visible, position relative to it
                if strcmp(obj.MainWindowHandle.Visible, 'on')
                    mainPos = obj.MainWindowHandle.Position;
                    toolsWidth = UiComponents.TOOLS_WINDOW_WIDTH;
                    toolsHeight = UiComponents.TOOLS_WINDOW_HEIGHT;
                    
                    % Position to the right of main window with some spacing
                    newX = mainPos(1) + mainPos(3) + UiComponents.TOOLS_WINDOW_OFFSET;
                    newY = mainPos(2) + (mainPos(4) - toolsHeight) / 2; % Center vertically
                    
                    obj.UIFigure.Position = [newX newY toolsWidth toolsHeight];
                else
                    % If main window is hidden, center tools window on screen
                    obj.centerOnScreen();
                end
            catch
                % If positioning fails, center on screen
                obj.centerOnScreen();
            end
        end
        
        function centerOnScreen(obj)
            % Center the tools window on screen
            if ~isvalid(obj.UIFigure)
                return;
            end
            
            try
                screenSize = get(0, 'ScreenSize');
                centerX = (screenSize(3) - UiComponents.TOOLS_WINDOW_WIDTH) / 2;
                centerY = (screenSize(4) - UiComponents.TOOLS_WINDOW_HEIGHT) / 2;
                
                obj.UIFigure.Position = [centerX centerY UiComponents.TOOLS_WINDOW_WIDTH UiComponents.TOOLS_WINDOW_HEIGHT];
            catch
                % If centering fails, use default position
            end
        end
    end
end