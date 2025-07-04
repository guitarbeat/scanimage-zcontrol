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
        DisplayPanel
    end

    properties (Access = private)
        % Camera and UI State
        CameraHandles = {}
        ImageHandles = {}
        AxisHandles = {}
        AvailableCameras = {}
        IsPreviewActive = false
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

            % Delete the figure if it exists and is valid, breaking recursion
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                obj.UIFigure.CloseRequestFcn = ''; % Prevent recursion
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
            obj.UIFigure.Name = 'Stage View - Microscope Camera Feed';
            obj.UIFigure.Position = [200 200 1000 700];
            obj.UIFigure.AutoResizeChildren = 'off';
            
            % Main Layout
            obj.MainLayout = uigridlayout(obj.UIFigure);
            obj.MainLayout.ColumnWidth = {250, '1x'};
            obj.MainLayout.RowHeight = {'1x'};
            obj.MainLayout.Padding = [10 10 10 10];
            obj.MainLayout.ColumnSpacing = 10;
            
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
            obj.CameraListBox.Multiselect = 'on';
            obj.CameraListBox.Items = {};
            
            % Control Buttons
            obj.RefreshButton = uibutton(controlLayout, 'push');
            obj.RefreshButton.Text = 'Refresh Cameras';
            obj.RefreshButton.Layout.Row = 3;
            obj.RefreshButton.Layout.Column = 1;
            
            obj.StartAllButton = uibutton(controlLayout, 'push');
            obj.StartAllButton.Text = 'Start Selected';
            obj.StartAllButton.Layout.Row = 4;
            obj.StartAllButton.Layout.Column = 1;
            obj.StartAllButton.BackgroundColor = [0.2 0.8 0.2];
            
            obj.StopAllButton = uibutton(controlLayout, 'push');
            obj.StopAllButton.Text = 'Stop All';
            obj.StopAllButton.Layout.Row = 5;
            obj.StopAllButton.Layout.Column = 1;
            obj.StopAllButton.BackgroundColor = [0.8 0.2 0.2];
            
            obj.SnapshotAllButton = uibutton(controlLayout, 'push');
            obj.SnapshotAllButton.Text = 'Snapshot All';
            obj.SnapshotAllButton.Layout.Row = 6;
            obj.SnapshotAllButton.Layout.Column = 1;
            obj.SnapshotAllButton.BackgroundColor = [0.2 0.6 0.8];
            
            % Instructions
            instructionLabel = uilabel(controlLayout);
            instructionLabel.Text = 'Select cameras and click Start';
            instructionLabel.Layout.Row = 8;
            instructionLabel.Layout.Column = 1;
            instructionLabel.FontSize = 10;
            instructionLabel.FontColor = [0.5 0.5 0.5];
            
            % Display Panel
            obj.DisplayPanel = uipanel(obj.MainLayout);
            obj.DisplayPanel.Title = 'Camera Feeds';
            obj.DisplayPanel.Layout.Row = 1;
            obj.DisplayPanel.Layout.Column = 2;
            
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
        end

        function initialize(obj)
            % Initialize the application
            obj.refreshCameraList();
            obj.updateUI();
        end

        function cleanup(obj)
            % Clean up all resources
            
            % Stop all cameras
            obj.stopAllCameras();
            
            % Additional cleanup if needed
            try
                % Clear any remaining graphics objects
                if isvalid(obj.DisplayPanel)
                    delete(allchild(obj.DisplayPanel));
                end
            catch
                % Ignore cleanup errors
            end
        end

        function updateUI(obj)
            % Update UI state based on current conditions
            
            % Enable/disable buttons based on state
            hasActiveCameras = ~isempty(obj.CameraHandles);
            hasCamerasAvailable = ~isempty(obj.AvailableCameras) && ...
                                 ~strcmp(obj.AvailableCameras{1}, 'No cameras detected');
            
            obj.StartAllButton.Enable = hasCamerasAvailable && ~obj.IsPreviewActive;
            obj.StopAllButton.Enable = hasActiveCameras;
            obj.SnapshotAllButton.Enable = hasActiveCameras;
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
            % Start preview for selected cameras
            
            % Stop any existing previews first
            obj.stopAllCameras();
            
            % Get selected cameras
            selectedItems = obj.CameraListBox.Value;
            if isempty(selectedItems) || (ischar(selectedItems) && strcmp(selectedItems, 'No cameras detected'))
                uialert(obj.UIFigure, 'Please select at least one camera to start.', 'No Selection');
                return;
            end
            
            % Convert to cell array if single selection
            if ischar(selectedItems)
                selectedItems = {selectedItems};
            end
            
            % Find indices of selected cameras
            selectedIndices = zeros(1, length(selectedItems));
            validCount = 0;
            for i = 1:length(selectedItems)
                idx = find(strcmp(obj.AvailableCameras, selectedItems{i}), 1);
                if ~isempty(idx)
                    validCount = validCount + 1;
                    selectedIndices(validCount) = idx;
                end
            end
            selectedIndices = selectedIndices(1:validCount);
            
            if isempty(selectedIndices)
                uialert(obj.UIFigure, 'Invalid camera selection.', 'Selection Error');
                return;
            end
            
            n = length(selectedIndices);
            
            % Calculate grid layout
            rows = ceil(sqrt(n));
            cols = ceil(n / rows);
            
            % Clear display panel
            delete(allchild(obj.DisplayPanel));
            
            obj.StatusLabel.Text = 'Starting cameras...';
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
                    
                    obj.CameraHandles{end+1} = cam;
                    
                    % Calculate position in grid
                    row = ceil(k / cols);
                    col = mod(k - 1, cols) + 1;
                    
                    % Create normalized position [left bottom width height]
                    left = (col - 1) / cols;
                    bottom = 1 - (row / rows);
                    width = 1 / cols;
                    height = 1 / rows;
                    
                    % Create axes in display panel
                    ax = axes('Parent', obj.DisplayPanel, ...
                             'Units', 'normalized', ...
                             'Position', [left bottom width height]);
                    
                    obj.AxisHandles{end+1} = ax;
                    
                    % Take initial snapshot and create image
                    frame = snapshot(cam);
                    img = image(frame, 'Parent', ax);
                    axis(ax, 'off');
                    title(ax, selectedItems{k}, 'FontSize', 10);
                    
                    obj.ImageHandles{end+1} = img;
                    
                    % Start live preview
                    preview(cam, img);
                    
                catch ME
                    uialert(obj.UIFigure, ...
                           sprintf('Failed to initialize camera %d: %s', idx, ME.message), ...
                           'Camera Error');
                    continue;
                end
            end
            
            if ~isempty(obj.CameraHandles)
                obj.IsPreviewActive = true;
                obj.StatusLabel.Text = sprintf('%d camera(s) active', length(obj.CameraHandles));
                obj.StatusLabel.FontColor = [0.2 0.6 0.2];
            else
                obj.StatusLabel.Text = 'Failed to start cameras';
                obj.StatusLabel.FontColor = [0.8 0.2 0.2];
            end
            
            obj.updateUI();
        end
        
        function stopAllCameras(obj)
            % Stop all camera previews and release resources
            
            % Stop previews
            for i = 1:length(obj.CameraHandles)
                try
                    if isvalid(obj.CameraHandles{i})
                        closePreview(obj.CameraHandles{i});
                        clear obj.CameraHandles{i};
                    end
                catch
                    % Ignore errors during cleanup
                end
            end
            
            % Clear handles
            obj.CameraHandles = {};
            obj.ImageHandles = {};
            obj.AxisHandles = {};
            
            % Clear display panel
            if isvalid(obj.DisplayPanel)
                delete(allchild(obj.DisplayPanel));
            end
            
            obj.IsPreviewActive = false;
            obj.StatusLabel.Text = 'All cameras stopped';
            obj.StatusLabel.FontColor = [0.5 0.5 0.5];
            
            obj.updateUI();
        end
        
        function captureSnapshots(obj)
            % Capture snapshots from all active cameras
            
            if isempty(obj.CameraHandles)
                uialert(obj.UIFigure, 'No active cameras to capture from.', 'No Cameras');
                return;
            end
            
            obj.StatusLabel.Text = 'Capturing snapshots...';
            drawnow;
            
            successCount = 0;
            
            for i = 1:length(obj.CameraHandles)
                try
                    if isvalid(obj.CameraHandles{i})
                        img = snapshot(obj.CameraHandles{i});
                        
                        % Create new figure for snapshot
                        figName = sprintf('Snapshot - Camera %d', i);
                        figure('Name', figName, 'NumberTitle', 'off');
                        imshow(img);
                        title(sprintf('Camera %d - %s', i, datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
                        
                        successCount = successCount + 1;
                    end
                catch ME
                    warning('stageview:SnapshotError', ...
                           'Failed to capture snapshot from camera %d: %s', i, ME.message);
                end
            end
            
            obj.StatusLabel.Text = sprintf('%d snapshot(s) captured', successCount);
            if successCount > 0
                obj.StatusLabel.FontColor = [0.2 0.6 0.2];
            else
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
            obj.captureSnapshots();
        end
    end
end 
