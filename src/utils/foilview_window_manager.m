classdef foilview_window_manager < handle
    % foilview_window_manager - Manages additional windows for foilview
    %
    % This class handles all operations related to additional windows such as
    % the Stage View and Bookmarks View, including creation, positioning,
    % toggling visibility, and cleanup.
    
    properties (Access = private)
        ParentApp               % Reference to main foilview app
        StageViewApp            % Stage view window instance
        BookmarksViewApp        % Bookmarks view window instance
    end
    
    methods
        function obj = foilview_window_manager(parentApp)
            % Constructor
            obj.ParentApp = parentApp;
            obj.StageViewApp = [];
            obj.BookmarksViewApp = [];
        end
        
        function launchStageView(obj)
            % Launch the Stage View window
            try
                obj.StageViewApp = stageview();
                obj.positionStageViewWindow();
            catch ME
                warning('foilview:StageViewLaunch', ...
                       'Failed to launch Stage View: %s', ME.message);
                obj.StageViewApp = [];
            end
            obj.updateWindowStatusButtons();
        end
        
        function launchBookmarksView(obj)
            % Launch the Bookmarks View window
            try
                obj.BookmarksViewApp = bookmarksview(obj.ParentApp.Controller);
                obj.positionBookmarksViewWindow();
            catch ME
                warning('foilview:BookmarksViewLaunch', ...
                       'Failed to launch Bookmarks View: %s', ME.message);
                obj.BookmarksViewApp = [];
            end
            obj.updateWindowStatusButtons();
        end
        
        function toggleStageView(obj)
            % Toggle Stage View window visibility
            try
                if obj.isStageViewValid()
                    if obj.isStageViewVisible()
                        delete(obj.StageViewApp);
                        obj.StageViewApp = [];
                    else
                        obj.showStageView();
                    end
                else
                    obj.launchStageView();
                end
            catch ME
                obj.handleStageViewError(ME);
            end
            obj.updateWindowStatusButtons();
        end
        
        function toggleBookmarksView(obj)
            % Toggle Bookmarks View window visibility
            if obj.isBookmarksViewValid()
                if obj.isBookmarksViewVisible()
                    delete(obj.BookmarksViewApp);
                    obj.BookmarksViewApp = [];
                else
                    obj.showBookmarksView();
                end
            else
                obj.launchBookmarksView();
            end
            obj.updateWindowStatusButtons();
        end
        
        function updateWindowStatusButtons(obj)
            % Update window status indicator buttons
            if isempty(obj.ParentApp.StatusControls)
                return;
            end
            
            bookmarksActive = obj.isBookmarksViewActive();
            stageViewActive = obj.isStageViewActive();
            
            % Update buttons using centralized styling
            foilview_styling.styleWindowIndicator(obj.ParentApp.StatusControls.BookmarksButton, ...
                bookmarksActive, ...
                foilview_constants.BOOKMARKS_ICON_INACTIVE, ...
                foilview_constants.BOOKMARKS_ICON_ACTIVE, ...
                foilview_constants.BOOKMARKS_ICON_TOOLTIP);
            
            foilview_styling.styleWindowIndicator(obj.ParentApp.StatusControls.StageViewButton, ...
                stageViewActive, ...
                foilview_constants.STAGE_VIEW_ICON_INACTIVE, ...
                foilview_constants.STAGE_VIEW_ICON_ACTIVE, ...
                foilview_constants.STAGE_VIEW_ICON_TOOLTIP);
        end
        
        function cleanup(obj)
            % Clean up all managed windows
            if obj.isStageViewValid()
                delete(obj.StageViewApp);
            end
            if obj.isBookmarksViewValid()
                delete(obj.BookmarksViewApp);
            end
            obj.StageViewApp = [];
            obj.BookmarksViewApp = [];
        end
        
        function launchAllWindows(obj)
            % Launch both additional windows during initialization
            obj.launchStageView();
            obj.launchBookmarksView();
        end
    end
    
    methods (Access = private)
        function positionStageViewWindow(obj)
            % Position stage view window relative to main window
            if ~obj.isStageViewValid()
                return;
            end
            
            mainPos = obj.ParentApp.UIFigure.Position;
            obj.StageViewApp.UIFigure.Position(1) = mainPos(1) + mainPos(3) + foilview_constants.WINDOW_SPACING;
            obj.StageViewApp.UIFigure.Position(2) = mainPos(2);
        end
        
        function positionBookmarksViewWindow(obj)
            % Position bookmarks view window relative to main window
            if ~obj.isBookmarksViewValid()
                return;
            end
            
            mainPos = obj.ParentApp.UIFigure.Position;
            bookmarksPos = obj.BookmarksViewApp.UIFigure.Position;
            obj.BookmarksViewApp.UIFigure.Position(1) = mainPos(1) - bookmarksPos(3) - foilview_constants.WINDOW_SPACING;
            obj.BookmarksViewApp.UIFigure.Position(2) = mainPos(2);
        end
        
        function valid = isStageViewValid(obj)
            % Check if stage view window is valid
            valid = ~isempty(obj.StageViewApp) && ...
                   isvalid(obj.StageViewApp) && ...
                   ~isempty(obj.StageViewApp.UIFigure) && ...
                   isvalid(obj.StageViewApp.UIFigure);
        end
        
        function valid = isBookmarksViewValid(obj)
            % Check if bookmarks view window is valid
            valid = ~isempty(obj.BookmarksViewApp) && ...
                   isvalid(obj.BookmarksViewApp) && ...
                   ~isempty(obj.BookmarksViewApp.UIFigure) && ...
                   isvalid(obj.BookmarksViewApp.UIFigure);
        end
        
        function visible = isStageViewVisible(obj)
            % Check if stage view window is visible
            visible = obj.isStageViewValid() && ...
                     strcmp(obj.StageViewApp.UIFigure.Visible, 'on');
        end
        
        function visible = isBookmarksViewVisible(obj)
            % Check if bookmarks view window is visible
            visible = obj.isBookmarksViewValid() && ...
                     strcmp(obj.BookmarksViewApp.UIFigure.Visible, 'on');
        end
        
        function active = isStageViewActive(obj)
            % Check if stage view window is active (valid and visible)
            active = obj.isStageViewValid() && obj.isStageViewVisible();
        end
        
        function active = isBookmarksViewActive(obj)
            % Check if bookmarks view window is active (valid and visible)
            active = obj.isBookmarksViewValid() && obj.isBookmarksViewVisible();
        end
        
        function showStageView(obj)
            % Make stage view window visible and bring to front
            obj.StageViewApp.UIFigure.Visible = 'on';
            figure(obj.StageViewApp.UIFigure);
            obj.positionStageViewWindow();
        end
        
        function showBookmarksView(obj)
            % Make bookmarks view window visible and bring to front
            obj.BookmarksViewApp.UIFigure.Visible = 'on';
            figure(obj.BookmarksViewApp.UIFigure);
            obj.positionBookmarksViewWindow();
        end
        
        function handleStageViewError(obj, ME)
            % Handle stage view related errors
            obj.StageViewApp = [];
            warning('foilview:StageViewToggle', 'Failed to toggle Stage View: %s', ME.message);
            
            % Show user-friendly dialog if UI is available
            if isvalid(obj.ParentApp.UIFigure)
                uialert(obj.ParentApp.UIFigure, ...
                       sprintf('Could not open Stage View: %s', ME.message), ...
                       'Stage View Error');
            end
        end
    end
end 