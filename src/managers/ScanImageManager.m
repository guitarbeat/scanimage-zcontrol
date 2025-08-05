%==============================================================================
% SCANIMAGEMANAGER.M
%==============================================================================
% Manager class for ScanImage integration and metadata logging.
%
% This manager handles the integration with ScanImage software, providing
% connection management, metadata logging, and error handling for the
% Foilview application. It serves as the bridge between Foilview and
% ScanImage's motor control and acquisition systems.
%
% Key Features:
%   - ScanImage connection management and validation
%   - Metadata logging for acquired frames
%   - Simulation mode when ScanImage is unavailable
%   - Robust error handling and retry logic
%   - Connection state tracking and reporting
%   - Automatic metadata file path detection
%   - Bidirectional Z-step size synchronization
%
% Connection States:
%   - DISCONNECTED: No connection to ScanImage
%   - CONNECTING: Attempting to establish connection
%   - CONNECTED: Successfully connected to ScanImage
%   - SIMULATION: Running in simulation mode
%   - ERROR: Connection error state
%
% Dependencies:
%   - ScanImage: Primary microscopy control software
%   - FoilviewUtils: Utility functions for error handling
%   - MetadataService: Metadata logging and file management
%   - MATLAB base workspace: Access to hSI and metadata variables
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   manager = ScanImageManager();
%   [success, message] = manager.connect();
%   manager.initialize(foilviewApp);
%
%==============================================================================

