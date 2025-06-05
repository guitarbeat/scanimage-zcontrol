classdef HybridZControlGUI < handle
    % HybridZControlGUI - GUI for controlling Z position using ScanImage or direct hardware
    % This class encapsulates the GUI previously implemented as a script in
    % launchHybridZControlGUI.m. All callbacks are implemented as methods and the
    % GUI is created during object construction.

    properties
        hFig                % Figure handle
        handles struct       % Struct storing UI handles and state
        updateTimer          % Timer for updating position display
        movementTimer        % Timer for monitoring movement status
        scanTimer            % Timer for direct hardware scanning
    end

    methods
        function obj = HybridZControlGUI
            % Verify ScanImage is running
            try
                evalin('base', 'hSI;');
            catch
                errordlg('ScanImage must be running. Please start ScanImage first.', ...
                         'ScanImage Not Found');
                return;
            end

            % Create GUI
            obj.buildGUI();

            % Initialize handles
            obj.handles.zControl = [];
            obj.handles.statusMessages = {};
            obj.handles.maxStatusMessages = 100;
            obj.handles.useDirectHardwareControl = true;

            % Initialize control object
            obj.initializeZControl();
        end

        function delete(obj)
            if isvalid(obj.hFig)
                obj.onClose();
            end
        end
    end

    methods (Access = private)
        function buildGUI(obj)
            obj.hFig = figure('Name', 'ScanImage Z Control', ...
                'NumberTitle', 'off', ...
                'Position', [100, 100, 500, 600], ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'CloseRequestFcn', @(~,~) obj.onClose());

            hControlPanel = uipanel(obj.hFig, 'Title', 'Z Movement Controls', ...
                'Position', [0.05, 0.75, 0.9, 0.2]);
            hAutoPanel = uipanel(obj.hFig, 'Title', 'Automated Z Scanning', ...
                'Position', [0.05, 0.5, 0.9, 0.2]);
            hConfigPanel = uipanel(obj.hFig, 'Title', 'Configuration', ...
                'Position', [0.05, 0.3, 0.9, 0.15]);
            hStatusPanel = uipanel(obj.hFig, 'Title', 'Status', ...
                'Position', [0.05, 0.05, 0.9, 0.2]);

            obj.createManualControls(hControlPanel);
            obj.createAutoControls(hAutoPanel);
            obj.createConfigControls(hConfigPanel);

            obj.handles.hStatusText = uicontrol(hStatusPanel, 'Style', 'edit', ...
                'Position', [10, 10, 430, 80], 'Max', 2, 'Min', 0, ...
                'HorizontalAlignment', 'left', 'Enable', 'inactive', ...
                'FontName', 'Consolas', 'FontSize', 9, ...
                'String', 'Initializing Z control...');
        end

        function createManualControls(obj, hPanel)
            uicontrol(hPanel, 'Style', 'text', 'String', 'Current Z Position:', ...
                'Position', [20, 80, 150, 20], 'HorizontalAlignment', 'left');

            obj.handles.hCurrentZ = uicontrol(hPanel, 'Style', 'text', ...
                'String', '0.00 \x03BCm', 'Position', [180, 80, 150, 20], ...
                'HorizontalAlignment', 'left', 'FontWeight', 'bold');

            uicontrol(hPanel, 'Style', 'text', 'String', 'Step Size (\x03BCm):', ...
                'Position', [20, 50, 150, 20], 'HorizontalAlignment', 'left');

            obj.handles.hStepSize = uicontrol(hPanel, 'Style', 'edit', ...
                'String', '1.0', 'Position', [180, 50, 60, 20], ...
                'Callback', @(src,~) obj.onStepSizeChanged(src));

            obj.handles.hMoveUpButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
                'String', '\x25B2 Move Up', 'Position', [20, 15, 100, 30], ...
                'Callback', @(~,~) obj.onMoveUp());

            obj.handles.hMoveDownButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
                'String', '\x25BC Move Down', 'Position', [130, 15, 100, 30], ...
                'Callback', @(~,~) obj.onMoveDown());

            obj.handles.hUpdateButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
                'String', 'Update Position', 'Position', [240, 15, 100, 30], ...
                'Callback', @(~,~) obj.onUpdatePosition());

            uicontrol(hPanel, 'Style', 'text', 'String', 'Go to Z:', ...
                'Position', [350, 50, 60, 20], 'HorizontalAlignment', 'left');

            obj.handles.hGotoZ = uicontrol(hPanel, 'Style', 'edit', 'String', '0.0', ...
                'Position', [410, 50, 60, 20]);
            obj.handles.hGotoButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
                'String', 'Go', 'Position', [350, 15, 120, 30], ...
                'Callback', @(~,~) obj.onGotoPosition());
        end

        function createAutoControls(obj, hPanel)
            uicontrol(hPanel, 'Style', 'text', 'String', 'Number of Steps:', ...
                'Position', [20, 80, 150, 20], 'HorizontalAlignment', 'left');
            obj.handles.hNumSteps = uicontrol(hPanel, 'Style', 'edit', ...
                'String', '10', 'Position', [180, 80, 60, 20]);

            uicontrol(hPanel, 'Style', 'text', 'String', 'Delay Between Steps (s):', ...
                'Position', [20, 50, 150, 20], 'HorizontalAlignment', 'left');
            obj.handles.hDelay = uicontrol(hPanel, 'Style', 'edit', ...
                'String', '0.5', 'Position', [180, 50, 60, 20]);

            obj.handles.hDirUp = uicontrol(hPanel, 'Style', 'radiobutton', ...
                'String', 'Move Up', 'Position', [20, 20, 80, 20], 'Value', 1);
            obj.handles.hDirDown = uicontrol(hPanel, 'Style', 'radiobutton', ...
                'String', 'Move Down', 'Position', [110, 20, 90, 20], 'Value', 0);

            bg = uibuttongroup('Visible', 'off', 'Position', [0 0 1 1], ...
                'Parent', hPanel);
            set(obj.handles.hDirUp, 'Parent', bg);
            set(obj.handles.hDirDown, 'Parent', bg);
            set(bg, 'Visible', 'on');
            obj.handles.buttonGroup = bg;

            obj.handles.hStartButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
                'String', 'Start Scan', 'Position', [250, 65, 120, 30], ...
                'Callback', @(~,~) obj.onStartScan());
            obj.handles.hStopButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
                'String', 'Stop', 'Position', [250, 20, 120, 30], ...
                'Enable', 'off', 'Callback', @(~,~) obj.onStopScan());
            obj.handles.hReturnButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
                'String', 'Return to Start', 'Position', [380, 20, 100, 30], ...
                'Callback', @(~,~) obj.onReturnToStart());
        end

        function createConfigControls(obj, hPanel)
            uicontrol(hPanel, 'Style', 'text', 'String', 'Z Control Method:', ...
                'Position', [20, 50, 150, 20], 'HorizontalAlignment', 'left');
            obj.handles.hDirectControl = uicontrol(hPanel, 'Style', 'radiobutton', ...
                'String', 'Direct Hardware Control', 'Position', [180, 50, 150, 20], ...
                'Value', 1, 'Tag', 'directControl');
            obj.handles.hScanImageControl = uicontrol(hPanel, 'Style', 'radiobutton', ...
                'String', 'ScanImage API', 'Position', [340, 50, 120, 20], ...
                'Value', 0, 'Tag', 'siControl');
            bgControl = uibuttongroup('Visible', 'off', 'Position', [0 0 1 1], ...
                'Parent', hPanel, 'SelectionChangedFcn', @(src,evt) obj.onControlMethodChanged(evt));
            set(obj.handles.hDirectControl, 'Parent', bgControl);
            set(obj.handles.hScanImageControl, 'Parent', bgControl);
            set(bgControl, 'Visible', 'on');
            obj.handles.bgControl = bgControl;

            uicontrol(hPanel, 'Style', 'text', 'String', 'Debug Level:', ...
                'Position', [20, 20, 150, 20], 'HorizontalAlignment', 'left');
            obj.handles.hDebugLevel = uicontrol(hPanel, 'Style', 'popupmenu', ...
                'String', {'0 - Minimal','1 - Normal','2 - Verbose'}, ...
                'Position', [180, 20, 150, 20], 'Value', 2, ...
                'Callback', @(src,~) obj.onDebugLevelChanged(src));
        end

        function initializeZControl(obj)
            statusCallback = @(msg) obj.updateStatusText(msg);
            try
                if obj.handles.useDirectHardwareControl
                    obj.updateStatusText('Initializing direct hardware Z control...');
                    obj.handles.zControl = ThorlabsZControl();
                    obj.handles.zControl.debugLevel = 2;
                    if obj.handles.zControl.isConnected
                        obj.updateStatusText('Successfully connected to Thorlabs Z motor.');
                        obj.updateZPositionDisplay();
                    else
                        obj.updateStatusText('Failed to connect to Thorlabs Z motor. Check hardware connection.');
                    end
                else
                    obj.updateStatusText('Initializing ScanImage API Z control...');
                    obj.handles.zControl = SIZControl(statusCallback);
                    obj.updateZPositionDisplay();
                end

                obj.updateTimer = timer('Period',1.0,'ExecutionMode','fixedRate', ...
                    'TimerFcn', @(~,~) obj.updateZPositionDisplay());
                start(obj.updateTimer);
            catch ME
                obj.updateStatusText(['Error initializing Z control: ' ME.message]);
            end
        end

        function updateZPositionDisplay(obj)
            if isempty(obj.handles.zControl)
                return;
            end
            try
                if obj.handles.useDirectHardwareControl
                    z = obj.handles.zControl.getCurrentPosition();
                else
                    z = obj.handles.zControl.getCurrentZPosition();
                end
                set(obj.handles.hCurrentZ, 'String', sprintf('%.2f \x03BCm', z));
            catch
            end
        end

        function onStepSizeChanged(obj, src)
            if isempty(obj.handles.zControl)
                return;
            end
            stepSize = str2double(get(src,'String'));
            if isnan(stepSize) || stepSize <= 0
                set(src,'String','1.0');
                stepSize = 1.0;
            end
            if ~obj.handles.useDirectHardwareControl
                obj.handles.zControl.stepSize = stepSize;
            end
            obj.updateStatusText(sprintf('Step size set to %.2f \x03BCm', stepSize));
        end

        function onMoveUp(obj)
            if isempty(obj.handles.zControl)
                return;
            end
            stepSize = str2double(get(obj.handles.hStepSize,'String'));
            if obj.handles.useDirectHardwareControl
                obj.handles.zControl.moveRelative(stepSize);
            else
                obj.handles.zControl.moveUp();
            end
            obj.updateZPositionDisplay();
        end

        function onMoveDown(obj)
            if isempty(obj.handles.zControl)
                return;
            end
            stepSize = str2double(get(obj.handles.hStepSize,'String'));
            if obj.handles.useDirectHardwareControl
                obj.handles.zControl.moveRelative(-stepSize);
            else
                obj.handles.zControl.moveDown();
            end
            obj.updateZPositionDisplay();
        end

        function onUpdatePosition(obj)
            obj.updateZPositionDisplay();
        end

        function onGotoPosition(obj)
            if isempty(obj.handles.zControl)
                return;
            end
            targetZ = str2double(get(obj.handles.hGotoZ,'String'));
            if isnan(targetZ)
                obj.updateStatusText('Invalid Z position. Please enter a number.');
                return;
            end
            obj.updateStatusText(sprintf('Moving to Z position: %.2f \x03BCm', targetZ));
            if obj.handles.useDirectHardwareControl
                obj.handles.zControl.moveAbsolute(targetZ);
            else
                obj.handles.zControl.absoluteMove(targetZ);
            end
            obj.updateZPositionDisplay();
        end

        function onStartScan(obj)
            if isempty(obj.handles.zControl)
                return;
            end
            numSteps = str2double(get(obj.handles.hNumSteps,'String'));
            delay = str2double(get(obj.handles.hDelay,'String'));
            direction = 1;
            if get(obj.handles.hDirDown,'Value') == 1
                direction = -1;
            end
            if isnan(numSteps) || numSteps <= 0
                set(obj.handles.hNumSteps,'String','10');
                numSteps = 10;
            end
            if isnan(delay) || delay < 0.1
                set(obj.handles.hDelay,'String','0.5');
                delay = 0.5;
            end
            if obj.handles.useDirectHardwareControl
                obj.handles.scanParams = struct();
                obj.handles.scanParams.numSteps = numSteps;
                obj.handles.scanParams.delay = delay;
                obj.handles.scanParams.direction = direction;
                obj.handles.scanParams.currentStep = 0;
                obj.handles.scanParams.startZ = obj.handles.zControl.getCurrentPosition();
                obj.handles.scanParams.stepSize = str2double(get(obj.handles.hStepSize,'String'));
                obj.handles.scanParams.isRunning = true;
                dirStr = 'up';
                if direction <= 0
                    dirStr = 'down';
                end
                obj.updateStatusText(sprintf('Starting Z scan: %d steps of %.2f \x03BCm %s', ...
                    numSteps, obj.handles.scanParams.stepSize, dirStr));
                obj.scanTimer = timer('Period', delay, 'ExecutionMode', 'fixedRate', ...
                    'TimerFcn', @(~,~) obj.performNextStep());
                start(obj.scanTimer);
            else
                obj.handles.zControl.numSteps = numSteps;
                obj.handles.zControl.delayBetweenSteps = delay;
                obj.handles.zControl.direction = direction;
                obj.handles.zControl.startZMovement();
            end
            set(obj.handles.hStartButton,'Enable','off');
            set(obj.handles.hStopButton,'Enable','on');
            obj.movementTimer = timer('Period', 0.5, 'ExecutionMode', 'fixedRate', ...
                'TimerFcn', @(~,~) obj.checkMovementStatus());
            start(obj.movementTimer);
        end

        function performNextStep(obj)
            if ~isfield(obj.handles,'scanParams') || ~obj.handles.scanParams.isRunning
                return;
            end
            if obj.handles.scanParams.currentStep >= obj.handles.scanParams.numSteps
                obj.updateStatusText('Z scan complete.');
                obj.handles.scanParams.isRunning = false;
                if ~isempty(obj.scanTimer) && isvalid(obj.scanTimer)
                    stop(obj.scanTimer); delete(obj.scanTimer);
                end
                return;
            end
            obj.handles.scanParams.currentStep = obj.handles.scanParams.currentStep + 1;
            distance = obj.handles.scanParams.direction * obj.handles.scanParams.stepSize;
            obj.updateStatusText(sprintf('Step %d/%d: Moving by %.2f \x03BCm', ...
                obj.handles.scanParams.currentStep, obj.handles.scanParams.numSteps, distance));
            obj.handles.zControl.moveRelative(distance);
            obj.updateZPositionDisplay();
        end

        function onStopScan(obj)
            if isempty(obj.handles.zControl)
                return;
            end
            if obj.handles.useDirectHardwareControl
                if isfield(obj.handles,'scanParams')
                    obj.handles.scanParams.isRunning = false;
                end
                if ~isempty(obj.scanTimer) && isvalid(obj.scanTimer)
                    stop(obj.scanTimer); delete(obj.scanTimer);
                end
            else
                obj.handles.zControl.stopZMovement();
            end
            obj.updateStatusText('Z scan stopped.');
            set(obj.handles.hStartButton,'Enable','on');
            set(obj.handles.hStopButton,'Enable','off');
            if ~isempty(obj.movementTimer) && isvalid(obj.movementTimer)
                stop(obj.movementTimer); delete(obj.movementTimer);
            end
        end

        function onReturnToStart(obj)
            if isempty(obj.handles.zControl)
                return;
            end
            if obj.handles.useDirectHardwareControl
                if isfield(obj.handles,'scanParams') && isfield(obj.handles.scanParams,'startZ')
                    obj.updateStatusText(sprintf('Returning to starting position: %.2f \x03BCm', obj.handles.scanParams.startZ));
                    obj.handles.zControl.moveAbsolute(obj.handles.scanParams.startZ);
                else
                    obj.updateStatusText('No starting position recorded.');
                end
            else
                obj.handles.zControl.returnToStart();
            end
            obj.updateZPositionDisplay();
        end

        function checkMovementStatus(obj)
            if isempty(obj.handles.zControl)
                return;
            end
            isRunning = false;
            if obj.handles.useDirectHardwareControl
                if isfield(obj.handles,'scanParams')
                    isRunning = obj.handles.scanParams.isRunning;
                end
            else
                isRunning = obj.handles.zControl.isRunning;
            end
            if ~isRunning
                set(obj.handles.hStartButton,'Enable','on');
                set(obj.handles.hStopButton,'Enable','off');
                if ~isempty(obj.movementTimer) && isvalid(obj.movementTimer)
                    stop(obj.movementTimer); delete(obj.movementTimer);
                end
            end
            obj.updateZPositionDisplay();
        end

        function onControlMethodChanged(obj, evt)
            selected = evt.NewValue;
            obj.handles.useDirectHardwareControl = strcmp(get(selected,'Tag'),'directControl');
            if obj.handles.useDirectHardwareControl
                obj.updateStatusText('Switching to direct hardware control...');
            else
                obj.updateStatusText('Switching to ScanImage API control...');
            end
            if ~isempty(obj.handles.zControl)
                try
                    delete(obj.handles.zControl);
                catch
                end
                obj.handles.zControl = [];
            end
            obj.initializeZControl();
        end

        function onDebugLevelChanged(obj, src)
            if isempty(obj.handles.zControl)
                return;
            end
            levels = [0 1 2];
            selectedLevel = levels(get(src,'Value'));
            if obj.handles.useDirectHardwareControl
                obj.handles.zControl.debugLevel = selectedLevel;
            end
            obj.updateStatusText(sprintf('Debug level set to %d', selectedLevel));
        end

        function updateStatusText(obj, message)
            timestamp = datestr(now,'HH:MM:SS');
            fullMessage = sprintf('[%s] %s', timestamp, message);
            obj.handles.statusMessages{end+1} = fullMessage;
            if numel(obj.handles.statusMessages) > obj.handles.maxStatusMessages
                obj.handles.statusMessages = obj.handles.statusMessages(end-obj.handles.maxStatusMessages+1:end);
            end
            set(obj.handles.hStatusText,'String', strjoin(obj.handles.statusMessages, '\n'));
            drawnow;
        end

        function onClose(obj)
            if ~isempty(obj.updateTimer) && isvalid(obj.updateTimer)
                stop(obj.updateTimer); delete(obj.updateTimer);
            end
            if ~isempty(obj.movementTimer) && isvalid(obj.movementTimer)
                stop(obj.movementTimer); delete(obj.movementTimer);
            end
            if ~isempty(obj.scanTimer) && isvalid(obj.scanTimer)
                stop(obj.scanTimer); delete(obj.scanTimer);
            end
            if isfield(obj.handles,'zControl') && ~isempty(obj.handles.zControl)
                try
                    delete(obj.handles.zControl);
                catch
                end
            end
            if ishandle(obj.hFig)
                delete(obj.hFig);
            end
        end
    end
end
