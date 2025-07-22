classdef StageView < handle
    % Manages the Stage View - Microscope Camera Feed window

    properties (Access = public)
        % UI Components
        UIFigure
        MainLayout
        ControlPanel
        StatusLabel
        CameraListBox
        RefreshButton
        StartAllButton
        StopAllButton
        SnapshotAllButton
        StartRecordingButton
        StopRecordingButton
        RecordingStatusLabel
        
        % Periodic Capture UI Components
        StartPeriodicButton
        StopPeriodicButton
        IntervalSpinner
        IntervalLabel
        RecordingElapsedLabel
        % Add next capture label to public UI properties
        NextCaptureLabel
    end

    properties (Access = private)
        % Camera and UI State
        ActivePreviews = {} % Cell array of structs, each holding {name, camera, figure}
        AvailableCameras = {}
        IsPreviewActive = false

        % Video Recording State
        IsRecording = false;
        VideoWriterObj = [];
        VideoRecordTimer = [];
        RecordingStartTime = [];
        RecordingFileName = '';
        
        % Periodic Capture System
        SelectedCameras = {}           % Cell array of selected camera names
        CaptureTimer = []              % Timer for periodic capture cycle
        CurrentCameraIndex = 1         % Index of current camera in cycle
        CaptureInterval = 1.0          % Seconds between captures (configurable)
        
        % Display Management
        CameraDisplays                 % Map of camera name -> display data struct
        DisplayFigure = []             % Single figure for all camera displays
        DisplayLayout = []             % Tiled layout for multiple camera views
        
        % Capture State
        IsPeriodicCaptureActive = false
        LastCaptureTime = datetime.empty
        CaptureErrors                  % Map to track errors per camera
    end

    methods
        function obj = StageView()
            % Constructor: Creates the Stage View window and initializes components
            
            % Initialize containers.Map objects
            obj.CameraDisplays = containers.Map();
            obj.CaptureErrors = containers.Map();
            
            obj.createUI();
            obj.setupCallbacks();
            obj.initialize();
        end

        function delete(obj)
            % Destructor: Cleans up all resources
            obj.stopPeriodicCapture();
            obj.stopAllCameras();

            % Delete the figure if it exists and is valid
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                delete(obj.UIFigure);
            end
        end
    end

    methods (Access = public)
        function bringToFront(obj)
            % Brings the UI figure to the front
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                figure(obj.UIFigure);
            end
        end
    end

    methods (Access = private)
        % UI and App Lifecycle
        function createUI(obj)
            % Create and configure all stage view UI components

            % Main Figure
            obj.UIFigure = uifigure('Visible', 'off');
            obj.UIFigure.Name = 'Stage View - Live Camera Control';
            obj.UIFigure.Position = [200 200 400 400];  % Even more compact initial height
            obj.UIFigure.AutoResizeChildren = 'on'; % * Enable responsive resizing

            % Main Layout
            obj.MainLayout = uigridlayout(obj.UIFigure);
            obj.MainLayout.ColumnWidth = {'1x'};
            obj.MainLayout.RowHeight = {'fit', '1x'}; % Remove status label row
            obj.MainLayout.Padding = [1 1 1 1];
            obj.MainLayout.RowSpacing = 1;

            % Header
            headerLabel = uilabel(obj.MainLayout);
            headerLabel.Text = 'Stage View - Live Camera Control';
            headerLabel.FontSize = 18;
            headerLabel.FontWeight = 'bold';
            headerLabel.HorizontalAlignment = 'center';
            headerLabel.Layout.Row = 1;
            headerLabel.Layout.Column = 1;

            % Main Control Panel (with sub-panels)
            obj.ControlPanel = uipanel(obj.MainLayout);
            obj.ControlPanel.Title = '';
            obj.ControlPanel.Layout.Row = 2;
            obj.ControlPanel.Layout.Column = 1;
            obj.ControlPanel.BackgroundColor = [0.98 0.99 1.0];

            % Sub-layout for grouped controls
            mainControlLayout = uigridlayout(obj.ControlPanel);
            mainControlLayout.RowHeight = {'fit', '1x', 'fit'}; % * Make recording panel expand
            mainControlLayout.ColumnWidth = {'1x'};
            mainControlLayout.Padding = [5 5 5 5];
            mainControlLayout.RowSpacing = 10;

            %% Camera Actions Group
            cameraPanel = uipanel(mainControlLayout);
            cameraPanel.Title = 'Camera Actions';
            cameraPanel.Layout.Row = 1;
            cameraPanel.Layout.Column = 1;
            cameraPanel.BackgroundColor = [0.96 0.97 0.98];
            cameraLayout = uigridlayout(cameraPanel);
            cameraLayout.RowHeight = {'1x', 'fit', 'fit', 'fit', 'fit'}; % * Camera list grows with panel
            cameraLayout.ColumnWidth = {'1x', '1x'};
            cameraLayout.Padding = [1 1 1 1];
            cameraLayout.RowSpacing = 1;
            cameraLayout.ColumnSpacing = 1;

            % Camera List Box
            obj.CameraListBox = uilistbox(cameraLayout);
            obj.CameraListBox.Layout.Row = 1;
            obj.CameraListBox.Layout.Column = [1 2];
            obj.CameraListBox.Multiselect = 'on';
            obj.CameraListBox.Items = {};
            obj.CameraListBox.FontSize = 11;
            obj.CameraListBox.Tooltip = 'Select camera(s) for preview or periodic capture';

            % Refresh Button
            obj.RefreshButton = uibutton(cameraLayout, 'push');
            obj.RefreshButton.Text = 'Refresh';
            obj.RefreshButton.Layout.Row = 2;
            obj.RefreshButton.Layout.Column = 1;
            obj.RefreshButton.BackgroundColor = [0.2 0.6 0.8];
            obj.RefreshButton.FontColor = [1 1 1];
            obj.RefreshButton.Tooltip = 'Refresh camera list';
            obj.RefreshButton.FontSize = 12;

            % Start Camera Button
            obj.StartAllButton = uibutton(cameraLayout, 'push');
            obj.StartAllButton.Text = 'Start';
            obj.StartAllButton.Layout.Row = 2;
            obj.StartAllButton.Layout.Column = 2;
            obj.StartAllButton.BackgroundColor = [0.16 0.68 0.38];
            obj.StartAllButton.FontColor = [1 1 1];
            obj.StartAllButton.Tooltip = 'Start preview for selected camera(s)';
            obj.StartAllButton.FontSize = 12;

            % Stop Camera Button
            obj.StopAllButton = uibutton(cameraLayout, 'push');
            obj.StopAllButton.Text = 'Stop';
            obj.StopAllButton.Layout.Row = 3;
            obj.StopAllButton.Layout.Column = 1;
            obj.StopAllButton.BackgroundColor = [0.86 0.24 0.24];
            obj.StopAllButton.FontColor = [1 1 1];
            obj.StopAllButton.Tooltip = 'Stop all camera previews';
            obj.StopAllButton.FontSize = 12;

            % Snapshot Button
            obj.SnapshotAllButton = uibutton(cameraLayout, 'push');
            obj.SnapshotAllButton.Text = 'Snapshot';
            obj.SnapshotAllButton.Layout.Row = 3;
            obj.SnapshotAllButton.Layout.Column = 2;
            obj.SnapshotAllButton.BackgroundColor = [0.2 0.6 0.8];
            obj.SnapshotAllButton.FontColor = [1 1 1];
            obj.SnapshotAllButton.Tooltip = 'Capture a snapshot from the active camera';
            obj.SnapshotAllButton.FontSize = 12;

            %% Recording Group
            recordingPanel = uipanel(mainControlLayout);
            recordingPanel.Title = 'Recording';
            recordingPanel.Layout.Row = 2;
            recordingPanel.Layout.Column = 1;
            recordingPanel.BackgroundColor = [0.98 0.95 0.90];
            recordingLayout = uigridlayout(recordingPanel);
            recordingLayout.RowHeight = {'fit', 'fit', '1x'}; % * Elapsed label grows
            recordingLayout.ColumnWidth = {'1x', '1x'};
            recordingLayout.Padding = [1 1 1 1];
            recordingLayout.RowSpacing = 1;
            recordingLayout.ColumnSpacing = 1;

            % Start Recording Button
            obj.StartRecordingButton = uibutton(recordingLayout, 'push');
            obj.StartRecordingButton.Text = 'Record';
            obj.StartRecordingButton.Layout.Row = 1;
            obj.StartRecordingButton.Layout.Column = 1;
            obj.StartRecordingButton.BackgroundColor = [0.9 0.6 0.2];
            obj.StartRecordingButton.FontColor = [1 1 1];
            obj.StartRecordingButton.Tooltip = 'Start video recording';
            obj.StartRecordingButton.FontSize = 12;

            % Stop Recording Button
            obj.StopRecordingButton = uibutton(recordingLayout, 'push');
            obj.StopRecordingButton.Text = 'Stop';
            obj.StopRecordingButton.Layout.Row = 1;
            obj.StopRecordingButton.Layout.Column = 2;
            obj.StopRecordingButton.BackgroundColor = [0.86 0.24 0.24];
            obj.StopRecordingButton.FontColor = [1 1 1];
            obj.StopRecordingButton.Tooltip = 'Stop video recording';
            obj.StopRecordingButton.FontSize = 12;
            obj.StopRecordingButton.Enable = 'off';

            % Recording Status Label
            obj.RecordingStatusLabel = uilabel(recordingLayout);
            obj.RecordingStatusLabel.Text = 'Not recording';
            obj.RecordingStatusLabel.Layout.Row = 2;
            obj.RecordingStatusLabel.Layout.Column = [1 2];
            obj.RecordingStatusLabel.FontColor = [0.5 0.5 0.5];
            obj.RecordingStatusLabel.FontWeight = 'bold';
            obj.RecordingStatusLabel.FontSize = 11;
            obj.RecordingStatusLabel.HorizontalAlignment = 'center';

            % Elapsed Recording Time
            obj.RecordingElapsedLabel = uilabel(recordingLayout);
            obj.RecordingElapsedLabel.Text = 'Elapsed: 00:00';
            obj.RecordingElapsedLabel.Layout.Row = 3;
            obj.RecordingElapsedLabel.Layout.Column = [1 2];
            obj.RecordingElapsedLabel.FontColor = [0.2 0.6 0.8];
            obj.RecordingElapsedLabel.FontSize = 10;
            obj.RecordingElapsedLabel.HorizontalAlignment = 'center';

            %% Periodic Capture Group
            periodicPanel = uipanel(mainControlLayout);
            periodicPanel.Title = 'Periodic Capture';
            periodicPanel.Layout.Row = 3;
            periodicPanel.Layout.Column = 1;
            periodicPanel.BackgroundColor = [0.95 0.98 0.95];
            periodicLayout = uigridlayout(periodicPanel);
            periodicLayout.RowHeight = {'fit', 'fit', '1x', 'fit'}; % * Next capture label grows
            periodicLayout.ColumnWidth = {'1x', '1x'};
            periodicLayout.Padding = [1 1 1 1];
            periodicLayout.RowSpacing = 1;
            periodicLayout.ColumnSpacing = 1;

            % Start Periodic Capture Button
            obj.StartPeriodicButton = uibutton(periodicLayout, 'push');
            obj.StartPeriodicButton.Text = 'Start Periodic';
            obj.StartPeriodicButton.Layout.Row = 1;
            obj.StartPeriodicButton.Layout.Column = 1;
            obj.StartPeriodicButton.BackgroundColor = [0.16 0.68 0.38];
            obj.StartPeriodicButton.FontColor = [1 1 1];
            obj.StartPeriodicButton.Tooltip = 'Start periodic capture for all available cameras';
            obj.StartPeriodicButton.FontSize = 12;

            % Stop Periodic Capture Button
            obj.StopPeriodicButton = uibutton(periodicLayout, 'push');
            obj.StopPeriodicButton.Text = 'Stop';
            obj.StopPeriodicButton.Layout.Row = 1;
            obj.StopPeriodicButton.Layout.Column = 2;
            obj.StopPeriodicButton.BackgroundColor = [0.86 0.24 0.24];
            obj.StopPeriodicButton.FontColor = [1 1 1];
            obj.StopPeriodicButton.Tooltip = 'Stop periodic capture';
            obj.StopPeriodicButton.FontSize = 12;
            obj.StopPeriodicButton.Enable = 'off';

            % Interval Label
            obj.IntervalLabel = uilabel(periodicLayout);
            obj.IntervalLabel.Text = 'Interval (seconds):';
            obj.IntervalLabel.Layout.Row = 2;
            obj.IntervalLabel.Layout.Column = 1;
            obj.IntervalLabel.FontSize = 11;
            obj.IntervalLabel.HorizontalAlignment = 'right';

            % Interval Spinner
            obj.IntervalSpinner = uispinner(periodicLayout);
            obj.IntervalSpinner.Layout.Row = 2;
            obj.IntervalSpinner.Layout.Column = 2;
            obj.IntervalSpinner.Limits = [0.5 10];
            obj.IntervalSpinner.Value = 1.0;
            obj.IntervalSpinner.Step = 0.1;
            obj.IntervalSpinner.FontSize = 11;
            obj.IntervalSpinner.Tooltip = 'Set interval for periodic capture';

            % Next Capture Label
            obj.NextCaptureLabel = uilabel(periodicLayout);
            obj.NextCaptureLabel.Text = 'Next: --:--:--';
            obj.NextCaptureLabel.Layout.Row = 3;
            obj.NextCaptureLabel.Layout.Column = [1 2];
            obj.NextCaptureLabel.FontColor = [0.2 0.6 0.8];
            obj.NextCaptureLabel.FontSize = 10;
            obj.NextCaptureLabel.HorizontalAlignment = 'center';

            % Make figure visible
            obj.UIFigure.Visible = 'on';
        end

        function setupCallbacks(obj)
            % Set up all UI callback functions

            % Main window
            obj.UIFigure.CloseRequestFcn = @(~,~) delete(obj);

            % Button callbacks
            obj.RefreshButton.ButtonPushedFcn = @(~,~) obj.onRefreshButtonPushed();
            obj.StartAllButton.ButtonPushedFcn = @(~,~) obj.onStartAllButtonPushed();
            obj.StopAllButton.ButtonPushedFcn = @(~,~) obj.onStopAllButtonPushed();
            obj.SnapshotAllButton.ButtonPushedFcn = @(~,~) obj.onSnapshotAllButtonPushed();
            obj.StartRecordingButton.ButtonPushedFcn = @(~,~) obj.onStartRecordingButtonPushed();
            obj.StopRecordingButton.ButtonPushedFcn = @(~,~) obj.onStopRecordingButtonPushed();
            
            % Periodic capture callbacks
            obj.StartPeriodicButton.ButtonPushedFcn = @(~,~) obj.onStartPeriodicButtonPushed();
            obj.StopPeriodicButton.ButtonPushedFcn = @(~,~) obj.onStopPeriodicButtonPushed();
            obj.IntervalSpinner.ValueChangedFcn = @(~,~) obj.onIntervalChanged();
            
            % Camera selection callback
            obj.CameraListBox.ValueChangedFcn = @(~,~) obj.updateSelectedCameras();
        end

        function initialize(obj)
            % Initialize the application.
            obj.refreshCameraList();
            obj.updateUI();
        end

        function updateUI(obj)
            % Update UI state based on current conditions

            % Enable/disable buttons based on state
            hasActiveCameras = ~isempty(obj.ActivePreviews);
            hasCamerasAvailable = ~isempty(obj.AvailableCameras) && ...
                ~strcmp(obj.AvailableCameras{1}, 'No cameras detected');

            obj.StartAllButton.Enable = hasCamerasAvailable;
            obj.StopAllButton.Enable = hasActiveCameras;
            obj.SnapshotAllButton.Enable = hasActiveCameras;
            obj.StartRecordingButton.Enable = obj.IsPreviewActive && ~obj.IsRecording;
            obj.StopRecordingButton.Enable = obj.IsRecording;
            obj.StartPeriodicButton.Enable = hasCamerasAvailable && ~obj.IsPeriodicCaptureActive;
            obj.StopPeriodicButton.Enable = obj.IsPeriodicCaptureActive;
            obj.IntervalSpinner.Enable = ~obj.IsPeriodicCaptureActive;

            % Update status bar color
            if obj.IsRecording
                obj.StatusLabel.BackgroundColor = [0.9 0.6 0.2]; % Orange for recording
            elseif obj.IsPeriodicCaptureActive
                obj.StatusLabel.BackgroundColor = [0.2 0.6 0.8]; % Blue for periodic
            elseif hasActiveCameras
                obj.StatusLabel.BackgroundColor = [0.16 0.68 0.38]; % Green for active
            elseif hasCamerasAvailable
                obj.StatusLabel.BackgroundColor = [1 1 1]; % White/neutral for ready (no orange block)
            else
                obj.StatusLabel.BackgroundColor = [0.86 0.24 0.24]; % Red for error
            end
        end

        % Camera Operations
        function refreshCameraList(obj)
            % Detect and update the list of available cameras
            try
                obj.AvailableCameras = webcamlist;
                if isempty(obj.AvailableCameras)
                    obj.CameraListBox.Items = {'No cameras detected'};
                    obj.StatusLabel.Text = 'No cameras found';
                    obj.StatusLabel.FontColor = [0.8 0.2 0.2];
                else
                    obj.CameraListBox.Items = obj.AvailableCameras;
                    % REMOVED: obj.StatusLabel.Text = sprintf('%d camera(s) detected', length(obj.AvailableCameras));
                    % REMOVED: obj.StatusLabel.FontColor = [0.2 0.6 0.2];
                    obj.StatusLabel.Text = '';
                    obj.StatusLabel.FontColor = [0.2 0.6 0.2];
                end
            catch ME
                obj.CameraListBox.Items = {'Error detecting cameras'};
                obj.StatusLabel.Text = 'Camera detection failed';
                obj.StatusLabel.FontColor = [0.8 0.2 0.2];
                FoilviewUtils.logException('StageView', ME, 'Failed to detect cameras');
            end
        end

        function startSelectedCameras(obj)
            % Start preview for the selected camera, stopping any other active preview first.

            % Stop any and all currently running previews to free up hardware resources.
            if obj.IsPreviewActive
                obj.stopAllCameras();
                pause(0.5); % Give hardware time to release
            end

            % Get selected camera
            selectedValue = obj.CameraListBox.Value;
            
            % Handle both single selection (char) and multi-selection (cell array)
            if iscell(selectedValue)
                if isempty(selectedValue)
                    uialert(obj.UIFigure, 'Please select a camera to start.', 'No Selection');
                    return;
                end
                camName = selectedValue{1}; % Use first selected camera
            else
                camName = selectedValue;
            end
            
            if isempty(camName) || strcmp(camName, 'No cameras detected')
                uialert(obj.UIFigure, 'Please select a camera to start.', 'No Selection');
                return;
            end

            obj.StatusLabel.Text = 'Starting camera...';
            drawnow;

            try
                % Create webcam object
                cam = webcam(camName);

                % Let MATLAB create the figure by calling preview
                hImage = preview(cam);

                % Traverse up the parent hierarchy to find the figure handle reliably
                hParent = hImage.Parent;
                while ~isempty(hParent) && ~isa(hParent, 'matlab.ui.Figure')
                    hParent = hParent.Parent;
                end

                if isempty(hParent) || ~isvalid(hParent)
                    error('StageView:FigureNotFound', 'Could not find parent figure for the camera preview.');
                end
                hFig = hParent;

                hFig.Name = sprintf('Live Feed: %s', camName);
                set(hFig, 'MenuBar', 'none', 'ToolBar', 'none', 'Color', [0 0 0]);
                % Make axes tight
                ax = hImage.Parent;
                if isa(ax, 'matlab.graphics.axis.Axes')
                    ax.Units = 'normalized';
                    ax.Position = [0 0 1 1];
                    ax.XColor = 'none';
                    ax.YColor = 'none';
                    ax.Box = 'off';
                    ax.XTick = [];
                    ax.YTick = [];
                    ax.Toolbar = [];
                    ax.Title.String = '';
                    ax.Clipping = 'off';
                    set(ax, 'LooseInset', [0 0 0 0]);
                end

                % Hook the close function to our custom handler
                hFig.CloseRequestFcn = @(~,~) obj.closeSingleCamera(camName);

                % Store all handles in a struct
                previewData.name = camName;
                previewData.camera = cam;
                previewData.figure = hFig;

                obj.ActivePreviews{end+1} = previewData;

            catch ME
                uialert(obj.UIFigure, ...
                    sprintf('Failed to initialize camera %s: %s', camName, ME.message), ...
                    'Camera Error');
                if exist('cam', 'var')
                    clear cam;
                end
            end

            if ~isempty(obj.ActivePreviews)
                obj.IsPreviewActive = true;
            end
            obj.updateStatusLabel();
            obj.updateUI();
        end

        function stopAllCameras(obj)
            % Stop all camera previews and release resources

            numPreviews = length(obj.ActivePreviews);
            for i = numPreviews:-1:1 % Iterate backwards for safe removal
                previewData = obj.ActivePreviews{i};
                try
                    if isvalid(previewData.camera)
                        closePreview(previewData.camera);
                        clear previewData.camera;
                    end
                catch ME
                    FoilviewUtils.logException('StageView', ME, 'Error closing camera preview');
                end

                try
                    % The close request function will be handled by closeSingleCamera if user closes it
                    % But if we stop all, we need to manage it here
                    if isvalid(previewData.figure)
                        previewData.figure.CloseRequestFcn = 'closereq'; % Restore default
                        delete(previewData.figure);
                    end
                catch ME
                    FoilviewUtils.logException('StageView', ME, 'Error deleting figure');
                end
            end

            obj.ActivePreviews = {};
            obj.IsPreviewActive = false;
            obj.updateStatusLabel();
            obj.updateUI();
            obj.cleanupRecording();
        end

        function closeSingleCamera(obj, camName)
            % Close a single camera feed window and release its resources

            foundIdx = -1;
            for i = 1:length(obj.ActivePreviews)
                if strcmp(obj.ActivePreviews{i}.name, camName)
                    foundIdx = i;
                    break;
                end
            end

            if foundIdx > -1
                previewData = obj.ActivePreviews{foundIdx};

                try
                    if isvalid(previewData.camera)
                        closePreview(previewData.camera);
                        clear previewData.camera;
                    end
                catch ME
                    FoilviewUtils.logException('StageView', ME, 'Error closing single camera preview');
                end

                % Figure is closing, but we need to delete its handle to prevent memory leaks
                if isvalid(previewData.figure)
                    delete(previewData.figure);
                end

                % Remove from our list
                obj.ActivePreviews(foundIdx) = [];

                if isempty(obj.ActivePreviews)
                    obj.IsPreviewActive = false;
                end

                obj.updateStatusLabel();
                obj.updateUI();
                obj.cleanupRecording();
            end
        end

        function updateStatusLabel(obj)
            % Update the status label based on camera state
            if obj.IsPreviewActive
                numCams = length(obj.ActivePreviews);
                obj.StatusLabel.Text = sprintf('%d camera(s) active', numCams);
                obj.StatusLabel.FontColor = [0.2 0.6 0.2];
            else
                obj.StatusLabel.Text = 'No camera active';
                obj.StatusLabel.FontColor = [0.5 0.5 0.5];
            end
        end

        function captureSnapshot(obj)
            % Capture a snapshot from the active camera

            if isempty(obj.ActivePreviews)
                uialert(obj.UIFigure, 'No active camera to capture from.', 'No Camera');
                return;
            end

            obj.StatusLabel.Text = 'Capturing snapshot...';
            drawnow;

            % Since only one preview can be active, we take the first
            feed = obj.ActivePreviews{1};
            success = false;

            try
                if isvalid(feed.camera)
                    img = snapshot(feed.camera);

                    % Create new figure for snapshot
                    figName = sprintf('Snapshot - %s', feed.name);
                    hFig = figure('Name', figName, 'NumberTitle', 'off', 'Color', [0 0 0]);
                    ax = axes(hFig, 'Position', [0 0 1 1], 'Units', 'normalized');
                    ax.XColor = 'none';
                    ax.YColor = 'none';
                    ax.Box = 'off';
                    ax.XTick = [];
                    ax.YTick = [];
                    ax.Toolbar = [];
                    ax.Title.String = '';
                    ax.Clipping = 'off';
                    set(ax, 'LooseInset', [0 0 0 0]);
                    imshow(img, 'Parent', ax);
                    title(ax, sprintf('%s - %s', feed.name, datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));

                    success = true;
                end
            catch ME
                FoilviewUtils.logException('StageView', ME, 'Snapshot error');
            end

            if success
                obj.StatusLabel.Text = 'Snapshot captured';
                obj.StatusLabel.FontColor = [0.2 0.6 0.2];
            else
                obj.StatusLabel.Text = 'Snapshot failed';
                obj.StatusLabel.FontColor = [0.8 0.2 0.2];
            end
        end

        % Callbacks
        function onRefreshButtonPushed(obj)
            obj.refreshCameraList();
            obj.updateUI();
        end

        function onStartAllButtonPushed(obj)
            obj.startSelectedCameras();
        end

        function onStopAllButtonPushed(obj)
            obj.stopAllCameras();
        end

        function onSnapshotAllButtonPushed(obj)
            obj.captureSnapshot();
        end

        function onStartRecordingButtonPushed(obj)
            % Start video recording for the currently previewed camera
            if obj.IsRecording
                return;
            end
            if isempty(obj.ActivePreviews) || ~isvalid(obj.ActivePreviews{1}.camera)
                uialert(obj.UIFigure, 'No active camera to record from.', 'No Camera');
                return;
            end
            [file, path] = uiputfile('*.avi', 'Save Video As');
            if isequal(file,0)
                return;
            end
            obj.RecordingFileName = fullfile(path, file);
            cam = obj.ActivePreviews{1}.camera;
            try
                snapshot(cam); % Test camera access
                obj.VideoWriterObj = VideoWriter(obj.RecordingFileName, 'Motion JPEG AVI');
                obj.VideoWriterObj.FrameRate = 15; % Default, can be parameterized
                open(obj.VideoWriterObj);
                obj.IsRecording = true;
                obj.RecordingStartTime = datetime('now');
                obj.RecordingStatusLabel.Text = sprintf('Recording: %s', file);
                obj.RecordingStatusLabel.FontColor = [0.9 0.6 0.2];
                obj.StartRecordingButton.Enable = 'off';
                obj.StopRecordingButton.Enable = 'on';
                % Start timer to grab frames
                obj.VideoRecordTimer = timer('ExecutionMode','fixedRate', ...
                    'Period', 1/obj.VideoWriterObj.FrameRate, ...
                    'TimerFcn', @(~,~) obj.recordFrame(), ...
                    'ErrorFcn', @(~,e) disp(e.Data));
                start(obj.VideoRecordTimer);
            catch ME
                uialert(obj.UIFigure, sprintf('Failed to start recording: %s', ME.message), 'Recording Error');
                obj.cleanupRecording();
            end
        end

        function onStopRecordingButtonPushed(obj)
            % Stop video recording
            obj.cleanupRecording();
        end

        function recordFrame(obj)
            % Timer callback to record a frame from the camera
            if ~obj.IsRecording || isempty(obj.ActivePreviews) || ~isvalid(obj.ActivePreviews{1}.camera)
                obj.cleanupRecording();
                return;
            end
            try
                cam = obj.ActivePreviews{1}.camera;
                frame = snapshot(cam);
                writeVideo(obj.VideoWriterObj, frame);
            catch ME
                FoilviewUtils.logException('StageView', ME, 'Failed to record frame');
                obj.cleanupRecording();
            end
        end

        function cleanupRecording(obj)
            % Clean up video recording resources
            if ~isempty(obj.VideoRecordTimer) && isvalid(obj.VideoRecordTimer)
                stop(obj.VideoRecordTimer);
                delete(obj.VideoRecordTimer);
            end
            obj.VideoRecordTimer = [];
            if ~isempty(obj.VideoWriterObj)
                try
                    close(obj.VideoWriterObj);
                catch
                end
            end
            obj.VideoWriterObj = [];
            obj.IsRecording = false;
            obj.RecordingStatusLabel.Text = 'Not recording';
            obj.RecordingStatusLabel.FontColor = [0.5 0.5 0.5];
            obj.StartRecordingButton.Enable = obj.IsPreviewActive;
            obj.StopRecordingButton.Enable = 'off';
        end
        
        % Periodic Capture Methods
        function updateSelectedCameras(obj)
            % Get selected cameras from listbox for periodic capture
            selectedItems = obj.CameraListBox.Value;
            
            % Handle single vs multiple selection
            if ischar(selectedItems)
                obj.SelectedCameras = {selectedItems};
            elseif iscell(selectedItems)
                obj.SelectedCameras = selectedItems;
            else
                obj.SelectedCameras = {};
            end
            
            % Filter out invalid selections
            obj.SelectedCameras = obj.SelectedCameras(...
                ~strcmp(obj.SelectedCameras, 'No cameras detected'));
            
            obj.updatePeriodicUI();
        end
        
        function updatePeriodicUI(obj)
            % Update UI state for periodic capture controls
            hasSelectedCameras = ~isempty(obj.SelectedCameras);
            
            obj.StartPeriodicButton.Enable = hasSelectedCameras && ~obj.IsPeriodicCaptureActive;
            obj.StopPeriodicButton.Enable = obj.IsPeriodicCaptureActive;
        end
        
        function startPeriodicCapture(obj)
            % Initialize periodic capture system
            
            if obj.IsPeriodicCaptureActive
                return; % Already running
            end
            
            if isempty(obj.SelectedCameras)
                uialert(obj.UIFigure, 'Please select cameras for periodic capture.', 'No Selection');
                return;
            end
            
            % Stop any existing live previews
            obj.stopAllCameras();
            
            % Initialize display system
            obj.createMultiCameraDisplay();
            
            % Reset capture state
            obj.CurrentCameraIndex = 1;
            obj.CaptureErrors.remove(obj.CaptureErrors.keys);
            
            % Create and start capture timer
            obj.CaptureInterval = obj.IntervalSpinner.Value;
            obj.CaptureTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', obj.CaptureInterval, ...
                'TimerFcn', @(~,~) obj.captureNextCamera(), ...
                'ErrorFcn', @(~,e) obj.handleCaptureError(e));
            
            obj.IsPeriodicCaptureActive = true;
            start(obj.CaptureTimer);
            
            obj.updatePeriodicStatus();
            obj.updatePeriodicUI();
        end
        
        function stopPeriodicCapture(obj)
            % Stop periodic capture system
            
            if ~obj.IsPeriodicCaptureActive
                return;
            end
            
            % Stop and cleanup timer
            if ~isempty(obj.CaptureTimer) && isvalid(obj.CaptureTimer)
                stop(obj.CaptureTimer);
                delete(obj.CaptureTimer);
            end
            obj.CaptureTimer = [];
            
            % Close all individual camera display figures
            cameraNames = obj.CameraDisplays.keys;
            for i = 1:length(cameraNames)
                displayData = obj.CameraDisplays(cameraNames{i});
                if isfield(displayData, 'figure') && isvalid(displayData.figure)
                    delete(displayData.figure);
                end
            end
            
            % Clear display data
            obj.CameraDisplays.remove(obj.CameraDisplays.keys);
            
            obj.IsPeriodicCaptureActive = false;
            obj.updateStatusLabel();
            obj.updatePeriodicUI();
        end
        
        function createMultiCameraDisplay(obj)
            % Create separate windows for each selected camera (like normal Start Camera)
            
            numCameras = length(obj.SelectedCameras);
            if numCameras == 0
                return;
            end
            
            % Clear any existing displays
            obj.CameraDisplays = containers.Map();
            
            % Create separate figure for each camera
            for i = 1:numCameras
                cameraName = obj.SelectedCameras{i};
                
                % Calculate window position (offset each window)
                baseX = 350 + (i-1) * 50;  % Offset horizontally
                baseY = 250 + (i-1) * 30;  % Offset vertically
                
                % Create individual figure for this camera
                hFig = figure(...
                    'Name', sprintf('Periodic Feed: %s', cameraName), ...
                    'NumberTitle', 'off', ...
                    'Position', [baseX, baseY, 640, 480], ...
                    'CloseRequestFcn', @(~,~) obj.onPeriodicDisplayClose(cameraName), ...
                    'ResizeFcn', @(~,~) obj.onPeriodicDisplayResize(cameraName), ...
                    'AutoResizeChildren', 'on'); % * Enable responsive resizing
                
                % Create axes that fill the entire figure
                ax = axes(hFig, 'Position', [0 0 1 1], 'Units', 'normalized');
                set(hFig, 'MenuBar', 'none', 'ToolBar', 'none', 'Color', [0 0 0]);
                ax.Units = 'normalized';
                ax.Position = [0 0 1 1];
                ax.XColor = 'none';
                ax.YColor = 'none';
                ax.Box = 'off';
                ax.XTick = [];
                ax.YTick = [];
                ax.Toolbar = [];
                ax.Title.String = '';
                ax.Clipping = 'off';
                
                % Create placeholder image
                placeholderImg = zeros(240, 320, 3, 'uint8');
                imgHandle = imshow(placeholderImg, 'Parent', ax);
                
                % Configure axes for scalable display
                axis(ax, 'image');  % Preserve aspect ratio
                axis(ax, 'tight');  % No extra space around image
                set(ax, 'LooseInset', [0 0 0 0]);
                
                % Store display data
                displayData = struct(...
                    'name', cameraName, ...
                    'figure', hFig, ...
                    'axes', ax, ...
                    'image', imgHandle, ...
                    'lastUpdate', datetime.empty, ...
                    'isActive', true, ...
                    'errorCount', 0);
                
                obj.CameraDisplays(cameraName) = displayData;
            end
        end
        
        function captureNextCamera(obj)
            % Capture from the next camera in the rotation
            
            if isempty(obj.SelectedCameras)
                obj.stopPeriodicCapture();
                return;
            end
            
            % Get current camera name
            cameraName = obj.SelectedCameras{obj.CurrentCameraIndex};
            
            % Update status
            obj.StatusLabel.Text = sprintf('Capturing from %s...', cameraName);
            drawnow;
            
            success = false;
            cam = [];
            
            try
                % CRITICAL: Open camera exclusively
                cam = webcam(cameraName);
                
                % Brief pause to ensure camera is ready
                pause(0.1);
                
                % Capture snapshot
                img = snapshot(cam);
                
                % Update display immediately
                obj.updateCameraDisplay(cameraName, img);
                
                success = true;
                
            catch ME
                % Log error but continue with next camera
                obj.handleCameraError(cameraName, ME);
            end
            
            % CRITICAL: Always close camera to free hardware
            try
                if ~isempty(cam)
                    clear cam; % This releases the webcam object
                end
            catch
                % Ignore cleanup errors
            end
            
            % Update error tracking
            if success
                obj.CaptureErrors(cameraName) = 0; % Reset error count
            else
                currentErrors = 0;
                if obj.CaptureErrors.isKey(cameraName)
                    currentErrors = obj.CaptureErrors(cameraName);
                end
                obj.CaptureErrors(cameraName) = currentErrors + 1;
            end
            
            % Move to next camera
            obj.CurrentCameraIndex = obj.CurrentCameraIndex + 1;
            if obj.CurrentCameraIndex > length(obj.SelectedCameras)
                obj.CurrentCameraIndex = 1; % Wrap around
            end
            
            % Update status
            obj.updatePeriodicStatus();
        end
        
        function updateCameraDisplay(obj, cameraName, img)
            % Update the display for a specific camera in its separate window
            
            if ~obj.CameraDisplays.isKey(cameraName)
                return;
            end
            
            displayData = obj.CameraDisplays(cameraName);
            
            try
                % Update image data
                set(displayData.image, 'CData', img);
                
                % Ensure proper aspect ratio and scaling
                axis(displayData.axes, 'image');  % Preserve aspect ratio
                axis(displayData.axes, 'tight');  % Show full image without extra space
                displayData.axes.Position = [0 0 1 1];
                displayData.axes.XColor = 'none';
                displayData.axes.YColor = 'none';
                displayData.axes.Box = 'off';
                displayData.axes.XTick = [];
                displayData.axes.YTick = [];
                displayData.axes.Toolbar = [];
                displayData.axes.Title.String = '';
                displayData.axes.Clipping = 'off';
                set(displayData.axes, 'LooseInset', [0 0 0 0]);
                
                % Update figure title with timestamp
                timeStr = char(datetime('now', 'Format', 'HH:mm:ss'));
                displayData.figure.Name = sprintf('Periodic Feed: %s (%s)', cameraName, timeStr);
                
                % Update last update time
                displayData.lastUpdate = datetime('now');
                displayData.errorCount = 0;
                
                obj.CameraDisplays(cameraName) = displayData;
                
            catch ME
                FoilviewUtils.logException('StageView', ME, ...
                    sprintf('Failed to update display for %s', cameraName));
            end
        end
        
        function handleCameraError(obj, cameraName, ME)
            % Handle errors for specific cameras
            
            FoilviewUtils.logException('StageView', ME, ...
                sprintf('Periodic capture error for %s', cameraName));
            
            % Update display to show error
            if obj.CameraDisplays.isKey(cameraName)
                displayData = obj.CameraDisplays(cameraName);
                
                % Update title to show error
                title(displayData.axes, sprintf('%s (ERROR)', cameraName), ...
                    'FontSize', 10, 'Interpreter', 'none', 'Color', [0.8 0.2 0.2]);
                
                displayData.errorCount = displayData.errorCount + 1;
                obj.CameraDisplays(cameraName) = displayData;
            end
            
            % If too many consecutive errors, consider removing camera
            if obj.CaptureErrors.isKey(cameraName) && obj.CaptureErrors(cameraName) > 5
                obj.disableCamera(cameraName);
            end
        end
        
        function disableCamera(obj, cameraName)
            % Temporarily disable a problematic camera
            
            % Remove from selected cameras
            obj.SelectedCameras = obj.SelectedCameras(...
                ~strcmp(obj.SelectedCameras, cameraName));
            
            % Update display
            if obj.CameraDisplays.isKey(cameraName)
                displayData = obj.CameraDisplays(cameraName);
                title(displayData.axes, sprintf('%s (DISABLED)', cameraName), ...
                    'FontSize', 10, 'Interpreter', 'none', 'Color', [0.5 0.5 0.5]);
            end
            
            % Adjust current index if needed
            if obj.CurrentCameraIndex > length(obj.SelectedCameras)
                obj.CurrentCameraIndex = 1;
            end
            
            % Stop if no cameras left
            if isempty(obj.SelectedCameras)
                obj.stopPeriodicCapture();
            end
        end
        
        function updatePeriodicStatus(obj)
            % Update status label for periodic capture
            
            if ~obj.IsPeriodicCaptureActive
                return;
            end
            
            numCameras = length(obj.SelectedCameras);
            currentCamera = '';
            if numCameras > 0
                currentCamera = obj.SelectedCameras{obj.CurrentCameraIndex};
            end
            
            % Count active cameras (those without too many errors)
            activeCameras = 0;
            for i = 1:numCameras
                cameraName = obj.SelectedCameras{i};
                errorCount = 0;
                if obj.CaptureErrors.isKey(cameraName)
                    errorCount = obj.CaptureErrors(cameraName);
                end
                if errorCount < 5
                    activeCameras = activeCameras + 1;
                end
            end
            
            obj.StatusLabel.Text = sprintf('Periodic: %d/%d active (Next: %s)', ...
                activeCameras, numCameras, currentCamera);
            obj.StatusLabel.FontColor = [0.2 0.6 0.8];
        end
        
        function handleCaptureError(obj, errorEvent)
            % Handle timer errors
            FoilviewUtils.logException('StageView', errorEvent, 'Capture timer error');
            obj.stopPeriodicCapture();
        end
        
        function onDisplayFigureClose(obj)
            % Handle display figure close event
            obj.stopPeriodicCapture();
        end
        
        function onIntervalChanged(obj)
            % Update capture interval while running
            
            newInterval = obj.IntervalSpinner.Value;
            
            if obj.IsPeriodicCaptureActive && ~isempty(obj.CaptureTimer)
                % Stop current timer
                stop(obj.CaptureTimer);
                
                % Update period
                obj.CaptureTimer.Period = newInterval;
                obj.CaptureInterval = newInterval;
                
                % Restart timer
                start(obj.CaptureTimer);
                
                obj.StatusLabel.Text = sprintf('Interval updated to %.1fs', newInterval);
            end
        end
        
        % Periodic Capture Callbacks
        function onStartPeriodicButtonPushed(obj)
            % * Overhauled: Start periodic capture for all available cameras
            obj.CameraListBox.Value = obj.CameraListBox.Items; % Select all
            obj.updateSelectedCameras();
            obj.startPeriodicCapture();
        end
        
        function onStopPeriodicButtonPushed(obj)
            obj.stopPeriodicCapture();
        end
        
        function onPeriodicDisplayClose(obj, cameraName)
            % Handle individual camera display window close
            if obj.CameraDisplays.isKey(cameraName)
                displayData = obj.CameraDisplays(cameraName);
                if isfield(displayData, 'figure') && isvalid(displayData.figure)
                    delete(displayData.figure);
                end
                obj.CameraDisplays.remove(cameraName);
            end
            
            % If no more displays, stop periodic capture
            if obj.CameraDisplays.Count == 0
                obj.stopPeriodicCapture();
            end
        end
        
        function onPeriodicDisplayResize(obj, cameraName)
            % Handle individual camera display window resize
            if ~obj.CameraDisplays.isKey(cameraName)
                return;
            end
            displayData = obj.CameraDisplays(cameraName);
            try
                % * Ensure image and axes fill the window responsively
                displayData.axes.Units = 'normalized';
                displayData.axes.Position = [0 0 1 1];
                axis(displayData.axes, 'image');
                axis(displayData.axes, 'tight');
                set(displayData.axes, 'LooseInset', [0 0 0 0]);
            catch ME
                % Ignore resize errors
            end
        end
    end
end
