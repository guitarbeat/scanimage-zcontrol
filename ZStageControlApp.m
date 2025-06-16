classdef ZStageControlApp < matlab.apps.AppBase
    % ZStageControlApp - Streamlined Z-stage positioning control interface
    % Simplified UI with essential functionality

    % UI Component Properties
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainLayout                  matlab.ui.container.GridLayout
        ControlTabs                 matlab.ui.container.TabGroup
    end

    % Private UI Component Properties
    properties (Access = private)
        % Position Display Components
        PositionDisplay = struct(...
            'Label', [], ...
            'Status', [])

        % Manual Control Components
        ManualControls = struct(...
            'UpButton', [], ...
            'DownButton', [], ...
            'StepSizeDropdown', [], ...
            'ZeroButton', [])

        % Auto Step Components
        AutoControls = struct(...
            'StepField', [], ...
            'StepsField', [], ...
            'DelayField', [], ...
            'UpButton', [], ...
            'DownButton', [], ...
            'StartStopButton', [])

        % Bookmark Components
        BookmarkControls = struct(...
            'PositionList', [], ...
            'MarkField', [], ...
            'MarkButton', [], ...
            'GoToButton', [], ...
            'DeleteButton', [])

        % ScanImage Status Components
        StatusControls = struct(...
            'Label', [], ...
            'RefreshButton', [])
    end

    % Application State Properties
    properties (Access = private)
        CurrentPosition (1,1) double = 0
        IsAutoRunning (1,1) logical = false
        AutoTimer
        CurrentStep (1,1) double = 0
        TotalSteps (1,1) double = 0
        MarkedPositions = struct('Labels', {{}}, 'Positions', [])

        % ScanImage Integration
        SimulationMode = true       % Default to simulation until ScanImage detected
        hSI                         % ScanImage handle
        motorFig                    % Motor Controls figure handle
        etZPos                      % Z position field
        Zstep                       % Z step field
        Zdec                        % Z decrease button
        Zinc                        % Z increase button
        RefreshTimer                % Timer for position refresh
    end

    % Constants
    properties (Constant, Access = private)
        WINDOW_WIDTH = 320
        WINDOW_HEIGHT = 340         % Made more square-like
        STEP_SIZES = [0.1, 0.5, 1, 5, 10, 50]
        COLORS = struct(...
            'Background', [0.95 0.95 0.95], ...
            'Primary', [0.2 0.6 0.9], ...
            'Success', [0.2 0.7 0.3], ...
            'Warning', [0.9 0.6 0.2], ...
            'Danger', [0.9 0.3 0.3], ...
            'Light', [0.98 0.98 0.98])
    end

    methods (Access = public)
        function app = ZStageControlApp()
            % Initialize UI component structures
            app.PositionDisplay = struct('Label', [], 'Status', []);
            app.ManualControls = struct('UpButton', [], 'DownButton', [], 'StepSizeDropdown', [], 'ZeroButton', []);
            app.AutoControls = struct('StepField', [], 'StepsField', [], 'DelayField', [], 'UpButton', [], 'DownButton', [], 'StartStopButton', []);
            app.BookmarkControls = struct('PositionList', [], 'MarkField', [], 'MarkButton', [], 'GoToButton', [], 'DeleteButton', []);
            app.StatusControls = struct('Label', [], 'RefreshButton', []);

            % Create UI components
            createComponents(app);

            % Initialize defaults and start timers
            initializeDefaults(app);
            initializeScanImage(app);

            % Register the app
            registerApp(app, app.UIFigure);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            try
                cleanup(app);
            catch ex
                warning(ex.identifier, '%s', ex.message);
            end
            
            % Delete UI figure if it's still valid
            if isvalid(app.UIFigure)
                try
                    delete(app.UIFigure);
                catch
                    % Continue even if this fails
                end
            end
        end
    end

    methods (Access = private)
        function createComponents(app)
            % Create main window and layout first
            createMainWindow(app);

            % Then create all other components
            createManualControls(app);
            createAutoControls(app);
            createBookmarks(app);

            % Initialize defaults and start timers
            initializeDefaults(app);
            initializeScanImage(app);

            % Make window visible
            app.UIFigure.Visible = 'on';
        end

        function createMainWindow(app)
            % Create the main figure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 app.WINDOW_WIDTH app.WINDOW_HEIGHT];
            app.UIFigure.Name = 'Z-Stage Control';
            app.UIFigure.Color = app.COLORS.Background;
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @onWindowClose, true);
            app.UIFigure.Resize = 'on';

            % Main grid layout for the entire window
            mainGrid = uigridlayout(app.UIFigure, [3, 1]);
            mainGrid.RowHeight = {'fit', '1x', 'fit'};
            mainGrid.ColumnWidth = {'1x'};
            mainGrid.Padding = [10 10 10 10];
            mainGrid.RowSpacing = 10;
            mainGrid.ColumnSpacing = 10;

            % Position display at top
            positionGrid = uigridlayout(mainGrid, [2, 1]);
            positionGrid.RowHeight = {'fit', 'fit'};
            positionGrid.ColumnWidth = {'1x'};
            positionGrid.Padding = [0 0 0 0];
            positionGrid.RowSpacing = 5;
            positionGrid.Layout.Row = 1;
            positionGrid.Layout.Column = 1;

            app.PositionDisplay.Label = uilabel(positionGrid);
            app.PositionDisplay.Label.Text = '0.0 μm';
            app.PositionDisplay.Label.FontSize = 28;
            app.PositionDisplay.Label.FontWeight = 'bold';
            app.PositionDisplay.Label.FontName = 'Courier New';
            app.PositionDisplay.Label.HorizontalAlignment = 'center';
            app.PositionDisplay.Label.BackgroundColor = app.COLORS.Light;
            app.PositionDisplay.Label.Layout.Row = 1;
            app.PositionDisplay.Label.Layout.Column = 1;

            app.StatusControls.Label = uilabel(positionGrid);
            app.StatusControls.Label.Text = 'Ready';
            app.StatusControls.Label.FontSize = 9;
            app.StatusControls.Label.FontWeight = 'normal';
            app.StatusControls.Label.HorizontalAlignment = 'center';
            app.StatusControls.Label.Layout.Row = 2;
            app.StatusControls.Label.Layout.Column = 1;
            app.StatusControls.Label.FontColor = [0.5 0.5 0.5];

            % Tab group in middle
            app.ControlTabs = uitabgroup(mainGrid);
            app.ControlTabs.Layout.Row = 2;
            app.ControlTabs.Layout.Column = 1;

            % ScanImage status at bottom
            statusGrid = uigridlayout(mainGrid, [1, 2]);
            statusGrid.RowHeight = {'fit'};
            statusGrid.ColumnWidth = {'1x', 'fit'};
            statusGrid.Padding = [0 0 0 0];
            statusGrid.ColumnSpacing = 10;
            statusGrid.Layout.Row = 3;
            statusGrid.Layout.Column = 1;

            app.StatusControls.Label = uilabel(statusGrid);
            app.StatusControls.Label.Text = 'ScanImage: Initializing...';
            app.StatusControls.Label.FontSize = 9;
            app.StatusControls.Label.Layout.Row = 1;
            app.StatusControls.Label.Layout.Column = 1;

            app.StatusControls.RefreshButton = uibutton(statusGrid, 'push');
            app.StatusControls.RefreshButton.Text = '↻';
            app.StatusControls.RefreshButton.ButtonPushedFcn = createCallbackFcn(app, @onRefreshButtonPushed, true);
            app.StatusControls.RefreshButton.FontSize = 11;
            app.StatusControls.RefreshButton.FontWeight = 'bold';
            app.StatusControls.RefreshButton.Layout.Row = 1;
            app.StatusControls.RefreshButton.Layout.Column = 2;
        end

        function createPositionDisplay(app)
            % Large position display at top
            app.PositionDisplay.Label = uilabel(app.MainLayout);
            app.PositionDisplay.Label.Text = '0.0 μm';
            app.PositionDisplay.Label.FontSize = 28;
            app.PositionDisplay.Label.FontWeight = 'bold';
            app.PositionDisplay.Label.FontName = 'Courier New';
            app.PositionDisplay.Label.HorizontalAlignment = 'center';
            app.PositionDisplay.Label.Position = [10 app.WINDOW_HEIGHT-60 app.WINDOW_WIDTH-30 40];
            app.PositionDisplay.Label.BackgroundColor = app.COLORS.Light;

            app.StatusControls.Label = uilabel(app.MainLayout);
            app.StatusControls.Label.Text = 'Ready';
            app.StatusControls.Label.FontSize = 9;
            app.StatusControls.Label.FontWeight = 'normal';
            app.StatusControls.Label.HorizontalAlignment = 'center';
            app.StatusControls.Label.Position = [10 app.WINDOW_HEIGHT-75 app.WINDOW_WIDTH-30 15];
            app.StatusControls.Label.FontColor = [0.5 0.5 0.5];
        end

        function createManualControls(app)
            % Create manual control tab
            manualTab = uitab(app.ControlTabs, 'Title', 'Manual Control');

            % Create grid layout for manual controls
            manualGrid = uigridlayout(manualTab, [2, 4]);
            manualGrid.RowHeight = {'fit', 'fit'};
            manualGrid.ColumnWidth = {'fit', 'fit', '1x', '1x'};
            manualGrid.Padding = [10 10 10 10];
            manualGrid.RowSpacing = 10;
            manualGrid.ColumnSpacing = 10;

            % Step size controls
            stepLabel = uilabel(manualGrid, 'Text', 'Step:', 'FontSize', 10);
            stepLabel.Layout.Row = 1;
            stepLabel.Layout.Column = 1;

            app.ManualControls.StepSizeDropdown = uidropdown(manualGrid);
            app.ManualControls.StepSizeDropdown.Items = arrayfun(@(x) sprintf('%.1f μm', x), app.STEP_SIZES, 'UniformOutput', false);
            app.ManualControls.StepSizeDropdown.Value = '1.0 μm';
            app.ManualControls.StepSizeDropdown.FontSize = 9;
            app.ManualControls.StepSizeDropdown.Layout.Row = 1;
            app.ManualControls.StepSizeDropdown.Layout.Column = 2;
            app.ManualControls.StepSizeDropdown.ValueChangedFcn = createCallbackFcn(app, @onStepSizeChanged, true);

            % Up/Down buttons
            app.ManualControls.UpButton = uibutton(manualGrid, 'push');
            app.ManualControls.UpButton.ButtonPushedFcn = createCallbackFcn(app, @onUpButtonPushed, true);
            app.ManualControls.UpButton.Layout.Row = 1;
            app.ManualControls.UpButton.Layout.Column = 3;
            app.styleButton(app.ManualControls.UpButton, 'success', '▲');

            app.ManualControls.DownButton = uibutton(manualGrid, 'push');
            app.ManualControls.DownButton.ButtonPushedFcn = createCallbackFcn(app, @onDownButtonPushed, true);
            app.ManualControls.DownButton.Layout.Row = 1;
            app.ManualControls.DownButton.Layout.Column = 4;
            app.styleButton(app.ManualControls.DownButton, 'warning', '▼');

            % Zero button
            app.ManualControls.ZeroButton = uibutton(manualGrid, 'push');
            app.ManualControls.ZeroButton.ButtonPushedFcn = createCallbackFcn(app, @onZeroButtonPushed, true);
            app.ManualControls.ZeroButton.Layout.Row = 2;
            app.ManualControls.ZeroButton.Layout.Column = [3 4];
            app.styleButton(app.ManualControls.ZeroButton, 'primary', 'ZERO');
        end

        function createAutoControls(app)
            % Create auto step tab
            autoTab = uitab(app.ControlTabs, 'Title', 'Auto Step');

            % Create grid layout for auto controls
            autoGrid = uigridlayout(autoTab, [3, 4]);
            autoGrid.RowHeight = {'fit', 'fit', 'fit'};
            autoGrid.ColumnWidth = {'fit', 'fit', '1x', '1x'};
            autoGrid.Padding = [10 10 10 10];
            autoGrid.RowSpacing = 10;
            autoGrid.ColumnSpacing = 10;

            % Parameters in grid
            sizeLabel = uilabel(autoGrid, 'Text', 'Size:', 'FontSize', 9);
            sizeLabel.Layout.Row = 1;
            sizeLabel.Layout.Column = 1;

            app.AutoControls.StepField = uieditfield(autoGrid, 'numeric');
            app.AutoControls.StepField.Value = 10;
            app.AutoControls.StepField.FontSize = 9;
            app.AutoControls.StepField.Layout.Row = 1;
            app.AutoControls.StepField.Layout.Column = 2;
            app.AutoControls.StepField.ValueChangedFcn = createCallbackFcn(app, @onAutoStepSizeChanged, true);

            stepsLabel = uilabel(autoGrid, 'Text', 'Steps:', 'FontSize', 9);
            stepsLabel.Layout.Row = 1;
            stepsLabel.Layout.Column = 3;

            app.AutoControls.StepsField = uieditfield(autoGrid, 'numeric');
            app.AutoControls.StepsField.Value = 10;
            app.AutoControls.StepsField.FontSize = 9;
            app.AutoControls.StepsField.Layout.Row = 1;
            app.AutoControls.StepsField.Layout.Column = 4;

            delayLabel = uilabel(autoGrid, 'Text', 'Delay:', 'FontSize', 9);
            delayLabel.Layout.Row = 2;
            delayLabel.Layout.Column = 1;

            app.AutoControls.DelayField = uieditfield(autoGrid, 'numeric');
            app.AutoControls.DelayField.Value = 0.5;
            app.AutoControls.DelayField.FontSize = 9;
            app.AutoControls.DelayField.Layout.Row = 2;
            app.AutoControls.DelayField.Layout.Column = 2;

            % Direction and start/stop
            app.AutoControls.UpButton = uibutton(autoGrid, 'push');
            app.AutoControls.UpButton.ButtonPushedFcn = createCallbackFcn(app, @onAutoDirectionChanged, true);
            app.AutoControls.UpButton.Layout.Row = 3;
            app.AutoControls.UpButton.Layout.Column = 1;
            app.styleButton(app.AutoControls.UpButton, 'success', '▲');

            app.AutoControls.DownButton = uibutton(autoGrid, 'push');
            app.AutoControls.DownButton.ButtonPushedFcn = createCallbackFcn(app, @onAutoDirectionChanged, true);
            app.AutoControls.DownButton.Layout.Row = 3;
            app.AutoControls.DownButton.Layout.Column = 2;
            app.styleButton(app.AutoControls.DownButton, 'warning', '▼');

            app.AutoControls.StartStopButton = uibutton(autoGrid, 'push');
            app.AutoControls.StartStopButton.ButtonPushedFcn = createCallbackFcn(app, @onStartStopButtonPushed, true);
            app.AutoControls.StartStopButton.Layout.Row = 3;
            app.AutoControls.StartStopButton.Layout.Column = [3 4];
            app.styleButton(app.AutoControls.StartStopButton, 'success', 'START');
        end

        function createBookmarks(app)
            % Create bookmarks tab
            bookmarksTab = uitab(app.ControlTabs, 'Title', 'Bookmarks');

            % Create grid layout for bookmarks
            bookmarksGrid = uigridlayout(bookmarksTab, [4, 2]);
            bookmarksGrid.RowHeight = {'fit', '1x', 'fit', 'fit'};
            bookmarksGrid.ColumnWidth = {'1x', 'fit'};
            bookmarksGrid.Padding = [10 10 10 10];
            bookmarksGrid.RowSpacing = 10;
            bookmarksGrid.ColumnSpacing = 10;

            % Mark controls
            app.BookmarkControls.MarkField = uieditfield(bookmarksGrid, 'text');
            app.BookmarkControls.MarkField.Placeholder = 'Label...';
            app.BookmarkControls.MarkField.FontSize = 9;
            app.BookmarkControls.MarkField.Layout.Row = 1;
            app.BookmarkControls.MarkField.Layout.Column = 1;

            app.BookmarkControls.MarkButton = uibutton(bookmarksGrid, 'push');
            app.BookmarkControls.MarkButton.ButtonPushedFcn = createCallbackFcn(app, @onMarkButtonPushed, true);
            app.BookmarkControls.MarkButton.Layout.Row = 1;
            app.BookmarkControls.MarkButton.Layout.Column = 2;
            app.styleButton(app.BookmarkControls.MarkButton, 'primary', 'MARK');

            % Position list
            app.BookmarkControls.PositionList = uilistbox(bookmarksGrid);
            app.BookmarkControls.PositionList.Items = {};
            app.BookmarkControls.PositionList.FontSize = 9;
            app.BookmarkControls.PositionList.FontName = 'Courier New';
            app.BookmarkControls.PositionList.ValueChangedFcn = createCallbackFcn(app, @onPositionListChanged, true);
            app.BookmarkControls.PositionList.Layout.Row = 2;
            app.BookmarkControls.PositionList.Layout.Column = [1 2];

            % Control buttons
            app.BookmarkControls.GoToButton = uibutton(bookmarksGrid, 'push');
            app.BookmarkControls.GoToButton.ButtonPushedFcn = createCallbackFcn(app, @onGoToButtonPushed, true);
            app.BookmarkControls.GoToButton.Enable = 'off';
            app.BookmarkControls.GoToButton.Layout.Row = 3;
            app.BookmarkControls.GoToButton.Layout.Column = 1;
            app.styleButton(app.BookmarkControls.GoToButton, 'success', 'GO TO');

            app.BookmarkControls.DeleteButton = uibutton(bookmarksGrid, 'push');
            app.BookmarkControls.DeleteButton.ButtonPushedFcn = createCallbackFcn(app, @onDeleteButtonPushed, true);
            app.BookmarkControls.DeleteButton.Enable = 'off';
            app.BookmarkControls.DeleteButton.Layout.Row = 3;
            app.BookmarkControls.DeleteButton.Layout.Column = 2;
            app.styleButton(app.BookmarkControls.DeleteButton, 'danger', 'DELETE');
        end

        function createScanImageStatus(app)
            % ScanImage connection status
            app.StatusControls.Label = uilabel(app.MainLayout);
            app.StatusControls.Label.Text = 'ScanImage: Initializing...';
            app.StatusControls.Label.FontSize = 9;
            app.StatusControls.Label.Position = [15 15 150 15];

            % Refresh button
            app.StatusControls.RefreshButton = uibutton(app.MainLayout, 'push');
            app.StatusControls.RefreshButton.Text = '↻';
            app.StatusControls.RefreshButton.Position = [225 10 30 20];
            app.StatusControls.RefreshButton.ButtonPushedFcn = createCallbackFcn(app, @onRefreshButtonPushed, true);
            app.StatusControls.RefreshButton.FontSize = 11;
            app.StatusControls.RefreshButton.FontWeight = 'bold';
        end

        function initializeDefaults(app)
            updatePositionDisplay(app);
            updatePositionsList(app);

            % Start position refresh timer
            app.RefreshTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', 0.5, ...
                'TimerFcn', @(~,~) app.refreshPosition());
            start(app.RefreshTimer);
        end

        function initializeScanImage(app)
            % Check if ScanImage is running
            try
                % Check if hSI exists and is an object
                siExists = evalin('base', 'exist(''hSI'', ''var'')');
                if ~siExists
                    setSimulationMode(app, true, 'ScanImage not running');
                    return;
                end

                % Now check if it's a valid object
                isValidSI = evalin('base', 'isobject(hSI)');
                if ~isValidSI
                    setSimulationMode(app, true, 'hSI is not a valid object');
                    return;
                end

                % ScanImage is running with valid hSI
                app.hSI = evalin('base', 'hSI');

                % Find motor controls window
                app.motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                if isempty(app.motorFig)
                    setSimulationMode(app, true, 'Motor Controls window not found');
                    return;
                end

                % Find motor UI elements
                app.etZPos = findall(app.motorFig, 'Tag', 'etZPos');
                app.Zstep = findall(app.motorFig, 'Tag', 'Zstep');
                app.Zdec = findall(app.motorFig, 'Tag', 'Zdec');
                app.Zinc = findall(app.motorFig, 'Tag', 'Zinc');

                if any(cellfun(@isempty, {app.etZPos, app.Zstep, app.Zdec, app.Zinc}))
                    setSimulationMode(app, true, 'Missing UI elements in Motor Controls');
                    return;
                end

                % Successfully connected to ScanImage
                setSimulationMode(app, false, 'Connected to ScanImage');

                % Initialize position from ScanImage
                app.CurrentPosition = str2double(app.etZPos.String);
                if isnan(app.CurrentPosition)
                    app.CurrentPosition = 0;
                end

                % Display info message about direct interaction
                app.StatusControls.Label.Text = 'Note: You can also directly enter positions in ScanImage';
                app.StatusControls.Label.FontColor = app.COLORS.Primary;

                % Reset status after 5 seconds
                timer('StartDelay', 5, 'TimerFcn', @(~,~) resetStatus(app), 'ExecutionMode', 'singleShot', 'StopFcn', @(t,~)delete(t));

            catch ex
                setSimulationMode(app, true, ['Error: ' ex.message]);
            end
        end

        function resetStatus(app)
            if isvalid(app) && isvalid(app.StatusControls.Label)
                app.StatusControls.Label.Text = 'Ready';
                app.StatusControls.Label.FontColor = [0.5 0.5 0.5];
            end
        end

        function setSimulationMode(app, isEnabled, message)
            app.SimulationMode = isEnabled;

            if isEnabled
                app.StatusControls.Label.Text = ['ScanImage: Simulation (' message ')'];
                app.StatusControls.Label.FontColor = app.COLORS.Warning;
            else
                app.StatusControls.Label.Text = ['ScanImage: ' message];
                app.StatusControls.Label.FontColor = app.COLORS.Success;
            end
        end

        function refreshPosition(app)
            % Only refresh if we're not in simulation mode and not auto-running
            if ~app.SimulationMode && ~app.IsAutoRunning && isvalid(app.etZPos)
                try
                    % Get position from ScanImage
                    zPos = str2double(app.etZPos.String);
                    if ~isnan(zPos) && zPos ~= app.CurrentPosition
                        app.CurrentPosition = zPos;
                        updatePositionDisplay(app);
                    end
                catch
                    % If there's an error, switch to simulation mode
                    setSimulationMode(app, true, 'Lost connection');
                end
            end
        end
    end

    %% Core Functionality Methods
    methods (Access = private)
        function moveStage(app, microns)
            if app.SimulationMode
                % Just update the internal position
                app.CurrentPosition = app.CurrentPosition + microns;
            else
                % Set step size in ScanImage control
                app.Zstep.String = num2str(abs(microns));

                % Press the appropriate button
                if microns > 0
                    app.Zinc.Callback(app.Zinc, []);
                else
                    app.Zdec.Callback(app.Zdec, []);
                end

                % Read back the position
                pause(0.1); % Give UI time to update
                zPos = str2double(app.etZPos.String);
                if ~isnan(zPos)
                    app.CurrentPosition = zPos;
                else
                    app.CurrentPosition = app.CurrentPosition + microns; % Fallback
                end
            end

            updatePositionDisplay(app);
            fprintf('Stage moved %.1f μm to position %.1f μm\n', microns, app.CurrentPosition);
        end

        function setPosition(app, position)
            import java.awt.Robot;
            import java.awt.event.KeyEvent;
            
            fprintf('[DEBUG] SET POS: Starting setPosition to %.1f μm\n', position);

            if app.SimulationMode
                % Just update the internal position
                fprintf('[DEBUG] SET POS: Using simulation mode\n');
                app.CurrentPosition = position;
            else
                fprintf('[DEBUG] SET POS: Using ScanImage mode\n');

                % Try direct ScanImage approach
                try
                    fprintf('[DEBUG] SET POS: METHOD 1 - Trying incremental movement\n');
                    % Method 1: Try direct incremental movement
                    % Calculate the difference to move
                    delta = position - app.CurrentPosition;
                    fprintf('[DEBUG] SET POS: Delta = %.1f μm\n', delta);

                    % Set step size in ScanImage control
                    fprintf('[DEBUG] SET POS: Setting Zstep.String to "%s"\n', num2str(abs(delta)));
                    app.Zstep.String = num2str(abs(delta));
                    drawnow;

                    % Press the appropriate button
                    if delta > 0
                        fprintf('[DEBUG] SET POS: Pressing UP button (Zinc)\n');
                        app.Zinc.Callback(app.Zinc, []);
                    elseif delta < 0
                        fprintf('[DEBUG] SET POS: Pressing DOWN button (Zdec)\n');
                        app.Zdec.Callback(app.Zdec, []);
                    else
                        fprintf('[DEBUG] SET POS: No movement needed (delta = 0)\n');
                    end

                    % Allow time for movement
                    pause(0.2);

                    % Verify position changed
                    zPos = str2double(app.etZPos.String);
                    fprintf('[DEBUG] SET POS: Position read after movement: %.1f μm\n', zPos);

                    if ~isnan(zPos)
                        app.CurrentPosition = zPos;
                        fprintf('[DEBUG] SET POS: METHOD 1 successful\n');
                    else
                        app.CurrentPosition = position; % Fallback
                        fprintf('[DEBUG] SET POS: Invalid position read, using fallback\n');
                    end
                catch ex
                    fprintf('[DEBUG] SET POS: METHOD 1 failed: %s\n', ex.message);

                    % Method 2: Try direct text entry with keypress simulation
                    try
                        fprintf('[DEBUG] SET POS: METHOD 2 - Trying direct text entry\n');

                        % Set the position directly in the Z Position textbox
                        fprintf('[DEBUG] SET POS: Setting etZPos.String to %s\n', num2str(position));
                        app.etZPos.String = num2str(position);

                        % Save original focus
                        originalFig = get(0, 'CurrentFigure');
                        fprintf('[DEBUG] SET POS: Original figure handle: %s\n', num2str(double(originalFig)));

                        % Set focus to motor controls and position field
                        fprintf('[DEBUG] SET POS: Setting focus to ScanImage Motor Controls window\n');
                        figure(app.motorFig);
                        uicontrol(app.etZPos);
                        drawnow;

                        % Try to simulate Enter key press using Java robot
                        fprintf('[DEBUG] SET POS: Attempting Enter key simulation\n');
                        try
                            robot = Robot();
                            robot.keyPress(KeyEvent.VK_ENTER);
                            robot.delay(50);
                            robot.keyRelease(KeyEvent.VK_ENTER);
                            fprintf('[DEBUG] SET POS: Java Robot Enter key simulation completed\n');
                        catch javaErr
                            fprintf('[DEBUG] SET POS: Java Robot failed: %s\n', javaErr.message);

                            % If Java robot fails, try callback method
                            if ~isempty(app.etZPos.Callback)
                                fprintf('[DEBUG] SET POS: Trying direct callback with Key=return\n');
                                if isa(app.etZPos.Callback, 'function_handle')
                                    app.etZPos.Callback(app.etZPos, struct('Key', 'return'));
                                elseif iscell(app.etZPos.Callback)
                                    app.etZPos.Callback{1}(app.etZPos, struct('Key', 'return'), app.etZPos.Callback{2:end});
                                end
                                fprintf('[DEBUG] SET POS: Callback execution completed\n');
                            else
                                fprintf('[DEBUG] SET POS: No callback found for etZPos\n');
                            end
                        end

                        % Restore original focus
                        if ~isempty(originalFig) && isvalid(originalFig)
                            fprintf('[DEBUG] SET POS: Restoring original figure focus\n');
                            figure(originalFig);
                        end

                        % Read back the position after a brief pause
                        fprintf('[DEBUG] SET POS: Waiting for movement completion...\n');
                        pause(0.5);
                        zPos = str2double(app.etZPos.String);
                        fprintf('[DEBUG] SET POS: Position read after direct text entry: %.1f μm\n', zPos);

                        if ~isnan(zPos)
                            app.CurrentPosition = zPos;
                            fprintf('[DEBUG] SET POS: METHOD 2 successful\n');
                        else
                            app.CurrentPosition = position; % Fallback
                            fprintf('[DEBUG] SET POS: Invalid position read, using fallback\n');
                        end
                    catch ex
                        fprintf('[DEBUG] SET POS: METHOD 2 failed: %s\n', ex.message);

                        % Method 3: Last resort fallback - simulate position change
                        fprintf('[DEBUG] SET POS: METHOD 3 - Using fallback simulation\n');
                        app.CurrentPosition = position;
                        fprintf('Warning: Could not communicate with ScanImage. Position simulated.\n');
                    end
                end
            end

            updatePositionDisplay(app);
            fprintf('Stage moved to position %.1f μm\n', app.CurrentPosition);
        end

        function resetPosition(app)
            if app.SimulationMode
                app.CurrentPosition = 0;
            else
                % Store the current absolute position for reference
                oldPosition = app.CurrentPosition;

                % Create a temporary offset field that can be used for relative mode
                % This would depend on ScanImage's specific API - for now we'll use simulation
                app.CurrentPosition = 0;

                fprintf('Stage position reset to 0 μm (actual position: %.1f μm)\n', oldPosition);
            end

            updatePositionDisplay(app);
        end

        function stepSize = getSelectedStepSize(app)
            % Get currently selected step size
            idx = strcmp(app.ManualControls.StepSizeDropdown.Value, app.ManualControls.StepSizeDropdown.Items);
            stepSize = app.STEP_SIZES(idx);
        end
    end

    %% Auto-stepping Methods
    methods (Access = private)
        function updateUIControls(app)
            % Update all UI controls based on current state
            updatePositionDisplay(app);
            updatePositionsList(app);
            updateAutoStepControls(app);
            updateManualControls(app);
        end

        function updateAutoStepControls(app)
            % Update auto step controls based on current state
            if app.IsAutoRunning
                app.AutoControls.StartStopButton.Text = 'STOP';
                app.AutoControls.StartStopButton.BackgroundColor = app.COLORS.Danger;
                app.AutoControls.StepField.Enable = 'off';
                app.AutoControls.StepsField.Enable = 'off';
                app.AutoControls.DelayField.Enable = 'off';
                app.AutoControls.UpButton.Enable = 'off';
                app.AutoControls.DownButton.Enable = 'off';
            else
                app.AutoControls.StartStopButton.Text = 'START';
                app.AutoControls.StartStopButton.BackgroundColor = app.COLORS.Success;
                app.AutoControls.StepField.Enable = 'on';
                app.AutoControls.StepsField.Enable = 'on';
                app.AutoControls.DelayField.Enable = 'on';
                app.AutoControls.UpButton.Enable = 'on';
                app.AutoControls.DownButton.Enable = 'on';
            end
        end

        function updateManualControls(app)
            % Update manual controls based on current state
            if app.IsAutoRunning
                app.ManualControls.UpButton.Enable = 'off';
                app.ManualControls.DownButton.Enable = 'off';
                app.ManualControls.ZeroButton.Enable = 'off';
                app.ManualControls.StepSizeDropdown.Enable = 'off';
            else
                app.ManualControls.UpButton.Enable = 'on';
                app.ManualControls.DownButton.Enable = 'on';
                app.ManualControls.ZeroButton.Enable = 'on';
                app.ManualControls.StepSizeDropdown.Enable = 'on';
            end
        end

        function updatePositionsList(app)
            % Update the positions list and its control buttons
            if isempty(app.MarkedPositions.Labels)
                app.BookmarkControls.PositionList.Items = {};
                app.BookmarkControls.GoToButton.Enable = 'off';
                app.BookmarkControls.DeleteButton.Enable = 'off';
                return;
            end

            items = cell(length(app.MarkedPositions.Labels), 1);
            for i = 1:length(app.MarkedPositions.Labels)
                items{i} = sprintf('%-12s %7.1f μm', ...
                    app.MarkedPositions.Labels{i}, app.MarkedPositions.Positions(i));
            end

            app.BookmarkControls.PositionList.Items = items;

            hasSelection = ~isempty(app.BookmarkControls.PositionList.Value);
            app.BookmarkControls.GoToButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
            app.BookmarkControls.DeleteButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
        end

        function updatePositionDisplay(app)
            app.PositionDisplay.Label.Text = sprintf('%.1f μm', app.CurrentPosition);

            if app.IsAutoRunning
                app.StatusControls.Label.Text = sprintf('Auto-stepping: %d/%d', app.CurrentStep, app.TotalSteps);
                app.StatusControls.Label.FontSize = 9;
                app.StatusControls.Label.FontWeight = 'normal';
                app.StatusControls.Label.FontColor = [0.5 0.5 0.5];
            else
                if app.SimulationMode
                    app.StatusControls.Label.Text = 'Simulation Mode';
                    app.StatusControls.Label.FontSize = 9;
                    app.StatusControls.Label.FontWeight = 'normal';
                    app.StatusControls.Label.FontColor = app.COLORS.Warning;
                else
                    % Keep the current status message if it's not the default "Ready"
                    if strcmp(app.StatusControls.Label.Text, 'Ready') || isempty(app.StatusControls.Label.Text)
                        app.StatusControls.Label.Text = 'Ready';
                        app.StatusControls.Label.FontSize = 9;
                        app.StatusControls.Label.FontWeight = 'normal';
                        app.StatusControls.Label.FontColor = [0.5 0.5 0.5];
                    end
                end
            end

            % Update UI figure title with position
            app.UIFigure.Name = sprintf('Z-Stage Control (%.1f μm)', app.CurrentPosition);
        end

        function startAutoStepping(app)
            if app.IsAutoRunning || ~validateAutoStepParameters(app)
                return;
            end

            app.IsAutoRunning = true;
            app.CurrentStep = 0;
            app.TotalSteps = app.AutoControls.StepsField.Value;

            % Store the exact step size from the field
            stepSize = app.AutoControls.StepField.Value;
            if isequal(app.AutoControls.DownButton.BackgroundColor, app.COLORS.Warning)
                stepSize = -stepSize;
            end

            % Create timer with the exact step size
            app.AutoTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', app.AutoControls.DelayField.Value, ...
                'TimerFcn', @(~,~) executeAutoStep(app, stepSize), ...
                'UserData', stepSize);  % Store step size in timer's UserData

            start(app.AutoTimer);
            updateUIControls(app);

            fprintf('Auto-stepping started: %d steps of %.1f μm\n', ...
                app.TotalSteps, abs(stepSize));
        end

        function stopAutoStepping(app)
            if ~isempty(app.AutoTimer) && isvalid(app.AutoTimer)
                stop(app.AutoTimer);
                delete(app.AutoTimer);
                app.AutoTimer = [];
            end

            app.IsAutoRunning = false;
            updateUIControls(app);

            fprintf('Auto-stepping completed at position %.1f μm\n', app.CurrentPosition);
        end

        function executeAutoStep(app, stepSize)
            % Use the exact step size passed in
            app.CurrentStep = app.CurrentStep + 1;
            moveStage(app, stepSize);

            if app.CurrentStep >= app.TotalSteps
                stopAutoStepping(app);
            end
        end

        function onStartStopButtonPushed(app, ~)
            if app.IsAutoRunning
                stopAutoStepping(app);
            else
                startAutoStepping(app);
            end
        end

        function onPositionListChanged(app, ~)
            updatePositionsList(app);
        end

        function onMarkButtonPushed(app, ~)
            label = strtrim(app.BookmarkControls.MarkField.Value);
            markCurrentPosition(app, label);
            app.BookmarkControls.MarkField.Value = '';
            updateUIControls(app);
        end

        function onGoToButtonPushed(app, ~)
            index = getSelectedPositionIndex(app);
            if ~isempty(index)
                goToMarkedPosition(app, index);
                updateUIControls(app);
            end
        end

        function onDeleteButtonPushed(app, ~)
            index = getSelectedPositionIndex(app);
            if ~isempty(index)
                deleteMarkedPosition(app, index);
                updateUIControls(app);
            end
        end

        function onRefreshButtonPushed(app, ~)
            initializeScanImage(app);
            updateUIControls(app);
        end
    end

    %% Position Management Methods
    methods (Access = private)
        function markCurrentPosition(app, label)
            if isempty(strtrim(label))
                uialert(app.UIFigure, 'Please enter a label', 'Input Required');
                return;
            end

            % Check for duplicates and handle
            if any(strcmp(app.MarkedPositions.Labels, label))
                idx = strcmp(app.MarkedPositions.Labels, label);
                app.MarkedPositions.Labels(idx) = [];
                app.MarkedPositions.Positions(idx) = [];
            end

            app.MarkedPositions.Labels{end+1} = label;
            app.MarkedPositions.Positions(end+1) = app.CurrentPosition;

            updatePositionsList(app);
            fprintf('Position marked: "%s" at %.1f μm\n', label, app.CurrentPosition);
        end

        function goToMarkedPosition(app, index)
            import java.awt.event.KeyEvent;
            import java.awt.Robot;
            
            if index < 1 || index > length(app.MarkedPositions.Positions) || app.IsAutoRunning
                return;
            end

            position = app.MarkedPositions.Positions(index);
            label = app.MarkedPositions.Labels{index};

            fprintf('[DEBUG] GO TO: Starting move to position %.1f μm ("%s")\n', position, label);

            % First try direct position setting method with Enter key simulation
            success = false;
            if ~app.SimulationMode && isvalid(app.etZPos)
                fprintf('[DEBUG] GO TO: ScanImage mode active, trying direct text entry method\n');
                try
                    % Set the position directly
                    fprintf('[DEBUG] GO TO: Setting etZPos.String to %s\n', num2str(position));
                    app.etZPos.String = num2str(position);
                    drawnow; % Ensure UI updates

                    % Save the original focus
                    originalFig = get(0, 'CurrentFigure');
                    fprintf('[DEBUG] GO TO: Original figure handle: %s\n', num2str(double(originalFig)));

                    % Explicitly set focus to the text field and simulate pressing Enter
                    fprintf('[DEBUG] GO TO: Setting focus to ScanImage Motor Controls window\n');
                    figure(app.motorFig); % Bring ScanImage motor window to front
                    uicontrol(app.etZPos); % Set focus to the position field
                    drawnow; % Update display

                    % Create and send a key press event with Enter key
                    robot = Robot();
                    robot.keyPress(KeyEvent.VK_ENTER);
                    robot.keyRelease(KeyEvent.VK_ENTER);
                    pause(0.1);
                    fprintf('[DEBUG] GO TO: Java Robot Enter key simulation completed\n');

                    % Allow time for stage to move
                    fprintf('[DEBUG] GO TO: Waiting for stage movement to complete...\n');
                    pause(0.5);

                    % Update current position from ScanImage
                    zPos = str2double(app.etZPos.String);
                    fprintf('[DEBUG] GO TO: Position read back from ScanImage: %.1f\n', zPos);
                    if ~isnan(zPos)
                        app.CurrentPosition = zPos;
                        success = true;
                        fprintf('[DEBUG] GO TO: Direct text entry method successful\n');
                    else
                        fprintf('[DEBUG] GO TO: Invalid position read back from ScanImage\n');
                    end

                    % Restore original focus
                    if ~isempty(originalFig) && isvalid(originalFig)
                        fprintf('[DEBUG] GO TO: Restoring original figure focus\n');
                        figure(originalFig);
                    end

                catch ex
                    % If direct setting fails, fall back to original method
                    fprintf('[DEBUG] GO TO: Direct text entry method failed: %s\n', ex.message);
                    success = false;
                end
            else
                fprintf('[DEBUG] GO TO: Using simulation mode or invalid ScanImage controls\n');
            end

            % If direct method failed, fall back to incremental method
            if ~success
                fprintf('[DEBUG] GO TO: Falling back to setPosition method\n');
                setPosition(app, position);
            end

            % Update display
            updatePositionDisplay(app);
            fprintf('Moved to "%s": %.1f μm\n', label, position);
        end

        function deleteMarkedPosition(app, index)
            if index < 1 || index > length(app.MarkedPositions.Labels)
                return;
            end

            label = app.MarkedPositions.Labels{index};
            app.MarkedPositions.Labels(index) = [];
            app.MarkedPositions.Positions(index) = [];

            updatePositionsList(app);
            fprintf('Deleted: "%s"\n', label);
        end

        function index = getSelectedPositionIndex(app)
            index = [];
            if isempty(app.BookmarkControls.PositionList.Value)
                return;
            end
            index = find(strcmp(app.BookmarkControls.PositionList.Items, app.BookmarkControls.PositionList.Value), 1);
        end
    end

    %% Event Callbacks
    methods (Access = private)
        function onUpButtonPushed(app, ~)
            stepSize = getSelectedStepSize(app);
            moveStage(app, stepSize);
        end

        function onDownButtonPushed(app, ~)
            stepSize = getSelectedStepSize(app);
            moveStage(app, -stepSize);
        end

        function onZeroButtonPushed(app, ~)
            resetPosition(app);
        end

        function onAutoDirectionChanged(app, event)
            % Toggle between up and down direction
            if event.Source == app.AutoControls.UpButton
                app.AutoControls.UpButton.BackgroundColor = app.COLORS.Success;
                app.AutoControls.DownButton.BackgroundColor = app.COLORS.Light;
            else
                app.AutoControls.UpButton.BackgroundColor = app.COLORS.Light;
                app.AutoControls.DownButton.BackgroundColor = app.COLORS.Warning;
            end
        end

        function onWindowClose(app, ~)
            try
                cleanup(app);
            catch ex
                warning(ex.identifier, '%s', ex.message);
            end
            
            try
                delete(app);
            catch
                % If delete fails, force deletion by removing reference to UIFigure
                if isvalid(app.UIFigure)
                    delete(app.UIFigure);
                end
            end
        end
    end

    methods (Access = private)
        function cleanup(app)
            % First stop any auto-stepping that might be in progress
            if app.IsAutoRunning
                try
                    stopAutoStepping(app);
                catch
                    % Continue with cleanup even if this fails
                end
            end

            % Stop refresh timer
            if ~isempty(app.RefreshTimer) && isobject(app.RefreshTimer) && isvalid(app.RefreshTimer)
                try
                    stop(app.RefreshTimer);
                    delete(app.RefreshTimer);
                catch
                    % Continue with cleanup even if this fails
                end
                app.RefreshTimer = [];
            end

            % Delete any other timers that might have been created
            try
                % Find all timers that might be associated with this app
                allTimers = timerfindall;
                for i = 1:length(allTimers)
                    if isvalid(allTimers(i))
                        try
                            stop(allTimers(i));
                            delete(allTimers(i));
                        catch
                            % Continue with cleanup even if this fails
                        end
                    end
                end
            catch
                % Continue with cleanup even if timer cleanup fails
            end

            % Set flags to prevent further callbacks from executing
            app.IsAutoRunning = false;
        end

        function btn = styleButton(app, btn, type, text)
            % Helper function to apply consistent button styling
            btn.Text = text;
            btn.FontSize = 10;
            btn.FontWeight = 'bold';
            btn.FontColor = [1 1 1];  % White text for all buttons

            % Apply semantic color coding
            switch type
                case 'success'
                    btn.BackgroundColor = app.COLORS.Success;
                case 'warning'
                    btn.BackgroundColor = app.COLORS.Warning;
                case 'primary'
                    btn.BackgroundColor = app.COLORS.Primary;
                case 'danger'
                    btn.BackgroundColor = app.COLORS.Danger;
            end
        end

        function isValid = validateAutoStepParameters(app)
            % Validate auto step parameters before starting
            isValid = true;

            % Check step size
            if app.AutoControls.StepField.Value <= 0
                uialert(app.UIFigure, 'Step size must be greater than 0', 'Invalid Parameter');
                isValid = false;
                return;
            end

            % Check number of steps
            steps = app.AutoControls.StepsField.Value;
            if steps <= 0 || mod(steps, 1) ~= 0
                uialert(app.UIFigure, 'Number of steps must be a positive whole number', 'Invalid Parameter');
                isValid = false;
                return;
            end

            % Check delay
            if app.AutoControls.DelayField.Value < 0
                uialert(app.UIFigure, 'Delay must be non-negative', 'Invalid Parameter');
                isValid = false;
                return;
            end

            % Check if a direction is selected
            upIsLight = isequal(app.AutoControls.UpButton.BackgroundColor, app.COLORS.Light);
            downIsLight = isequal(app.AutoControls.DownButton.BackgroundColor, app.COLORS.Light);
            if upIsLight && downIsLight
                uialert(app.UIFigure, 'Please select a direction (Up or Down)', 'Invalid Parameter');
                isValid = false;
                return;
            end
        end

        function onStepSizeChanged(app, event)
            % Get the numeric value from the dropdown text
            stepText = event.Value;
            stepValue = str2double(extractBefore(stepText, ' μm'));

            % Update the auto step size field if it exists
            if ~isempty(app.AutoControls) && isvalid(app.AutoControls.StepField)
                app.AutoControls.StepField.Value = stepValue;
            end
        end

        function onAutoStepSizeChanged(app, event)
            % Get the new step size value
            newStepSize = event.Value;

            % Find the closest matching step size in our predefined list
            [~, idx] = min(abs(app.STEP_SIZES - newStepSize));
            closestStep = app.STEP_SIZES(idx);

            % Update the dropdown to match
            app.ManualControls.StepSizeDropdown.Value = sprintf('%.1f μm', closestStep);
        end
    end
end