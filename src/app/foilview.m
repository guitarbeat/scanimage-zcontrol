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
            components = UiBuilder.build(app);
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
    end
    
    methods (Access = private)
        function copyComponentsFromStruct(app, components)
            fields = fieldnames(components);
            for i = 1:length(fields)
                app.(fields{i}) = components.(fields{i});
            end
        end
        
        function initializeApplication(app)
            app.Controller = FoilviewController();
            app.PlotManager = PlotManager(app);
            app.ScanImageManager = ScanImageManager();
            
            addlistener(app.Controller, 'StatusChanged', @(src,evt) app.onControllerStatusChanged());
            addlistener(app.Controller, 'PositionChanged', @(src,evt) app.onControllerPositionChanged());
            addlistener(app.Controller, 'MetricChanged', @(src,evt) app.onControllerMetricChanged());
            addlistener(app.Controller, 'AutoStepComplete', @(src,evt) app.onControllerAutoStepComplete());
            
            app.PlotManager.initializeMetricsPlot(app.MetricsPlotControls.Axes);
            UiComponents.updateAllUI(app);
            app.updateAutoStepStatus();
            app.updateDirectionButtons();
            app.launchStageView();
            app.launchBookmarksView();
            app.updateWindowStatusButtons();
            app.startRefreshTimer();
            app.startMetricTimer();
            app.startResizeMonitorTimer();
            
            % Initialize ScanImage integration after metadata setup
            app.ScanImageManager.initialize(app);
        end
        
        function startRefreshTimer(app)
            app.RefreshTimer = FoilviewUtils.createTimer('fixedRate', ...
                app.Controller.POSITION_REFRESH_PERIOD, ...
                @(~,~) app.Controller.refreshPosition());
            start(app.RefreshTimer);
        end
        
        function startMetricTimer(app)
            app.MetricTimer = FoilviewUtils.createTimer('fixedRate', ...
                app.Controller.METRIC_REFRESH_PERIOD, ...
                @(~,~) app.Controller.updateMetric());
            start(app.MetricTimer);
        end
        
        function startResizeMonitorTimer(app)
            % Monitor window size changes and adjust UI responsively
            app.ResizeMonitorTimer = FoilviewUtils.createTimer('fixedRate', ...
                0.5, ...  % Check every 0.5 seconds
                @(~,~) app.monitorWindowResize());
            
            % Initialize the last window size
            if isvalid(app.UIFigure)
                app.LastWindowSize = app.UIFigure.Position;
            end
            
            start(app.ResizeMonitorTimer);
        end
        
        function launchStageView(app)
            % Launch the stage view window
            if isempty(app.StageViewApp) || ~isvalid(app.StageViewApp) || ~isvalid(app.StageViewApp.UIFigure)
                try
                    app.StageViewApp = StageView();
                catch ME
                    warning('foilview:StageViewLaunch', 'Failed to launch Stage View: %s', ME.message);
                    app.StageViewApp = [];
                end
            else
                app.StageViewApp.bringToFront();
            end
        end
        
        function launchBookmarksView(app)
            % Launch the Bookmarks View window automatically
            if isempty(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp.UIFigure)
                try
                    app.BookmarksViewApp = BookmarksView(app.Controller);
                catch ME
                    warning('foilview:BookmarksViewLaunch', 'Failed to launch Bookmarks View: %s', ME.message);
                    app.BookmarksViewApp = [];
                end
            else
                figure(app.BookmarksViewApp.UIFigure);
            end
        end
        
        function setupCallbacks(app)
            % Set up all UI callback functions
            
            % Main window
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @app.onWindowClose, true);
            
            % Manual control callbacks
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
            
            % Auto step callbacks
            app.AutoControls.StepField.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onAutoStepSizeChanged, true);
            app.AutoControls.StepsField.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onAutoStepsChanged, true);
            app.AutoControls.DelayField.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onAutoDelayChanged, true);
            app.AutoControls.DirectionButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onAutoDirectionToggled, true);
            app.AutoControls.StartStopButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onStartStopButtonPushed, true);
            

            
            % Metric callbacks
            app.MetricDisplay.TypeDropdown.ValueChangedFcn = ...
                createCallbackFcn(app, @app.onMetricTypeChanged, true);
            app.MetricDisplay.RefreshButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onMetricRefreshButtonPushed, true);
            
            % Status callbacks
            app.StatusControls.RefreshButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onRefreshButtonPushed, true);
            app.StatusControls.BookmarksButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onBookmarksButtonPushed, true);
            app.StatusControls.StageViewButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onStageViewButtonPushed, true);
            app.StatusControls.MetadataButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onMetadataButtonPushed, true);
            
            % Plot control callbacks
            app.MetricsPlotControls.ExpandButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onExpandButtonPushed, true);
            app.MetricsPlotControls.ClearButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onClearPlotButtonPushed, true);
            app.MetricsPlotControls.ExportButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @app.onExportPlotButtonPushed, true);
        end
    end
    

    methods (Access = private)
        function onControllerStatusChanged(app)
            UiComponents.updateStatusDisplay(app.PositionDisplay, app.StatusControls, app.Controller);
        end
        
        function onControllerPositionChanged(app)
            UiComponents.updatePositionDisplay(app.UIFigure, app.PositionDisplay, app.Controller);
        end
        
        function onControllerMetricChanged(app)
            UiComponents.updateMetricDisplay(app.MetricDisplay, app.Controller);
        end
        
        function onControllerAutoStepComplete(app)
            UiComponents.updateControlStates(app.ManualControls, app.AutoControls, app.Controller);
            % If metrics were recorded, update the plot and expand the GUI
            if app.Controller.RecordMetrics
                metrics = app.Controller.getAutoStepMetrics();
                if ~isempty(metrics.Positions)
                    app.PlotManager.updateMetricsPlot(app.MetricsPlotControls.Axes, app.Controller);
                    % Expand the GUI to show the plot
                    if ~app.PlotManager.getIsPlotExpanded()
                        app.PlotManager.expandGUI(app.UIFigure, app.MainPanel, ...
                            app.MetricsPlotControls.Panel, app.MetricsPlotControls.ExpandButton, app);
                    end
                end
            end
        end
    end
    

    methods (Access = private)

        function onUpButtonPushed(app, varargin)
            app.Controller.moveStageManual(app.ManualControls, 1);
        end
        
        function onDownButtonPushed(app, varargin)
            app.Controller.moveStageManual(app.ManualControls, -1);
        end
        
        function onZeroButtonPushed(app, varargin)
            app.Controller.resetPosition();
        end
        
        function onStepSizeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                app.Controller.setStepSize(event.Value);
                app.updateStepSizeDisplay();
            end
        end
        
        function onStepUpButtonPushed(app, varargin)
            % Cycle to next larger step size
            currentIndex = app.ManualControls.CurrentStepIndex;
            if currentIndex < length(app.ManualControls.StepSizes)
                newIndex = currentIndex + 1;
                newStepSize = app.ManualControls.StepSizes(newIndex);
                app.updateStepSizeDisplay(newIndex, newStepSize);
            end
        end
        
        function onStepDownButtonPushed(app, varargin)
            % Cycle to next smaller step size
            currentIndex = app.ManualControls.CurrentStepIndex;
            if currentIndex > 1
                newIndex = currentIndex - 1;
                newStepSize = app.ManualControls.StepSizes(newIndex);
                app.updateStepSizeDisplay(newIndex, newStepSize);
            end
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
        
        function onAutoDelayChanged(app, varargin)
            app.updateAutoStepStatus();
        end
        
        function onAutoDirectionToggled(app, varargin)
            % Toggle between up and down directions
            currentDirection = app.Controller.AutoDirection;
            newDirection = -currentDirection;  % Toggle: 1 -> -1, -1 -> 1
            app.Controller.setAutoDirectionWithValidation(app.AutoControls, newDirection);
            app.updateAutoStepStatus();
            app.updateDirectionButtons();
        end
        
        function onStartStopButtonPushed(app, varargin)
            if app.Controller.IsAutoRunning
                app.Controller.stopAutoStepping();
            else
                app.Controller.startAutoSteppingWithValidation(app, app.AutoControls, app.PlotManager);
            end
            UiComponents.updateAllUI(app);
            app.updateAutoStepStatus();
            app.updateDirectionButtons();
        end
        

        

        function onRefreshButtonPushed(app, ~, ~)
            app.Controller.refreshPosition();
        end
        
        function onBookmarksButtonPushed(app, ~, ~)
            if isempty(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp) || ~isvalid(app.BookmarksViewApp.UIFigure)
                app.launchBookmarksView();
            else
                delete(app.BookmarksViewApp);
                app.BookmarksViewApp = [];
            end
            app.updateWindowStatusButtons();
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
            % This function is called when the main window is closed.
            % The delete() method will handle all cleanup.
            delete(app);
        end
        

        function onMetricTypeChanged(app, varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'matlab.ui.eventdata.ValueChangedData')
                event = varargin{1};
                app.Controller.setMetricTypeWithValidation(event.Value);
            end
            
            % Close any child windows
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
        
        function onMetricRefreshButtonPushed(app, ~, ~)
            app.Controller.updateMetric();
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
        
        function onClearPlotButtonPushed(app, varargin)
            app.PlotManager.clearMetricsPlot(app.MetricsPlotControls.Axes);
        end
        
        function onExportPlotButtonPushed(app, varargin)
            app.PlotManager.exportPlotData(app.UIFigure, app.Controller);
        end
    end
    

    methods (Access = private)
        function updateStepSizeDisplay(app, newIndex, newStepSize)
            % Update step size display and sync controls
            app.ManualControls.CurrentStepIndex = newIndex;
            
            % Update display label
            app.ManualControls.StepSizeDisplay.Text = sprintf('%.1fμm', newStepSize);
            
            % Update hidden dropdown for compatibility
            formattedValue = FoilviewUtils.formatPosition(newStepSize);
            if ismember(formattedValue, app.ManualControls.StepSizeDropdown.Items)
                app.ManualControls.StepSizeDropdown.Value = formattedValue;
            end
            
            % Sync with auto controls
            app.AutoControls.StepField.Value = newStepSize;
        end
        
        function updateAllUI(app)
            UiComponents.updateAllUI(app);
        end

        function updateAutoStepStatus(app)
            UiComponents.updateControlStates(app.ManualControls, app.AutoControls, app.Controller);
        end
        
        function updateDirectionButtons(app)
            % Update direction button and start button to show current direction
            direction = app.Controller.AutoDirection;
            
            % Style direction button based on direction and running state
            if direction > 0
                app.AutoControls.DirectionButton.Text = '▲';
                baseColor = [0.2 0.7 0.3];  % success color
            else
                app.AutoControls.DirectionButton.Text = '▼';
                baseColor = [0.9 0.6 0.2];  % warning color
            end
            
            if app.Controller.IsAutoRunning
                app.AutoControls.DirectionButton.BackgroundColor = [0.9 0.3 0.3];  % danger color
            else
                app.AutoControls.DirectionButton.BackgroundColor = baseColor;
            end
            
            app.AutoControls.DirectionButton.FontColor = [1 1 1];  % white text
            app.AutoControls.DirectionButton.FontSize = 10;
            app.AutoControls.DirectionButton.FontWeight = 'bold';
            
            % Style start/stop button based on state and direction
            if direction > 0
                if app.Controller.IsAutoRunning
                    app.AutoControls.StartStopButton.BackgroundColor = [0.9 0.3 0.3];  % danger color
                    app.AutoControls.StartStopButton.Text = 'STOP ▲';
                else
                    app.AutoControls.StartStopButton.BackgroundColor = [0.2 0.7 0.3];  % success color
                    app.AutoControls.StartStopButton.Text = 'START ▲';
                end
            else
                if app.Controller.IsAutoRunning
                    app.AutoControls.StartStopButton.BackgroundColor = [0.9 0.3 0.3];  % danger color
                    app.AutoControls.StartStopButton.Text = 'STOP ▼';
                else
                    app.AutoControls.StartStopButton.BackgroundColor = [0.2 0.7 0.3];  % success color
                    app.AutoControls.StartStopButton.Text = 'START ▼';
                end
            end
            app.AutoControls.StartStopButton.FontColor = [1 1 1];  % white text
            app.AutoControls.StartStopButton.FontSize = 10;
            app.AutoControls.StartStopButton.FontWeight = 'bold';
        end
        
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
        
        function monitorWindowResize(app)
            % Monitor window size changes and adjust UI elements accordingly
            if ~isvalid(app.UIFigure)
                return;
            end
            
            % Update window status buttons to catch external window closures
            app.updateWindowStatusButtons();
            
            currentSize = app.UIFigure.Position;
            
            % Skip monitoring if we're ignoring programmatic resizes
            if app.IgnoreNextResize
                app.IgnoreNextResize = false;
                app.LastWindowSize = currentSize;
                return;
            end
            
            % Check if window size has changed significantly
            sizeDiff = abs(currentSize - app.LastWindowSize);
            threshold = 30; % Pixel threshold for user-initiated changes
            
            % For font scaling, only consider HEIGHT changes (ignore width changes from plot)
            % This way, plot expand/collapse (width changes) won't trigger font scaling
            heightChanged = sizeDiff(4) > threshold;
            
            if heightChanged % Only adjust fonts based on height changes
                % Window height changed significantly (likely user resize)
                try
                    % Collect all UI components for font adjustment
                    components = struct();
                    components.PositionDisplay = app.PositionDisplay;
                    components.AutoControls = app.AutoControls;
                    components.ManualControls = app.ManualControls;
                    components.MetricDisplay = app.MetricDisplay;
                    components.StatusControls = app.StatusControls;
                    
                    % Calculate scaling based on height change only
                    heightBasedSize = [currentSize(1:2), app.LastWindowSize(3), currentSize(4)];
                    UiComponents.adjustFontSizes(components, heightBasedSize);
                    
                catch ME
                    % Log errors for debugging but don't crash
                    warning('foilview:ResizeError', 'Error during font resize: %s', ME.message);
                end
            end
            
            % Handle plot repositioning separately (for any significant size change)
            if any(sizeDiff(3:4) > threshold)
                try
                    % If plot is expanded, adjust its position with extra validation
                    if app.PlotManager.getIsPlotExpanded() && ...
                       isvalid(app.MetricsPlotControls.Panel) && ...
                       strcmp(app.MetricsPlotControls.Panel.Visible, 'on')
                        
                        % Only adjust if we have reasonable window dimensions
                        if currentSize(3) > 400 && currentSize(4) > 200
                            UiComponents.adjustPlotPosition(app.UIFigure, ...
                                app.MetricsPlotControls.Panel, 400);
                            
                            % Ensure plot panel stays visible
                            app.MetricsPlotControls.Panel.Visible = 'on';
                        end
                    end
                    
                catch ME
                    % Log errors for debugging but don't crash
                    warning('foilview:ResizeError', 'Error during plot resize: %s', ME.message);
                end
            end
            
            % Update last known size
            app.LastWindowSize = currentSize;
        end
        
        function stopTimers(app)
            % Stop and delete all timers
            FoilviewUtils.safeStopTimer(app.RefreshTimer);
            app.RefreshTimer = [];
            
            FoilviewUtils.safeStopTimer(app.MetricTimer);
            app.MetricTimer = [];
            
            FoilviewUtils.safeStopTimer(app.ResizeMonitorTimer);
            app.ResizeMonitorTimer = [];
        end
        
        function cleanup(app)
            % Clean up all application resources.
            
            % Stop timers
            app.stopTimers();
            
            % Clean up metadata logging
            app.cleanupMetadataLogging();
            
            % Clean up ScanImage manager
            if ~isempty(app.ScanImageManager) && isvalid(app.ScanImageManager)
                app.ScanImageManager.cleanup();
            end
            
            % Clean up controller
            if ~isempty(app.Controller) && isvalid(app.Controller)
                app.Controller.cleanup();
            end
            
            % Close any child windows by deleting their app objects.
            if ~isempty(app.BookmarksViewApp) && isvalid(app.BookmarksViewApp)
                delete(app.BookmarksViewApp);
                app.BookmarksViewApp = [];
            end
            
            if ~isempty(app.StageViewApp) && isvalid(app.StageViewApp)
                delete(app.StageViewApp);
                app.StageViewApp = [];
            end
        end

        function cleanupMetadataLogging(app)
            try
                metadataFile = app.getMetadataFile();
                if isempty(metadataFile)
                    return;
                end
                app.generateSessionStats(metadataFile);
            catch ME
                warning('%s: %s', ME.identifier, ME.message);
            end
        end

        function metadataFile = getMetadataFile(app)
            try
                metadataFile = evalin('base', 'metadataFilePath');
                if ~ischar(metadataFile) || isempty(metadataFile) || ~exist(metadataFile, 'file')
                    metadataFile = '';
                end
            catch
                metadataFile = '';
            end
        end

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
                warning('%s: %s', ME.identifier, ME.message);
            end
        end

        function timestamps = parseTimestamps(app, lines)
            timestamps = {};
            try
                for i = 2:length(lines)
                    parts = strsplit(lines{i}, ',');
                    if length(parts) > 0 && ~isempty(parts{1})
                        timestamps{end+1} = parts{1};
                    end
                end
            catch
                % Return whatever we've collected
            end
        end

        function duration = calculateDuration(app, timestamps)
            try
                if length(timestamps) >= 2
                    startTime = datenum(timestamps{1}, 'yyyy-mm-dd HH:MM:SS');
                    endTime = datenum(timestamps{end}, 'yyyy-mm-dd HH:MM:SS');
                    duration = (endTime - startTime) * 86400;
                else
                    duration = 0;
                end
            catch
                duration = 0;
            end
        end

        function displaySessionSummary(app, frameCount, duration, avgFrameRate, fileSize, metadataFile)
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
    end

    methods (Access = private)
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

        function configureMetadataPath(app)
            % Open dialog to configure metadata file path
            try
                % Get current base directory if available
                currentDir = '';
                if ~isempty(app.MetadataConfig) && isfield(app.MetadataConfig, 'baseDir')
                    currentDir = app.MetadataConfig.baseDir;
                elseif ~isempty(app.DataDir)
                    currentDir = fileparts(app.DataDir);
                else
                    % Default to user's Documents folder
                    currentDir = fullfile('C:', 'Users', getenv('USERNAME'), 'Documents');
                end
                
                % Open folder selection dialog
                selectedDir = uigetdir(currentDir, 'Select Base Directory for Metadata Files');
                
                if selectedDir ~= 0  % User didn't cancel
                    % Initialize or update configuration
                    if isempty(app.MetadataConfig)
                        app.MetadataConfig = app.getConfiguration();
                    end
                    
                    app.MetadataConfig.baseDir = selectedDir;
                    
                    % Store in workspace for persistence
                    assignin('base', 'metadataConfig', app.MetadataConfig);
                    
                    fprintf('Metadata base directory set to: %s\n', selectedDir);
                    
                    % Show confirmation
                    uialert(app.UIFigure, ...
                        sprintf('Metadata base directory set to:\n%s\n\nFiles will be saved in date-based subdirectories.', selectedDir), ...
                        'Configuration Updated', ...
                        'Icon', 'success');
                else
                    fprintf('Metadata path configuration cancelled\n');
                end
                
            catch ME
                warning('%s: %s', ME.identifier, ME.message);
                uialert(app.UIFigure, ...
                    sprintf('Error configuring metadata path:\n%s', ME.message), ...
                    'Configuration Error', ...
                    'Icon', 'error');
            end
        end

        function config = getConfiguration(app)
            % Try to get configuration from workspace or use defaults
            try
                config = evalin('base', 'metadataConfig');
                
                % If found but missing fields, add defaults
                if ~isfield(config, 'baseDir')
                    config.baseDir = '';
                end
            catch
                % Create default configuration
                config = struct();
                config.baseDir = '';
                config.dirFormat = 'yyyy-mm-dd';
                config.metadataFileName = 'imaging_metadata.csv';
                config.headers = ['Timestamp,Filename,Scanner,Zoom,FrameRate,Averaging,',...
                              'Resolution,FOV_um,PowerPercent,PockelsValue,',...
                              'ModulationVoltage,FeedbackVoltage,PowerWatts,',...
                              'ZPosition,XPosition,YPosition,Notes\n'];
            end
        end

        function baseDir = getBaseDirectory(app, hSI, config)
            % Determine base directory with priority:
            % 1. Config setting if provided
            % 2. ScanImage's current path if set
            % 3. Default Box directory
            
            if ~isempty(config.baseDir)
                baseDir = config.baseDir;
            elseif ~isempty(hSI.hScan2D.logFilePath)
                baseDir = fileparts(hSI.hScan2D.logFilePath);
            else
                % Default to user's Box directory
                baseDir = fullfile('C:', 'Users', getenv('USERNAME'), 'Box', 'FOIL', 'Aaron');
                
                % Verify the directory exists, if not, fallback to Documents
                if ~exist(baseDir, 'dir')
                    baseDir = fullfile('C:', 'Users', getenv('USERNAME'), 'Documents');
                end
            end
        end

        function createSimulationMetadataFile(app)
            % Create metadata file for simulation mode
            config = app.getConfiguration();
            
            % Use configured base directory if available, otherwise use simulation directory
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

        function initializeMetadataLogging(app)
            try
                if ~isempty(app.LastSetupTime) && (now - app.LastSetupTime) < (5/86400)
                    return;
                end
                app.LastSetupTime = now;
                
                % Check if we're in simulation mode
                isSimulation = app.Controller.SimulationMode;
                
                if isSimulation
                    % Create simulation metadata file
                    app.createSimulationMetadataFile();
                    fprintf('Metadata logging initialized in simulation mode\n');
                    return;
                end
                
                try
                    hSI = evalin('base', 'hSI');
                catch ME
                    warning('%s: %s', ME.identifier, ME.message);
                    % Fall back to simulation mode
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
                warning('%s: %s', ME.identifier, ME.message);
                % Fall back to simulation mode
                app.createSimulationMetadataFile();
                fprintf('Metadata logging initialized in simulation mode due to error\n');
            end
        end

        function collectSimulatedMetadata(app)
            % Collect simulated metadata for testing
            try
                metadata = struct();
                
                % Basic info
                metadata.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
                metadata.filename = sprintf('sim_%s.tif', datestr(now, 'yyyymmdd_HHMMSS'));
                
                % Simulated scanner and imaging parameters
                metadata.scanner = 'Simulation';
                metadata.zoom = 1.0;
                metadata.frameRate = 30.0;
                metadata.averaging = 1;
                metadata.resolution = '512x512';
                metadata.fov = '100.0x100.0';
                
                % Simulated laser power info
                metadata.powerPercent = 50.0;
                metadata.pockelsValue = 0.5;
                metadata.feedbackValue = struct('modulation', '2.5', 'feedback', '1.2', 'power', '0.025');
                
                % Current stage position from controller
                metadata.xPos = app.Controller.CurrentXPosition;
                metadata.yPos = app.Controller.CurrentYPosition;
                metadata.zPos = app.Controller.CurrentPosition;
                
                % Write to file
                if ~isempty(app.MetadataFile) && exist(fileparts(app.MetadataFile), 'dir')
                    app.writeMetadataToFile(metadata, app.MetadataFile, false);
                end
                
            catch ME
                warning('%s: %s', ME.identifier, ME.message);
            end
        end

        function writeMetadataToFile(app, metadata, metadataFile, verbose)
            if isempty(metadataFile) || ~exist(fileparts(metadataFile), 'dir')
                return;
            end
            
            try
                % Format the metadata string
                if isstruct(metadata.feedbackValue)
                    metadataStr = sprintf('%s,%s,%s,%.2f,%.1f,%d,%s,%s,%.1f,%.3f,%s,%s,%s,%.1f,%.1f,%.1f,\n',...
                        metadata.timestamp, metadata.filename, metadata.scanner, ...
                        metadata.zoom, metadata.frameRate, metadata.averaging,...
                        metadata.resolution, metadata.fov, metadata.powerPercent, ...
                        metadata.pockelsValue, metadata.feedbackValue.modulation,...
                        metadata.feedbackValue.feedback, metadata.feedbackValue.power,...
                        metadata.zPos, metadata.xPos, metadata.yPos);
                else
                    % Handle case where feedbackValue is not a struct
                    metadataStr = sprintf('%s,%s,%s,%.2f,%.1f,%d,%s,%s,%.1f,%.3f,NA,NA,NA,%.1f,%.1f,%.1f,\n',...
                        metadata.timestamp, metadata.filename, metadata.scanner, ...
                        metadata.zoom, metadata.frameRate, metadata.averaging,...
                        metadata.resolution, metadata.fov, metadata.powerPercent, ...
                        metadata.pockelsValue, metadata.zPos, metadata.xPos, metadata.yPos);
                end
                
                if verbose
                    fprintf('Writing to file: %s\n', metadataFile);
                end
                
                % Use a simple fopen/fprintf approach for speed
                fid = fopen(metadataFile, 'a');
                if fid == -1
                    return; % Silently fail if file can't be opened
                end
                
                % Write and close quickly
                fprintf(fid, metadataStr);
                fclose(fid);
            catch
                % Silently fail for performance reasons
                if exist('fid', 'var') && fid ~= -1
                    fclose(fid);
                end
            end
        end

        function dataDir = createDataDirectory(app, baseDir, config)
            % Create directory using specified date format
            todayStr = datestr(now, config.dirFormat);
            dataDir = fullfile(baseDir, todayStr);
            
            % Create directory if it doesn't exist
            if ~exist(dataDir, 'dir')
                [success, msg] = mkdir(dataDir);
                if ~success
                    warning('Failed to create directory: %s\nError: %s', dataDir, msg);
                    % Fallback to base directory if needed
                    dataDir = baseDir;
                end
            end
        end

        function ensureMetadataFile(app, metadataFile, headers)
            % Create CSV file with headers if it doesn't exist
            if ~exist(metadataFile, 'file')
                try
                    fid = fopen(metadataFile, 'w');
                    if fid == -1
                        warning('Failed to create metadata file: %s', metadataFile);
                        return;
                    end
                    fprintf(fid, headers);
                    fclose(fid);
                catch ME
                    if fid ~= -1
                        fclose(fid);
                    end
                    warning('%s: %s', ME.identifier, ME.message);
                end
            end
        end

        function checkBeamSystem(app, hSI, verbose)
            % Diagnostic function to check beam system configuration
            if nargin < 3
                verbose = true; % Default to verbose output
            end
            
            try
                if verbose
                    fprintf('\n--- Beam System Diagnostics ---\n');
                end
                
                % Check if beam control exists
                if ~isprop(hSI, 'hBeams') || isempty(hSI.hBeams)
                    if verbose
                        fprintf('❌ No beam control system found\n');
                    end
                    return;
                end
                
                if verbose
                    fprintf('✓ Beam control system detected\n');
                end
                
                % Check beam controller type
                if isprop(hSI.hBeams, 'hBeams') && ~isempty(hSI.hBeams.hBeams)
                    beam = hSI.hBeams.hBeams{1};
                    if verbose
                        fprintf('✓ Beam controller type: %s\n', class(beam));
                    end
                    
                    % Check for timing properties
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
                
                % Check for Pockels cell
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
end 
