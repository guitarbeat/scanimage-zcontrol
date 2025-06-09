function findZfocus()
    % findZfocus - Main entry point for Z-focus finding with brightness monitoring
    %
    % This function launches the main GUI for finding optimal Z-focus using
    % brightness monitoring. The GUI uses a modern, compact layout with:
    %   - Slider for step size
    %   - GridLayout for all controls
    %   - ToggleButtons for monitoring and Z-scan
    %   - Status label and compact usage guide
    %
    % Ensure ScanImage is running and hSI is in the base workspace.
    %
    % Returns:
    %   zc - SI_BrightnessZControl object (optional)
    
    try
        % Validate ScanImage environment
        validateScanImageEnvironment();
        
        % Create the control object
        fprintf('Initializing Z-focus control (compact UI)...\n');
        zc = SI_BrightnessZControl();
        
        % Display success message
        displaySuccessMessage();
        
        % Return control object if requested
        if nargout > 0
            varargout{1} = zc;
        end
        
    catch ME
        handleError(ME);
    end
end

function validateScanImageEnvironment()
    % Validate ScanImage environment and components
    
    % Check if ScanImage is running
    if ~evalin('base', 'exist(''hSI'', ''var'')')
        error('ScanImage must be running with hSI in the base workspace');
    end
    
    % Get ScanImage handle
    hSI = evalin('base', 'hSI');
    
    % Verify ScanImage components
    fprintf('Verifying ScanImage components...\n');
    
    % Check if acquisition is active
    if ~strcmp(hSI.acqState, 'idle')
        warning('ScanImage acquisition is not idle. Some features may not work properly.');
    end
    
    % Check if Channel 1 is active
    if isempty(hSI.hChannels.channelsActive) || ~ismember(1, hSI.hChannels.channelsActive)
        warning('Channel 1 is not active. Brightness monitoring may not work properly.');
    end
    
    % Check if display is properly configured
    if isempty(hSI.hDisplay) || isempty(hSI.hDisplay.lastAveragedFrame)
        warning('Display component may not be properly initialized.');
    end
end

function displaySuccessMessage()
    % Display initialization success message
    fprintf('\nZ-focus control initialized successfully!\n');
    fprintf('You can now:\n');
    fprintf('1. Set step size (slider), scan range, and pause time.\n');
    fprintf('2. Toggle Monitor and Z-Scan as needed.\n');
    fprintf('3. Use "Move to Max" to go to brightest position.\n');
    fprintf('4. The GUI is now more compact.\n');
end

function handleError(ME)
    % Handle and display error information
    fprintf('Error initializing Z-focus control: %s\n', ME.message);
    fprintf('Stack trace:\n');
    disp(getReport(ME));
end

% Test functions
function addTestButtons(zc)
    % Add test buttons to the main GUI
    
    % Create test panel
    testPanel = uipanel('Parent', zc.hFig, ...
                       'Title', 'Test Functions', ...
                       'Position', [0.1 0.85 0.8 0.1]);
    
    % Button positions
    buttonWidth = 120;
    buttonHeight = 30;
    buttonSpacing = 10;
    startX = 10;
    startY = 10;
    
    % Create test buttons
    createTestButton(testPanel, 'Test Z Movement', startX, startY, buttonWidth, buttonHeight, ...
        @(~,~) testZMovement(zc));
    
    createTestButton(testPanel, 'Test Monitoring', ...
        startX + (buttonWidth + buttonSpacing), startY, buttonWidth, buttonHeight, ...
        @(~,~) testMonitoring(zc));
    
    createTestButton(testPanel, 'Test Z-Scan', ...
        startX + 2*(buttonWidth + buttonSpacing), startY, buttonWidth, buttonHeight, ...
        @(~,~) testZScan(zc));
    
    createTestButton(testPanel, 'Test Max Brightness', ...
        startX + 3*(buttonWidth + buttonSpacing), startY, buttonWidth, buttonHeight, ...
        @(~,~) testMaxBrightness(zc));
end

function createTestButton(parent, text, x, y, width, height, callback)
    % Create a test button with consistent properties
    uicontrol('Parent', parent, ...
             'Style', 'pushbutton', ...
             'String', text, ...
             'Position', [x y width height], ...
             'Callback', callback);
end

function testZMovement(zc)
    % Test basic Z movement
    try
        fprintf('\nTesting Z movement...\n');
        currentZ = zc.getZ();
        fprintf('Current Z position: %.2f µm\n', currentZ);
        
        fprintf('Moving up 1 µm...\n');
        zc.moveUp();
        pause(1);
        
        fprintf('Moving down 1 µm...\n');
        zc.moveDown();
        pause(1);
        
        fprintf('Z movement test completed.\n');
    catch ME
        fprintf('Error in Z movement test: %s\n', ME.message);
    end
end

function testMonitoring(zc)
    % Test brightness monitoring
    try
        fprintf('\nTesting brightness monitoring...\n');
        
        fprintf('Starting monitoring...\n');
        zc.startMonitoring();
        pause(5); % Monitor for 5 seconds
        
        fprintf('Stopping monitoring...\n');
        zc.stopMonitoring();
        
        fprintf('Brightness monitoring test completed.\n');
    catch ME
        fprintf('Error in brightness monitoring test: %s\n', ME.message);
    end
end

function testZScan(zc)
    % Test Z-scan functionality
    try
        fprintf('\nTesting Z-scan...\n');
        
        fprintf('Starting Z-scan...\n');
        zc.startZScan();
        pause(5); % Scan for 5 seconds
        
        fprintf('Stopping Z-scan...\n');
        zc.stopZScan();
        
        fprintf('Z-scan test completed.\n');
    catch ME
        fprintf('Error in Z-scan test: %s\n', ME.message);
    end
end

function testMaxBrightness(zc)
    % Test maximum brightness detection
    try
        fprintf('\nTesting maximum brightness detection...\n');
        
        fprintf('Moving to maximum brightness position...\n');
        zc.moveToMaxBrightness();
        
        fprintf('Maximum brightness test completed.\n');
    catch ME
        fprintf('Error in maximum brightness test: %s\n', ME.message);
    end
end 