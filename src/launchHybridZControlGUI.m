function launchHybridZControlGUI
% launchHybridZControlGUI - Hybrid GUI for Z position control in ScanImage
%
% This script creates a user-friendly GUI for controlling Z position in ScanImage
% using both ScanImage API (where available) and direct Thorlabs Kinesis control.
%
% Usage:
%   Simply run this script in MATLAB after starting ScanImage
%
% Author: Manus AI (2025)

% Check if ScanImage is running
try
    hSI = evalin('base', 'hSI');
catch
    errordlg('ScanImage must be running. Please start ScanImage first.', 'ScanImage Not Found');
    return;
end

% Create the main figure
hFig = figure('Name', 'ScanImage Z Control', ...
    'NumberTitle', 'off', ...
    'Position', [100, 100, 500, 600], ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'CloseRequestFcn', @onClose);

% Create panels
hControlPanel = uipanel(hFig, 'Title', 'Z Movement Controls', ...
    'Position', [0.05, 0.75, 0.9, 0.2]);

hAutoPanel = uipanel(hFig, 'Title', 'Automated Z Scanning', ...
    'Position', [0.05, 0.5, 0.9, 0.2]);

hConfigPanel = uipanel(hFig, 'Title', 'Configuration', ...
    'Position', [0.05, 0.3, 0.9, 0.15]);

hStatusPanel = uipanel(hFig, 'Title', 'Status', ...
    'Position', [0.05, 0.05, 0.9, 0.2]);

% Create manual control elements
createManualControls(hControlPanel);

% Create automated scanning controls
createAutoControls(hAutoPanel);

% Create configuration controls
createConfigControls(hConfigPanel);

% Create status display
hStatusText = uicontrol(hStatusPanel, 'Style', 'edit', ...
    'Position', [10, 10, 430, 80], ...
    'Max', 2, 'Min', 0, ... % Make it multiline
    'HorizontalAlignment', 'left', ...
    'Enable', 'inactive', ... % Read-only but with normal appearance
    'FontName', 'Consolas', ... % Monospaced font
    'FontSize', 9, ...
    'String', 'Initializing Z control...');

% Store handles and data in figure's UserData
handles = struct();
handles.hStatusText = hStatusText;
handles.zControl = []; % Will hold the Z control object
handles.statusMessages = {};
handles.maxStatusMessages = 100;
handles.useDirectHardwareControl = true; % Default to direct hardware control
setappdata(hFig, 'handles', handles);

% Initialize Z control object with status callback
initializeZControl();

% Helper function to create manual control elements
function createManualControls(hPanel)
    % Current position display
    uicontrol(hPanel, 'Style', 'text', ...
        'String', 'Current Z Position:', ...
        'Position', [20, 80, 150, 20], ...
        'HorizontalAlignment', 'left');
    
    hCurrentZ = uicontrol(hPanel, 'Style', 'text', ...
        'String', '0.00 µm', ...
        'Position', [180, 80, 150, 20], ...
        'HorizontalAlignment', 'left', ...
        'FontWeight', 'bold', ...
        'Tag', 'currentZ');
    
    % Step size control
    uicontrol(hPanel, 'Style', 'text', ...
        'String', 'Step Size (µm):', ...
        'Position', [20, 50, 150, 20], ...
        'HorizontalAlignment', 'left');
    
    hStepSize = uicontrol(hPanel, 'Style', 'edit', ...
        'String', '1.0', ...
        'Position', [180, 50, 60, 20], ...
        'Tag', 'stepSize', ...
        'Callback', @onStepSizeChanged);
    
    % Movement buttons
    hMoveUpButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
        'String', '▲ Move Up', ...
        'Position', [20, 15, 100, 30], ...
        'Callback', @onMoveUp);
    
    hMoveDownButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
        'String', '▼ Move Down', ...
        'Position', [130, 15, 100, 30], ...
        'Callback', @onMoveDown);
    
    % Update position button
    hUpdateButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
        'String', 'Update Position', ...
        'Position', [240, 15, 100, 30], ...
        'Callback', @onUpdatePosition);
    
    % Go to position control
    uicontrol(hPanel, 'Style', 'text', ...
        'String', 'Go to Z:', ...
        'Position', [350, 50, 60, 20], ...
        'HorizontalAlignment', 'left');
    
    hGotoZ = uicontrol(hPanel, 'Style', 'edit', ...
        'String', '0.0', ...
        'Position', [410, 50, 60, 20], ...
        'Tag', 'gotoZ');
    
    hGotoButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
        'String', 'Go', ...
        'Position', [350, 15, 120, 30], ...
        'Callback', @onGotoPosition);
    
    % Store handles
    handles = getappdata(gcf, 'handles');
    handles.hCurrentZ = hCurrentZ;
    handles.hStepSize = hStepSize;
    handles.hMoveUpButton = hMoveUpButton;
    handles.hMoveDownButton = hMoveDownButton;
    handles.hUpdateButton = hUpdateButton;
    handles.hGotoZ = hGotoZ;
    handles.hGotoButton = hGotoButton;
    setappdata(gcf, 'handles', handles);
