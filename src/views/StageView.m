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
    end

    methods
        function obj = StageView()
            % Constructor: Creates the Stage View window and initializes components
            obj.createUI();
            obj.setupCallbacks();
            obj.initialize();
        end

        function delete(obj)
            % Destructor: Cleans up all resources
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
            obj.UIFigure.Position = [200 200 280 420];
            obj.UIFigure.AutoResizeChildren = 'off';
            
            % Main Layout
            obj.MainLayout = uigridlayout(obj.UIFigure);
            obj.MainLayout.ColumnWidth = {'1x'};
            obj.MainLayout.RowHeight = {'1x'};
            obj.MainLayout.Padding = [10 10 10 10];
            
            % Control Panel
            obj.ControlPanel = uipanel(obj.MainLayout);
            obj.ControlPanel.Title = 'Camera Controls';
            obj.ControlPanel.Layout.Row = 1;
            obj.ControlPanel.Layout.Column = 1;
            
            % Create control panel layout
            controlLayout = uigridlayout(obj.ControlPanel);
            controlLayout.ColumnWidth = {'1x'};
            controlLayout.RowHeight = {30, '1x', 40, 40, 40, 40, 40, 30};
            controlLayout.Padding = [10 10 10 10];
            controlLayout.RowSpacing = 5;
            
            % Status Label
            obj.StatusLabel = uilabel(controlLayout);
            obj.StatusLabel.Text = 'Initializing cameras...';
            obj.StatusLabel.Layout.Row = 1;
            obj.StatusLabel.Layout.Column = 1;
            obj.StatusLabel.FontWeight = 'bold';
            
            % Camera List Box
            obj.CameraListBox = uilistbox(controlLayout);
            obj.CameraListBox.Layout.Row = 2;
            obj.CameraListBox.Layout.Column = 1;
            obj.CameraListBox.Multiselect = 'off';
            obj.CameraListBox.Items = {};
            
            % Control Buttons
            obj.RefreshButton = uibutton(controlLayout, 'push');
            obj.RefreshButton.Text = 'Refresh Cameras';
            obj.RefreshButton.Layout.Row = 3;
            obj.RefreshButton.Layout.Column = 1;
            
            obj.StartAllButton = uibutton(controlLayout, 'push');
            obj.StartAllButton.Text = 'Start Camera';
            obj.StartAllButton.Layout.Row = 4;
            obj.StartAllButton.Layout.Column = 1;
            obj.StartAllButton.BackgroundColor = [0.2 0.8 0.2];
            
            obj.StopAllButton = uibutton(controlLayout, 'push');
            obj.StopAllButton.Text = 'Stop Camera';
            obj.StopAllButton.Layout.Row = 5;
            obj.StopAllButton.Layout.Column = 1;
            obj.StopAllButton.BackgroundColor = [0.8 0.2 0.2];
            
            obj.SnapshotAllButton = uibutton(controlLayout, 'push');
            obj.SnapshotAllButton.Text = 'Snapshot Camera';
            obj.SnapshotAllButton.Layout.Row = 6;
            obj.SnapshotAllButton.Layout.Column = 1;
            obj.SnapshotAllButton.BackgroundColor = [0.2 0.6 0.8];
            
            % Video Recording Buttons
            obj.StartRecordingButton = uibutton(controlLayout, 'push');
            obj.StartRecordingButton.Text = 'Start Recording';
            obj.StartRecordingButton.Layout.Row = 7;
            obj.StartRecordingButton.Layout.Column = 1;
            obj.StartRecordingButton.BackgroundColor = [0.9 0.6 0.2];
            
            obj.StopRecordingButton = uibutton(controlLayout, 'push');
            obj.StopRecordingButton.Text = 'Stop Recording';
            obj.StopRecordingButton.Layout.Row = 8;
            obj.StopRecordingButton.Layout.Column = 1;
            obj.StopRecordingButton.BackgroundColor = [0.8 0.2 0.2];
            obj.StopRecordingButton.Enable = 'off';
            
            % Recording Status Label
            obj.RecordingStatusLabel = uilabel(controlLayout);
            obj.RecordingStatusLabel.Text = 'Not recording';
            obj.RecordingStatusLabel.Layout.Row = 9;
            obj.RecordingStatusLabel.Layout.Column = 1;
            obj.RecordingStatusLabel.FontColor = [0.5 0.5 0.5];
            obj.RecordingStatusLabel.FontWeight = 'bold';
            
            % Instructions
            instructionLabel = uilabel(controlLayout);
            instructionLabel.Text = 'Select a camera and click Start';
            instructionLabel.Layout.Row = 10;
            instructionLabel.Layout.Column = 1;
            instructionLabel.FontSize = 10;
            instructionLabel.FontColor = [0.5 0.5 0.5];
            
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
                    obj.StatusLabel.Text = sprintf('%d camera(s) detected', length(obj.AvailableCameras));
                    obj.StatusLabel.FontColor = [0.2 0.6 0.2];
                end
            catch ME
                obj.CameraListBox.Items = {'Error detecting cameras'};
                obj.StatusLabel.Text = 'Camera detection failed';
                obj.StatusLabel.FontColor = [0.8 0.2 0.2];
                warning('stageview:CameraDetection', 'Failed to detect cameras: %s', ME.message);
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
            camName = obj.CameraListBox.Value;
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
                    warning('StageView:CleanupError', 'Error closing camera preview: %s', ME.message);
                end
                
                try
                    % The close request function will be handled by closeSingleCamera if user closes it
                    % But if we stop all, we need to manage it here
                    if isvalid(previewData.figure)
                        previewData.figure.CloseRequestFcn = 'closereq'; % Restore default
                        delete(previewData.figure);
                    end
                catch ME
                    warning('StageView:CleanupError', 'Error deleting figure: %s', ME.message);
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
                    warning('StageView:CleanupError', 'Error closing single camera preview: %s', ME.message);
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
                    figure('Name', figName, 'NumberTitle', 'off');
                    imshow(img);
                    title(sprintf('%s - %s', feed.name, datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
                    
                    success = true;
                end
            catch ME
                warning('stageview:SnapshotError', ...
                       'Failed to capture snapshot from camera %s: %s', feed.name, ME.message);
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
                warning('StageView:RecordFrameError', 'Failed to record frame: %s', ME.message);
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
    end
end 
