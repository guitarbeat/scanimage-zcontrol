classdef ZStageControlApp < matlab.apps.AppBase
    % ZStageControlApp - Streamlined Z-stage positioning control interface
    % Provides manual control, auto-stepping, and position bookmarking
    
    %% Constants
    properties (Constant, Access = private)
        % Window Configuration
        WINDOW_WIDTH = 320
        WINDOW_HEIGHT = 340
        
        % Step Size Options
        STEP_SIZES = [0.1, 0.5, 1, 5, 10, 50]
        DEFAULT_STEP_SIZE = 1.0
        
        % Auto Step Defaults
        DEFAULT_AUTO_STEP = 10
        DEFAULT_AUTO_STEPS = 10
        DEFAULT_AUTO_DELAY = 0.5
        
        % Timer Configuration
        POSITION_REFRESH_PERIOD = 0.5
        MOVEMENT_WAIT_TIME = 0.2
        STATUS_RESET_DELAY = 5
        
        % UI Theme Colors
        COLORS = struct(...
            'Background', [0.95 0.95 0.95], ...
            'Primary', [0.2 0.6 0.9], ...
            'Success', [0.2 0.7 0.3], ...
            'Warning', [0.9 0.6 0.2], ...
            'Danger', [0.9 0.3 0.3], ...
            'Light', [0.98 0.98 0.98], ...
            'TextMuted', [0.5 0.5 0.5])
        
        % UI Text
        TEXT = struct(...
            'WindowTitle', 'Z-Stage Control', ...
            'Ready', 'Ready', ...
            'Simulation', 'Simulation Mode', ...
            'Initializing', 'ScanImage: Initializing...', ...
            'Connected', 'Connected to ScanImage', ...
            'NotRunning', 'ScanImage not running', ...
            'WindowNotFound', 'Motor Controls window not found', ...
            'MissingElements', 'Missing UI elements in Motor Controls', ...
            'LostConnection', 'Lost connection')
    end
    
    %% Public Properties - UI Components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainLayout                  matlab.ui.container.GridLayout
        ControlTabs                 matlab.ui.container.TabGroup
    end
    
    %% Private Properties - UI Component Groups
    properties (Access = private)
        % Position Display
        PositionDisplay = struct('Label', [], 'Status', [])
        
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
        
        % Status Components
        StatusControls = struct('Label', [], 'RefreshButton', [])
    end
    
    %% Private Properties - Application State
    properties (Access = private)
        % Position State
        CurrentPosition (1,1) double = 0
        MarkedPositions = struct('Labels', {{}}, 'Positions', [])
        
        % Auto Step State
        IsAutoRunning (1,1) logical = false
        AutoTimer
        CurrentStep (1,1) double = 0
        TotalSteps (1,1) double = 0
        AutoDirection (1,1) double = 1  % 1 for up, -1 for down
        
        % ScanImage Integration
        SimulationMode (1,1) logical = true
        hSI                         % ScanImage handle
        motorFig                    % Motor Controls figure handle
        etZPos                      % Z position field
        Zstep                       % Z step field
        Zdec                        % Z decrease button
        Zinc                        % Z increase button
        
        % Timers
        RefreshTimer
    end
    
    %% Constructor and Destructor
    methods (Access = public)
        function app = ZStageControlApp()
            % Initialize component structures
            initializeComponentStructures(app);
            
            % Create UI
            createComponents(app);
            
            % Initialize application
            initializeApplication(app);
            
            % Register app
            registerApp(app, app.UIFigure);
            
            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            cleanup(app);
            deleteUIFigure(app);
        end
    end
    
    %% Initialization Methods
    methods (Access = private)
        function initializeComponentStructures(app)
            % Ensure all component structures are properly initialized
            app.PositionDisplay = struct('Label', [], 'Status', []);
            app.ManualControls = struct(...
                'UpButton', [], 'DownButton', [], ...
                'StepSizeDropdown', [], 'ZeroButton', []);
            app.AutoControls = struct(...
                'StepField', [], 'StepsField', [], 'DelayField', [], ...
                'UpButton', [], 'DownButton', [], 'StartStopButton', []);
            app.BookmarkControls = struct(...
                'PositionList', [], 'MarkField', [], 'MarkButton', [], ...
                'GoToButton', [], 'DeleteButton', []);
            app.StatusControls = struct('Label', [], 'RefreshButton', []);
        end
        
        function initializeApplication(app)
            % Initialize ScanImage interface
            connectToScanImage(app);
            
            % Update initial display
            updateAllUI(app);
            
            % Start refresh timer
            startRefreshTimer(app);
        end
        
        function connectToScanImage(app)
            % Check if ScanImage is running
            try
                % Check if hSI exists
                if ~evalin('base', 'exist(''hSI'', ''var'') && isobject(hSI)')
                    setSimulationMode(app, true, app.TEXT.NotRunning);
                    return;
                end
                
                % Get ScanImage handle
                app.hSI = evalin('base', 'hSI');
                
                % Find motor controls window
                app.motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                if isempty(app.motorFig)
                    setSimulationMode(app, true, app.TEXT.WindowNotFound);
                    return;
                end
                
                % Find motor UI elements
                app.etZPos = findall(app.motorFig, 'Tag', 'etZPos');
                app.Zstep = findall(app.motorFig, 'Tag', 'Zstep');
                app.Zdec = findall(app.motorFig, 'Tag', 'Zdec');
                app.Zinc = findall(app.motorFig, 'Tag', 'Zinc');
                
                if any(cellfun(@isempty, {app.etZPos, app.Zstep, app.Zdec, app.Zinc}))
                    setSimulationMode(app, true, app.TEXT.MissingElements);
                    return;
                end
                
                % Successfully connected
                setSimulationMode(app, false, app.TEXT.Connected);
                
                % Initialize position
                app.CurrentPosition = str2double(app.etZPos.String);
                if isnan(app.CurrentPosition)
                    app.CurrentPosition = 0;
                end
                
            catch ex
                setSimulationMode(app, true, ['Error: ' ex.message]);
            end
        end
        
        function setSimulationMode(app, isSimulation, message)
            app.SimulationMode = isSimulation;
            
            if isSimulation
                app.StatusControls.Label.Text = ['ScanImage: Simulation (' message ')'];
                app.StatusControls.Label.FontColor = app.COLORS.Warning;
            else
                app.StatusControls.Label.Text = ['ScanImage: ' message];
                app.StatusControls.Label.FontColor = app.COLORS.Success;
            end
        end
        
        function startRefreshTimer(app)
            app.RefreshTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', app.POSITION_REFRESH_PERIOD, ...
                'TimerFcn', @(~,~) refreshPosition(app));
            start(app.RefreshTimer);
        end
    end
    
    %% UI Creation Methods
    methods (Access = private)
        function createComponents(app)
            createMainWindow(app);
            createTabs(app);
            app.UIFigure.Visible = 'on';
        end
        
        function createMainWindow(app)
            % Create main figure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 app.WINDOW_WIDTH app.WINDOW_HEIGHT];
            app.UIFigure.Name = app.TEXT.WindowTitle;
            app.UIFigure.Color = app.COLORS.Background;
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @onWindowClose, true);
            app.UIFigure.Resize = 'on';
            
            % Create main layout
            app.MainLayout = uigridlayout(app.UIFigure, [3, 1]);
            app.MainLayout.RowHeight = {'fit', '1x', 'fit'};
            app.MainLayout.ColumnWidth = {'1x'};
            app.MainLayout.Padding = [10 10 10 10];
            app.MainLayout.RowSpacing = 10;
            
            % Create sections
            createPositionDisplay(app);
            createTabGroup(app);
            createStatusBar(app);
        end
        
        function createPositionDisplay(app)
            % Create position display panel
            positionPanel = uigridlayout(app.MainLayout, [2, 1]);
            positionPanel.RowHeight = {'fit', 'fit'};
            positionPanel.RowSpacing = 5;
            positionPanel.Layout.Row = 1;
            
            % Position label
            app.PositionDisplay.Label = uilabel(positionPanel);
            app.PositionDisplay.Label.Text = '0.0 μm';
            app.PositionDisplay.Label.FontSize = 28;
            app.PositionDisplay.Label.FontWeight = 'bold';
            app.PositionDisplay.Label.FontName = 'Courier New';
            app.PositionDisplay.Label.HorizontalAlignment = 'center';
            app.PositionDisplay.Label.BackgroundColor = app.COLORS.Light;
            
            % Status label
            app.PositionDisplay.Status = uilabel(positionPanel);
            app.PositionDisplay.Status.Text = app.TEXT.Ready;
            app.PositionDisplay.Status.FontSize = 9;
            app.PositionDisplay.Status.HorizontalAlignment = 'center';
            app.PositionDisplay.Status.FontColor = app.COLORS.TextMuted;
        end
        
        function createTabGroup(app)
            app.ControlTabs = uitabgroup(app.MainLayout);
            app.ControlTabs.Layout.Row = 2;
        end
        
        function createStatusBar(app)
            statusBar = uigridlayout(app.MainLayout, [1, 2]);
            statusBar.ColumnWidth = {'1x', 'fit'};
            statusBar.Layout.Row = 3;
            
            % Status label
            app.StatusControls.Label = uilabel(statusBar);
            app.StatusControls.Label.Text = app.TEXT.Initializing;
            app.StatusControls.Label.FontSize = 9;
            
            % Refresh button
            app.StatusControls.RefreshButton = uibutton(statusBar, 'push');
            app.StatusControls.RefreshButton.Text = '↻';
            app.StatusControls.RefreshButton.FontSize = 11;
            app.StatusControls.RefreshButton.FontWeight = 'bold';
            app.StatusControls.RefreshButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @onRefreshButtonPushed, true);
        end
        
        function createTabs(app)
            createManualControlTab(app);
            createAutoStepTab(app);
            createBookmarksTab(app);
        end
        
        function createManualControlTab(app)
            tab = uitab(app.ControlTabs, 'Title', 'Manual Control');
            grid = uigridlayout(tab, [2, 4]);
            configureGridLayout(app, grid);
            
            % Step size controls
            createLabeledControl(app, grid, 'Step:', 1, 1);
            
            app.ManualControls.StepSizeDropdown = uidropdown(grid);
            app.ManualControls.StepSizeDropdown.Items = ...
                arrayfun(@(x) sprintf('%.1f μm', x), app.STEP_SIZES, 'UniformOutput', false);
            app.ManualControls.StepSizeDropdown.Value = sprintf('%.1f μm', app.DEFAULT_STEP_SIZE);
            app.ManualControls.StepSizeDropdown.FontSize = 9;
            app.ManualControls.StepSizeDropdown.Layout.Row = 1;
            app.ManualControls.StepSizeDropdown.Layout.Column = 2;
            app.ManualControls.StepSizeDropdown.ValueChangedFcn = ...
                createCallbackFcn(app, @onStepSizeChanged, true);
            
            % Movement buttons
            app.ManualControls.UpButton = createStyledButton(app, grid, ...
                'success', '▲', @onUpButtonPushed, [1, 3]);
            app.ManualControls.DownButton = createStyledButton(app, grid, ...
                'warning', '▼', @onDownButtonPushed, [1, 4]);
            
            % Zero button
            app.ManualControls.ZeroButton = createStyledButton(app, grid, ...
                'primary', 'ZERO', @onZeroButtonPushed, [2, [3 4]]);
        end
        
        function createAutoStepTab(app)
            tab = uitab(app.ControlTabs, 'Title', 'Auto Step');
            grid = uigridlayout(tab, [3, 4]);
            configureGridLayout(app, grid);
            
            % Step size field
            createLabeledControl(app, grid, 'Size:', 1, 1);
            app.AutoControls.StepField = uieditfield(grid, 'numeric');
            app.AutoControls.StepField.Value = app.DEFAULT_AUTO_STEP;
            app.AutoControls.StepField.FontSize = 9;
            app.AutoControls.StepField.Layout.Row = 1;
            app.AutoControls.StepField.Layout.Column = 2;
            app.AutoControls.StepField.ValueChangedFcn = ...
                createCallbackFcn(app, @onAutoStepSizeChanged, true);
            
            % Steps field
            createLabeledControl(app, grid, 'Steps:', 1, 3);
            app.AutoControls.StepsField = uieditfield(grid, 'numeric');
            app.AutoControls.StepsField.Value = app.DEFAULT_AUTO_STEPS;
            app.AutoControls.StepsField.FontSize = 9;
            app.AutoControls.StepsField.Layout.Row = 1;
            app.AutoControls.StepsField.Layout.Column = 4;
            
            % Delay field
            createLabeledControl(app, grid, 'Delay:', 2, 1);
            app.AutoControls.DelayField = uieditfield(grid, 'numeric');
            app.AutoControls.DelayField.Value = app.DEFAULT_AUTO_DELAY;
            app.AutoControls.DelayField.FontSize = 9;
            app.AutoControls.DelayField.Layout.Row = 2;
            app.AutoControls.DelayField.Layout.Column = 2;
            
            % Direction buttons
            app.AutoControls.UpButton = createStyledButton(app, grid, ...
                'success', '▲', @onAutoDirectionChanged, [3, 1]);
            app.AutoControls.DownButton = createStyledButton(app, grid, ...
                'warning', '▼', @onAutoDirectionChanged, [3, 2]);
            
            % Start/stop button
            app.AutoControls.StartStopButton = createStyledButton(app, grid, ...
                'success', 'START', @onStartStopButtonPushed, [3, [3 4]]);
        end
        
        function createBookmarksTab(app)
            tab = uitab(app.ControlTabs, 'Title', 'Bookmarks');
            grid = uigridlayout(tab, [4, 2]);
            configureGridLayout(app, grid);
            
            % Mark controls
            app.BookmarkControls.MarkField = uieditfield(grid, 'text');
            app.BookmarkControls.MarkField.Placeholder = 'Label...';
            app.BookmarkControls.MarkField.FontSize = 9;
            app.BookmarkControls.MarkField.Layout.Row = 1;
            app.BookmarkControls.MarkField.Layout.Column = 1;
            
            app.BookmarkControls.MarkButton = createStyledButton(app, grid, ...
                'primary', 'MARK', @onMarkButtonPushed, [1, 2]);
            
            % Position list
            app.BookmarkControls.PositionList = uilistbox(grid);
            app.BookmarkControls.PositionList.FontSize = 9;
            app.BookmarkControls.PositionList.FontName = 'Courier New';
            app.BookmarkControls.PositionList.Layout.Row = 2;
            app.BookmarkControls.PositionList.Layout.Column = [1 2];
            app.BookmarkControls.PositionList.ValueChangedFcn = ...
                createCallbackFcn(app, @onPositionListChanged, true);
            
            % Control buttons
            app.BookmarkControls.GoToButton = createStyledButton(app, grid, ...
                'success', 'GO TO', @onGoToButtonPushed, [3, 1]);
            app.BookmarkControls.GoToButton.Enable = 'off';
            
            app.BookmarkControls.DeleteButton = createStyledButton(app, grid, ...
                'danger', 'DELETE', @onDeleteButtonPushed, [3, 2]);
            app.BookmarkControls.DeleteButton.Enable = 'off';
        end
    end
    
    %% UI Helper Methods
    methods (Access = private)
        function configureGridLayout(app, grid)
            grid.RowHeight = {'fit', 'fit', 'fit'};
            grid.ColumnWidth = {'fit', 'fit', '1x', '1x'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 10;
            grid.ColumnSpacing = 10;
        end
        
        function createLabeledControl(app, parent, text, row, col)
            label = uilabel(parent, 'Text', text, 'FontSize', 9);
            label.Layout.Row = row;
            label.Layout.Column = col;
        end
        
        function button = createStyledButton(app, parent, style, text, callback, position)
            button = uibutton(parent, 'push');
            button.Text = text;
            button.FontSize = 10;
            button.FontWeight = 'bold';
            button.Layout.Row = position(1);
            
            if length(position) > 1
                button.Layout.Column = position(2);
            end
            
            button.ButtonPushedFcn = createCallbackFcn(app, callback, true);
            
            % Apply style
            switch style
                case 'success'
                    button.BackgroundColor = app.COLORS.Success;
                case 'warning'
                    button.BackgroundColor = app.COLORS.Warning;
                case 'primary'
                    button.BackgroundColor = app.COLORS.Primary;
                case 'danger'
                    button.BackgroundColor = app.COLORS.Danger;
            end
            button.FontColor = [1 1 1];  % White text
        end
    end
    
    %% Position Control Methods
    methods (Access = private)
        function moveStage(app, microns)
            if app.SimulationMode
                app.CurrentPosition = app.CurrentPosition + microns;
            else
                % Set step size
                app.Zstep.String = num2str(abs(microns));
                
                % Simulate pressing Enter in the step field to apply the value
                if isfield(app.Zstep, 'Callback') && ~isempty(app.Zstep.Callback)
                    app.Zstep.Callback(app.Zstep, []);
                end
                
                % Press button
                if microns > 0
                    app.Zinc.Callback(app.Zinc, []);
                else
                    app.Zdec.Callback(app.Zdec, []);
                end
                
                % Read position
                pause(0.1);
                zPos = str2double(app.etZPos.String);
                if ~isnan(zPos)
                    app.CurrentPosition = zPos;
                else
                    app.CurrentPosition = app.CurrentPosition + microns;
                end
            end
            
            updatePositionDisplay(app);
            fprintf('Stage moved %.1f μm to position %.1f μm\n', microns, app.CurrentPosition);
        end
        
        function setPosition(app, position)
            if app.SimulationMode
                app.CurrentPosition = position;
            else
                % Calculate delta
                delta = position - app.CurrentPosition;
                
                if abs(delta) > 0.01
                    moveStage(app, delta);
                end
            end
            
            updatePositionDisplay(app);
        end
        
        function resetPosition(app)
            oldPosition = app.CurrentPosition;
            app.CurrentPosition = 0;
            updatePositionDisplay(app);
            fprintf('Position reset to 0 μm (was %.1f μm)\n', oldPosition);
        end
        
        function refreshPosition(app)
            if shouldRefreshPosition(app)
                try
                    zPos = str2double(app.etZPos.String);
                    if ~isnan(zPos) && zPos ~= app.CurrentPosition
                        app.CurrentPosition = zPos;
                        updatePositionDisplay(app);
                    end
                catch
                    handleConnectionLoss(app);
                end
            end
        end
        
        function should = shouldRefreshPosition(app)
            should = ~app.SimulationMode && ...
                     ~app.IsAutoRunning && ...
                     isvalid(app.etZPos);
        end
        
        function handleConnectionLoss(app)
            app.SimulationMode = true;
            setSimulationMode(app, true, app.TEXT.LostConnection);
        end
    end
    
    %% Auto Step Methods
    methods (Access = private)
        function startAutoStepping(app)
            if ~validateAutoStepParameters(app)
                return;
            end
            
            app.IsAutoRunning = true;
            app.CurrentStep = 0;
            app.TotalSteps = app.AutoControls.StepsField.Value;
            
            stepSize = app.AutoControls.StepField.Value * app.AutoDirection;
            
            app.AutoTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', app.AutoControls.DelayField.Value, ...
                'TimerFcn', @(~,~) executeAutoStep(app, stepSize));
            
            start(app.AutoTimer);
            updateAllUI(app);
            
            fprintf('Auto-stepping started: %d steps of %.1f μm\n', ...
                app.TotalSteps, abs(stepSize));
        end
        
        function stopAutoStepping(app)
            stopTimer(app, app.AutoTimer);
            app.AutoTimer = [];
            app.IsAutoRunning = false;
            updateAllUI(app);
            
            fprintf('Auto-stepping completed at position %.1f μm\n', app.CurrentPosition);
        end
        
        function executeAutoStep(app, stepSize)
            app.CurrentStep = app.CurrentStep + 1;
            moveStage(app, stepSize);
            
            if app.CurrentStep >= app.TotalSteps
                stopAutoStepping(app);
            else
                updateStatusDisplay(app);
            end
        end
        
        function valid = validateAutoStepParameters(app)
            valid = true;
            
            if app.AutoControls.StepField.Value <= 0
                showError(app, 'Step size must be greater than 0');
                valid = false;
            elseif app.AutoControls.StepsField.Value <= 0 || ...
                   mod(app.AutoControls.StepsField.Value, 1) ~= 0
                showError(app, 'Number of steps must be a positive whole number');
                valid = false;
            elseif app.AutoControls.DelayField.Value < 0
                showError(app, 'Delay must be non-negative');
                valid = false;
            end
        end
    end
    
    %% Bookmark Methods
    methods (Access = private)
        function markCurrentPosition(app, label)
            if isempty(strtrim(label))
                showError(app, 'Please enter a label');
                return;
            end
            
            % Remove existing bookmark with same label
            existingIdx = strcmp(app.MarkedPositions.Labels, label);
            if any(existingIdx)
                app.MarkedPositions.Labels(existingIdx) = [];
                app.MarkedPositions.Positions(existingIdx) = [];
            end
            
            % Add new bookmark
            app.MarkedPositions.Labels{end+1} = label;
            app.MarkedPositions.Positions(end+1) = app.CurrentPosition;
            
            updateBookmarksList(app);
            fprintf('Position marked: "%s" at %.1f μm\n', label, app.CurrentPosition);
        end
        
        function goToMarkedPosition(app, index)
            if ~isValidBookmarkIndex(app, index) || app.IsAutoRunning
                return;
            end
            
            position = app.MarkedPositions.Positions(index);
            label = app.MarkedPositions.Labels{index};
            
            setPosition(app, position);
            fprintf('Moved to bookmark "%s": %.1f μm\n', label, position);
        end
        
        function deleteMarkedPosition(app, index)
            if ~isValidBookmarkIndex(app, index)
                return;
            end
            
            label = app.MarkedPositions.Labels{index};
            app.MarkedPositions.Labels(index) = [];
            app.MarkedPositions.Positions(index) = [];
            
            updateBookmarksList(app);
            fprintf('Deleted bookmark: "%s"\n', label);
        end
        
        function valid = isValidBookmarkIndex(app, index)
            valid = index >= 1 && index <= length(app.MarkedPositions.Labels);
        end
        
        function index = getSelectedBookmarkIndex(app)
            index = [];
            selectedValue = app.BookmarkControls.PositionList.Value;
            if isempty(selectedValue)
                return;
            end
            
            index = find(strcmp(app.BookmarkControls.PositionList.Items, selectedValue), 1);
        end
    end
    
    %% UI Update Methods
    methods (Access = private)
        function updateAllUI(app)
            updatePositionDisplay(app);
            updateStatusDisplay(app);
            updateBookmarksList(app);
            updateControlStates(app);
        end
        
        function updatePositionDisplay(app)
            app.PositionDisplay.Label.Text = sprintf('%.1f μm', app.CurrentPosition);
            app.UIFigure.Name = sprintf('%s (%.1f μm)', app.TEXT.WindowTitle, app.CurrentPosition);
        end
        
        function updateStatusDisplay(app)
            if app.IsAutoRunning
                text = sprintf('Auto-stepping: %d/%d', app.CurrentStep, app.TotalSteps);
                app.PositionDisplay.Status.Text = text;
            else
                app.PositionDisplay.Status.Text = app.TEXT.Ready;
            end
        end
        
        function updateBookmarksList(app)
            if isempty(app.MarkedPositions.Labels)
                app.BookmarkControls.PositionList.Items = {};
                app.BookmarkControls.GoToButton.Enable = 'off';
                app.BookmarkControls.DeleteButton.Enable = 'off';
                return;
            end
            
            % Format bookmark items
            items = arrayfun(@(i) sprintf('%-12s %7.1f μm', ...
                app.MarkedPositions.Labels{i}, ...
                app.MarkedPositions.Positions(i)), ...
                1:length(app.MarkedPositions.Labels), ...
                'UniformOutput', false);
            
            app.BookmarkControls.PositionList.Items = items;
            
            % Update button states
            hasSelection = ~isempty(app.BookmarkControls.PositionList.Value);
            app.BookmarkControls.GoToButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
            app.BookmarkControls.DeleteButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
        end
        
        function updateControlStates(app)
            if app.IsAutoRunning
                disableManualControls(app);
                updateAutoStepButton(app, true);
            else
                enableManualControls(app);
                updateAutoStepButton(app, false);
            end
        end
        
        function disableManualControls(app)
            app.ManualControls.UpButton.Enable = 'off';
            app.ManualControls.DownButton.Enable = 'off';
            app.ManualControls.ZeroButton.Enable = 'off';
            app.ManualControls.StepSizeDropdown.Enable = 'off';
            
            app.AutoControls.StepField.Enable = 'off';
            app.AutoControls.StepsField.Enable = 'off';
            app.AutoControls.DelayField.Enable = 'off';
            app.AutoControls.UpButton.Enable = 'off';
            app.AutoControls.DownButton.Enable = 'off';
        end
        
        function enableManualControls(app)
            app.ManualControls.UpButton.Enable = 'on';
            app.ManualControls.DownButton.Enable = 'on';
            app.ManualControls.ZeroButton.Enable = 'on';
            app.ManualControls.StepSizeDropdown.Enable = 'on';
            
            app.AutoControls.StepField.Enable = 'on';
            app.AutoControls.StepsField.Enable = 'on';
            app.AutoControls.DelayField.Enable = 'on';
            app.AutoControls.UpButton.Enable = 'on';
            app.AutoControls.DownButton.Enable = 'on';
        end
        
        function updateAutoStepButton(app, isRunning)
            if isRunning
                app.AutoControls.StartStopButton.Text = 'STOP';
                app.AutoControls.StartStopButton.BackgroundColor = app.COLORS.Danger;
            else
                app.AutoControls.StartStopButton.Text = 'START';
                app.AutoControls.StartStopButton.BackgroundColor = app.COLORS.Success;
            end
        end
    end
    
    %% Event Handlers
    methods (Access = private)
        % Manual Control Events
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
        
        function onStepSizeChanged(app, event)
            stepValue = str2double(extractBefore(event.Value, ' μm'));
            app.AutoControls.StepField.Value = stepValue;
        end
        
        % Auto Step Events
        function onAutoStepSizeChanged(app, event)
            newStepSize = event.Value;
            [~, idx] = min(abs(app.STEP_SIZES - newStepSize));
            app.ManualControls.StepSizeDropdown.Value = ...
                sprintf('%.1f μm', app.STEP_SIZES(idx));
        end
        
        function onAutoDirectionChanged(app, event)
            if event.Source == app.AutoControls.UpButton
                app.AutoDirection = 1;
                app.AutoControls.UpButton.BackgroundColor = app.COLORS.Success;
                app.AutoControls.DownButton.BackgroundColor = app.COLORS.Light;
            else
                app.AutoDirection = -1;
                app.AutoControls.UpButton.BackgroundColor = app.COLORS.Light;
                app.AutoControls.DownButton.BackgroundColor = app.COLORS.Warning;
            end
        end
        
        function onStartStopButtonPushed(app, ~)
            if app.IsAutoRunning
                stopAutoStepping(app);
            else
                startAutoStepping(app);
            end
        end
        
        % Bookmark Events
        function onMarkButtonPushed(app, ~)
            label = strtrim(app.BookmarkControls.MarkField.Value);
            markCurrentPosition(app, label);
            app.BookmarkControls.MarkField.Value = '';
        end
        
        function onGoToButtonPushed(app, ~)
            index = getSelectedBookmarkIndex(app);
            if ~isempty(index)
                goToMarkedPosition(app, index);
            end
        end
        
        function onDeleteButtonPushed(app, ~)
            index = getSelectedBookmarkIndex(app);
            if ~isempty(index)
                deleteMarkedPosition(app, index);
            end
        end
        
        function onPositionListChanged(app, ~)
            updateBookmarksList(app);
        end
        
        % System Events
        function onRefreshButtonPushed(app, ~)
            connectToScanImage(app);
            updateAllUI(app);
        end
        
        function onWindowClose(app, ~)
            cleanup(app);
            delete(app);
        end
    end
    
    %% Helper Methods
    methods (Access = private)
        function stepSize = getSelectedStepSize(app)
            idx = strcmp(app.ManualControls.StepSizeDropdown.Value, ...
                app.ManualControls.StepSizeDropdown.Items);
            stepSize = app.STEP_SIZES(idx);
        end
        
        function showError(app, message)
            uialert(app.UIFigure, message, 'Invalid Parameter');
        end
        
        function stopTimer(app, timer)
            if ~isempty(timer) && isvalid(timer)
                stop(timer);
                delete(timer);
            end
        end
        
        function cleanup(app)
            % Stop auto-stepping
            if app.IsAutoRunning
                stopAutoStepping(app);
            end
            
            % Stop timers
            stopTimer(app, app.RefreshTimer);
            app.RefreshTimer = [];
            
            % Clean up any other timers
            allTimers = timerfindall;
            for timer = allTimers'
                if isvalid(timer)
                    stop(timer);
                    delete(timer);
                end
            end
        end
        
        function deleteUIFigure(app)
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
end