end

% Helper function to create automated scanning controls
function createAutoControls(hPanel)
    % Number of steps control
    uicontrol(hPanel, 'Style', 'text', ...
        'String', 'Number of Steps:', ...
        'Position', [20, 80, 150, 20], ...
        'HorizontalAlignment', 'left');
    
    hNumSteps = uicontrol(hPanel, 'Style', 'edit', ...
        'String', '10', ...
        'Position', [180, 80, 60, 20], ...
        'Tag', 'numSteps');
    
    % Delay between steps control
    uicontrol(hPanel, 'Style', 'text', ...
        'String', 'Delay Between Steps (s):', ...
        'Position', [20, 50, 150, 20], ...
        'HorizontalAlignment', 'left');
    
    hDelay = uicontrol(hPanel, 'Style', 'edit', ...
        'String', '0.5', ...
        'Position', [180, 50, 60, 20], ...
        'Tag', 'delay');
    
    % Direction control
    hDirUp = uicontrol(hPanel, 'Style', 'radiobutton', ...
        'String', 'Move Up', ...
        'Position', [20, 20, 80, 20], ...
        'Value', 1, ...
        'Tag', 'dirUp');
    
    hDirDown = uicontrol(hPanel, 'Style', 'radiobutton', ...
        'String', 'Move Down', ...
        'Position', [110, 20, 90, 20], ...
        'Value', 0, ...
        'Tag', 'dirDown');
    
    % Create button group for radio buttons
    bg = uibuttongroup('Visible', 'off', 'Position', [0 0 1 1], 'Parent', hPanel);
    set(hDirUp, 'Parent', bg);
    set(hDirDown, 'Parent', bg);
    set(bg, 'Visible', 'on');
    
    % Start/Stop buttons
    hStartButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
        'String', 'Start Scan', ...
        'Position', [250, 65, 120, 30], ...
        'Callback', @onStartScan);
    
    hStopButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
        'String', 'Stop', ...
        'Position', [250, 20, 120, 30], ...
        'Callback', @onStopScan, ...
        'Enable', 'off');
    
    % Return to start button
    hReturnButton = uicontrol(hPanel, 'Style', 'pushbutton', ...
        'String', 'Return to Start', ...
        'Position', [380, 20, 100, 30], ...
        'Callback', @onReturnToStart);
    
    % Store handles
    handles = getappdata(gcf, 'handles');
    handles.hNumSteps = hNumSteps;
    handles.hDelay = hDelay;
    handles.hDirUp = hDirUp;
    handles.hDirDown = hDirDown;
    handles.hStartButton = hStartButton;
    handles.hStopButton = hStopButton;
    handles.hReturnButton = hReturnButton;
    handles.buttonGroup = bg;
    setappdata(gcf, 'handles', handles);
