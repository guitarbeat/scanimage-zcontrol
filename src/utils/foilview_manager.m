classdef foilview_manager < handle
    % foilview_manager - Consolidated management for foilview application
    %
    % This class consolidates the functionality previously spread across multiple
    % manager classes:
    %   - Callback management (from foilview_callback_manager)
    %   - Application initialization (from foilview_initialization_manager)  
    %   - Window management (from foilview_window_manager)
    %
    % This consolidation reduces file count while maintaining clear separation
    % of concerns through well-organized methods and properties.
    
    properties (Access = private)
        ParentApp               % Reference to main foilview app
        StageViewApp            % Stage view window instance
        BookmarksViewApp        % Bookmarks view window instance
    end
    
    methods (Static)
        function assignCallbacks(app, callbacks)
            % Assign callbacks from a cell array definition
            % callbacks: cell array of {component, property, function_handle} triplets
            
            for i = 1:length(callbacks)
                component = callbacks{i}{1};
                property = callbacks{i}{2};
                functionHandle = callbacks{i}{3};
                
                if ~isempty(component) && isvalid(component)
                    try
                        component.(property) = createCallbackFcn(app, functionHandle, true);
                    catch
                        % Fallback for environments where createCallbackFcn is not available
                        component.(property) = functionHandle;
                    end
                end
            end
        end
        %% Application Initialization Methods
        function initializeApplication(app)
            % Main initialization sequence
            foilview_manager.initializeCore(app);
            foilview_manager.initializeHelpers(app);
            foilview_manager.setupEventListeners(app);
            foilview_manager.initializePlot(app);
            foilview_manager.performInitialUpdates(app);
            foilview_manager.launchAdditionalWindows(app);
            % Timers are now started in the app directly
        end
        
        function initializeCore(app)
            % Initialize core components
            app.Controller = foilview_controller();
        end
        
        function initializeHelpers(app)
            % Initialize helper classes
            app.PlotManager = foilview_plot(app);
            app.WindowManager = foilview_manager(app);
        end
        
        function setupEventListeners(app)
            % Set up event listeners for controller events
            addlistener(app.Controller, 'StatusChanged', ...
                @(src,evt) app.onControllerStatusChanged());
            addlistener(app.Controller, 'PositionChanged', ...
                @(src,evt) app.onControllerPositionChanged());
            addlistener(app.Controller, 'MetricChanged', ...
                @(src,evt) app.onControllerMetricChanged());
            addlistener(app.Controller, 'AutoStepComplete', ...
                @(src,evt) app.onControllerAutoStepComplete());
        end
        
        function initializePlot(app)
            % Initialize the metrics plot
            app.PlotManager.initializeMetricsPlot(app.MetricsPlotControls.Axes);
        end
        
        function performInitialUpdates(app)
            % Perform initial UI updates
            foilview_updater.updateAllUI(app);
            app.updateAutoStepStatus();
            app.updateDirectionButtons();
        end
        
        function launchAdditionalWindows(app)
            % Launch additional windows and update status
            app.WindowManager.launchAllWindows();
            app.WindowManager.updateWindowStatusButtons();
        end
        
        %% Callback Setup Methods
        function setupAllCallbacks(app)
            % Set up all UI callbacks for the application
            foilview_manager.setupMainWindowCallbacks(app);
            foilview_manager.setupManualControlCallbacks(app);
            foilview_manager.setupAutoStepCallbacks(app);
            foilview_manager.setupMetricCallbacks(app);
            foilview_manager.setupStatusCallbacks(app);
            foilview_manager.setupPlotControlCallbacks(app);
        end
        
        function setupMainWindowCallbacks(app)
            % Set up main window callbacks
            try
                app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @app.onWindowClose, true);
            catch
                % Fallback for environments where createCallbackFcn is not available
                app.UIFigure.CloseRequestFcn = @(src, event) app.onWindowClose(src, event);
            end
        end
        
        function setupManualControlCallbacks(app)
            % Set up manual control callbacks
            callbacks = {
                {app.ManualControls.StepSizeField, 'ValueChangedFcn', @app.onManualStepSizeChanged}
                {app.ManualControls.UpButton, 'ButtonPushedFcn', @app.onUpButtonPushed}
                {app.ManualControls.DownButton, 'ButtonPushedFcn', @app.onDownButtonPushed}
                {app.ManualControls.ZeroButton, 'ButtonPushedFcn', @app.onZeroButtonPushed}
                {app.ManualControls.StepUpButton, 'ButtonPushedFcn', @app.onStepUpButtonPushed}
                {app.ManualControls.StepDownButton, 'ButtonPushedFcn', @app.onStepDownButtonPushed}
            };
            
            foilview_manager.assignCallbacks(app, callbacks);
        end
        
        function setupAutoStepCallbacks(app)
            % Set up auto step control callbacks
            callbacks = {
                {app.AutoControls.StepField, 'ValueChangedFcn', @app.onAutoStepSizeChanged}
                {app.AutoControls.StepsField, 'ValueChangedFcn', @app.onAutoStepsChanged}
                {app.AutoControls.DelayField, 'ValueChangedFcn', @app.onAutoDelayChanged}
                {app.AutoControls.DirectionButton, 'ButtonPushedFcn', @app.onAutoDirectionToggled}
                {app.AutoControls.StartStopButton, 'ButtonPushedFcn', @app.onStartStopButtonPushed}
            };
            
            foilview_manager.assignCallbacks(app, callbacks);
        end
        
        function setupMetricCallbacks(app)
            % Set up metric display callbacks
            callbacks = {
                {app.MetricDisplay.TypeDropdown, 'ValueChangedFcn', @app.onMetricTypeChanged}
                {app.MetricDisplay.RefreshButton, 'ButtonPushedFcn', @app.onMetricRefreshButtonPushed}
            };
            
            foilview_manager.assignCallbacks(app, callbacks);
        end
        
        function setupStatusCallbacks(app)
            % Set up status control callbacks
            callbacks = {
                {app.StatusControls.RefreshButton, 'ButtonPushedFcn', @app.onRefreshButtonPushed}
                {app.StatusControls.BookmarksButton, 'ButtonPushedFcn', @app.onBookmarksButtonPushed}
                {app.StatusControls.StageViewButton, 'ButtonPushedFcn', @app.onStageViewButtonPushed}
            };
            
            foilview_manager.assignCallbacks(app, callbacks);
        end
        
        function setupPlotControlCallbacks(app)
            % Set up plot control callbacks
            callbacks = {
                {app.MetricsPlotControls.ExpandButton, 'ButtonPushedFcn', @app.onExpandButtonPushed}
                {app.MetricsPlotControls.ClearButton, 'ButtonPushedFcn', @app.onClearPlotButtonPushed}
                {app.MetricsPlotControls.ExportButton, 'ButtonPushedFcn', @app.onExportPlotButtonPushed}
            };
            
            foilview_manager.assignCallbacks(app, callbacks);
        end
    end
    
    methods
        %% Constructor
        function obj = foilview_manager(parentApp)
            % Constructor
            obj.ParentApp = parentApp;
            obj.StageViewApp = [];
            obj.BookmarksViewApp = [];
        end
        
        %% Window Management Methods
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
        %% Private Callback Methods
        %% Private Window Management Methods
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