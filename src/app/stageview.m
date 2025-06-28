classdef stageview < matlab.apps.AppBase
    % stageview - Webcam-based Stage View Application
    %
    % This MATLAB App provides a dedicated window for viewing the microscope
    % stage through connected webcams. It supports multiple camera feeds,
    % live preview, snapshot capture, and flexible grid layout display.
    %
    % Key Features:
    %   - Automatic webcam detection and listing
    %   - Multi-camera support with grid layout
    %   - Live preview with real-time updates
    %   - Snapshot capture for all active cameras
    %   - Clean camera resource management
    %   - Independent window operation
    %
    % Usage:
    %   app = stageview();    % Launch the stage view application
    %   delete(app);          % Clean shutdown when done
    
    %% Public Properties - UI Components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainLayout                  matlab.ui.container.GridLayout
        
        % Control Panel Components
        ControlPanel                matlab.ui.container.Panel
        CameraListBox               matlab.ui.control.ListBox
        StartAllButton              matlab.ui.control.Button
        StopAllButton               matlab.ui.control.Button
        SnapshotAllButton           matlab.ui.control.Button
        RefreshButton               matlab.ui.control.Button
        StatusLabel                 matlab.ui.control.Label
        
        % Display Panel
        DisplayPanel                matlab.ui.container.Panel
    end
    
    %% Private Properties - Camera Management
    properties (Access = private)
        % Camera handles and resources
        CameraHandles = {}          % Cell array of webcam objects
        ImageHandles = {}           % Cell array of image handles
        AxisHandles = {}            % Cell array of axis handles
        
        % Available cameras
        AvailableCameras = {}       % List of available camera names
        
        % State tracking
        IsPreviewActive = false     % Flag for preview state
    end
    
    %% Constructor and Destructor
    methods (Access = public)
        function app = stageview()
            % stageview Constructor
            % 
            % Creates and initializes the Stage View application with webcam
            % detection, UI setup, and resource management.
            %
            % Initialization sequence:
            %   1. Create UI components
            %   2. Detect available webcams
            %   3. Set up event handlers
            %   4. Initialize display
            %   5. Register app with MATLAB
            
            % Create UI components
            app.createUIComponents();
            
            % Set up callbacks
            app.setupCallbacks();
            
            % Initialize application
            app.initializeApplication();
            
            % Register app
            registerApp(app, app.UIFigure);
            
            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            % stageview Destructor
            %
            % Performs clean shutdown including:
            %   - Stopping all camera previews
            %   - Releasing camera resources
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
            app.UIFigure.Name = 'Stage View - Microscope Camera Feed';
            app.UIFigure.Position = [200 200 1000 700];
            app.UIFigure.AutoResizeChildren = 'off';
            
            % Main Layout
            app.MainLayout = uigridlayout(app.UIFigure);
            app.MainLayout.ColumnWidth = {250, '1x'};
            app.MainLayout.RowHeight = {'1x'};
            app.MainLayout.Padding = [10 10 10 10];
            app.MainLayout.ColumnSpacing = 10;
            
            % Control Panel
            app.ControlPanel = uipanel(app.MainLayout);
            app.ControlPanel.Title = 'Camera Controls';
            app.ControlPanel.Layout.Row = 1;
            app.ControlPanel.Layout.Column = 1;
            
            % Create control panel layout
            controlLayout = uigridlayout(app.ControlPanel);
            controlLayout.ColumnWidth = {'1x'};
            controlLayout.RowHeight = {30, '1x', 40, 40, 40, 40, 40, 30};
            controlLayout.Padding = [10 10 10 10];
            controlLayout.RowSpacing = 5;
            
            % Status Label
            app.StatusLabel = uilabel(controlLayout);
            app.StatusLabel.Text = 'Initializing cameras...';
            app.StatusLabel.Layout.Row = 1;
            app.StatusLabel.Layout.Column = 1;
            app.StatusLabel.FontWeight = 'bold';
            
            % Camera List Box
            app.CameraListBox = uilistbox(controlLayout);
            app.CameraListBox.Layout.Row = 2;
            app.CameraListBox.Layout.Column = 1;
            app.CameraListBox.Multiselect = 'on';
            app.CameraListBox.Items = {};
            
            % Control Buttons
            app.RefreshButton = uibutton(controlLayout, 'push');
            app.RefreshButton.Text = 'Refresh Cameras';
            app.RefreshButton.Layout.Row = 3;
            app.RefreshButton.Layout.Column = 1;
            
            app.StartAllButton = uibutton(controlLayout, 'push');
            app.StartAllButton.Text = 'Start Selected';
            app.StartAllButton.Layout.Row = 4;
            app.StartAllButton.Layout.Column = 1;
            app.StartAllButton.BackgroundColor = [0.2 0.8 0.2];
            
            app.StopAllButton = uibutton(controlLayout, 'push');
            app.StopAllButton.Text = 'Stop All';
            app.StopAllButton.Layout.Row = 5;
            app.StopAllButton.Layout.Column = 1;
            app.StopAllButton.BackgroundColor = [0.8 0.2 0.2];
            
            app.SnapshotAllButton = uibutton(controlLayout, 'push');
            app.SnapshotAllButton.Text = 'Snapshot All';
            app.SnapshotAllButton.Layout.Row = 6;
            app.SnapshotAllButton.Layout.Column = 1;
            app.SnapshotAllButton.BackgroundColor = [0.2 0.6 0.8];
            
            % Instructions
            instructionLabel = uilabel(controlLayout);
            instructionLabel.Text = 'Select cameras and click Start';
            instructionLabel.Layout.Row = 8;
            instructionLabel.Layout.Column = 1;
            instructionLabel.FontSize = 10;
            instructionLabel.FontColor = [0.5 0.5 0.5];
            
            % Display Panel
            app.DisplayPanel = uipanel(app.MainLayout);
            app.DisplayPanel.Title = 'Camera Feeds';
            app.DisplayPanel.Layout.Row = 1;
            app.DisplayPanel.Layout.Column = 2;
            
            % Make figure visible
            app.UIFigure.Visible = 'on';
        end
        
        function setupCallbacks(app)
            % Set up all UI callback functions
            
            % Main window
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @app.onWindowClose, true);
            
            % Button callbacks
            app.RefreshButton.ButtonPushedFcn = createCallbackFcn(app, @app.onRefreshButtonPushed, true);
            app.StartAllButton.ButtonPushedFcn = createCallbackFcn(app, @app.onStartAllButtonPushed, true);
            app.StopAllButton.ButtonPushedFcn = createCallbackFcn(app, @app.onStopAllButtonPushed, true);
            app.SnapshotAllButton.ButtonPushedFcn = createCallbackFcn(app, @app.onSnapshotAllButtonPushed, true);
        end
        
        function initializeApplication(app)
            % Initialize the application
            app.refreshCameraList();
            app.updateUI();
        end
    end
    
    %% Camera Management Methods
    methods (Access = private)
        function refreshCameraList(app)
            % Detect and update the list of available cameras
            try
                app.AvailableCameras = webcamlist;
                if isempty(app.AvailableCameras)
                    app.CameraListBox.Items = {'No cameras detected'};
                    app.StatusLabel.Text = 'No cameras found';
                    app.StatusLabel.FontColor = [0.8 0.2 0.2];
                else
                    app.CameraListBox.Items = app.AvailableCameras;
                    app.StatusLabel.Text = sprintf('%d camera(s) detected', length(app.AvailableCameras));
                    app.StatusLabel.FontColor = [0.2 0.6 0.2];
                end
            catch ME
                app.CameraListBox.Items = {'Error detecting cameras'};
                app.StatusLabel.Text = 'Camera detection failed';
                app.StatusLabel.FontColor = [0.8 0.2 0.2];
                warning('stageview:CameraDetection', 'Failed to detect cameras: %s', ME.message);
            end
        end
        
        function startSelectedCameras(app)
            % Start preview for selected cameras
            
            % Stop any existing previews first
            app.stopAllCameras();
            
            % Get selected cameras
            selectedItems = app.CameraListBox.Value;
            if isempty(selectedItems) || (ischar(selectedItems) && strcmp(selectedItems, 'No cameras detected'))
                uialert(app.UIFigure, 'Please select at least one camera to start.', 'No Selection');
                return;
            end
            
            % Convert to cell array if single selection
            if ischar(selectedItems)
                selectedItems = {selectedItems};
            end
            
            % Find indices of selected cameras
            selectedIndices = [];
            for i = 1:length(selectedItems)
                idx = find(strcmp(app.AvailableCameras, selectedItems{i}), 1);
                if ~isempty(idx)
                    selectedIndices(end+1) = idx;
                end
            end
            
            if isempty(selectedIndices)
                uialert(app.UIFigure, 'Invalid camera selection.', 'Selection Error');
                return;
            end
            
            n = length(selectedIndices);
            
            % Calculate grid layout
            rows = ceil(sqrt(n));
            cols = ceil(n / rows);
            
            % Clear display panel
            delete(allchild(app.DisplayPanel));
            
            app.StatusLabel.Text = 'Starting cameras...';
            drawnow;
            
            % Initialize cameras
            for k = 1:n
                idx = selectedIndices(k);
                try
                    % Create webcam object
                    cam = webcam(idx);
                    
                    % Set resolution if available
                    if ~isempty(cam.AvailableResolutions)
                        cam.Resolution = cam.AvailableResolutions{1};
                    end
                    
                    app.CameraHandles{end+1} = cam;
                    
                    % Calculate position in grid
                    row = ceil(k / cols);
                    col = mod(k - 1, cols) + 1;
                    
                    % Create normalized position [left bottom width height]
                    left = (col - 1) / cols;
                    bottom = 1 - (row / rows);
                    width = 1 / cols;
                    height = 1 / rows;
                    
                    % Create axes in display panel
                    ax = axes('Parent', app.DisplayPanel, ...
                             'Units', 'normalized', ...
                             'Position', [left bottom width height]);
                    
                    app.AxisHandles{end+1} = ax;
                    
                    % Take initial snapshot and create image
                    frame = snapshot(cam);
                    img = image(frame, 'Parent', ax);
                    axis(ax, 'off');
                    title(ax, selectedItems{k}, 'FontSize', 10);
                    
                    app.ImageHandles{end+1} = img;
                    
                    % Start live preview
                    preview(cam, img);
                    
                catch ME
                    uialert(app.UIFigure, ...
                           sprintf('Failed to initialize camera %d: %s', idx, ME.message), ...
                           'Camera Error');
                    continue;
                end
            end
            
            if ~isempty(app.CameraHandles)
                app.IsPreviewActive = true;
                app.StatusLabel.Text = sprintf('%d camera(s) active', length(app.CameraHandles));
                app.StatusLabel.FontColor = [0.2 0.6 0.2];
            else
                app.StatusLabel.Text = 'Failed to start cameras';
                app.StatusLabel.FontColor = [0.8 0.2 0.2];
            end
            
            app.updateUI();
        end
        
        function stopAllCameras(app)
            % Stop all camera previews and release resources
            
            % Stop previews
            for i = 1:length(app.CameraHandles)
                try
                    if isvalid(app.CameraHandles{i})
                        closePreview(app.CameraHandles{i});
                        clear app.CameraHandles{i};
                    end
                catch
                    % Ignore errors during cleanup
                end
            end
            
            % Clear handles
            app.CameraHandles = {};
            app.ImageHandles = {};
            app.AxisHandles = {};
            
            % Clear display panel
            delete(allchild(app.DisplayPanel));
            
            app.IsPreviewActive = false;
            app.StatusLabel.Text = 'All cameras stopped';
            app.StatusLabel.FontColor = [0.5 0.5 0.5];
            
            app.updateUI();
        end
        
        function captureSnapshots(app)
            % Capture snapshots from all active cameras
            
            if isempty(app.CameraHandles)
                uialert(app.UIFigure, 'No active cameras to capture from.', 'No Cameras');
                return;
            end
            
            app.StatusLabel.Text = 'Capturing snapshots...';
            drawnow;
            
            successCount = 0;
            
            for i = 1:length(app.CameraHandles)
                try
                    if isvalid(app.CameraHandles{i})
                        img = snapshot(app.CameraHandles{i});
                        
                        % Create new figure for snapshot
                        figName = sprintf('Snapshot - Camera %d', i);
                        snapshotFig = figure('Name', figName, 'NumberTitle', 'off');
                        imshow(img);
                        title(sprintf('Camera %d - %s', i, datestr(now, 'yyyy-mm-dd HH:MM:SS')));
                        
                        successCount = successCount + 1;
                    end
                catch ME
                    warning('stageview:SnapshotError', ...
                           'Failed to capture snapshot from camera %d: %s', i, ME.message);
                end
            end
            
            app.StatusLabel.Text = sprintf('%d snapshot(s) captured', successCount);
            if successCount > 0
                app.StatusLabel.FontColor = [0.2 0.6 0.2];
            else
                app.StatusLabel.FontColor = [0.8 0.2 0.2];
            end
        end
        
        function updateUI(app)
            % Update UI state based on current conditions
            
            % Enable/disable buttons based on state
            hasActiveCameras = ~isempty(app.CameraHandles);
            hasCamerasAvailable = ~isempty(app.AvailableCameras) && ...
                                 ~strcmp(app.AvailableCameras{1}, 'No cameras detected');
            
            app.StartAllButton.Enable = hasCamerasAvailable && ~app.IsPreviewActive;
            app.StopAllButton.Enable = hasActiveCameras;
            app.SnapshotAllButton.Enable = hasActiveCameras;
        end
    end
    
    %% UI Event Handlers
    methods (Access = private)
        function onRefreshButtonPushed(app, varargin)
            app.refreshCameraList();
            app.updateUI();
        end
        
        function onStartAllButtonPushed(app, varargin)
            app.startSelectedCameras();
        end
        
        function onStopAllButtonPushed(app, varargin)
            app.stopAllCameras();
        end
        
        function onSnapshotAllButtonPushed(app, varargin)
            app.captureSnapshots();
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
            
            % Stop all cameras
            app.stopAllCameras();
            
            % Additional cleanup if needed
            try
                % Clear any remaining graphics objects
                if isvalid(app.DisplayPanel)
                    delete(allchild(app.DisplayPanel));
                end
            catch
                % Ignore cleanup errors
            end
        end
    end
end 