end

% Helper function to create configuration controls
function createConfigControls(hConfigPanel)
    % Control method selection
    uicontrol(hConfigPanel, 'Style', 'text', ...
        'String', 'Z Control Method:', ...
        'Position', [20, 50, 150, 20], ...
        'HorizontalAlignment', 'left');
    
    hDirectControl = uicontrol(hConfigPanel, 'Style', 'radiobutton', ...
        'String', 'Direct Hardware Control', ...
        'Position', [180, 50, 150, 20], ...
        'Value', 1, ...
        'Tag', 'directControl');
    
    hScanImageControl = uicontrol(hConfigPanel, 'Style', 'radiobutton', ...
        'String', 'ScanImage API', ...
        'Position', [340, 50, 120, 20], ...
        'Value', 0, ...
        'Tag', 'siControl');
    
    % Create button group for radio buttons
    bgControl = uibuttongroup('Visible', 'off', 'Position', [0 0 1 1], 'Parent', hConfigPanel);
    set(hDirectControl, 'Parent', bgControl);
    set(hScanImageControl, 'Parent', bgControl);
    set(bgControl, 'Visible', 'on');
    set(bgControl, 'SelectionChangedFcn', @onControlMethodChanged);
    
    % Debug level
    uicontrol(hConfigPanel, 'Style', 'text', ...
        'String', 'Debug Level:', ...
        'Position', [20, 20, 150, 20], ...
        'HorizontalAlignment', 'left');
    
    hDebugLevel = uicontrol(hConfigPanel, 'Style', 'popupmenu', ...
        'String', {'0 - Minimal', '1 - Normal', '2 - Verbose'}, ...
        'Position', [180, 20, 150, 20], ...
        'Value', 2, ...
        'Callback', @onDebugLevelChanged);
    
    % Store handles
    handles = getappdata(gcf, 'handles');
    handles.hDirectControl = hDirectControl;
    handles.hScanImageControl = hScanImageControl;
    handles.hDebugLevel = hDebugLevel;
    handles.bgControl = bgControl;
    setappdata(gcf, 'handles', handles);
end

% Initialize Z control object
function initializeZControl()
    handles = getappdata(gcf, 'handles');
    
    % Create status callback function
    statusCallback = @(msg) updateStatusText(msg);
    
    try
        % Create Z control object based on selected method
        if handles.useDirectHardwareControl
            % Use direct hardware control
            updateStatusText('Initializing direct hardware Z control...');
            handles.zControl = ThorlabsZControl();
            handles.zControl.debugLevel = 2; % Start with verbose debugging
            
            if handles.zControl.isConnected
                updateStatusText('Successfully connected to Thorlabs Z motor.');
                updateZPositionDisplay();
            else
                updateStatusText('Failed to connect to Thorlabs Z motor. Check hardware connection.');
            end
        else
            % Use ScanImage API
            updateStatusText('Initializing ScanImage API Z control...');
            handles.zControl = SIZControl(@updateStatusText);
            updateZPositionDisplay();
        end
        
        setappdata(gcf, 'handles', handles);
        
        % Start position update timer
        t = timer('Period', 1.0, ...
                  'ExecutionMode', 'fixedRate', ...
                  'TimerFcn', @(~,~) updateZPositionDisplay());
        setappdata(gcf, 'updateTimer', t);
        start(t);
        
    catch ME
        updateStatusText(['Error initializing Z control: ' ME.message]);
    end
end

% Update Z position display
function updateZPositionDisplay()
    handles = getappdata(gcf, 'handles');
    if isempty(handles.zControl)
        return;
    end
    
    try
        % Get current Z position
        if handles.useDirectHardwareControl
            z = handles.zControl.getCurrentPosition();
        else
            z = handles.zControl.getCurrentZPosition();
        end
        
        % Update display
        set(handles.hCurrentZ, 'String', sprintf('%.2f µm', z));
    catch
        % Ignore errors during update
    end