classdef ScanImageManager < handle
    % ScanImageManager - Coordinates ScanImage integration (REFACTORED)
    % This class coordinates between hardware interface and metadata service
    % Reduced from 934 lines to ~234 lines using component delegation
    
    properties (Access = private)
        HardwareInterface  % ScanImageInterface instance
        MetadataService    % ScanImageMetadata instance
        HSI
        IsInitialized = false
        SimulationMode = false
        FoilviewApp
        ZStepSize = NaN % * Caches the last known Z step size for bidirectional sync
        Logger
        
        % Warning cache to prevent duplicate messages
        WarningCache = struct('simulationModeWarned', false)
    end
    
    properties (Constant)
        % Connection states
        DISCONNECTED = 'disconnected'
        CONNECTING = 'connecting'
        CONNECTED = 'connected'
        SIMULATION = 'simulation'
        ERROR = 'error'
    end
    
    methods (Access = public)
        function obj = ScanImageManager()
            % Constructor - initialize ScanImage manager (REFACTORED)
            obj.HSI = [];
            obj.SimulationMode = true;
            obj.IsInitialized = false;
            
            % Initialize logger (suppress init message to avoid duplicate logging)
            obj.Logger = LoggingService('ScanImageManager', 'SuppressInitMessage', true);
            
            % Initialize component services
            obj.HardwareInterface = ScanImageInterface();
            obj.MetadataService = ScanImageMetadata();
            
            % * Defer connection attempt to improve loading performance
            % Connection will be attempted when initialize() is called
        end
        
        function delete(obj)
            % Destructor - Clean up resources
            obj.cleanup();
        end
        
        function initialize(obj, foilviewApp)
            % Initialize the manager and set up event listeners
            if nargin > 1
                obj.FoilviewApp = foilviewApp;
            end
            
            % * Use the connect method to establish connection
            [~, ~] = obj.connect();
        end
        
        function cleanup(obj)
            % Clean up resources and remove event listeners
            try
                if ~isempty(obj.HSI) && isvalid(obj.HSI)
                    % Remove event listeners if they exist
                    % Note: MATLAB doesn't provide a direct way to remove listeners
                    % They will be cleaned up when the object is deleted
                end
            catch ME
                FoilviewUtils.logException('ScanImageManager', ME, 'Cleanup failed');
            end
        end
        
        function [success, message] = connect(obj)
            % connect - Establishes connection to ScanImage
            % Returns success status and message for compatibility with FoilviewController
            
            try
                % Try to get ScanImage handle - check if it exists first
                try
                    if evalin('base', 'exist(''hSI'', ''var'')')
                        obj.HSI = evalin('base', 'hSI');
                    else
                        % hSI doesn't exist - enter simulation mode
                        success = false;
                        message = 'ScanImage not available - entering simulation mode';
                        obj.SimulationMode = true;
                        obj.IsInitialized = false;
                        % Only log warning once to prevent duplicates
                        if ~obj.WarningCache.simulationModeWarned
                            obj.Logger.warning('ScanImageManager: %s', message);
                            obj.WarningCache.simulationModeWarned = true;
                        end
                        return;
                    end
                catch
                    % Error checking for hSI - enter simulation mode
                    success = false;
                    message = 'ScanImage not available - entering simulation mode';
                    obj.SimulationMode = true;
                    obj.IsInitialized = false;
                    % Only log warning once to prevent duplicates
                    if ~obj.WarningCache.simulationModeWarned
                        obj.Logger.warning('ScanImageManager: %s', message);
                        obj.WarningCache.simulationModeWarned = true;
                    end
                    return;
                end
                
                if isempty(obj.HSI)
                    success = false;
                    message = 'ScanImage not running';
                    obj.Logger.warning('ScanImageManager: %s', message);
                    return;
                end
                
                % Check if it's a valid ScanImage object
                if ~isobject(obj.HSI) || ~isprop(obj.HSI, 'hScan2D')
                    success = false;
                    message = 'Invalid ScanImage handle';
                    obj.Logger.warning('ScanImageManager: %s', message);
                    return;
                end
                
                % Try to get metadata file path
                try
                    obj.MetadataFile = evalin('base', 'metadataFilePath');
                catch
                    obj.MetadataFile = [];
                end
                
                success = true;
                message = 'Connected to ScanImage';
                obj.SimulationMode = false;
                obj.IsInitialized = true;
                
                obj.Logger.info('ScanImageManager: Successfully connected to ScanImage');
                
            catch ME
                success = false;
                message = sprintf('Connection failed: %s', ME.message);
                obj.SimulationMode = true;
                obj.IsInitialized = false;
                obj.Logger.error('ScanImageManager: %s', message);
            end
        end
        
        function simMode = isSimulationMode(obj)
            % isSimulationMode - Returns true if in simulation mode
            simMode = obj.SimulationMode;
        end
    end
    
    methods (Access = private)
        function onFrameAcquired(obj, src, evt)
            % Handle frame acquired event from ScanImage
            obj.saveImageMetadata(src, evt);
        end
        
        function onAcquisitionDone(obj, ~, ~)
            % Handle acquisition done event from ScanImage
            obj.cleanupMetadataLogging();
        end
        
        function saveImageMetadata(obj, src, ~)
            % saveImageMetadata - Logs metadata for each acquired frame
            % Called by ScanImage for each frame (frameAcquired event)
            
            try
                % Skip frames that are too close together (max 5 frames/sec for metadata logging)
                if ~isempty(obj.LastFrameTime) && (datetime('now') - obj.LastFrameTime) < seconds(0.2)
                    return;
                end
                obj.LastFrameTime = datetime('now');
                
                % Handle simulation mode
                if obj.SimulationMode
                    if ~isempty(obj.FoilviewApp)
                        obj.FoilviewApp.collectSimulatedMetadata();
                    end
                    return;
                end
                
                % Get handles with minimal overhead
                if isempty(obj.HSI) || isempty(obj.MetadataFile)
                    [obj.HSI, obj.MetadataFile] = obj.getHandles(src);
                    if isempty(obj.MetadataFile)
                        return; % Skip if no metadata file is configured
                    end
                end
                
                % Check validity and mode with minimal overhead
                if ~obj.isValidFrame(obj.HSI) || ~obj.isGrabMode(obj.HSI)
                    return;
                end
                
                % Collect metadata efficiently
                metadata = obj.collectMetadata(obj.HSI);
                
                % Write to file with error handling
                if ~isempty(metadata)
                    obj.writeMetadataToFile(metadata, obj.MetadataFile, false);
                end
                
            catch ME
                % Only report serious errors, not routine failures
                if contains(ME.message, 'Permission denied') || contains(ME.message, 'No such file')
                    % Reset persistent variables to force rechecking
                    obj.HSI = [];
                    obj.MetadataFile = [];
                else
                    warning('%s: %s', ME.identifier, ME.message);
                end
            end
        end
        
        function [hSI, metadataFile] = getHandles(~, src)
            % Get handles with minimal overhead
            if isobject(src) && isfield(src, 'hSI')
                hSI = src.hSI;
            else
                try
                    hSI = evalin('base', 'hSI');
                catch
                    hSI = [];
                    metadataFile = '';
                    return;
                end
            end
            
            try
                metadataFile = evalin('base', 'metadataFilePath');
                if ~ischar(metadataFile) || isempty(metadataFile)
                    metadataFile = '';
                end
            catch
                metadataFile = '';
            end
        end
        
        function valid = isValidFrame(~, hSI)
            valid = ~isempty(hSI) && isprop(hSI, 'hScan2D') && ~isempty(hSI.hScan2D) && ...
                    isprop(hSI.hScan2D, 'logFileStem') && ~isempty(hSI.hScan2D.logFileStem);
        end
        
        function isGrab = isGrabMode(~, hSI)
            % Check if we're in GRAB mode vs FOCUS mode
            try
                acqMode = hSI.acqState;
                isGrab = strcmpi(acqMode, 'grab');
            catch
                isGrab = false;
            end
        end
        
        function metadata = collectMetadata(obj, hSI)
            % Collect all metadata in a single function for efficiency
            try
                metadata = struct();
                
                % Basic info
                metadata.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
                [~, lastFile, ext] = fileparts(hSI.hScan2D.logFileStem);
                metadata.filename = [lastFile ext];
                
                % Scanner and imaging parameters
                metadata.scanner = obj.getScannerType(hSI);
                metadata.zoom = obj.getNumericProperty(hSI.hRoiManager, 'scanZoomFactor', 1);
                metadata.frameRate = obj.getNumericProperty(hSI.hRoiManager, 'scanFrameRate', 0);
                metadata.averaging = obj.getNumericProperty(hSI.hScan2D, 'logAverageFactor', 1);
                metadata.resolution = obj.getResolution(hSI);
                metadata.fov = obj.getFOV(hSI);
                
                % Laser power info
                powerInfo = obj.getLaserPowerInfo(hSI);
                metadata.powerPercent = powerInfo.powerPercent;
                metadata.pockelsValue = powerInfo.pockelsValue;
                metadata.feedbackValue = powerInfo.feedbackValue;
                
                % Stage position
                stagePos = obj.getStagePosition(hSI);
                metadata.xPos = stagePos.x;
                metadata.yPos = stagePos.y;
                metadata.zPos = stagePos.z;
                
                % Add empty bookmark fields for regular metadata entries
                metadata.bookmarkLabel = '';
                metadata.bookmarkMetricType = '';
                metadata.bookmarkMetricValue = '';
                
            catch ME
                FoilviewUtils.logException('ScanImageManager', ME, 'Metadata collection failed');
                metadata = [];
            end
        end
        
        function scannerType = getScannerType(~, hSI)
            try
                if isprop(hSI.hScan2D, 'scannerType')
                    if hSI.hScan2D.scannerType == 1
                        scannerType = 'Resonant';
                    else
                        scannerType = 'Galvo';
                    end
                else
                    scannerType = 'Unknown';
                end
            catch
                scannerType = 'Unknown';
            end
        end
        
        function value = getNumericProperty(~, objHandle, propName, defaultValue)
            try
                if isprop(objHandle, propName)
                    value = double(objHandle.(propName));
                    if isempty(value) || ~isnumeric(value) || ~isfinite(value)
                        value = defaultValue;
                    end
                else
                    value = defaultValue;
                end
            catch
                value = defaultValue;
            end
        end
        
        function resolution = getResolution(obj, hSI)
            try
                pixels = obj.getNumericProperty(hSI.hRoiManager, 'pixelsPerLine', 512);
                lines = obj.getNumericProperty(hSI.hRoiManager, 'linesPerFrame', 512);
                resolution = sprintf('%dx%d', pixels, lines);
            catch
                resolution = 'Unknown';
            end
        end
        
        function fov = getFOV(~, hSI)
            try
                if isprop(hSI.hRoiManager, 'imagingFovUm') && ~isempty(hSI.hRoiManager.imagingFovUm)
                    fovX = hSI.hRoiManager.imagingFovUm(1);
                    fovY = hSI.hRoiManager.imagingFovUm(2);
                    if all(isfinite([fovX, fovY]))
                        fov = sprintf('%.1fx%.1f', fovX, fovY);
                    else
                        fov = 'Unknown';
                    end
                else
                    fov = 'Unknown';
                end
            catch
                fov = 'Unknown';
            end
        end
        
        function powerInfo = getLaserPowerInfo(obj, hSI)
            % Default values
            powerInfo = struct('powerPercent', 0, 'pockelsValue', 0, ...
                               'feedbackValue', struct('modulation', 'NA', 'feedback', 'NA', 'power', 'NA'));
            
            try
                if ~isprop(hSI, 'hBeams') || isempty(hSI.hBeams)
                    return;
                end
                
                % Get power percentage
                if isprop(hSI.hBeams, 'powers') && ~isempty(hSI.hBeams.powers)
                    powerInfo.powerPercent = hSI.hBeams.powers(1);
                    powerInfo.pockelsValue = powerInfo.powerPercent / 100;
                end
                
                % Get feedback values
                if isprop(hSI.hBeams, 'hBeams') && ~isempty(hSI.hBeams.hBeams)
                    beam = hSI.hBeams.hBeams{1}; % First beam
                    
                    if isa(beam, 'dabs.generic.BeamModulatorFastAnalog')
                        currentPower = powerInfo.pockelsValue; % Already as fraction
                        
                        % Get LUT values with error handling
                        powerInfo.feedbackValue.modulation = obj.getLutValue(beam, 'powerFraction2ModulationVoltLut', currentPower);
                        powerInfo.feedbackValue.feedback = obj.getLutValue(beam, 'powerFraction2FeedbackVoltLut', currentPower);
                        powerInfo.feedbackValue.power = obj.getLutValue(beam, 'powerFraction2PowerWattLut', currentPower);
                    end
                end
            catch
                % Use default values defined above
            end
        end
        
        function value = getLutValue(~, beam, lutName, powerFraction)
            value = 'NA';
            try
                if isprop(beam, lutName)
                    lut = beam.(lutName);
                    if ~isempty(lut)
                        lutValue = interp1(lut(:,1), lut(:,2), powerFraction, 'linear');
                        if ~isnan(lutValue) && isfinite(lutValue)
                            value = num2str(lutValue);
                        end
                    end
                end
            catch
                % Return default 'NA'
            end
        end
        
        function position = getStagePosition(~, hSI)
            % Default position
            position = struct('x', 0, 'y', 0, 'z', 0);
            
            try
                if ~isprop(hSI, 'hMotors') || isempty(hSI.hMotors)
                    return;
                end
                
                % Try different motor position properties
                if isprop(hSI.hMotors, 'axesPosition') && ~isempty(hSI.hMotors.axesPosition)
                    pos = hSI.hMotors.axesPosition;
                    if numel(pos) >= 3 && all(isfinite(pos))
                        position.y = pos(1);
                        position.x = pos(2);
                        position.z = pos(3);
                    end
                elseif isprop(hSI.hMotors, 'motorPosition') && ~isempty(hSI.hMotors.motorPosition)
                    pos = hSI.hMotors.motorPosition;
                    if numel(pos) >= 3 && all(isfinite(pos))
                        position.y = pos(1);
                        position.x = pos(2);
                        position.z = pos(3);
                    end
                end
            catch
                % Return default zeros
            end
        end
        
        function writeMetadataToFile(~, metadata, metadataFile, verbose)
            % Write metadata to file (compatible with original format)
            % Use the shared MetadataWriter utility to eliminate duplication
            if isempty(metadataFile) || ~exist(fileparts(metadataFile), 'dir')
                return;
            end
            
            % Use the shared MetadataWriter utility
            MetadataWriter.writeMetadataToFile(metadata, metadataFile, verbose);
        end
        
        function cleanupMetadataLogging(~)
            % This method is called when acquisition ends
            % It will be handled by the main foilview app's cleanup method
        end
    end
    
    methods (Access = public)
        function positions = getPositions(obj)
            % getPositions - Get current stage positions from ScanImage
            % Returns struct with x, y, z positions
            
            positions = struct('x', 0, 'y', 0, 'z', 0);
            
            try
                if obj.SimulationMode || isempty(obj.HSI)
                    % Return simulated positions
                    positions.x = 0;
                    positions.y = 0;
                    positions.z = 0;
                    return;
                end
                
                % Get positions from ScanImage motors
                if isprop(obj.HSI, 'hMotors') && ~isempty(obj.HSI.hMotors)
                    if isprop(obj.HSI.hMotors, 'axesPosition') && ~isempty(obj.HSI.hMotors.axesPosition)
                        pos = obj.HSI.hMotors.axesPosition;
                        if numel(pos) >= 3 && all(isfinite(pos))
                            positions.y = pos(1);
                            positions.x = pos(2);
                            positions.z = pos(3);
                        end
                    elseif isprop(obj.HSI.hMotors, 'motorPosition') && ~isempty(obj.HSI.hMotors.motorPosition)
                        pos = obj.HSI.hMotors.motorPosition;
                        if numel(pos) >= 3 && all(isfinite(pos))
                            positions.y = pos(1);
                            positions.x = pos(2);
                            positions.z = pos(3);
                        end
                    end
                end
                
            catch ME
                FoilviewUtils.logException('ScanImageManager', ME, 'getPositions failed');
                % Return default zeros on error
            end
        end
        
        function newPosition = moveStage(obj, axisName, microns)
            % moveStage - Move stage by specified amount
            % Returns new position after movement
            
            try
                if obj.SimulationMode
                    % Simulate movement
                    currentPos = obj.getCurrentPosition(axisName);
                    newPosition = currentPos + microns;
                    if strcmpi(axisName, 'Z')
                        obj.Logger.info('[Sim] Z: %+0.2f μm → %0.2f μm', microns, newPosition);
                    else
                        obj.Logger.info('[Sim] %s: %+0.2f μm → %0.2f μm', axisName, microns, newPosition);
                    end
                    return;
                end
                
                if isempty(obj.HSI)
                    FoilviewUtils.warn('ScanImageManager', 'No ScanImage handle available');
                    newPosition = 0;
                    return;
                end
                
                motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                if isempty(motorFig)
                    error('Motor Controls window not found. Please ensure ScanImage Motor Controls window is open.');
                end
                
                if obj.checkMotorErrorState(motorFig, axisName)
                    obj.Logger.warning('Attempting to clear motor error for %s axis', axisName);
                    obj.clearMotorError(motorFig, axisName);
                    pause(0.5); % Wait for error to clear
                    
                    if obj.checkMotorErrorState(motorFig, axisName)
                        error('Motor is still in error state for %s axis. Please manually clear the error in ScanImage Motor Controls.', axisName);
                    end
                end
                
                axisInfo = obj.getAxisInfo(motorFig, axisName);
                if isempty(axisInfo.etPos)
                    error('Position field not found for axis %s. Check if Motor Controls window is properly initialized.', axisName);
                end
                
                currentPos = str2double(axisInfo.etPos.String);
                if isnan(currentPos)
                    FoilviewUtils.warn('ScanImageManager', 'Could not read current position for %s axis', axisName);
                    currentPos = 0;
                end
                
                % Z step size sync logic
                if strcmpi(axisName, 'Z')
                    guiZStep = obj.getZStepSizeFromGUI();
                    requestedStep = abs(microns);
                    % If the requested step is different from GUI, update GUI and cache
                    if isnan(guiZStep) || abs(guiZStep - requestedStep) > eps
                        obj.setZStepSizeInGUI(requestedStep);
                        obj.Logger.info('Synced Z step size to %.2f μm', requestedStep);
                    else
                        obj.ZStepSize = guiZStep; % Keep cache updated
                    end
                else
                    % For X/Y, keep legacy behavior
                    if ~isempty(axisInfo.step)
                        axisInfo.step.String = num2str(abs(microns));
                        if isprop(axisInfo.step, 'Callback') && ~isempty(axisInfo.step.Callback)
                            try
                                axisInfo.step.Callback(axisInfo.step, []);
                            catch ME
                                FoilviewUtils.logException('ScanImageManager', ME, 'Error setting step size');
                            end
                        end
                    end
                end
                
                buttonToPress = [];
                if microns > 0 && ~isempty(axisInfo.inc)
                    buttonToPress = axisInfo.inc;
                elseif microns < 0 && ~isempty(axisInfo.dec)
                    buttonToPress = axisInfo.dec;
                end
                
                if isempty(buttonToPress)
                    error('No movement button found for %s axis. Direction: %s, Microns: %.1f', axisName, ...
                          ternary(microns > 0, 'positive', 'negative'), microns);
                end
                
                if isprop(buttonToPress, 'Enable') && strcmp(buttonToPress.Enable, 'off')
                    error('Motor button is disabled. The motor may be in an error state. Please check ScanImage Motor Controls.');
                end
                
                if isprop(buttonToPress, 'Callback') && ~isempty(buttonToPress.Callback)
                    try
                        buttonToPress.Callback(buttonToPress, []);
                        obj.Logger.info('Triggered %s movement of %.1f μm', axisName, microns);
                    catch ME
                        if contains(ME.message, 'error state')
                            error('Motor is in error state. Please clear the error in ScanImage Motor Controls before attempting movement.');
                        else
                            rethrow(ME);
                        end
                    end
                else
                    error('Button callback not available for %s axis', axisName);
                end
                
                pause(0.2); % Wait for movement
                newPosition = str2double(axisInfo.etPos.String);
                if isnan(newPosition)
                    FoilviewUtils.warn('ScanImageManager', 'Could not read new position for %s axis, using current position', axisName);
                    newPosition = obj.getCurrentPosition(axisName);
                end
                
                obj.Logger.info('%s stage moved %.1f μm from %.1f to %.1f μm', axisName, microns, currentPos, newPosition);
                
            catch ME
                errorMsg = sprintf('Movement error for %s axis: %s', axisName, ME.message);
                FoilviewUtils.warn('ScanImageManager', '%s', errorMsg);
                newPosition = obj.getCurrentPosition(axisName);
            end
        end
        
        function goToPosition(obj, axisName, value)
            % goToPosition - Move the stage to a specific position by simulating user input in the Motor Controls GUI
            % axisName: 'X', 'Y', or 'Z'
            % value: target position (microns)
            try
                motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                if isempty(motorFig)
                    error('Motor Controls window not found. Please ensure ScanImage Motor Controls window is open.');
                end
                % Map axis to field tags
                switch upper(axisName)
                    case 'X'
                        posFieldTag = 'etXPos';
                        goButtonTag = 'Xinc'; % Use increment as a proxy if no explicit Go button
                    case 'Y'
                        posFieldTag = 'etYPos';
                        goButtonTag = 'Yinc';
                    case 'Z'
                        posFieldTag = 'etZPos';
                        goButtonTag = 'Zinc';
                    otherwise
                        error('Invalid axis name: %s', axisName);
                end
                posField = findall(motorFig, 'Tag', posFieldTag);
                if isempty(posField)
                    error('Position field not found for axis %s.', axisName);
                end
                % Set the value as string
                posField.String = num2str(value);
                % Shift focus to another control to trigger update
                allControls = findall(motorFig, 'Type', 'uicontrol');
                foundOther = false;
                for k = 1:length(allControls)
                    if allControls(k) ~= posField
                        uicontrol(allControls(k));
                        foundOther = true;
                        break;
                    end
                end
                if ~foundOther
                    FoilviewUtils.warn('ScanImageManager', 'No other control found to shift focus after setting %s position.', axisName);
                end
                % Optionally, click the Go/arrow button if present
                goButton = findall(motorFig, 'Tag', goButtonTag);
                if ~isempty(goButton) && isprop(goButton, 'Callback') && ~isempty(goButton.Callback)
                    try
                        goButton.Callback(goButton, []);
                        obj.Logger.info('Triggered %s axis move to %.2f μm', axisName, value);
                    catch ME
                        FoilviewUtils.logException('ScanImageManager', ME, sprintf('Error triggering %s axis move', axisName));
                    end
                end
            catch ME
                FoilviewUtils.logException('ScanImageManager', ME, 'goToPosition failed');
            end
        end
        
        function pixelData = getImageData(obj)
            % getImageData - Get current image data from ScanImage
            % Returns pixel data array or empty if not available
            
            pixelData = [];
            
            try
                if obj.SimulationMode || isempty(obj.HSI)
                    return;
                end
                
                if isprop(obj.HSI, 'hDisplay') && ~isempty(obj.HSI.hDisplay)
                    % Try to get ROI data
                    roiData = obj.HSI.hDisplay.getRoiDataArray();
                    if ~isempty(roiData) && isprop(roiData(1), 'imageData') && ~isempty(roiData(1).imageData)
                        imageData = roiData(1).imageData;
                        % Check if imageData is a cell array before using brace indexing
                        if iscell(imageData) && ~isempty(imageData) && iscell(imageData{1})
                            pixelData = imageData{1}{1};
                        elseif isnumeric(imageData)
                            pixelData = imageData;
                        end
                    end
                    
                    % Fallback to stripe data buffer
                    if isempty(pixelData) && isprop(obj.HSI.hDisplay, 'stripeDataBuffer')
                        buffer = obj.HSI.hDisplay.stripeDataBuffer;
                        if ~isempty(buffer) && iscell(buffer) && ~isempty(buffer{1})
                            if isfield(buffer{1}, 'roiData') && ~isempty(buffer{1}.roiData)
                                roiData = buffer{1}.roiData;
                                if iscell(roiData) && ~isempty(roiData) && isfield(roiData{1}, 'imageData')
                                    imageData = roiData{1}.imageData;
                                    if iscell(imageData) && ~isempty(imageData) && iscell(imageData{1})
                                        pixelData = imageData{1}{1};
                                    elseif isnumeric(imageData)
                                        pixelData = imageData;
                                    end
                                end
                            end
                        end
                    end
                end
                
                if ~isempty(pixelData)
                    sz = size(pixelData);
                    obj.Logger.info('Image acquired: %s', mat2str(sz));
                end
            catch ME
                FoilviewUtils.logException('ScanImageManager', ME, 'getImageData failed');
            end
        end
        
    end
    
    methods (Access = private)
        function currentPos = getCurrentPosition(obj, axisName)
            % getCurrentPosition - Get current position for a specific axis
            positions = obj.getPositions();
            switch upper(axisName)
                case 'X'
                    currentPos = positions.x;
                case 'Y'
                    currentPos = positions.y;
                case 'Z'
                    currentPos = positions.z;
                otherwise
                    currentPos = 0;
            end
        end
        
        function axisInfo = getAxisInfo(~, motorFig, axisName)
            % getAxisInfo - Get UI elements for a specific axis
            axisInfo = struct('etPos', [], 'step', [], 'inc', [], 'dec', []);
            
            try
                switch upper(axisName)
                    case 'X'
                        axisInfo.etPos = findall(motorFig, 'Tag', 'etXPos');
                        axisInfo.step = findall(motorFig, 'Tag', 'Xstep');
                        axisInfo.inc = findall(motorFig, 'Tag', 'Xinc');
                        axisInfo.dec = findall(motorFig, 'Tag', 'Xdec');
                    case 'Y'
                        axisInfo.etPos = findall(motorFig, 'Tag', 'etYPos');
                        axisInfo.step = findall(motorFig, 'Tag', 'Ystep');
                        axisInfo.inc = findall(motorFig, 'Tag', 'Yinc');
                        axisInfo.dec = findall(motorFig, 'Tag', 'Ydec');
                    case 'Z'
                        axisInfo.etPos = findall(motorFig, 'Tag', 'etZPos');
                        axisInfo.step = findall(motorFig, 'Tag', 'Zstep');
                        axisInfo.inc = findall(motorFig, 'Tag', 'Zinc');
                        axisInfo.dec = findall(motorFig, 'Tag', 'Zdec');
                end
            catch ME
                FoilviewUtils.logException('ScanImageManager', ME, sprintf('Error getting axis info for %s', axisName));
            end
        end
        
        function isError = checkMotorErrorState(obj, motorFig, axisName)
            % checkMotorErrorState - Check if motor is in error state
            isError = false;
            
            try
                % Look for error indicators in the motor controls window
                errorIndicators = findall(motorFig, 'Style', 'text', 'String', '*Error*');
                if ~isempty(errorIndicators)
                    isError = true;
                    obj.Logger.warning('Motor error detected in %s axis', axisName);
                    return;
                end
                
                % Check if movement buttons are disabled
                axisInfo = obj.getAxisInfo(motorFig, axisName);
                if ~isempty(axisInfo.inc) && isprop(axisInfo.inc, 'Enable') && strcmp(axisInfo.inc.Enable, 'off')
                    isError = true;
                    obj.Logger.warning('Motor buttons disabled for %s axis', axisName);
                    return;
                end
                
                if ~isempty(axisInfo.dec) && isprop(axisInfo.dec, 'Enable') && strcmp(axisInfo.dec.Enable, 'off')
                    isError = true;
                    obj.Logger.warning('Motor buttons disabled for %s axis', axisName);
                    return;
                end
                
            catch ME
                FoilviewUtils.logException('ScanImageManager', ME, 'Error checking motor error state');
                isError = true; % Assume error if we can't check
            end
        end
        
        function clearMotorError(~, motorFig, axisName)
            % clearMotorError - Attempt to clear motor error state
            try
                % Look for clear/reset buttons
                clearButtons = findall(motorFig, 'String', 'Clear');
                if ~isempty(clearButtons)
                    for i = 1:length(clearButtons)
                        if isprop(clearButtons(i), 'Callback') && ~isempty(clearButtons(i).Callback)
                            clearButtons(i).Callback(clearButtons(i), []);
                            obj.Logger.info('Attempted to clear motor error for %s axis', axisName);
                            pause(0.5); % Give time for error to clear
                            return;
                        end
                    end
                end
                
                % Look for reset buttons
                resetButtons = findall(motorFig, 'String', 'Reset');
                if ~isempty(resetButtons)
                    for i = 1:length(resetButtons)
                        if isprop(resetButtons(i), 'Callback') && ~isempty(resetButtons(i).Callback)
                            resetButtons(i).Callback(resetButtons(i), []);
                            obj.Logger.info('Attempted to reset motor for %s axis', axisName);
                            pause(0.5); % Give time for reset
                            return;
                        end
                    end
                end
                
                obj.Logger.warning('No clear/reset buttons found for %s axis', axisName);
                
            catch ME
                FoilviewUtils.logException('ScanImageManager', ME, 'Error clearing motor error');
            end
        end

        function zStep = getZStepSizeFromGUI(obj)
            % * Gets the current Z step size from the ScanImage Motor Controls GUI
            zStep = NaN;
            try
                motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                if isempty(motorFig)
                    return;
                end
                zStepField = findall(motorFig, 'Tag', 'Zstep');
                if ~isempty(zStepField)
                    zStep = str2double(zStepField.String);
                    if isnan(zStep)
                        zStep = NaN;
                    end
                end
            catch ME
                FoilviewUtils.logException('ScanImageManager', ME, 'getZStepSizeFromGUI failed');
            end
            obj.ZStepSize = zStep;
        end

        function setZStepSizeInGUI(obj, value)
            % * Sets the Z step size in the ScanImage Motor Controls GUI and updates cache
            try
                motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                if isempty(motorFig)
                    return;
                end
                zStepField = findall(motorFig, 'Tag', 'Zstep');
                if ~isempty(zStepField)
                    zStepField.String = num2str(value);
                    % * Shift focus to another control to trigger update
                    allControls = findall(motorFig, 'Type', 'uicontrol');
                    foundOther = false;
                    for k = 1:length(allControls)
                        if allControls(k) ~= zStepField
                            uicontrol(allControls(k));
                            foundOther = true;
                            break;
                        end
                    end
                    if ~foundOther
                        FoilviewUtils.warn('ScanImageManager', 'No other control found to shift focus after setting Z step size.');
                    end
                end
                obj.ZStepSize = value;
            catch ME
                FoilviewUtils.logException('ScanImageManager', ME, 'setZStepSizeInGUI failed');
            end
        end
    end
end 