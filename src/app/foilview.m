classdef foilview < matlab.apps.AppBase
    
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainPanel                   matlab.ui.container.Panel
        MainLayout                  matlab.ui.container.GridLayout
        ControlTabs                 matlab.ui.container.TabGroup
    end
    
    properties (Access = public)
        PositionDisplay
        MetricDisplay
        ManualControls
        AutoControls
        StatusControls
        MetricsPlotControls
    end
    
    properties (Access = public)
        Controller                  FoilviewController
        UIController                UIController
        PlotManager                 PlotManager
        StageViewApp
        BookmarksViewApp
        ScanImageManager
    end
    
    properties (Access = private)
        RefreshTimer
        MetricTimer
        ResizeMonitorTimer
        LastWindowSize = [0 0 0 0]
        IgnoreNextResize = false
        MetadataFile
        DataDir
        LastSetupTime
        MetadataConfig
    end
    
    methods (Access = public)
        function app = foilview()
            components = UiBuilder.build();
            app.copyComponentsFromStruct(components);
            app.setupCallbacks();
            app.initializeApplication();
            registerApp(app, app.UIFigure);
            
            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            % Main destructor for the application.
            app.cleanup();
            
            % Safely delete the UIFigure without recursion.
            if isvalid(app.UIFigure)
                app.UIFigure.CloseRequestFcn = '';
                delete(app.UIFigure);
            end
        end
        
        function saveBookmarkToMetadata(app, label, xPos, yPos, zPos, metricStruct)
            % Save bookmark information to the metadata file - now delegates to MetadataService
            try
                MetadataService.saveBookmarkMetadata(label, xPos, yPos, zPos, metricStruct, app.MetadataFile, app.Controller);
            catch ME
                FoilviewUtils.logException('FoilviewApp.saveBookmarkToMetadata', ME);
            end
        end
        
        function writeMetadataToFile(app, metadata, filePath, verbose)
            % Write metadata to file - delegates to MetadataService
            if nargin < 4
                verbose = false;
            end
            try
                MetadataService.writeMetadataToFile(metadata, filePath, verbose);
            catch ME
                FoilviewUtils.logException('FoilviewApp.writeMetadataToFile', ME);
            end
        end

    end
    
    % === UI Callback Methods ===
    methods (Access = private)
        % -- Manual Controls Callbacks --
        function onDownButtonPushed(app, varargin)
            stepSize = app.ManualControls.StepSizes(app.ManualControls.CurrentStepIndex);
            app.Controller.moveStageManual(stepSize, -1);
        end
        function onStepDownButtonPushed(app, varargin)
            currentIndex = app.ManualControls.CurrentStepIndex;
            if currentIndex > 1
                newIndex = currentIndex - 1;
                newStepSize = app.ManualControls.StepSizes(newIndex);
                app.updateStepSizeDisplay(newIndex, newStepSize);
            end
        end
        function onStepSizeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                app.Controller.setStepSize(event.Value);
                app.updateStepSizeDisplay();
            end
        end
        function onStepUpButtonPushed(app, varargin)
            currentIndex = app.ManualControls.CurrentStepIndex;
            if currentIndex < length(app.ManualControls.StepSizes)
                newIndex = currentIndex + 1;
                newStepSize = app.ManualControls.StepSizes(newIndex);
                app.updateStepSizeDisplay(newIndex, newStepSize);
            end
        end
        function onUpButtonPushed(app, varargin)
            stepSize = app.ManualControls.StepSizes(app.ManualControls.CurrentStepIndex);
            app.Controller.moveStageManual(stepSize, 1);
        end
        function onZeroButtonPushed(app, varargin)
            app.Controller.resetPosition();
        end
        % -- Auto Controls Callbacks --
        function onAutoDelayChanged(app, varargin)
            app.updateAutoStepStatus();
        end
        function onAutoDirectionSwitchChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                if strcmp(event.Value, 'Up')
                    direction = 1;
                else
                    direction = -1;
                end
                app.Controller.setAutoDirectionWithValidation(app.AutoControls, direction);
                app.updateAutoStepStatus();
                app.UIController.updateAllUI();
            end
        end
        function onAutoDirectionToggled(app, varargin)
            currentDirection = app.Controller.AutoDirection;
            newDirection = -currentDirection;
            app.Controller.setAutoDirectionWithValidation(app.AutoControls, newDirection);
            app.updateAutoStepStatus();
            app.UIController.updateAllUI();
        end
        function onAutoStepSizeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                app.Controller.syncStepSizes(app.ManualControls, app.AutoControls, event.Value, false);
                app.updateAutoStepStatus();
            end
        end
        function onAutoStepsChanged(app, varargin)
            app.updateAutoStepStatus();
        end
        function onStartStopButtonPushed(app, varargin)
            fprintf('DEBUG: onStartStopButtonPushed ENTRY - IsAutoRunning: %d\n', app.Controller.IsAutoRunning);
            if app.Controller.IsAutoRunning
                fprintf('DEBUG: Stopping auto-stepping from UI\n');
                app.Controller.stopAutoStepping();
            else
                fprintf('DEBUG: Starting auto-stepping from UI\n');
                app.Controller.startAutoSteppingWithValidation(app, app.AutoControls, app.PlotManager);
            end
            fprintf('DEBUG: Updating UI after start/stop operation\n');
            app.UIController.updateAllUI();
            app.updateAutoStepStatus();
            fprintf('DEBUG: onStartStopButtonPushed EXIT - IsAutoRunning: %d\n', app.Controller.IsAutoRunning);
        end
        % -- Status Controls Callbacks --
        function onBookmarksButtonPushed(app, ~, ~)
            if isempty(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp.UIFigure)
                app.launchBookmarksView();
            else
                delete(app.BookmarksViewApp);
                app.BookmarksViewApp = [];
            end
            app.updateWindowStatusButtons();
        end

        function onRefreshButtonPushed(app, ~, ~)
            app.Controller.refreshPosition();
        end
        function onStageViewButtonPushed(app, ~, ~)
            if isempty(app.StageViewApp) || ~isvalid(app.StageViewApp) || ~isvalid(app.StageViewApp.UIFigure)
                app.launchStageView();
            else
                delete(app.StageViewApp);
                app.StageViewApp = [];
            end
            app.updateWindowStatusButtons();
        end
        function onWindowClose(app, varargin)
            delete(app);
        end
        function onWindowSizeChanged(app, varargin)
            % Immediate callback for window size changes - more responsive than timer
            if ~isvalid(app.UIFigure)
                return;
            end
            
            currentSize = app.UIFigure.Position;
            
            % Skip if we're ignoring resize events
            if app.IgnoreNextResize
                return;
            end
            
            % Update the main panel position based on plot expansion state
            if isvalid(app.MainPanel)
                % Ensure MainPanel uses normalized units
                app.MainPanel.Units = 'normalized';
                
                if app.PlotManager.getIsPlotExpanded()
                    % When plot is expanded, main panel should only occupy left portion
                    % Calculate the ratio based on original vs current window width
                    originalWindowSize = app.PlotManager.getOriginalWindowSize();
                    if ~isempty(originalWindowSize) && length(originalWindowSize) >= 4
                        originalWidth = originalWindowSize(3);
                        currentWidth = currentSize(3);
                        if currentWidth > originalWidth && originalWidth > 0
                            mainPanelWidthRatio = max(0.3, min(1.0, originalWidth / currentWidth));
                            app.MainPanel.Position = [0, 0, mainPanelWidthRatio, 1];
                        else
                            app.MainPanel.Position = [0, 0, 1, 1];
                        end
                    else
                        app.MainPanel.Position = [0, 0, 1, 1];
                    end
                else
                    % When plot is collapsed, main panel fills entire window
                    app.MainPanel.Position = [0, 0, 1, 1];
                end
                
                % Force a layout refresh
                drawnow limitrate;
            end
            
            % Check if size actually changed significantly
            if ~isempty(app.LastWindowSize)
                sizeDiff = abs(currentSize - app.LastWindowSize);
                if any(sizeDiff(3:4) > 10) % Even lower threshold for immediate response
                    try
                        % Prepare components for font scaling
                        components = struct();
                        components.PositionDisplay = app.PositionDisplay;
                        components.AutoControls = app.AutoControls;
                        components.ManualControls = app.ManualControls;
                        components.MetricDisplay = app.MetricDisplay;
                        components.StatusControls = app.StatusControls;
                        
                        % Apply font scaling immediately
                        UiComponents.adjustFontSizes(components, currentSize);
                        
                        % Update last window size
                        app.LastWindowSize = currentSize;
                        
                    catch ME
                        FoilviewUtils.warn('FoilviewApp', 'Error during immediate resize: %s', ME.message);
                    end
                end
            else
                % First time - just store the size
                app.LastWindowSize = currentSize;
            end
        end
        % -- Metric Controls Callbacks --
        function onMetricRefreshButtonPushed(app, ~, ~)
            app.Controller.updateMetric();
        end
        function onMetricTypeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                app.Controller.setMetricTypeWithValidation(event.Value);
            end
            if ~isempty(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp)
                delete(app.BookmarksViewApp);
            end
            app.BookmarksViewApp = [];
            if ~isempty(app.StageViewApp) && isvalid(app.StageViewApp)
                delete(app.StageViewApp);
            end
            app.StageViewApp = [];
            FoilviewUtils.safeStopTimer(app.ResizeMonitorTimer);
            app.ResizeMonitorTimer = [];
        end
        % -- Plot Controls Callbacks --
        function onClearPlotButtonPushed(app, varargin)
            app.PlotManager.clearMetricsPlot(app.MetricsPlotControls.Axes);
        end
        function onExpandButtonPushed(app, ~, ~)
            isExpanded = app.PlotManager.getIsPlotExpanded();
            if isExpanded
                app.PlotManager.collapseGUI(app.UIFigure, app.MainPanel, ...
                    app.MetricsPlotControls.Panel, app.MetricsPlotControls.ExpandButton, app);
            else
                app.PlotManager.expandGUI(app.UIFigure, app.MainPanel, ...
                    app.MetricsPlotControls.Panel, app.MetricsPlotControls.ExpandButton, app);
            end
        end
        function onExportPlotButtonPushed(app, varargin)
            app.PlotManager.exportPlotData(app.UIFigure, app.Controller);
        end
    end

    % === UI Update Methods ===
    methods (Access = private)
        %% Update step size display and sync controls
        function updateStepSizeDisplay(app, newIndex, newStepSize)
            app.ManualControls.CurrentStepIndex = newIndex;
            app.ManualControls.StepSizeDisplay.Text = sprintf('%.1fμm', newStepSize);
            formattedValue = FoilviewUtils.formatPosition(newStepSize);
            if ismember(formattedValue, app.ManualControls.StepSizeDropdown.Items)
                app.ManualControls.StepSizeDropdown.Value = formattedValue;
            end
            app.AutoControls.StepField.Value = newStepSize;
        end
        %% Update all UI components
        function updateAllUI(app)
            app.UIController.updateAllUI();
        end
        %% Update auto step status controls
        function updateAutoStepStatus(app)
            UiComponents.updateControlStates(app.ManualControls, app.AutoControls, app.Controller);
        end
        %% Update window status buttons (Bookmarks/StageView)
        function updateWindowStatusButtons(app)
            isBookmarksOpen = ~isempty(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp.UIFigure);
            isStageViewOpen = ~isempty(app.StageViewApp) && isvalid(app.StageViewApp) && isvalid(app.StageViewApp.UIFigure);
            if isBookmarksOpen
                app.StatusControls.BookmarksButton.Text = 'Close Bookmarks';
                app.StatusControls.BookmarksButton.Icon = '';
            else
                app.StatusControls.BookmarksButton.Text = 'Open Bookmarks';
                app.StatusControls.BookmarksButton.Icon = '';
            end
            if isStageViewOpen
                app.StatusControls.StageViewButton.Text = 'Close Stage View';
                app.StatusControls.StageViewButton.Icon = '';
            else
                app.StatusControls.StageViewButton.Text = 'Open Stage View';
                app.StatusControls.StageViewButton.Icon = '';
            end
        end
    end

    % === Timer Management Methods ===
    methods (Access = private)
        %% Start the refresh timer for position updates
        function startRefreshTimer(app)
            app.RefreshTimer = FoilviewUtils.createTimer('fixedRate', ...
                app.Controller.POSITION_REFRESH_PERIOD, ...
                @(~,~) app.Controller.refreshPosition());
            start(app.RefreshTimer);
        end
        %% Start the metric timer for metric updates
        function startMetricTimer(app)
            app.MetricTimer = FoilviewUtils.createTimer('fixedRate', ...
                app.Controller.METRIC_REFRESH_PERIOD, ...
                @(~,~) app.Controller.updateMetric());
            start(app.MetricTimer);
        end
        %% Start the resize monitor timer
        function startResizeMonitorTimer(app)
            app.ResizeMonitorTimer = FoilviewUtils.createTimer('fixedRate', ...
                0.5, ...
                @(~,~) app.monitorWindowResize());
            if isvalid(app.UIFigure)
                app.LastWindowSize = app.UIFigure.Position;
            end
            start(app.ResizeMonitorTimer);
        end
        %% Stop and delete all timers
        function stopTimers(app)
            FoilviewUtils.safeStopTimer(app.RefreshTimer);
            app.RefreshTimer = [];
            FoilviewUtils.safeStopTimer(app.MetricTimer);
            app.MetricTimer = [];
            FoilviewUtils.safeStopTimer(app.ResizeMonitorTimer);
            app.ResizeMonitorTimer = [];
        end
    end

    % === Resource Cleanup Methods ===
    methods (Access = private)
        %% Clean up all application resources
        function cleanup(app)
            app.stopTimers();
            app.cleanupMetadataLogging();
            if ~isempty(app.ScanImageManager) && isvalid(app.ScanImageManager)
                app.ScanImageManager.cleanup();
            end
            if ~isempty(app.Controller) && isvalid(app.Controller)
                app.Controller.cleanup();
            end
            if ~isempty(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp)
                delete(app.BookmarksViewApp);
                app.BookmarksViewApp = [];
            end
            if ~isempty(app.StageViewApp) && isvalid(app.StageViewApp)
                delete(app.StageViewApp);
                app.StageViewApp = [];
            end
        end
        %% Clean up metadata logging and generate session stats
        function cleanupMetadataLogging(app)
            try
                metadataFile = app.getMetadataFile();
                if isempty(metadataFile)
                    return;
                end
                app.generateSessionStats(metadataFile);
            catch ME
                FoilviewUtils.logException('FoilviewApp', ME);
            end
        end
    end

    % === Utility/Helper Methods ===
    methods (Access = private)
        %% Copy UI components from struct
        function copyComponentsFromStruct(app, components)
            fields = fieldnames(components);
            for i = 1:length(fields)
                app.(fields{i}) = components.(fields{i});
            end
        end
        %% Initialize the application (controllers, listeners, UI, timers)
        function initializeApplication(app)
            app.Controller = FoilviewController();
            app.UIController = UIController(app);
            app.PlotManager = PlotManager(app);
            app.ScanImageManager = ScanImageManager();
            app.Controller.setFoilviewApp(app);
            addlistener(app.Controller, 'StatusChanged', @(src,evt) app.onControllerStatusChanged());
            addlistener(app.Controller, 'PositionChanged', @(src,evt) app.onControllerPositionChanged());
            addlistener(app.Controller, 'MetricChanged', @(src,evt) app.onControllerMetricChanged());
            addlistener(app.Controller, 'AutoStepComplete', @(src,evt) app.onControllerAutoStepComplete());
            app.PlotManager.initializeMetricsPlot(app.MetricsPlotControls.Axes);
            app.UIController.updateAllUI();
            app.updateAutoStepStatus();
            app.updateWindowStatusButtons();
            app.startRefreshTimer();
            app.startMetricTimer();
            app.startResizeMonitorTimer();
            app.ScanImageManager.initialize(app);
        end
        %% Launch the stage view window
        function launchStageView(app)
            if isempty(app.StageViewApp) || ~isvalid(app.StageViewApp) || ~isvalid(app.StageViewApp.UIFigure)
                try
                    app.StageViewApp = StageView();
                catch ME
                    FoilviewUtils.warn('FoilviewApp', 'Failed to launch Stage View: %s', ME.message);
                    app.StageViewApp = [];
                end
            else
                app.StageViewApp.bringToFront();
            end
        end
        %% Launch the bookmarks view window
        function launchBookmarksView(app)
            if isempty(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp.UIFigure)
                try
                    app.BookmarksViewApp = BookmarksView(app.Controller);
                catch ME
                    FoilviewUtils.warn('FoilviewApp', 'Failed to launch Bookmarks View: %s', ME.message);
                    app.BookmarksViewApp = [];
                end
            else
                figure(app.BookmarksViewApp.UIFigure);
            end
        end
        %% Set up all UI callback functions
        function setupCallbacks(app)
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @app.onWindowClose, true);
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @app.onWindowSizeChanged, true);
            app.ManualControls.StepSizeDropdown.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onStepSizeChanged, true);
            app.ManualControls.UpButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onUpButtonPushed, true);
            app.ManualControls.DownButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onDownButtonPushed, true);
            app.ManualControls.ZeroButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onZeroButtonPushed, true);
            app.ManualControls.StepUpButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onStepUpButtonPushed, true);
            app.ManualControls.StepDownButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onStepDownButtonPushed, true);
            app.AutoControls.StepField.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onAutoStepSizeChanged, true);
            app.AutoControls.StepsField.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onAutoStepsChanged, true);
            app.AutoControls.DelayField.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onAutoDelayChanged, true);
            app.AutoControls.DirectionSwitch.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onAutoDirectionSwitchChanged, true);
            app.AutoControls.DirectionButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onAutoDirectionToggled, true);
            app.AutoControls.StartStopButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onStartStopButtonPushed, true);
            app.MetricDisplay.TypeDropdown.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onMetricTypeChanged, true);
            app.MetricDisplay.RefreshButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onMetricRefreshButtonPushed, true);
            app.StatusControls.RefreshButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onRefreshButtonPushed, true);
            app.StatusControls.BookmarksButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onBookmarksButtonPushed, true);
            app.StatusControls.StageViewButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onStageViewButtonPushed, true);
            app.StatusControls.MetadataButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onMetadataButtonPushed, true);

            app.MetricsPlotControls.ExpandButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onExpandButtonPushed, true);
            app.MetricsPlotControls.ClearButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onClearPlotButtonPushed, true);
            app.MetricsPlotControls.ExportButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onExportPlotButtonPushed, true);
        end
        %% Monitor window size changes and adjust UI responsively
        function monitorWindowResize(app)
            if ~isa(app.UIFigure, 'matlab.ui.Figure')
                FoilviewUtils.warn('FoilviewApp', 'UIFigure is not a handle! Type: %s, Value: %s', ...
                    class(app.UIFigure), mat2str(app.UIFigure));
                return;
            end
            if ~isvalid(app.UIFigure)
                return;
            end
            app.updateWindowStatusButtons();
            currentSize = app.UIFigure.Position;
            if app.IgnoreNextResize
                app.IgnoreNextResize = false;
                app.LastWindowSize = currentSize;
                return;
            end
            sizeDiff = abs(currentSize - app.LastWindowSize);
            threshold = 15; % Lower threshold for more responsive resizing
            
            % Check for any significant size change (width OR height)
            sizeChanged = any(sizeDiff(3:4) > threshold);
            
            if sizeChanged
                try
                    % Prepare components for font scaling
                    components = struct();
                    components.PositionDisplay = app.PositionDisplay;
                    components.AutoControls = app.AutoControls;
                    components.ManualControls = app.ManualControls;
                    components.MetricDisplay = app.MetricDisplay;
                    components.StatusControls = app.StatusControls;
                    
                    % Use current size for scaling (both width and height matter)
                    UiComponents.adjustFontSizes(components, currentSize);
                    
                    % Handle plot positioning if expanded
                    if app.PlotManager.getIsPlotExpanded() && ...
                       isvalid(app.MetricsPlotControls.Panel) && ...
                       strcmp(app.MetricsPlotControls.Panel.Visible, 'on')
                        if currentSize(3) > 400 && currentSize(4) > 200
                            UiComponents.adjustPlotPosition(app.UIFigure, ...
                                app.MetricsPlotControls.Panel, 400);
                            app.MetricsPlotControls.Panel.Visible = 'on';
                        end
                    end
                    
                catch ME
                    FoilviewUtils.warn('FoilviewApp', 'Error during resize: %s', ME.message);
                end
            end
            app.LastWindowSize = currentSize;
        end
        %% Get the metadata file path from workspace
        function metadataFile = getMetadataFile(~)
            try
                metadataFile = evalin('base', 'metadataFilePath');
                if ~ischar(metadataFile) || isempty(metadataFile) || ~exist(metadataFile, 'file')
                    metadataFile = '';
                end
            catch
                metadataFile = '';
            end
        end
        %% Generate session statistics from metadata file
        function generateSessionStats(app, metadataFile)
            try
                content = fileread(metadataFile);
                lines = regexp(content, '\r?\n', 'split');
                validLines = lines(~cellfun('isempty', lines));
                frameCount = max(0, length(validLines)-1);
                if frameCount > 0
                    timestamps = app.parseTimestamps(validLines);
                    duration = app.calculateDuration(timestamps);
                    if duration > 0
                        avgFrameRate = frameCount / duration;
                    else
                        avgFrameRate = 0;
                    end
                    fileInfo = dir(metadataFile);
                    if ~isempty(fileInfo)
                        fileSize = fileInfo(1).bytes / 1024;
                    else
                        fileSize = 0;
                    end
                    app.displaySessionSummary(frameCount, duration, avgFrameRate, fileSize, metadataFile);
                end
            catch ME
                FoilviewUtils.logException('FoilviewApp', ME);
            end
        end
        %% Parse timestamps from metadata lines
        function timestamps = parseTimestamps(~, lines)
            timestamps = {};
            try
                % Preallocate array for better performance
                validLines = lines(~cellfun('isempty', lines));
                if length(validLines) > 1
                    timestamps = cell(length(validLines) - 1, 1);
                    timestampIdx = 1;
                    for i = 2:length(lines)
                        parts = strsplit(lines{i}, ',');
                        if ~isempty(parts) && ~isempty(parts{1})
                            timestamps{timestampIdx} = parts{1};
                            timestampIdx = timestampIdx + 1;
                        end
                    end
                    % Trim unused cells
                    timestamps = timestamps(1:timestampIdx-1);
                end
            catch
                timestamps = {};
            end
        end
        %% Calculate duration from timestamps
        function duration = calculateDuration(~, timestamps)
            try
                if length(timestamps) >= 2
                    startTime = datetime(timestamps{1}, 'Format', 'yyyy-MM-dd HH:mm:ss');
                    endTime = datetime(timestamps{end}, 'Format', 'yyyy-MM-dd HH:mm:ss');
                    duration = seconds(endTime - startTime);
                else
                    duration = 0;
                end
            catch
                duration = 0;
            end
        end
        %% Display session summary in command window
        function displaySessionSummary(~, frameCount, duration, avgFrameRate, fileSize, metadataFile)
            fprintf('\n=== Session Summary ===\n');
            fprintf('Frames recorded: %d\n', frameCount);
            if duration >= 60
                mins = floor(duration / 60);
                secs = duration - (mins * 60);
                fprintf('Session duration: %d min %d sec\n', mins, round(secs));
            else
                fprintf('Session duration: %.1f sec\n', duration);
            end
            if avgFrameRate > 0
                fprintf('Average frame rate: %.2f frames/sec\n', avgFrameRate);
            end
            fprintf('Metadata file: %s\n', metadataFile);
            fprintf('File size: %.1f KB\n', fileSize);
        end
        %% Controller event: Status changed
        function onControllerStatusChanged(app)
            UiComponents.updateStatusDisplay(app.PositionDisplay, app.StatusControls, app.Controller);
        end
        %% Controller event: Position changed
        function onControllerPositionChanged(app)
            UiComponents.updatePositionDisplay(app.UIFigure, app.PositionDisplay, app.Controller);
        end
        %% Controller event: Metric changed
        function onControllerMetricChanged(app)
            UiComponents.updateMetricDisplay(app.MetricDisplay, app.Controller);
        end
        %% Controller event: Auto step complete
        function onControllerAutoStepComplete(app)
            UiComponents.updateControlStates(app.ManualControls, app.AutoControls, app.Controller);
            if app.Controller.RecordMetrics
                metrics = app.Controller.getAutoStepMetrics();
                if ~isempty(metrics.Positions)
                    app.PlotManager.updateMetricsPlot(app.MetricsPlotControls.Axes, app.Controller);
                    if ~app.PlotManager.getIsPlotExpanded()
                        app.PlotManager.expandGUI(app.UIFigure, app.MainPanel, ...
                            app.MetricsPlotControls.Panel, app.MetricsPlotControls.ExpandButton, app);
                    end
                end
            end
        end
    end

    % === Metadata Management Methods ===
    methods (Access = private)
        %% Handles the Metadata button press, initializes logging and simulation entry
        function onMetadataButtonPushed(app, ~, ~)
            % Check if Controller exists and is valid
            if isempty(app.Controller) || ~isvalid(app.Controller)
                return;
            end
            % Configure metadata path if not already set
            if isempty(app.MetadataConfig) || ~isfield(app.MetadataConfig, 'baseDir') || isempty(app.MetadataConfig.baseDir)
                app.configureMetadataPath();
            end
            app.initializeMetadataLogging();
            % In simulation mode, also collect a sample metadata entry for testing
            if app.Controller.SimulationMode
                app.collectSimulatedMetadata();
                fprintf('Sample metadata collected in simulation mode\n');
            end
        end

        %% Opens dialog to configure metadata file path
        function configureMetadataPath(app)
            try
                if ~isempty(app.MetadataConfig) && isfield(app.MetadataConfig, 'baseDir')
                    currentDir = app.MetadataConfig.baseDir;
                elseif ~isempty(app.DataDir)
                    currentDir = fileparts(app.DataDir);
                else
                    currentDir = fullfile('C:', 'Users', getenv('USERNAME'), 'Documents');
                end
                selectedDir = uigetdir(currentDir, 'Select Base Directory for Metadata Files');
                if selectedDir ~= 0
                    if isempty(app.MetadataConfig)
                        app.MetadataConfig = app.getConfiguration();
                    end
                    app.MetadataConfig.baseDir = selectedDir;
                    assignin('base', 'metadataConfig', app.MetadataConfig);
                    fprintf('Metadata base directory set to: %s\n', selectedDir);
                    uialert(app.UIFigure, ...
                        sprintf('Metadata base directory set to:\n%s\n\nFiles will be saved in date-based subdirectories.', selectedDir), ...
                        'Configuration Updated', ...
                        'Icon', 'success');
                else
                    fprintf('Metadata path configuration cancelled\n');
                end
            catch ME
                FoilviewUtils.logException('FoilviewApp', ME);
                uialert(app.UIFigure, ...
                    sprintf('Error configuring metadata path:\n%s', ME.message), ...
                    'Configuration Error', ...
                    'Icon', 'error');
            end
        end

        %% Loads or creates default metadata configuration
        function config = getConfiguration(~)
            try
                config = evalin('base', 'metadataConfig');
                if ~isfield(config, 'baseDir')
                    config.baseDir = '';
                end
            catch
                config = struct();
                config.baseDir = '';
                config.dirFormat = 'yyyy-MM-dd';
                config.metadataFileName = 'imaging_metadata.csv';
                config.headers = ['Timestamp,Filename,Scanner,Zoom,FrameRate,Averaging,',...
                              'Resolution,FOV_um,PowerPercent,PockelsValue,',...
                              'ModulationVoltage,FeedbackVoltage,PowerWatts,',...
                              'ZPosition,XPosition,YPosition,BookmarkLabel,BookmarkMetricType,BookmarkMetricValue,Notes\n'];
            end
        end

        %% Determines the base directory for metadata files
        function baseDir = getBaseDirectory(~, hSI, config)
            if ~isempty(config.baseDir)
                baseDir = config.baseDir;
            elseif ~isempty(hSI.hScan2D.logFilePath)
                baseDir = fileparts(hSI.hScan2D.logFilePath);
            else
                baseDir = fullfile('C:', 'Users', getenv('USERNAME'), 'Box', 'FOIL', 'Aaron');
                if ~exist(baseDir, 'dir')
                    baseDir = fullfile('C:', 'Users', getenv('USERNAME'), 'Documents');
                end
            end
        end

        %% Creates metadata file for simulation mode
        function createSimulationMetadataFile(app)
            config = app.getConfiguration();
            if ~isempty(config.baseDir)
                baseDir = config.baseDir;
            else
                baseDir = fullfile('C:', 'Users', getenv('USERNAME'), 'Documents', 'FoilView_Simulation');
            end
            app.DataDir = app.createDataDirectory(baseDir, config);
            app.MetadataFile = fullfile(app.DataDir, config.metadataFileName);
            app.ensureMetadataFile(app.MetadataFile, config.headers);
            assignin('base', 'metadataFilePath', app.MetadataFile);
            assignin('base', 'metadataConfig', config);
        end

        %% Initializes metadata logging (real or simulation)
        function initializeMetadataLogging(app)
            try
                if ~isempty(app.LastSetupTime) && (datetime('now') - app.LastSetupTime) < seconds(5)
                    return;
                end
                app.LastSetupTime = datetime('now');
                isSimulation = app.Controller.SimulationMode;
                if isSimulation
                    app.createSimulationMetadataFile();
                    fprintf('Metadata logging initialized in simulation mode\n');
                    return;
                end
                try
                    hSI = evalin('base', 'hSI');
                catch ME
                    FoilviewUtils.logException('FoilviewApp', ME);
                    app.createSimulationMetadataFile();
                    fprintf('Metadata logging initialized in simulation mode (ScanImage not available)\n');
                    return;
                end
                app.checkBeamSystem(hSI, false);
                config = app.getConfiguration();
                baseDir = app.getBaseDirectory(hSI, config);
                app.DataDir = app.createDataDirectory(baseDir, config);
                hSI.hScan2D.logFilePath = app.DataDir;
                app.MetadataFile = fullfile(app.DataDir, config.metadataFileName);
                app.ensureMetadataFile(app.MetadataFile, config.headers);
                assignin('base', 'metadataFilePath', app.MetadataFile);
                assignin('base', 'metadataConfig', config);
                fprintf('Metadata logging initialized successfully\n');
            catch ME
                FoilviewUtils.logException('FoilviewApp', ME);
                app.createSimulationMetadataFile();
                fprintf('Metadata logging initialized in simulation mode due to error\n');
            end
        end

        %% Collects a simulated metadata entry for testing
        function collectSimulatedMetadata(app)
            try
                metadata = struct();
                metadata.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
                metadata.filename = sprintf('sim_%s.tif', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
                metadata.scanner = 'Simulation';
                metadata.zoom = 1.0;
                metadata.frameRate = 30.0;
                metadata.averaging = 1;
                metadata.resolution = '512x512';
                metadata.fov = '100.0x100.0';
                metadata.powerPercent = 50.0;
                metadata.pockelsValue = 0.5;
                metadata.feedbackValue = struct('modulation', '2.5', 'feedback', '1.2', 'power', '0.025');
                metadata.xPos = app.Controller.CurrentXPosition;
                metadata.yPos = app.Controller.CurrentYPosition;
                metadata.zPos = app.Controller.CurrentPosition;
                metadata.bookmarkLabel = '';
                metadata.bookmarkMetricType = '';
                metadata.bookmarkMetricValue = '';
                if ~isempty(app.MetadataFile) && exist(fileparts(app.MetadataFile), 'dir')
                    app.writeMetadataToFile(metadata, app.MetadataFile, false);
                end
            catch ME
                FoilviewUtils.logException('FoilviewApp', ME);
            end
        end



        %% Creates a date-based data directory for metadata
        function dataDir = createDataDirectory(~, baseDir, config)
            todayStr = char(datetime('now', 'Format', config.dirFormat));
            dataDir = fullfile(baseDir, todayStr);
            if ~exist(dataDir, 'dir')
                [success, msg] = mkdir(dataDir);
                if ~success
                    FoilviewUtils.warn('FoilviewApp', 'Failed to create directory: %s. Error: %s', dataDir, msg);
                    dataDir = baseDir;
                end
            end
        end

        %% Ensures the metadata file exists and has headers
        function ensureMetadataFile(~, metadataFile, headers)
            if ~exist(metadataFile, 'file')
                try
                    fid = fopen(metadataFile, 'w');
                    if fid == -1
                        FoilviewUtils.warn('FoilviewApp', 'Failed to create metadata file: %s', metadataFile);
                        return;
                    end
                    fprintf(fid, headers);
                    fclose(fid);
                catch ME
                    if fid ~= -1
                        fclose(fid);
                    end
                    FoilviewUtils.logException('FoilviewApp', ME);
                end
            end
        end

        %% Diagnostic: checks beam system configuration
        function checkBeamSystem(~, hSI, verbose)
            if nargin < 3
                verbose = true;
            end
            try
                if verbose
                    fprintf('\n--- Beam System Diagnostics ---\n');
                end
                if ~isprop(hSI, 'hBeams') || isempty(hSI.hBeams)
                    if verbose
                        fprintf('❌ No beam control system found\n');
                    end
                    return;
                end
                if verbose
                    fprintf('✓ Beam control system detected\n');
                end
                if isprop(hSI.hBeams, 'hBeams') && ~isempty(hSI.hBeams.hBeams)
                    beam = hSI.hBeams.hBeams{1};
                    if verbose
                        fprintf('✓ Beam controller type: %s\n', class(beam));
                    end
                    if isprop(beam, 'beamBufferSize')
                        if verbose
                            fprintf('✓ Beam buffer size: %d\n', beam.beamBufferSize);
                        end
                    end
                    if isprop(beam, 'beamBufferTimeout')
                        if verbose
                            fprintf('✓ Beam buffer timeout: %f seconds\n', beam.beamBufferTimeout);
                            fprintf('  (If timeout errors occur, consider increasing this value)\n');
                        end
                    end
                end
                if verbose
                    if isprop(hSI.hBeams, 'hPockels') && ~isempty(hSI.hBeams.hPockels)
                        fprintf('✓ Pockels cell controller found\n');
                    else
                        fprintf('❌ No Pockels cell controller found\n');
                    end
                    if verbose
                        fprintf('--- End Beam Diagnostics ---\n\n');
                    end
                end
            catch ME
                if verbose
                    fprintf('Error during beam diagnostics: %s\n', ME.message);
                end
            end
        end
    end

    % === UI State Management Methods ===
    methods (Access = public)
        function setIgnoreNextResize(app, value)
            % Set the IgnoreNextResize flag for plot expansion/collapse
            app.IgnoreNextResize = value;
        end
    end
end