end

% Callback for step size change
function onStepSizeChanged(src, ~)
    handles = getappdata(gcf, 'handles');
    if isempty(handles.zControl)
        return;
    end
    
    % Get new step size
    stepSize = str2double(get(src, 'String'));
    
    % Validate input
    if isnan(stepSize) || stepSize <= 0
        set(src, 'String', '1.0');
        stepSize = 1.0;
    end
    
    % Update Z control object
    if handles.useDirectHardwareControl
        % Direct hardware control doesn't store step size
    else
        handles.zControl.stepSize = stepSize;
    end
    
    updateStatusText(sprintf('Step size set to %.2f µm', stepSize));
end

% Callback for move up button
function onMoveUp(~, ~)
    handles = getappdata(gcf, 'handles');
    if isempty(handles.zControl)
        return;
    end
    
    % Get step size
    stepSize = str2double(get(handles.hStepSize, 'String'));
    
    % Move up one step
    if handles.useDirectHardwareControl
        handles.zControl.moveRelative(stepSize);
    else
        handles.zControl.moveUp();
    end
    
    % Update position display
    updateZPositionDisplay();
end

% Callback for move down button
function onMoveDown(~, ~)
    handles = getappdata(gcf, 'handles');
    if isempty(handles.zControl)
        return;
    end
    
    % Get step size
    stepSize = str2double(get(handles.hStepSize, 'String'));
    
    % Move down one step
    if handles.useDirectHardwareControl
        handles.zControl.moveRelative(-stepSize);
    else
        handles.zControl.moveDown();
    end
    
    % Update position display
    updateZPositionDisplay();
end

% Callback for update position button
function onUpdatePosition(~, ~)
    updateZPositionDisplay();
end

% Callback for go to position button
function onGotoPosition(~, ~)
    handles = getappdata(gcf, 'handles');
    if isempty(handles.zControl)
        return;
    end
    
    % Get target position
    targetZ = str2double(get(handles.hGotoZ, 'String'));
    
    % Validate input
    if isnan(targetZ)
        updateStatusText('Invalid Z position. Please enter a number.');
        return;
    end
    
    % Move to position
    updateStatusText(sprintf('Moving to Z position: %.2f µm', targetZ));
    
    if handles.useDirectHardwareControl
        handles.zControl.moveAbsolute(targetZ);
    else
        handles.zControl.absoluteMove(targetZ);
    end
    
    % Update position display
    updateZPositionDisplay();
end

% Callback for start scan button
function onStartScan(~, ~)
    handles = getappdata(gcf, 'handles');
    if isempty(handles.zControl)
        return;
    end
    
    % Get scan parameters
    numSteps = str2double(get(handles.hNumSteps, 'String'));
    delay = str2double(get(handles.hDelay, 'String'));
    direction = 1; % Default up
    
    % Get selected direction
    if get(handles.hDirDown, 'Value') == 1
        direction = -1;
    end
    
    % Validate inputs
    if isnan(numSteps) || numSteps <= 0
        set(handles.hNumSteps, 'String', '10');
        numSteps = 10;
    end
    
    if isnan(delay) || delay < 0.1
        set(handles.hDelay, 'String', '0.5');
        delay = 0.5;
    end
    
    % Update Z control parameters
    if handles.useDirectHardwareControl
        % For direct hardware control, we'll implement the scanning here
        handles.scanParams = struct();
        handles.scanParams.numSteps = numSteps;
        handles.scanParams.delay = delay;
        handles.scanParams.direction = direction;
        handles.scanParams.currentStep = 0;
        handles.scanParams.startZ = handles.zControl.getCurrentPosition();
        handles.scanParams.stepSize = str2double(get(handles.hStepSize, 'String'));
        handles.scanParams.isRunning = true;
        
        % Store updated handles
        setappdata(gcf, 'handles', handles);
        
        % Start the scan
        updateStatusText(sprintf('Starting Z scan: %d steps of %.2f µm %s', ...
            numSteps, handles.scanParams.stepSize, ternary(direction > 0, 'up', 'down')));
        
        % Start a timer for the scan
        t = timer('Period', delay, ...
                  'ExecutionMode', 'fixedRate', ...
                  'TimerFcn', @performNextStep);
        setappdata(gcf, 'scanTimer', t);
        start(t);
    else
        % For ScanImage API control
        handles.zControl.numSteps = numSteps;
        handles.zControl.delayBetweenSteps = delay;
        handles.zControl.direction = direction;
        handles.zControl.startZMovement();
    end
    
    % Update UI state
    set(handles.hStartButton, 'Enable', 'off');
    set(handles.hStopButton, 'Enable', 'on');
    
    % Start a timer to check when movement is complete
    t = timer('Period', 0.5, ...
              'ExecutionMode', 'fixedRate', ...
              'TimerFcn', @checkMovementStatus);
    setappdata(gcf, 'movementTimer', t);
    start(t);
