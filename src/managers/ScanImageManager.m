classdef ScanImageManager < handle
    % ScanImageManager - Manages ScanImage integration and metadata logging
    % This class handles the integration with ScanImage and manages metadata
    % logging for acquired frames.
    
    properties (Access = private)
        LastFrameTime
        MetadataFile
        HSI
        IsInitialized = false
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
        
        function initialize(obj)
            % Initialize the manager and set up event listeners
            try
                obj.HSI = evalin('base', 'hSI');
                obj.MetadataFile = evalin('base', 'metadataFilePath');
                obj.IsInitialized = true;
                
                % Set up event listeners for ScanImage
                if ~isempty(obj.HSI)
                    addlistener(obj.HSI, 'frameAcquired', @(src, evt) obj.onFrameAcquired(src, evt));
                    addlistener(obj.HSI, 'acqDone', @(src, evt) obj.onAcquisitionDone(src, evt));
                end
            catch ME
                warning('%s: %s', ME.identifier, ME.message);
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
                metadataStr = sprintf('%s,%s,%s,%.2f,%.1f,%d,%s,%s,%.1f,%.3f,%s,%s,%s,%.1f,%.1f,%.1f,\n',...
                    metadata.timestamp, metadata.filename, metadata.scanner, ...
                    metadata.zoom, metadata.frameRate, metadata.averaging,...
                    metadata.resolution, metadata.fov, metadata.powerPercent, ...
                    metadata.pockelsValue, metadata.feedbackValue.modulation,...
                    metadata.feedbackValue.feedback, metadata.feedbackValue.power,...
                    metadata.zPos, metadata.xPos, metadata.yPos);
                
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
end 