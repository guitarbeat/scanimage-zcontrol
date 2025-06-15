classdef ZStageControlApp < matlab.apps.AppBase
    % ZStageControlApp - A comprehensive Z-stage positioning control interface
    % Provides manual control, automated stepping, and position marking functionality
    
    % UI Component Properties
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainPanel                   matlab.ui.container.Panel
        
        % Position Display Components
        PositionPanel               matlab.ui.container.Panel
        CurrentPositionLabel        matlab.ui.control.Label
        UnitsLabel                  matlab.ui.control.Label
        StatusLabel                 matlab.ui.control.Label
        
        % Manual Control Components
        ManualPanel                 matlab.ui.container.Panel
        Up1Button                   matlab.ui.control.Button
        Up10Button                  matlab.ui.control.Button
        ZeroButton                  matlab.ui.control.Button
        Down10Button                matlab.ui.control.Button
        Down1Button                 matlab.ui.control.Button
        
        % Auto Step Components
        AutoPanel                   matlab.ui.container.Panel
        StepSizeField               matlab.ui.control.NumericEditField
        RestTimeField               matlab.ui.control.NumericEditField
        NumStepsField               matlab.ui.control.NumericEditField
        UpDirectionButton           matlab.ui.control.StateButton
        DownDirectionButton         matlab.ui.control.StateButton
        StartButton                 matlab.ui.control.Button
        StopButton                  matlab.ui.control.Button
        ProgressBar                 matlab.ui.control.LinearGauge
        
        % Position Marking Components
        MarkPanel                   matlab.ui.container.Panel
        LabelField                  matlab.ui.control.EditField
        MarkButton                  matlab.ui.control.Button
        PositionList                matlab.ui.control.ListBox
        GoButton                    matlab.ui.control.Button
        DeleteButton                matlab.ui.control.Button
    end

    % Application State Properties
    properties (Access = private)
        % Position tracking
        CurrentPosition (1,1) double = 0    % Current stage position in microns
        
        % Auto-stepping state
        IsAutoRunning (1,1) logical = false % Auto-stepping active flag
        AutoTimer                           % Timer for auto-stepping
        CurrentStep (1,1) double = 0        % Current step counter
        TotalSteps (1,1) double = 0         % Total steps to execute
        
        % Position marking
        MarkedPositions = struct('Labels', {{}}, 'Positions', [])
    end
    
    % Constants
    properties (Constant, Access = private)
        % UI Layout Constants
        WINDOW_WIDTH = 320
        WINDOW_HEIGHT = 550
        PANEL_MARGIN = 5
        BUTTON_HEIGHT = 25
        FIELD_HEIGHT = 20
        
        % Movement Constants
        SMALL_STEP = 1      % Small step size in microns
        LARGE_STEP = 10     % Large step size in microns
        
        % Default Auto-stepping Parameters
        DEFAULT_STEP_SIZE = 30
        DEFAULT_REST_TIME = 0.5
        DEFAULT_NUM_STEPS = 10
        
        % Colors
        COLORS = struct(...
            'Background', [0.94 0.94 0.94], ...
            'Panel', [0.98 0.98 0.98], ...
            'Position', [0.9 0.95 1], ...
            'PositionBorder', [0.6 0.8 1], ...
            'PositionText', [0 0.3 0.7], ...
            'UpButton', [0.9 1 0.9], ...
            'DownButton', [1 0.9 0.9], ...
            'ZeroButton', [1 1 0.9], ...
            'StartButton', [0.2 0.8 0.2], ...
            'StopButton', [0.8 0.2 0.2], ...
            'MarkButton', [0.9 0.9 1], ...
            'GoButton', [0.9 1 0.9], ...
            'DeleteButton', [1 0.9 0.9])
    end

    %% Constructor and Destructor
    methods (Access = public)
        function app = ZStageControlApp()
            % Constructor - Initialize the application
            createComponents(app);
            initializeDefaults(app);
            registerApp(app, app.UIFigure);
            
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            % Destructor - Clean up resources
            cleanup(app);
            delete(app.UIFigure);
        end
    end

    %% Component Creation Methods
    methods (Access = private)
        function createComponents(app)
            % Create all UI components
            createMainWindow(app);
            createPositionPanel(app);
            createManualControlPanel(app);
            createAutoStepPanel(app);
            createMarkPositionPanel(app);
            
            app.UIFigure.Visible = 'on';
        end
        
        function createMainWindow(app)
            % Create main window and container
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 app.WINDOW_WIDTH app.WINDOW_HEIGHT];
            app.UIFigure.Name = 'Z-Stage Control';
            app.UIFigure.Color = app.COLORS.Background;
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @onWindowClose, true);

            app.MainPanel = uipanel(app.UIFigure);
            app.MainPanel.Position = [app.PANEL_MARGIN app.PANEL_MARGIN ...
                app.WINDOW_WIDTH-2*app.PANEL_MARGIN app.WINDOW_HEIGHT-2*app.PANEL_MARGIN];
            app.MainPanel.BorderType = 'none';
            app.MainPanel.BackgroundColor = app.COLORS.Background;
        end
        
        function createPositionPanel(app)
            % Create position display panel
            panelWidth = app.WINDOW_WIDTH - 2*app.PANEL_MARGIN;
            app.PositionPanel = uipanel(app.MainPanel);
            app.PositionPanel.Position = [app.PANEL_MARGIN 460 panelWidth 75];
            app.PositionPanel.Title = 'Current Position';
            app.PositionPanel.FontWeight = 'bold';
            app.PositionPanel.BackgroundColor = app.COLORS.Position;
            app.PositionPanel.BorderColor = app.COLORS.PositionBorder;

            % Position value display
            app.CurrentPositionLabel = uilabel(app.PositionPanel);
            app.CurrentPositionLabel.Text = '0.0';
            app.CurrentPositionLabel.FontSize = 28;
            app.CurrentPositionLabel.FontWeight = 'bold';
            app.CurrentPositionLabel.FontName = 'Courier New';
            app.CurrentPositionLabel.HorizontalAlignment = 'center';
            app.CurrentPositionLabel.Position = [10 25 panelWidth-20 35];
            app.CurrentPositionLabel.FontColor = app.COLORS.PositionText;

            % Units label
            app.UnitsLabel = uilabel(app.PositionPanel);
            app.UnitsLabel.Text = 'μm';
            app.UnitsLabel.FontSize = 11;
            app.UnitsLabel.HorizontalAlignment = 'center';
            app.UnitsLabel.Position = [10 10 panelWidth-20 15];
            app.UnitsLabel.FontColor = [0.5 0.5 0.5];

            % Status label
            app.StatusLabel = uilabel(app.PositionPanel);
            app.StatusLabel.Text = '';
            app.StatusLabel.FontSize = 9;
            app.StatusLabel.HorizontalAlignment = 'center';
            app.StatusLabel.Position = [10 0 panelWidth-20 10];
            app.StatusLabel.FontColor = [0.7 0.7 0.7];
        end
        
        function createManualControlPanel(app)
            % Create manual control panel with movement buttons
            panelWidth = app.WINDOW_WIDTH - 2*app.PANEL_MARGIN;
            app.ManualPanel = uipanel(app.MainPanel);
            app.ManualPanel.Position = [app.PANEL_MARGIN 395 panelWidth 60];
            app.ManualPanel.Title = 'Manual Control';
            app.ManualPanel.FontWeight = 'bold';
            app.ManualPanel.BackgroundColor = app.COLORS.Panel;

            % Calculate button layout
            buttonWidth = 50;
            spacing = 8;
            totalButtonWidth = 5 * buttonWidth + 4 * spacing;
            startX = (panelWidth - totalButtonWidth) / 2;

            % Create movement buttons
            buttons = {
                {'Up1Button', '↑1', app.COLORS.UpButton, @onUp1ButtonPushed}, ...
                {'Up10Button', '↑10', app.COLORS.UpButton, @onUp10ButtonPushed}, ...
                {'ZeroButton', '⊙', app.COLORS.ZeroButton, @onZeroButtonPushed}, ...
                {'Down10Button', '↓10', app.COLORS.DownButton, @onDown10ButtonPushed}, ...
                {'Down1Button', '↓1', app.COLORS.DownButton, @onDown1ButtonPushed}
            };
            
            for i = 1:length(buttons)
                buttonInfo = buttons{i};
                propName = buttonInfo{1};
                text = buttonInfo{2};
                color = buttonInfo{3};
                callback = buttonInfo{4};
                
                app.(propName) = uibutton(app.ManualPanel, 'push');
                app.(propName).Text = text;
                app.(propName).Position = [startX + (i-1)*(buttonWidth + spacing) 15 buttonWidth app.BUTTON_HEIGHT];
                app.(propName).ButtonPushedFcn = createCallbackFcn(app, callback, true);
                app.(propName).BackgroundColor = color;
                
                if strcmp(propName, 'ZeroButton')
                    app.(propName).FontWeight = 'bold';
                end
            end
        end
        
        function createAutoStepPanel(app)
            % Create automated stepping control panel
            panelWidth = app.WINDOW_WIDTH - 2*app.PANEL_MARGIN;
            app.AutoPanel = uipanel(app.MainPanel);
            app.AutoPanel.Position = [app.PANEL_MARGIN 250 panelWidth 140];
            app.AutoPanel.Title = 'Automated Stepping';
            app.AutoPanel.FontWeight = 'bold';
            app.AutoPanel.BackgroundColor = app.COLORS.Panel;

            createAutoStepParameters(app);
            createAutoStepControls(app);
            createAutoStepProgress(app);
        end
        
        function createAutoStepParameters(app)
            % Create parameter input fields
            yPos = 105;
            
            % Step size
            uilabel(app.AutoPanel, 'Text', 'Step Size:', 'Position', [15 yPos 50 15], 'FontSize', 10);
            app.StepSizeField = uieditfield(app.AutoPanel, 'numeric');
            app.StepSizeField.Value = app.DEFAULT_STEP_SIZE;
            app.StepSizeField.Position = [70 yPos 45 app.FIELD_HEIGHT];
            app.StepSizeField.FontSize = 10;
            uilabel(app.AutoPanel, 'Text', 'μm', 'Position', [120 yPos 20 15], 'FontSize', 9);

            % Rest time
            uilabel(app.AutoPanel, 'Text', 'Rest Time:', 'Position', [150 yPos 50 15], 'FontSize', 10);
            app.RestTimeField = uieditfield(app.AutoPanel, 'numeric');
            app.RestTimeField.Value = app.DEFAULT_REST_TIME;
            app.RestTimeField.Position = [205 yPos 45 app.FIELD_HEIGHT];
            app.RestTimeField.FontSize = 10;
            uilabel(app.AutoPanel, 'Text', 's', 'Position', [255 yPos 15 15], 'FontSize', 9);

            % Number of steps
            uilabel(app.AutoPanel, 'Text', 'Steps:', 'Position', [15 80 40 15], 'FontSize', 10);
            app.NumStepsField = uieditfield(app.AutoPanel, 'numeric');
            app.NumStepsField.Value = app.DEFAULT_NUM_STEPS;
            app.NumStepsField.Position = [60 80 60 app.FIELD_HEIGHT];
            app.NumStepsField.FontSize = 10;
        end
        
        function createAutoStepControls(app)
            % Create direction and control buttons
            % Direction buttons
            app.UpDirectionButton = uibutton(app.AutoPanel, 'state');
            app.UpDirectionButton.Text = '↑ Up';
            app.UpDirectionButton.Value = true;
            app.UpDirectionButton.Position = [140 80 50 app.BUTTON_HEIGHT];
            app.UpDirectionButton.ValueChangedFcn = createCallbackFcn(app, @onDirectionChanged, true);
            app.UpDirectionButton.BackgroundColor = app.COLORS.UpButton;

            app.DownDirectionButton = uibutton(app.AutoPanel, 'state');
            app.DownDirectionButton.Text = '↓ Down';
            app.DownDirectionButton.Position = [195 80 55 app.BUTTON_HEIGHT];
            app.DownDirectionButton.ValueChangedFcn = createCallbackFcn(app, @onDirectionChanged, true);
            app.DownDirectionButton.BackgroundColor = app.COLORS.DownButton;

            % Start/Stop buttons
            app.StartButton = uibutton(app.AutoPanel, 'push');
            app.StartButton.Text = '▶ START';
            app.StartButton.Position = [15 50 80 app.BUTTON_HEIGHT];
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @onStartButtonPushed, true);
            app.StartButton.BackgroundColor = app.COLORS.StartButton;
            app.StartButton.FontColor = [1 1 1];
            app.StartButton.FontWeight = 'bold';

            app.StopButton = uibutton(app.AutoPanel, 'push');
            app.StopButton.Text = '⏹ STOP';
            app.StopButton.Position = [100 50 80 app.BUTTON_HEIGHT];
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @onStopButtonPushed, true);
            app.StopButton.BackgroundColor = app.COLORS.StopButton;
            app.StopButton.FontColor = [1 1 1];
            app.StopButton.FontWeight = 'bold';
            app.StopButton.Enable = 'off';
        end
        
        function createAutoStepProgress(app)
            % Create progress tracking components
            panelWidth = app.WINDOW_WIDTH - 2*app.PANEL_MARGIN;
            
            % Progress bar
            app.ProgressBar = uigauge(app.AutoPanel, 'linear');
            app.ProgressBar.Position = [15 25 panelWidth-30 15];
            app.ProgressBar.Limits = [0 100];
            app.ProgressBar.Value = 0;
            app.ProgressBar.FontSize = 8;

            % Progress labels
            uilabel(app.AutoPanel, 'Text', 'Progress:', 'Position', [15 5 50 15], 'FontSize', 9);
            uilabel(app.AutoPanel, 'Text', '0/0 steps', 'Position', [70 5 100 15], ...
                'FontSize', 9, 'Tag', 'StepCounter');
        end
        
        function createMarkPositionPanel(app)
            % Create position marking and management panel
            panelWidth = app.WINDOW_WIDTH - 2*app.PANEL_MARGIN;
            app.MarkPanel = uipanel(app.MainPanel);
            app.MarkPanel.Position = [app.PANEL_MARGIN 10 panelWidth 235];
            app.MarkPanel.Title = 'Position Bookmarks';
            app.MarkPanel.FontWeight = 'bold';
            app.MarkPanel.BackgroundColor = app.COLORS.Panel;

            % Label input and mark button
            app.LabelField = uieditfield(app.MarkPanel, 'text');
            app.LabelField.Placeholder = 'Enter position label...';
            app.LabelField.Position = [15 190 170 22];
            app.LabelField.FontSize = 10;

            app.MarkButton = uibutton(app.MarkPanel, 'push');
            app.MarkButton.Text = '📍 MARK';
            app.MarkButton.Position = [190 190 80 22];
            app.MarkButton.ButtonPushedFcn = createCallbackFcn(app, @onMarkButtonPushed, true);
            app.MarkButton.BackgroundColor = app.COLORS.MarkButton;
            app.MarkButton.FontSize = 9;
            app.MarkButton.FontWeight = 'bold';

            % Position list
            app.PositionList = uilistbox(app.MarkPanel);
            app.PositionList.Position = [15 50 panelWidth-30 135];
            app.PositionList.Items = {};
            app.PositionList.FontSize = 10;
            app.PositionList.FontName = 'Courier New';
            app.PositionList.ValueChangedFcn = createCallbackFcn(app, @onPositionListChanged, true);

            % Control buttons
            app.GoButton = uibutton(app.MarkPanel, 'push');
            app.GoButton.Text = '→ GO TO';
            app.GoButton.Position = [15 20 80 app.BUTTON_HEIGHT];
            app.GoButton.ButtonPushedFcn = createCallbackFcn(app, @onGoButtonPushed, true);
            app.GoButton.BackgroundColor = app.COLORS.GoButton;
            app.GoButton.FontWeight = 'bold';
            app.GoButton.Enable = 'off';

            app.DeleteButton = uibutton(app.MarkPanel, 'push');
            app.DeleteButton.Text = '🗑 DELETE';
            app.DeleteButton.Position = [panelWidth-95 20 80 app.BUTTON_HEIGHT];
            app.DeleteButton.ButtonPushedFcn = createCallbackFcn(app, @onDeleteButtonPushed, true);
            app.DeleteButton.BackgroundColor = app.COLORS.DeleteButton;
            app.DeleteButton.FontWeight = 'bold';
            app.DeleteButton.Enable = 'off';
        end
        
        function initializeDefaults(app)
            % Initialize default values and states
            updatePositionDisplay(app);
            updatePositionsList(app);
        end
    end

    %% Core Functionality Methods
    methods (Access = private)
        function moveStage(app, microns)
            % Move stage by specified amount and update display
            app.CurrentPosition = app.CurrentPosition + microns;
            updatePositionDisplay(app);
            logMovement(app, microns);
        end
        
        function setPosition(app, position)
            % Set absolute position
            app.CurrentPosition = position;
            updatePositionDisplay(app);
            fprintf('Stage moved to position %.1f μm\n', position);
        end
        
        function resetPosition(app)
            % Reset position to zero
            app.CurrentPosition = 0;
            updatePositionDisplay(app);
            fprintf('Stage position reset to 0 μm\n');
        end
        
        function logMovement(app, displacement)
            % Log movement to command window
            direction = 'up';
            if displacement < 0
                direction = 'down';
            end
            fprintf('Stage moved %.1f μm %s to position %.1f μm\n', ...
                abs(displacement), direction, app.CurrentPosition);
        end
    end

    %% Auto-stepping Methods
    methods (Access = private)
        function startAutoStepping(app)
            % Start automated stepping sequence
            if app.IsAutoRunning || ~validateAutoStepParameters(app)
                return;
            end
            
            configureAutoStep(app);
            initializeAutoStepTimer(app);
            updateControlStates(app, true);
            
            fprintf('Auto-stepping started: %d steps of %.1f μm %s with %.1fs intervals\n', ...
                app.TotalSteps, abs(app.StepSizeField.Value), ...
                getDirectionString(app), app.RestTimeField.Value);
        end
        
        function stopAutoStepping(app)
            % Stop automated stepping sequence
            cleanupAutoStepTimer(app);
            app.IsAutoRunning = false;
            updatePositionDisplay(app);
            updateControlStates(app, false);
            
            fprintf('Auto-stepping completed at position %.1f μm (%d steps executed)\n', ...
                app.CurrentPosition, app.CurrentStep);
        end
        
        function valid = validateAutoStepParameters(app)
            % Validate auto-stepping parameters
            valid = true;
            
            if app.NumStepsField.Value <= 0
                uialert(app.UIFigure, 'Number of steps must be greater than 0', 'Invalid Input');
                valid = false;
                return;
            end
            
            if app.StepSizeField.Value <= 0
                uialert(app.UIFigure, 'Step size must be greater than 0', 'Invalid Input');
                valid = false;
                return;
            end
            
            if app.RestTimeField.Value < 0
                uialert(app.UIFigure, 'Rest time cannot be negative', 'Invalid Input');
                valid = false;
            end
        end
        
        function configureAutoStep(app)
            % Configure auto-stepping parameters
            app.IsAutoRunning = true;
            app.CurrentStep = 0;
            app.TotalSteps = app.NumStepsField.Value;
            updatePositionDisplay(app);
        end
        
        function initializeAutoStepTimer(app)
            % Initialize and start the auto-stepping timer
            stepSize = app.StepSizeField.Value;
            if app.DownDirectionButton.Value
                stepSize = -stepSize;
            end
            
            app.AutoTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', app.RestTimeField.Value, ...
                'TimerFcn', @(~,~) executeAutoStep(app, stepSize));
            
            start(app.AutoTimer);
        end
        
        function cleanupAutoStepTimer(app)
            % Clean up auto-stepping timer
            if ~isempty(app.AutoTimer) && isvalid(app.AutoTimer)
                stop(app.AutoTimer);
                delete(app.AutoTimer);
                app.AutoTimer = [];
            end
        end
        
        function executeAutoStep(app, stepSize)
            % Execute a single auto step
            app.CurrentStep = app.CurrentStep + 1;
            moveStage(app, stepSize);
            
            if app.CurrentStep >= app.TotalSteps
                stopAutoStepping(app);
            end
        end
        
        function dirStr = getDirectionString(app)
            % Get direction string for logging
            if app.UpDirectionButton.Value
                dirStr = 'up';
            else
                dirStr = 'down';
            end
        end
        
        function updateControlStates(app, isRunning)
            % Update control enable states based on auto-stepping status
            if isRunning
                app.StartButton.Enable = 'off';
                app.StopButton.Enable = 'on';
                setManualControlsEnabled(app, false);
            else
                app.StartButton.Enable = 'on';
                app.StopButton.Enable = 'off';
                setManualControlsEnabled(app, true);
            end
        end
        
        function setManualControlsEnabled(app, enabled)
            % Enable/disable manual controls
            enableState = matlab.lang.OnOffSwitchState(enabled);
            
            controls = {app.Up1Button, app.Up10Button, app.ZeroButton, ...
                       app.Down10Button, app.Down1Button};
            
            for i = 1:length(controls)
                controls{i}.Enable = enableState;
            end
        end
    end

    %% Position Management Methods
    methods (Access = private)
        function markCurrentPosition(app, label)
            % Mark current position with given label
            if isempty(strtrim(label))
                uialert(app.UIFigure, 'Please enter a label for this position', 'Input Required');
                return;
            end
            
            % Check for duplicate labels
            if any(strcmp(app.MarkedPositions.Labels, label))
                choice = uiconfirm(app.UIFigure, ...
                    sprintf('A position with label "%s" already exists. Replace it?', label), ...
                    'Duplicate Label', 'Options', {'Replace', 'Cancel'}, 'DefaultOption', 'Cancel');
                
                if strcmp(choice, 'Cancel')
                    return;
                end
                
                % Remove existing entry
                idx = strcmp(app.MarkedPositions.Labels, label);
                app.MarkedPositions.Labels(idx) = [];
                app.MarkedPositions.Positions(idx) = [];
            end
            
            % Add new marked position
            app.MarkedPositions.Labels{end+1} = label;
            app.MarkedPositions.Positions(end+1) = app.CurrentPosition;
            
            updatePositionsList(app);
            fprintf('Position marked: "%s" at %.1f μm\n', label, app.CurrentPosition);
        end
        
        function goToMarkedPosition(app, index)
            % Move to marked position by index
            if index < 1 || index > length(app.MarkedPositions.Positions)
                return;
            end
            
            if app.IsAutoRunning
                uialert(app.UIFigure, 'Cannot move while auto-stepping is active', 'Operation Not Allowed');
                return;
            end
            
            position = app.MarkedPositions.Positions(index);
            label = app.MarkedPositions.Labels{index};
            setPosition(app, position);
            fprintf('Moved to marked position "%s": %.1f μm\n', label, position);
        end
        
        function deleteMarkedPosition(app, index)
            % Delete marked position by index
            if index < 1 || index > length(app.MarkedPositions.Labels)
                return;
            end
            
            label = app.MarkedPositions.Labels{index};
            app.MarkedPositions.Labels(index) = [];
            app.MarkedPositions.Positions(index) = [];
            
            updatePositionsList(app);
            fprintf('Deleted marked position: "%s"\n', label);
        end
        
        function index = getSelectedPositionIndex(app)
            % Get index of currently selected position in list
            index = [];
            if isempty(app.PositionList.Value)
                return;
            end
            
            index = find(strcmp(app.PositionList.Items, app.PositionList.Value), 1);
        end
    end

    %% Display Update Methods
    methods (Access = private)
        function updatePositionDisplay(app)
            % Update position display and status
            app.CurrentPositionLabel.Text = sprintf('%.1f', app.CurrentPosition);
            updateStatusDisplay(app);
            updateProgressDisplay(app);
        end
        
        function updateStatusDisplay(app)
            % Update status label based on current state
            if app.IsAutoRunning
                direction = getDirectionString(app);
                app.StatusLabel.Text = sprintf('Auto-stepping %s • %d/%d', ...
                    direction, app.CurrentStep, app.TotalSteps);
            else
                app.StatusLabel.Text = '';
            end
        end
        
        function updateProgressDisplay(app)
            % Update progress bar and step counter
            if app.IsAutoRunning && app.TotalSteps > 0
                progress = (app.CurrentStep / app.TotalSteps) * 100;
                app.ProgressBar.Value = progress;
                
                stepCounterLabel = findobj(app.AutoPanel, 'Tag', 'StepCounter');
                if ~isempty(stepCounterLabel)
                    stepCounterLabel.Text = sprintf('%d/%d steps', app.CurrentStep, app.TotalSteps);
                end
            else
                app.ProgressBar.Value = 0;
                stepCounterLabel = findobj(app.AutoPanel, 'Tag', 'StepCounter');
                if ~isempty(stepCounterLabel)
                    stepCounterLabel.Text = '0/0 steps';
                end
            end
        end
        
        function updatePositionsList(app)
            % Update the marked positions list display
            if isempty(app.MarkedPositions.Labels)
                app.PositionList.Items = {};
                app.GoButton.Enable = 'off';
                app.DeleteButton.Enable = 'off';
                return;
            end
            
            % Create formatted list items
            items = cell(length(app.MarkedPositions.Labels), 1);
            for i = 1:length(app.MarkedPositions.Labels)
                items{i} = sprintf('%-20s %8.1f μm', ...
                    app.MarkedPositions.Labels{i}, app.MarkedPositions.Positions(i));
            end
            
            app.PositionList.Items = items;
            
            % Update button states
            hasSelection = ~isempty(app.PositionList.Value);
            app.GoButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
            app.DeleteButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
        end
    end

    %% Event Callbacks
    methods (Access = private)
        % Manual control callbacks
        function onUp1ButtonPushed(app, ~)
            moveStage(app, app.SMALL_STEP);
        end

        function onUp10ButtonPushed(app, ~)
            moveStage(app, app.LARGE_STEP);
        end

        function onZeroButtonPushed(app, ~)
            resetPosition(app);
        end

        function onDown10ButtonPushed(app, ~)
            moveStage(app, -app.LARGE_STEP);
        end

        function onDown1ButtonPushed(app, ~)
            moveStage(app, -app.SMALL_STEP);
        end

        % Auto-stepping callbacks
        function onDirectionChanged(app, event)
            % Handle direction button state changes
            if event.Source == app.UpDirectionButton && event.Value
                app.DownDirectionButton.Value = false;
            elseif event.Source == app.DownDirectionButton && event.Value
                app.UpDirectionButton.Value = false;
            end
            
            % Ensure at least one direction is always selected
            if ~app.UpDirectionButton.Value && ~app.DownDirectionButton.Value
                event.Source.Value = true;
            end
        end

        function onStartButtonPushed(app, ~)
            startAutoStepping(app);
        end

        function onStopButtonPushed(app, ~)
            stopAutoStepping(app);
        end

        % Position marking callbacks
        function onMarkButtonPushed(app, ~)
            label = strtrim(app.LabelField.Value);
            markCurrentPosition(app, label);
            app.LabelField.Value = ''; % Clear input field
        end

        function onPositionListChanged(app, ~)
            % Update button states when list selection changes
            hasSelection = ~isempty(app.PositionList.Value);
            app.GoButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
            app.DeleteButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
        end

        function onGoButtonPushed(app, ~)
            index = getSelectedPositionIndex(app);
            if ~isempty(index)
                goToMarkedPosition(app, index);
            end
        end

        function onDeleteButtonPushed(app, ~)
            index = getSelectedPositionIndex(app);
            if ~isempty(index)
                deleteMarkedPosition(app, index);
            end
        end

        % Window callback
        function onWindowClose(app, ~)
            cleanup(app);
            delete(app);
        end
    end

    %% Utility Methods
    methods (Access = private)
        function cleanup(app)
            % Clean up resources before app deletion
            if app.IsAutoRunning
                stopAutoStepping(app);
            end
        end
    end
end