end

% Perform next step in Z scan (for direct hardware control)
function performNextStep(~, ~)
    handles = getappdata(gcf, 'handles');
    
    if ~isfield(handles, 'scanParams') || ~handles.scanParams.isRunning
        return;
    end
    
    % Check if we've reached the end
    if handles.scanParams.currentStep >= handles.scanParams.numSteps
        updateStatusText('Z scan complete.');
        handles.scanParams.isRunning = false;
        setappdata(gcf, 'handles', handles);
        
        % Stop the scan timer
        t = getappdata(gcf, 'scanTimer');
        if ~isempty(t) && isvalid(t)
            stop(t);
            delete(t);
        end
        
        return;
    end
    
    % Increment step counter
    handles.scanParams.currentStep = handles.scanParams.currentStep + 1;
    
    % Calculate new Z position
    distance = handles.scanParams.direction * handles.scanParams.stepSize;
    
    % Move to new position
    updateStatusText(sprintf('Step %d/%d: Moving by %.2f µm', ...
        handles.scanParams.currentStep, handles.scanParams.numSteps, distance));
    
    handles.zControl.moveRelative(distance);
    
    % Update handles
    setappdata(gcf, 'handles', handles);
    
    % Update position display
    updateZPositionDisplay();
end

% Callback for stop scan button
function onStopScan(~, ~)
    handles = getappdata(gcf, 'handles');
    if isempty(handles.zControl)
        return;
    end
    
    % Stop Z movement
    if handles.useDirectHardwareControl
        if isfield(handles, 'scanParams')
            handles.scanParams.isRunning = false;
            setappdata(gcf, 'handles', handles);
        end
        
        % Stop the scan timer
        t = getappdata(gcf, 'scanTimer');
        if ~isempty(t) && isvalid(t)
            stop(t);
            delete(t);
        end
    else
        handles.zControl.stopZMovement();
    end
    
    updateStatusText('Z scan stopped.');
    
    % Update UI state
    set(handles.hStartButton, 'Enable', 'on');
    set(handles.hStopButton, 'Enable', 'off');
    
    % Stop movement timer if running
    t = getappdata(gcf, 'movementTimer');
    if ~isempty(t) && isvalid(t)
        stop(t);
        delete(t);
    end
end

% Callback for return to start button
function onReturnToStart(~, ~)
    handles = getappdata(gcf, 'handles');
    if isempty(handles.zControl)
        return;
    end
    
    % Return to starting position
    if handles.useDirectHardwareControl
        if isfield(handles, 'scanParams') && isfield(handles.scanParams, 'startZ')
            updateStatusText(sprintf('Returning to starting position: %.2f µm', handles.scanParams.startZ));
            handles.zControl.moveAbsolute(handles.scanParams.startZ);
        else
            updateStatusText('No starting position recorded.');
        end
    else
        handles.zControl.returnToStart();
    end
    
    % Update position display
    updateZPositionDisplay();
