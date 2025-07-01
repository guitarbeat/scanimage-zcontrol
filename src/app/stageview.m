classdef stageview < matlab.apps.AppBase
    % stageview - Live Webcam Stage View Application
    %
    % This MATLAB App provides a dedicated window for viewing live microscope
    % stage feeds through connected webcams. Optimized for real-time monitoring
    % with support for multiple simultaneous live camera feeds.
    %
    % Key Features:
    %   - Automatic webcam detection and listing
    %   - Multi-camera live feeds with adaptive grid layout
    %   - Real-time preview with live status indicators
    %   - Flexible camera selection and management
    %   - Clean camera resource management
    %   - Independent window operation optimized for live viewing
    %
    % Usage:
    %   app = stageview();    % Launch the live stage view application
    %   delete(app);          % Clean shutdown when done
    
    %% Public Properties - UI Components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainLayout                  matlab.ui.container.GridLayout
        
        % Control Panel Components
        ControlPanel                matlab.ui.container.Panel
        CameraListBox               matlab.ui.control.ListBox
        StartLiveFeedButton         matlab.ui.control.Button
        StopAllFeedsButton          matlab.ui.control.Button
        RefreshButton               matlab.ui.control.Button
        StatusLabel                 matlab.ui.control.Label
        LiveIndicator               matlab.ui.control.Lamp
        FeedCountLabel              matlab.ui.control.Label
        
        % Display Panel
        DisplayPanel                matlab.ui.container.Panel
        NoFeedLabel                 matlab.ui.control.Label
    end
    
    %% Private Properties - Camera Management
    properties (Access = private)
        % Camera handles and resources
        CameraHandles = {}          % Cell array of webcam objects
        ImageHandles = {}           % Cell array of image handles
        AxisHandles = {}            % Cell array of axis handles
        CameraWindows = {}          % Cell array of individual camera window figures
        CameraWindowTitles = {}     % Cell array of camera window titles
        
        % Available cameras
        AvailableCameras = {}       % List of available camera names
        
        % State tracking
        IsLiveFeedActive = false    % Flag for live feed state
        ActiveCameraCount = 0       % Number of active cameras
        
        % Live feed management
        UpdateTimer                 % Timer for live status updates
        
        % Individual camera controls
        CameraCheckBoxes = {}       % Cell array of checkboxes for each camera
        CameraControlGrid           % Grid layout for individual camera controls
    end
    
    %% Constants
    properties (Constant, Access = private)
        % UI Configuration
        LIVE_INDICATOR_COLOR_ACTIVE = [0.2 0.8 0.2]     % Green for active
        LIVE_INDICATOR_COLOR_INACTIVE = [0.8 0.2 0.2]   % Red for inactive
        LIVE_TEXT_COLOR = [0.2 0.8 0.2]                 % Green for live text
        
        % Camera Configuration
        PREFERRED_RESOLUTION = '640x480'                 % Default resolution for live feeds
    end
    
    %% Constructor and Destructor
    methods (Access = public)
        function app = stageview()
            % stageview Constructor
            % 
            % Creates and initializes the Live Stage View application with webcam
            % detection, UI setup optimized for live feeds, and resource management.
            %
            % Initialization sequence:
            %   1. Create UI components optimized for live viewing
            %   2. Detect available webcams
            %   3. Set up event handlers
            %   4. Initialize live feed display
            %   5. Register app with MATLAB
            
            try
                % Create UI components
                app.createUIComponents();
                
                % Set up callbacks
                app.setupCallbacks();
                
                % Initialize application
                app.initializeApplication();
                
                % Register app
                registerApp(app, app.UIFigure);
                
            catch ME
                % Clean up on initialization failure
                fprintf('Failed to initialize Stage View: %s\n', ME.message);
                try
                    app.cleanup();
                    if isvalid(app.UIFigure)
                        delete(app.UIFigure);
                    end
                catch
                    % Ignore cleanup errors during initialization failure
                end
                rethrow(ME);
            end
            
            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            % stageview Destructor
            %
            % Performs clean shutdown including:
            %   - Stopping all live camera feeds
            %   - Releasing camera resources
            %   - Cleaning up timers
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
            % Create and configure all UI components optimized for live feeds
            
            % Main Figure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = 'Stage View - Camera Window Manager';
            app.UIFigure.Position = [200 200 480 400];
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Color = [0.94 0.94 0.94];
            
            % Main Layout
            app.MainLayout = uigridlayout(app.UIFigure);
            app.MainLayout.ColumnWidth = {200, '1x'};
            app.MainLayout.RowHeight = {'1x'};
            app.MainLayout.Padding = [5 5 5 5];
            app.MainLayout.ColumnSpacing = 5;
            
            % Control Panel
            app.ControlPanel = uipanel(app.MainLayout);
            app.ControlPanel.Title = 'Camera Controls';
            app.ControlPanel.Layout.Row = 1;
            app.ControlPanel.Layout.Column = 1;
            app.ControlPanel.FontWeight = 'bold';
            app.ControlPanel.FontSize = 10;
            
            % Create control panel layout
            controlLayout = uigridlayout(app.ControlPanel);
            controlLayout.ColumnWidth = {'1x'};
            controlLayout.RowHeight = {25, 20, '1x', 35, 35, 35, 20, 20};
            controlLayout.Padding = [8 8 8 8];
            controlLayout.RowSpacing = 4;
            
            % Live Status Indicator
            statusGrid = uigridlayout(controlLayout, [1, 3]);
            statusGrid.Layout.Row = 1;
            statusGrid.ColumnWidth = {20, '1x', 20};
            statusGrid.ColumnSpacing = 3;
            
            app.LiveIndicator = uilamp(statusGrid);
            app.LiveIndicator.Layout.Column = 1;
            app.LiveIndicator.Color = app.LIVE_INDICATOR_COLOR_INACTIVE;
            
            app.StatusLabel = uilabel(statusGrid);
            app.StatusLabel.Text = 'Initializing...';
            app.StatusLabel.Layout.Column = 2;
            app.StatusLabel.FontWeight = 'bold';
            app.StatusLabel.FontSize = 9;
            app.StatusLabel.HorizontalAlignment = 'center';
            
            % Feed Count Label
            app.FeedCountLabel = uilabel(controlLayout);
            app.FeedCountLabel.Text = 'No windows open';
            app.FeedCountLabel.Layout.Row = 2;
            app.FeedCountLabel.FontSize = 8;
            app.FeedCountLabel.FontColor = [0.5 0.5 0.5];
            app.FeedCountLabel.HorizontalAlignment = 'center';
            
            % Camera Controls Area
            listLabel = uilabel(controlLayout);
            listLabel.Text = 'Cameras:';
            listLabel.Layout.Row = 3;
            listLabel.FontWeight = 'bold';
            listLabel.FontSize = 9;
            
            % Create scrollable panel for camera controls
            app.CameraControlGrid = uigridlayout(controlLayout);
            app.CameraControlGrid.Layout.Row = 3;
            app.CameraControlGrid.ColumnWidth = {'1x'};
            app.CameraControlGrid.RowHeight = {};  % Will be set dynamically
            app.CameraControlGrid.Padding = [3 3 3 3];
            app.CameraControlGrid.RowSpacing = 2;
            
            % Control Buttons - Optimized for live feeds
            app.RefreshButton = uibutton(controlLayout, 'push');
            app.RefreshButton.Text = '🔄 Refresh';
            app.RefreshButton.Layout.Row = 4;
            app.RefreshButton.FontSize = 9;
            app.RefreshButton.BackgroundColor = [0.9 0.9 0.9];
            
            app.StartLiveFeedButton = uibutton(controlLayout, 'push');
            app.StartLiveFeedButton.Text = '🪟 Open Selected';
            app.StartLiveFeedButton.Layout.Row = 5;
            app.StartLiveFeedButton.FontSize = 9;
            app.StartLiveFeedButton.FontWeight = 'bold';
            app.StartLiveFeedButton.BackgroundColor = app.LIVE_INDICATOR_COLOR_ACTIVE;
            app.StartLiveFeedButton.FontColor = [1 1 1];
            
            app.StopAllFeedsButton = uibutton(controlLayout, 'push');
            app.StopAllFeedsButton.Text = '❌ Close All';
            app.StopAllFeedsButton.Layout.Row = 6;
            app.StopAllFeedsButton.FontSize = 9;
            app.StopAllFeedsButton.BackgroundColor = app.LIVE_INDICATOR_COLOR_INACTIVE;
            app.StopAllFeedsButton.FontColor = [1 1 1];
            
            % Instructions
            instructionLabel = uilabel(controlLayout);
            instructionLabel.Text = 'Check cameras to open windows';
            instructionLabel.Layout.Row = 7;
            instructionLabel.FontSize = 8;
            instructionLabel.FontColor = [0.5 0.5 0.5];
            instructionLabel.HorizontalAlignment = 'center';
            
            tipLabel = uilabel(controlLayout);
            tipLabel.Text = 'Each opens in separate window';
            tipLabel.Layout.Row = 8;
            tipLabel.FontSize = 8;
            tipLabel.FontColor = [0.3 0.3 0.7];
            tipLabel.HorizontalAlignment = 'center';
            
            % Display Panel - Status and information
            app.DisplayPanel = uipanel(app.MainLayout);
            app.DisplayPanel.Title = 'Status';
            app.DisplayPanel.Layout.Row = 1;
            app.DisplayPanel.Layout.Column = 2;
            app.DisplayPanel.FontWeight = 'bold';
            app.DisplayPanel.FontSize = 10;
            app.DisplayPanel.BackgroundColor = [0.95 0.95 0.95];
            
            % No Feed Placeholder
            app.NoFeedLabel = uilabel(app.DisplayPanel);
            app.NoFeedLabel.Text = {'🪟 Individual Windows', '', 'Check cameras to open', 'separate windows', '', 'Drag to position'};
            app.NoFeedLabel.Position = [10 10 240 120];
            app.NoFeedLabel.FontSize = 9;
            app.NoFeedLabel.FontColor = [0.4 0.4 0.4];
            app.NoFeedLabel.HorizontalAlignment = 'center';
            app.NoFeedLabel.VerticalAlignment = 'center';
            
            % Make figure visible
            app.UIFigure.Visible = 'on';
        end
        
        function setupCallbacks(app)
            % Set up all UI callback functions
            
            % Main window
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @app.onWindowClose, true);
            
            % Button callbacks
            app.RefreshButton.ButtonPushedFcn = createCallbackFcn(app, @app.onRefreshButtonPushed, true);
            app.StartLiveFeedButton.ButtonPushedFcn = createCallbackFcn(app, @app.onStartLiveFeedButtonPushed, true);
            app.StopAllFeedsButton.ButtonPushedFcn = createCallbackFcn(app, @app.onStopAllFeedsButtonPushed, true);
        end
        
        function initializeApplication(app)
            % Initialize the application
            app.refreshCameraList();
            app.updateUI();
            app.setupLiveStatusUpdates();
        end
        
        function setupLiveStatusUpdates(app)
            % Set up timer for live status updates
            app.UpdateTimer = timer('ExecutionMode', 'fixedRate', ...
                                   'Period', 2.0, ...
                                   'TimerFcn', @(~,~) app.updateLiveStatus());
        end
    end
    
    %% Camera Management Methods
    methods (Access = private)
        function refreshCameraList(app)
            % Detect and update the list of available cameras
            try
                % Clear existing camera controls
                app.clearCameraControls();
                
                app.AvailableCameras = webcamlist;
                if isempty(app.AvailableCameras)
                    % Create a message label when no cameras found
                    noLabel = uilabel(app.CameraControlGrid);
                    noLabel.Text = 'No cameras detected';
                    noLabel.FontColor = [0.7 0.3 0.3];
                    noLabel.HorizontalAlignment = 'center';
                    noLabel.Layout.Row = 1;
                    app.updateStatusDisplay('No cameras found', app.LIVE_INDICATOR_COLOR_INACTIVE);
                else
                    % Create checkboxes for each camera
                    app.createCameraControls();
                    app.updateStatusDisplay(sprintf('%d camera(s) available', length(app.AvailableCameras)), [0.2 0.6 0.2]);
                end
            catch ME
                % Create error message label
                errorLabel = uilabel(app.CameraControlGrid);
                errorLabel.Text = 'Error detecting cameras';
                errorLabel.FontColor = [0.8 0.2 0.2];
                errorLabel.HorizontalAlignment = 'center';
                errorLabel.Layout.Row = 1;
                app.updateStatusDisplay('Camera detection failed', app.LIVE_INDICATOR_COLOR_INACTIVE);
                warning('stageview:CameraDetection', 'Failed to detect cameras: %s', ME.message);
            end
        end
        
        function clearCameraControls(app)
            % Clear existing camera control UI elements
            delete(allchild(app.CameraControlGrid));
            app.CameraCheckBoxes = {};
            app.CameraControlGrid.RowHeight = {};
        end
        
        function createCameraControls(app)
            % Create checkbox controls for each available camera
            numCameras = length(app.AvailableCameras);
            app.CameraControlGrid.RowHeight = repmat({18}, 1, numCameras);
            app.CameraCheckBoxes = cell(1, numCameras);
            
            for i = 1:numCameras
                checkbox = uicheckbox(app.CameraControlGrid);
                checkbox.Text = app.AvailableCameras{i};
                checkbox.Layout.Row = i;
                checkbox.FontSize = 8;
                checkbox.ValueChangedFcn = @(src, event) app.onCameraCheckboxChanged(src, event, i);
                app.CameraCheckBoxes{i} = checkbox;
            end
        end
        
        function startSelectedLiveFeeds(app)
            % Open camera windows for all selected cameras
            app.updateStatusDisplay('Opening camera windows...', [1 0.8 0]);
            
            successCount = 0;
            for i = 1:length(app.CameraCheckBoxes)
                if ~isempty(app.CameraCheckBoxes{i}) && isvalid(app.CameraCheckBoxes{i}) && app.CameraCheckBoxes{i}.Value
                    try
                        app.openCameraWindow(i);
                        successCount = successCount + 1;
                    catch ME
                        uialert(app.UIFigure, ...
                               sprintf('Failed to open window for camera %s: %s', app.AvailableCameras{i}, ME.message), ...
                               'Camera Error');
                        continue;
                    end
                end
            end
            
            % Update status based on results
            if successCount > 0
                app.IsLiveFeedActive = true;
                app.ActiveCameraCount = successCount;
                app.updateStatusDisplay(sprintf('%d camera window(s) open', successCount), app.LIVE_INDICATOR_COLOR_ACTIVE);
                app.LiveIndicator.Color = app.LIVE_INDICATOR_COLOR_ACTIVE;
                
                % Start live status timer
                if ~isempty(app.UpdateTimer) && isvalid(app.UpdateTimer)
                    start(app.UpdateTimer);
                end
            else
                app.updateStatusDisplay('No camera windows opened', app.LIVE_INDICATOR_COLOR_INACTIVE);
            end
            
            app.updateUI();
        end
        
        function openCameraWindow(app, cameraIndex)
            % Open an individual camera window
            if cameraIndex > length(app.AvailableCameras)
                error('Invalid camera index');
            end
            
            % Check if window already exists for this camera
            if length(app.CameraWindows) >= cameraIndex && ...
               ~isempty(app.CameraWindows{cameraIndex}) && ...
               isvalid(app.CameraWindows{cameraIndex})
                % Window already exists, bring to front
                figure(app.CameraWindows{cameraIndex});
                return;
            end
            
            cameraName = app.AvailableCameras{cameraIndex};
            
            % Create webcam object
            cam = webcam(cameraIndex);
            app.optimizeCameraForLiveFeed(cam);
            
            % Calculate window position (offset from main window)
            mainPos = app.UIFigure.Position;
            windowWidth = 360;
            windowHeight = 300;
            offsetX = 30 + (cameraIndex - 1) * 25;  % Cascade windows
            offsetY = 30 + (cameraIndex - 1) * 25;
            windowPos = [mainPos(1) + mainPos(3) + offsetX, mainPos(2) + offsetY, windowWidth, windowHeight];
            
            % Create camera window
            fig = uifigure('Name', sprintf('📹 %s', cameraName), ...
                          'Position', windowPos, ...
                          'Color', [0.1 0.1 0.1], ...
                          'Resize', 'on');
            
            % Create axes for camera display
            ax = axes('Parent', fig, ...
                     'Units', 'normalized', ...
                     'Position', [0.05 0.05 0.9 0.9], ...
                     'Color', [0.05 0.05 0.05]);
            
            % Take initial frame and create image with error handling
            try
                frame = snapshot(cam);
            catch
                % If snapshot fails, create a placeholder frame
                frame = uint8(zeros(480, 640, 3)); % Default black frame
                % Add text overlay
                frame(200:280, 200:450, 1) = 128; % Gray text area
                frame(200:280, 200:450, 2) = 128;
                frame(200:280, 200:450, 3) = 128;
            end
            
            img = image(frame, 'Parent', ax);
            axis(ax, 'off');
            
            % Set window close callback
            fig.CloseRequestFcn = @(src, event) app.closeCameraWindow(cameraIndex);
            
            % Store handles
            if length(app.CameraWindows) < cameraIndex
                app.CameraWindows{cameraIndex} = [];
                app.CameraHandles{cameraIndex} = [];
                app.ImageHandles{cameraIndex} = [];
                app.AxisHandles{cameraIndex} = [];
            end
            
            app.CameraWindows{cameraIndex} = fig;
            app.CameraHandles{cameraIndex} = cam;
            app.ImageHandles{cameraIndex} = img;
            app.AxisHandles{cameraIndex} = ax;
            
            % Start live preview with error handling
            try
                preview(cam, img);
            catch ME
                % If preview fails, show error message in window
                text(ax, 0.5, 0.5, {'Camera Preview Failed', ME.message}, ...
                     'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                     'Color', 'red', 'FontSize', 12);
                warning('stageview:Preview', 'Failed to start camera preview: %s', ME.message);
            end
        end
        
        function closeCameraWindow(app, cameraIndex)
            % Close a specific camera window
            try
                % Stop camera preview
                if length(app.CameraHandles) >= cameraIndex && ...
                   ~isempty(app.CameraHandles{cameraIndex}) && ...
                   isvalid(app.CameraHandles{cameraIndex})
                    closePreview(app.CameraHandles{cameraIndex});
                    clear app.CameraHandles{cameraIndex};
                    app.CameraHandles{cameraIndex} = [];
                end
                
                % Close window
                if length(app.CameraWindows) >= cameraIndex && ...
                   ~isempty(app.CameraWindows{cameraIndex}) && ...
                   isvalid(app.CameraWindows{cameraIndex})
                    delete(app.CameraWindows{cameraIndex});
                    app.CameraWindows{cameraIndex} = [];
                end
                
                % Clear other handles
                if length(app.ImageHandles) >= cameraIndex
                    app.ImageHandles{cameraIndex} = [];
                end
                if length(app.AxisHandles) >= cameraIndex
                    app.AxisHandles{cameraIndex} = [];
                end
                
                % Uncheck the corresponding checkbox
                if length(app.CameraCheckBoxes) >= cameraIndex && ...
                   ~isempty(app.CameraCheckBoxes{cameraIndex}) && ...
                   isvalid(app.CameraCheckBoxes{cameraIndex})
                    app.CameraCheckBoxes{cameraIndex}.Value = false;
                end
                
                % Update active camera count
                app.ActiveCameraCount = app.countActiveCameras();
                if app.ActiveCameraCount == 0
                    app.IsLiveFeedActive = false;
                    app.LiveIndicator.Color = app.LIVE_INDICATOR_COLOR_INACTIVE;
                    app.updateStatusDisplay('No camera windows open', [0.5 0.5 0.5]);
                    
                    % Stop timer
                    if ~isempty(app.UpdateTimer) && isvalid(app.UpdateTimer)
                        stop(app.UpdateTimer);
                    end
                else
                    app.updateStatusDisplay(sprintf('%d camera window(s) open', app.ActiveCameraCount), app.LIVE_INDICATOR_COLOR_ACTIVE);
                end
                
                app.updateUI();
                
            catch ME
                warning('stageview:WindowClose', 'Error closing camera window %d: %s', cameraIndex, ME.message);
            end
        end
        
        function count = countActiveCameras(app)
            % Count how many camera windows are currently open
            count = 0;
            for i = 1:length(app.CameraWindows)
                if ~isempty(app.CameraWindows{i}) && isvalid(app.CameraWindows{i})
                    count = count + 1;
                end
            end
        end
        
        function stopAllLiveFeeds(app)
            % Close all camera windows and release resources
            
            % Check if app is valid before proceeding
            if isempty(app)
                return;
            end
            
            % Stop timer
            try
                if ~isempty(app.UpdateTimer) && isvalid(app.UpdateTimer)
                    stop(app.UpdateTimer);
                end
            catch
                % Ignore timer cleanup errors
            end
            
            % Close all camera windows
            try
                for i = 1:length(app.CameraWindows)
                    if ~isempty(app.CameraWindows{i}) && isvalid(app.CameraWindows{i})
                        % Temporarily disable the close callback to avoid recursive calls
                        app.CameraWindows{i}.CloseRequestFcn = '';
                        delete(app.CameraWindows{i});
                    end
                end
            catch
                % Handle errors during window cleanup
            end
            
            % Stop camera previews and clear handles
            try
                for i = 1:length(app.CameraHandles)
                    try
                        if ~isempty(app.CameraHandles{i}) && isvalid(app.CameraHandles{i})
                            closePreview(app.CameraHandles{i});
                            clear app.CameraHandles{i};
                        end
                    catch
                        % Ignore errors during camera cleanup
                    end
                end
            catch
                % Handle case where CameraHandles doesn't exist
            end
            
            % Clear all handles safely
            try
                app.CameraHandles = {};
                app.ImageHandles = {};
                app.AxisHandles = {};
                app.CameraWindows = {};
                app.CameraWindowTitles = {};
            catch
                % Ignore if properties don't exist
            end
            
            % Uncheck all camera checkboxes
            try
                for i = 1:length(app.CameraCheckBoxes)
                    if ~isempty(app.CameraCheckBoxes{i}) && isvalid(app.CameraCheckBoxes{i})
                        app.CameraCheckBoxes{i}.Value = false;
                    end
                end
            catch
                % Ignore checkbox update errors
            end
            
            % Update state safely
            try
                app.IsLiveFeedActive = false;
                app.ActiveCameraCount = 0;
                app.updateStatusDisplay('All camera windows closed', [0.5 0.5 0.5]);
                if ~isempty(app.LiveIndicator) && isvalid(app.LiveIndicator)
                    app.LiveIndicator.Color = app.LIVE_INDICATOR_COLOR_INACTIVE;
                end
                app.updateUI();
            catch
                % Ignore status update errors during cleanup
            end
        end
        
        function optimizeCameraForLiveFeed(app, cam)
            % Optimize camera settings for live feed performance
            try
                % Set preferred resolution if available
                if ~isempty(cam.AvailableResolutions)
                    resolutions = cam.AvailableResolutions;
                    
                    % Try to find the preferred resolution
                    preferredIdx = find(contains(resolutions, app.PREFERRED_RESOLUTION), 1);
                    if ~isempty(preferredIdx)
                        try
                            cam.Resolution = resolutions{preferredIdx};
                            % Test if this resolution works by taking a snapshot
                            pause(0.5); % Allow camera to adjust
                            snapshot(cam);
                        catch
                            % If preferred resolution fails, try the first available
                            try
                                cam.Resolution = resolutions{1};
                                pause(0.5);
                                snapshot(cam);
                            catch
                                % If that fails too, leave at default
                                warning('stageview:Resolution', 'Camera resolution adjustment failed, using default');
                            end
                        end
                    else
                        % Use the first available resolution
                        try
                            cam.Resolution = resolutions{1};
                            pause(0.5);
                            snapshot(cam);
                        catch
                            % If that fails, leave at default
                            warning('stageview:Resolution', 'Camera resolution adjustment failed, using default');
                        end
                    end
                end
            catch ME
                % Continue if resolution setting fails completely
                warning('stageview:CameraOptimization', 'Failed to optimize camera settings: %s', ME.message);
            end
        end
        
        function updateLiveStatus(app)
            % Update live status indicators periodically
            try
                if ~isempty(app.FeedCountLabel) && isvalid(app.FeedCountLabel)
                    if app.IsLiveFeedActive && app.ActiveCameraCount > 0
                        % Update window count with live indicator
                        currentTime = char(datetime('now', 'Format', 'HH:mm:ss'));
                        app.FeedCountLabel.Text = sprintf('🪟 %d window(s) open - %s', app.ActiveCameraCount, currentTime);
                        app.FeedCountLabel.FontColor = app.LIVE_TEXT_COLOR;
                    else
                        app.FeedCountLabel.Text = 'No windows open';
                        app.FeedCountLabel.FontColor = [0.5 0.5 0.5];
                    end
                end
            catch
                % Ignore live status update errors
            end
        end
        
        function updateStatusDisplay(app, message, color)
            % Update status display with message and color
            try
                if ~isempty(app.StatusLabel) && isvalid(app.StatusLabel)
                    app.StatusLabel.Text = message;
                    app.StatusLabel.FontColor = color;
                end
            catch
                % Ignore status display errors
            end
        end
        
        function onCameraCheckboxChanged(app, src, ~, cameraIndex)
            % Handle checkbox changes for individual cameras
            if src.Value
                % Checkbox was checked - open camera window
                try
                    app.openCameraWindow(cameraIndex);
                    app.ActiveCameraCount = app.countActiveCameras();
                    if app.ActiveCameraCount > 0
                        app.IsLiveFeedActive = true;
                        app.LiveIndicator.Color = app.LIVE_INDICATOR_COLOR_ACTIVE;
                        app.updateStatusDisplay(sprintf('%d camera window(s) open', app.ActiveCameraCount), app.LIVE_INDICATOR_COLOR_ACTIVE);
                        
                        % Start timer if not already running
                        if ~isempty(app.UpdateTimer) && isvalid(app.UpdateTimer) && strcmp(app.UpdateTimer.Running, 'off')
                            start(app.UpdateTimer);
                        end
                    end
                    app.updateUI();
                catch ME
                    % Uncheck the box if opening failed
                    src.Value = false;
                    uialert(app.UIFigure, ...
                           sprintf('Failed to open camera window: %s', ME.message), ...
                           'Camera Error');
                end
            else
                % Checkbox was unchecked - close camera window
                app.closeCameraWindow(cameraIndex);
            end
        end
        
        function updateUI(app)
            % Update UI state based on current camera window conditions
            
            try
                % Enable/disable buttons based on state
                hasActiveCameras = app.ActiveCameraCount > 0;
                hasCamerasAvailable = ~isempty(app.AvailableCameras) && ...
                                     ~strcmp(app.AvailableCameras{1}, 'No cameras detected');
                hasSelectedCameras = app.hasSelectedCameras();
                
                if ~isempty(app.StartLiveFeedButton) && isvalid(app.StartLiveFeedButton)
                    app.StartLiveFeedButton.Enable = hasCamerasAvailable && hasSelectedCameras;
                end
                
                if ~isempty(app.StopAllFeedsButton) && isvalid(app.StopAllFeedsButton)
                    app.StopAllFeedsButton.Enable = hasActiveCameras;
                end
                
                % Update button appearance based on state
                if ~isempty(app.StartLiveFeedButton) && isvalid(app.StartLiveFeedButton)
                    if hasSelectedCameras
                        app.StartLiveFeedButton.Text = '🪟 Open Selected';
                        app.StartLiveFeedButton.BackgroundColor = app.LIVE_INDICATOR_COLOR_ACTIVE;
                    else
                        app.StartLiveFeedButton.Text = '🪟 Select First';
                        app.StartLiveFeedButton.BackgroundColor = [0.7 0.7 0.7];
                    end
                end
            catch
                % Ignore UI update errors
            end
        end
        
        function hasSelected = hasSelectedCameras(app)
            % Check if any cameras are selected via checkboxes
            hasSelected = false;
            try
                for i = 1:length(app.CameraCheckBoxes)
                    if ~isempty(app.CameraCheckBoxes{i}) && isvalid(app.CameraCheckBoxes{i}) && app.CameraCheckBoxes{i}.Value
                        hasSelected = true;
                        break;
                    end
                end
            catch
                % Ignore errors
            end
        end
    end
    
    %% UI Event Handlers
    methods (Access = private)
        function onRefreshButtonPushed(app, varargin)
            app.refreshCameraList();
            app.updateUI();
        end
        
        function onStartLiveFeedButtonPushed(app, varargin)
            app.startSelectedLiveFeeds();
        end
        
        function onStopAllFeedsButtonPushed(app, varargin)
            app.stopAllLiveFeeds();
        end
        
        function onWindowClose(app, varargin)
            app.cleanup();
            delete(app);
        end
    end
    
    %% Helper Methods
    methods (Access = private)
        function cleanup(app)
            % Clean up all resources
            
            % Check if app is valid
            if isempty(app)
                return;
            end
            
            % Stop timer safely
            try
                if ~isempty(app.UpdateTimer) && isvalid(app.UpdateTimer)
                    stop(app.UpdateTimer);
                    delete(app.UpdateTimer);
                end
            catch
                % Ignore timer cleanup errors
            end
            
            % Close all camera windows safely
            try
                app.stopAllLiveFeeds();
            catch
                % Ignore window cleanup errors
            end
        end
    end
end 