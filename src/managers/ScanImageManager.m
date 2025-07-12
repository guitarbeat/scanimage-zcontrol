classdef ScanImageManager < handle
    % ScanImageManager - Manages ScanImage integration and metadata logging
    % This class handles the integration with ScanImage and manages metadata
    % logging for acquired frames.
    
    properties (Access = private)
        LastFrameTime
        MetadataFile
        HSI
        IsInitialized = false
        SimulationMode = false
        FoilviewApp
    end
    
    methods (Access = public)
        function obj = ScanImageManager()
            % Constructor - Initialize the ScanImage manager
            obj.LastFrameTime = [];
            obj.MetadataFile = [];
            obj.HSI = [];
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
            
            try
                % Check if ScanImage is available
                obj.HSI = evalin('base', 'hSI');
                
                % Try to get metadata file path, but don't fail if it doesn't exist
                try
                    obj.MetadataFile = evalin('base', 'metadataFilePath');
                catch
                    obj.MetadataFile = [];
                end
                
                obj.SimulationMode = false;
                obj.IsInitialized = true;
                
                % Note: Event listeners for frameAcquired and acqDone are not set up
                % as these events may not be available in all ScanImage versions
                % The application will still function without automatic metadata logging
            catch ME
                warning('%s: %s', ME.identifier, ME.message);
                obj.SimulationMode = true;
                obj.IsInitialized = false;
            end
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
                warning('%s: %s', ME.identifier, ME.message);
            end
        end
        
        function [success, message] = connect(obj)
            % connect - Establishes connection to ScanImage
            % Returns success status and message for compatibility with FoilviewController
            
            try
                fprintf('ScanImageManager: Attempting to connect to ScanImage...\n');
                
                % Try to get ScanImage handle
                obj.HSI = evalin('base', 'hSI');
                
                if isempty(obj.HSI)
                    success = false;
                    message = 'ScanImage not running';
                    fprintf('ScanImageManager: %s\n', message);
                    return;
                end
                
                % Check if it's a valid ScanImage object
                if ~isobject(obj.HSI) || ~isprop(obj.HSI, 'hScan2D')
                    success = false;
                    message = 'Invalid ScanImage handle';
                    fprintf('ScanImageManager: %s\n', message);
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
                
                fprintf('ScanImageManager: Successfully connected to ScanImage\n');
                
            catch ME
                success = false;
                message = sprintf('Connection failed: %s', ME.message);
                obj.SimulationMode = true;
                obj.IsInitialized = false;
                fprintf('ScanImageManager: %s\n', message);
            end
        end
    end
    
    methods (Access = private)
        function onFrameAcquired(obj, src, evt)
            % Handle frame acquired event from ScanImage
            obj.saveImageMetadata(src, evt);
        end
        
        function onAcquisitionDone(obj, src, evt)
            % Handle acquisition done event from ScanImage
            obj.cleanupMetadataLogging();
        end
        
        function saveImageMetadata(obj, src, evt)
            % saveImageMetadata - Logs metadata for each acquired frame
            % Called by ScanImage for each frame (frameAcquired event)
            
            try
                % Skip frames that are too close together (max 5 frames/sec for metadata logging)
                if ~isempty(obj.LastFrameTime) && (now - obj.LastFrameTime) < (0.2/86400)
                    return;
                end
                obj.LastFrameTime = now;
                
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
        
        function [hSI, metadataFile] = getHandles(obj, src)
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
        
        function valid = isValidFrame(obj, hSI)
            valid = ~isempty(hSI) && isprop(hSI, 'hScan2D') && ~isempty(hSI.hScan2D) && ...
                    isprop(hSI.hScan2D, 'logFileStem') && ~isempty(hSI.hScan2D.logFileStem);
        end
        
        function isGrab = isGrabMode(obj, hSI)
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
                metadata.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
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
                
            catch ME
                warning('%s: %s', ME.identifier, ME.message);
                metadata = [];
            end
        end
        
        function scannerType = getScannerType(obj, hSI)
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
        
        function value = getNumericProperty(obj, objHandle, propName, defaultValue)
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
        
        function fov = getFOV(obj, hSI)
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
        
        function value = getLutValue(obj, beam, lutName, powerFraction)
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
        
        function position = getStagePosition(obj, hSI)
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
        
        function writeMetadataToFile(obj, metadata, metadataFile, verbose)
            if isempty(metadataFile) || ~exist(fileparts(metadataFile), 'dir')
                return;
            end
            
            try
                % Format the metadata string
                if isstruct(metadata.feedbackValue)
                    metadataStr = sprintf('%s,%s,%s,%.2f,%.1f,%d,%s,%s,%.1f,%.3f,%s,%s,%s,%.1f,%.1f,%.1f,\n',...
                        metadata.timestamp, metadata.filename, metadata.scanner, ...
                        metadata.zoom, metadata.frameRate, metadata.averaging,...
                        metadata.resolution, metadata.fov, metadata.powerPercent, ...
                        metadata.pockelsValue, metadata.feedbackValue.modulation,...
                        metadata.feedbackValue.feedback, metadata.feedbackValue.power,...
                        metadata.zPos, metadata.xPos, metadata.yPos);
                else
                    % Handle case where feedbackValue is not a struct
                    metadataStr = sprintf('%s,%s,%s,%.2f,%.1f,%d,%s,%s,%.1f,%.3f,NA,NA,NA,%.1f,%.1f,%.1f,\n',...
                        metadata.timestamp, metadata.filename, metadata.scanner, ...
                        metadata.zoom, metadata.frameRate, metadata.averaging,...
                        metadata.resolution, metadata.fov, metadata.powerPercent, ...
                        metadata.pockelsValue, metadata.zPos, metadata.xPos, metadata.yPos);
                end
                
                if verbose
                    fprintf('Writing to file: %s\n', metadataFile);
                end
                
                % Use a simple fopen/fprintf approach for speed
                fid = fopen(metadataFile, 'a');
                if fid == -1
                    return; % Silently fail if file can't be opened
                end
                
                % Write and close quickly
                fprintf(fid, metadataStr);
                fclose(fid);
            catch
                % Silently fail for performance reasons
                if exist('fid', 'var') && fid ~= -1
                    fclose(fid);
                end
            end
        end
        
        function cleanupMetadataLogging(obj)
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
                warning('%s: %s', ME.identifier, ME.message);
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
                    fprintf('Simulation: %s stage moved %.1f μm to position %.1f μm\n', axisName, microns, newPosition);
                    return;
                end
                
                if isempty(obj.HSI)
                    warning('ScanImageManager: No ScanImage handle available');
                    newPosition = 0;
                    return;
                end
                
                % Find motor controls window
                motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
                if isempty(motorFig)
                    error('Motor Controls window not found. Please ensure ScanImage Motor Controls window is open.');
                end
                
                % Check for motor error state first
                if obj.checkMotorErrorState(motorFig, axisName)
                    fprintf('ScanImageManager: Attempting to clear motor error for %s axis\n', axisName);
                    obj.clearMotorError(motorFig, axisName);
                    pause(0.5); % Wait for error to clear
                    
                    % Check again after attempting to clear
                    if obj.checkMotorErrorState(motorFig, axisName)
                        error('Motor is still in error state for %s axis. Please manually clear the error in ScanImage Motor Controls.', axisName);
                    end
                end
                
                % Get UI elements for the specified axis
                axisInfo = obj.getAxisInfo(motorFig, axisName);
                if isempty(axisInfo.etPos)
                    error('Position field not found for axis %s. Check if Motor Controls window is properly initialized.', axisName);
                end
                
                % Check current position before movement
                currentPos = str2double(axisInfo.etPos.String);
                if isnan(currentPos)
                    warning('ScanImageManager: Could not read current position for %s axis', axisName);
                    currentPos = 0;
                end
                
                % Set step size
                if ~isempty(axisInfo.step)
                    axisInfo.step.String = num2str(abs(microns));
                    if isprop(axisInfo.step, 'Callback') && ~isempty(axisInfo.step.Callback)
                        try
                            axisInfo.step.Callback(axisInfo.step, []);
                        catch ME
                            warning('ScanImageManager: Error setting step size: %s', ME.message);
                        end
                    end
                end
                
                % Determine which button to press
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
                
                % Check if button is enabled before pressing
                if isprop(buttonToPress, 'Enable') && strcmp(buttonToPress.Enable, 'off')
                    error('Motor button is disabled. The motor may be in an error state. Please check ScanImage Motor Controls.');
                end
                
                % Trigger the button callback
                if isprop(buttonToPress, 'Callback') && ~isempty(buttonToPress.Callback)
                    try
                        buttonToPress.Callback(buttonToPress, []);
                        fprintf('ScanImageManager: Triggered %s movement of %.1f μm\n', axisName, microns);
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
                
                % Wait for movement and read back position
                pause(0.2); % Wait for movement
                newPosition = str2double(axisInfo.etPos.String);
                if isnan(newPosition)
                    warning('ScanImageManager: Could not read new position for %s axis, using current position', axisName);
                    newPosition = obj.getCurrentPosition(axisName);
                end
                
                fprintf('ScanImageManager: %s stage moved %.1f μm from %.1f to %.1f μm\n', axisName, microns, currentPos, newPosition);
                
            catch ME
                errorMsg = sprintf('Movement error for %s axis: %s', axisName, ME.message);
                warning('ScanImageManager:MovementError', '%s', errorMsg);
                newPosition = obj.getCurrentPosition(axisName);
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
                
            catch ME
                warning('%s: %s', ME.identifier, ME.message);
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
        
        function axisInfo = getAxisInfo(obj, motorFig, axisName)
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
                warning('ScanImageManager:GetAxisInfoError', 'Error getting axis info for %s: %s', axisName, ME.message);
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
                    fprintf('ScanImageManager: Motor error detected in %s axis\n', axisName);
                    return;
                end
                
                % Check if movement buttons are disabled
                axisInfo = obj.getAxisInfo(motorFig, axisName);
                if ~isempty(axisInfo.inc) && isprop(axisInfo.inc, 'Enable') && strcmp(axisInfo.inc.Enable, 'off')
                    isError = true;
                    fprintf('ScanImageManager: Motor buttons disabled for %s axis\n', axisName);
                    return;
                end
                
                if ~isempty(axisInfo.dec) && isprop(axisInfo.dec, 'Enable') && strcmp(axisInfo.dec.Enable, 'off')
                    isError = true;
                    fprintf('ScanImageManager: Motor buttons disabled for %s axis\n', axisName);
                    return;
                end
                
            catch ME
                warning('ScanImageManager:CheckMotorErrorError', 'Error checking motor error state: %s', ME.message);
                isError = true; % Assume error if we can't check
            end
        end
        
        function clearMotorError(obj, motorFig, axisName)
            % clearMotorError - Attempt to clear motor error state
            try
                % Look for clear/reset buttons
                clearButtons = findall(motorFig, 'String', 'Clear');
                if ~isempty(clearButtons)
                    for i = 1:length(clearButtons)
                        if isprop(clearButtons(i), 'Callback') && ~isempty(clearButtons(i).Callback)
                            clearButtons(i).Callback(clearButtons(i), []);
                            fprintf('ScanImageManager: Attempted to clear motor error for %s axis\n', axisName);
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
                            fprintf('ScanImageManager: Attempted to reset motor for %s axis\n', axisName);
                            pause(0.5); % Give time for reset
                            return;
                        end
                    end
                end
                
                fprintf('ScanImageManager: No clear/reset buttons found for %s axis\n', axisName);
                
            catch ME
                warning('ScanImageManager:ClearMotorErrorError', 'Error clearing motor error: %s', ME.message);
            end
        end
    end
end 