end

% Check if movement is complete
function checkMovementStatus(~, ~)
    handles = getappdata(gcf, 'handles');
    if isempty(handles.zControl)
        return;
    end
    
    % Check if movement is still running
    isRunning = false;
    
    if handles.useDirectHardwareControl
        if isfield(handles, 'scanParams')
            isRunning = handles.scanParams.isRunning;
        end
    else
        isRunning = handles.zControl.isRunning;
    end
    
    if ~isRunning
        % Movement is complete, update UI
        set(handles.hStartButton, 'Enable', 'on');
        set(handles.hStopButton, 'Enable', 'off');
        
        % Stop timer
        t = getappdata(gcf, 'movementTimer');
        if ~isempty(t) && isvalid(t)
            stop(t);
            delete(t);
        end
    end
    
    % Update position display
    updateZPositionDisplay();
end

% Callback for control method change
function onControlMethodChanged(~, event)
    handles = getappdata(gcf, 'handles');
    
    % Get selected control method
    selectedButton = event.NewValue;
    handles.useDirectHardwareControl = strcmp(get(selectedButton, 'Tag'), 'directControl');
    
    % Update status
    if handles.useDirectHardwareControl
        updateStatusText('Switching to direct hardware control...');
    else
        updateStatusText('Switching to ScanImage API control...');
    end
    
    % Clean up existing control object
    if ~isempty(handles.zControl)
        try
            delete(handles.zControl);
        catch
            % Ignore errors
        end
        handles.zControl = [];
    end
    
    % Store updated handles
    setappdata(gcf, 'handles', handles);
    
    % Initialize new control object
    initializeZControl();
end

% Callback for debug level change
function onDebugLevelChanged(src, ~)
    handles = getappdata(gcf, 'handles');
    if isempty(handles.zControl)
        return;
    end
    
    % Get selected debug level
    levels = [0, 1, 2];
    selectedLevel = levels(get(src, 'Value'));
    
    % Update debug level
    if handles.useDirectHardwareControl
        handles.zControl.debugLevel = selectedLevel;
    else
        % ScanImage control doesn't have debug level
    end
    
    updateStatusText(sprintf('Debug level set to %d', selectedLevel));
end

% Function to update status text
function updateStatusText(message)
    handles = getappdata(gcf, 'handles');
    
    % Add timestamp to message
    timestamp = datestr(now, 'HH:MM:SS');
    fullMessage = sprintf('[%s] %s', timestamp, message);
    
    % Add to message list
    handles.statusMessages{end+1} = fullMessage;
    
    % Limit number of messages
    if length(handles.statusMessages) > handles.maxStatusMessages
        handles.statusMessages = handles.statusMessages(end-handles.maxStatusMessages+1:end);
    end
    
    % Update text control
    set(handles.hStatusText, 'String', strjoin(handles.statusMessages, '\n'));
    
    % Scroll to bottom
    drawnow;
    
    % Save updated messages
    setappdata(gcf, 'handles', handles);
end

% Callback for figure close
function onClose(~, ~)
    % Stop timers
    t = getappdata(gcf, 'updateTimer');
    if ~isempty(t) && isvalid(t)
        stop(t);
        delete(t);
    end
    
    t = getappdata(gcf, 'movementTimer');
    if ~isempty(t) && isvalid(t)
        stop(t);
        delete(t);
    end
    
    t = getappdata(gcf, 'scanTimer');
    if ~isempty(t) && isvalid(t)
        stop(t);
        delete(t);
    end
    
    % Clean up Z control object
    handles = getappdata(gcf, 'handles');
    if ~isempty(handles.zControl)
        try
            delete(handles.zControl);
        catch
            % Ignore errors
        end
    end
    
    % Close figure
    delete(gcf);
end

% Helper function for ternary operator
function result = ternary(condition, trueVal, falseVal)
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end

end
