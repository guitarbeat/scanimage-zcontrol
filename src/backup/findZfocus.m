function findZfocus()
    % findZfocus - Launch the Brightness Z-Control GUI for Z-focus finding
    %
    % This function launches the main GUI for finding optimal Z-focus using
    % brightness monitoring. The GUI provides:
    %   - Step size and pause controls
    %   - Z limit management
    %   - Brightness metric selection
    %   - Real-time plot and status
    %
    % Ensure ScanImage is running and hSI is in the base workspace.
    %
    % Returns:
    %   zc - BrightnessZController object (optional)
    
    try
        validateScanImageEnvironment();
        fprintf('Initializing Z-focus control...\n');
        zc = BrightnessZController();
        fprintf('Z-focus control ready.\n');
        if nargout > 0
            varargout{1} = zc;
        end
    catch ME
        handleError(ME);
    end
end

%% --- Validation and Utility Functions ---
function validateScanImageEnvironment()
    % Validate ScanImage environment and components
    % Checks for hSI, channel, and display readiness
    if ~evalin('base', 'exist(''hSI'', ''var'')')
        error('ScanImage must be running with hSI in base workspace');
    end
    hSI = evalin('base', 'hSI');
    if ~strcmp(hSI.acqState, 'idle')
        warning('ScanImage not idle.');
    end
    if isempty(hSI.hChannels.channelsActive) || ~ismember(1, hSI.hChannels.channelsActive)
        warning('Channel 1 not active.');
    end
    if isempty(hSI.hDisplay) || isempty(hSI.hDisplay.lastAveragedFrame)
        warning('Display not initialized.');
    end
end

function handleError(ME)
    % Handle and display error information
    fprintf('Error: %s\n', ME.message);
    disp(getReport(ME));
end 