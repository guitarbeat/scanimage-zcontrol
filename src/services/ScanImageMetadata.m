classdef ScanImageMetadata < handle
    %SCANIMAGEMETADATA ScanImage metadata collection and logging service
    %   Handles metadata collection, processing, and file writing
    %   Extracted from ScanImageManager for better separation of concerns
    
    properties (Access = private)
        MetadataFile
        LastFrameTime
        Logger
    end
    
    methods
        function obj = ScanImageMetadata()
            obj.MetadataFile = [];
            obj.LastFrameTime = [];
            obj.Logger = LoggingService('ScanImageMetadata', 'SuppressInitMessage', true);
        end
        
        function setMetadataFile(obj, filePath)
            %SETMETADATAFILE Set the metadata file path
            obj.MetadataFile = filePath;
        end
        
        function saveImageMetadata(obj, src, hSI, metadataFile, simulationMode, foilviewApp)
            %SAVEIMAGEMETADATA Logs metadata for each acquired frame
            try
                % Skip frames that are too close together (max 5 frames/sec for metadata logging)
                if ~isempty(obj.LastFrameTime) && (datetime('now') - obj.LastFrameTime) < seconds(0.2)
                    return;
                end
                obj.LastFrameTime = datetime('now');
                
                if simulationMode
                    if ~isempty(foilviewApp)
                        foilviewApp.collectSimulatedMetadata();
                    end
                    return;
                end
                
                % Get handles with minimal overhead
                if isempty(hSI) || isempty(metadataFile)
                    [hSI, metadataFile] = obj.getHandles(src);
                    if isempty(metadataFile)
                        return; % Skip if no metadata file is configured
                    end
                end
                
                % Check validity and mode with minimal overhead
                if ~obj.isValidFrame(hSI) || ~obj.isGrabMode(hSI)
                    return;
                end
                
                % Collect metadata efficiently
                metadata = obj.collectMetadata(hSI);
                
                % Write to file with error handling
                if ~isempty(metadata)
                    obj.writeMetadataToFile(metadata, metadataFile, false);
                end
                
            catch ME
                % Only report serious errors, not routine failures
                if contains(ME.message, 'Permission denied') || contains(ME.message, 'No such file')
                    % Reset persistent variables to force rechecking
                    hSI = [];
                    metadataFile = [];
                else
                    warning('%s: %s', ME.identifier, ME.message);
                end
            end
        end
        
        function metadata = collectMetadata(obj, hSI)
            %COLLECTMETADATA Collect all metadata in a single function for efficiency
            try
                if isempty(hSI)
                    metadata = [];
                    return;
                end
                
                % Initialize metadata structure
                metadata = struct();
                metadata.timestamp = datetime('now');
                
                % Get basic acquisition info
                if isprop(hSI, 'hScan2D') && ~isempty(hSI.hScan2D)
                    metadata.scanMode = obj.getStringProperty(hSI.hScan2D, 'scanMode', 'unknown');
                    metadata.bidirectional = obj.getBooleanProperty(hSI.hScan2D, 'bidirectional', false);
                end
                
                % Get resolution info
                metadata.resolution = obj.getResolution(hSI);
                
                % Get laser power info
                metadata.laserPower = obj.getLaserPowerInfo(hSI);
                
                % Get motor positions
                metadata.motorPositions = obj.getMotorPositions(hSI);
                
                % Get acquisition settings
                if isprop(hSI, 'hStackManager') && ~isempty(hSI.hStackManager)
                    metadata.stackSettings = struct();
                    metadata.stackSettings.enable = obj.getBooleanProperty(hSI.hStackManager, 'enable', false);
                    metadata.stackSettings.numSlices = obj.getNumericProperty(hSI.hStackManager, 'numSlices', 1);
                    metadata.stackSettings.stackZStepSize = obj.getNumericProperty(hSI.hStackManager, 'stackZStepSize', 0);
                end
                
                % Get timing info
                if isprop(hSI, 'hRoiManager') && ~isempty(hSI.hRoiManager)
                    metadata.timing = struct();
                    metadata.timing.scanFrameRate = obj.getNumericProperty(hSI.hRoiManager, 'scanFrameRate', 0);
                    metadata.timing.scanFramePeriod = obj.getNumericProperty(hSI.hRoiManager, 'scanFramePeriod', 0);
                end
                
            catch ME
                FoilviewUtils.logException('ScanImageMetadata', ME, 'Metadata collection failed');
                metadata = [];
            end
        end
        
        function resolution = getResolution(obj, hSI)
            %GETRESOLUTION Get image resolution information
            try
                pixels = obj.getNumericProperty(hSI.hRoiManager, 'pixelsPerLine', 512);
                lines = obj.getNumericProperty(hSI.hRoiManager, 'linesPerFrame', 512);
                
                resolution = struct();
                resolution.pixelsPerLine = pixels;
                resolution.linesPerFrame = lines;
                resolution.totalPixels = pixels * lines;
                
                % Get physical dimensions if available
                if isprop(hSI.hRoiManager, 'scanAngleMultiplierSlow') && isprop(hSI.hRoiManager, 'scanAngleMultiplierFast')
                    resolution.scanAngleX = obj.getNumericProperty(hSI.hRoiManager, 'scanAngleMultiplierFast', 1);
                    resolution.scanAngleY = obj.getNumericProperty(hSI.hRoiManager, 'scanAngleMultiplierSlow', 1);
                end
                
            catch ME
                FoilviewUtils.logException('ScanImageMetadata', ME, 'Error getting resolution');
                resolution = struct('pixelsPerLine', 512, 'linesPerFrame', 512, 'totalPixels', 262144);
            end
        end
        
        function powerInfo = getLaserPowerInfo(obj, hSI)
            %GETLASERPOWERINFO Get laser power information
            powerInfo = struct('powerPercent', 0, 'pockelsValue', 0, 'laserPower', 0);
            
            try
                if isprop(hSI, 'hBeams') && ~isempty(hSI.hBeams)
                    % Get power percentage
                    if isprop(hSI.hBeams, 'powers') && ~isempty(hSI.hBeams.powers)
                        powers = hSI.hBeams.powers;
                        if ~isempty(powers) && isnumeric(powers)
                            powerInfo.powerPercent = powers(1);
                        end
                    end
                    
                    % Get Pockels cell value
                    if isprop(hSI.hBeams, 'pockelsValue') && ~isempty(hSI.hBeams.pockelsValue)
                        pockels = hSI.hBeams.pockelsValue;
                        if ~isempty(pockels) && isnumeric(pockels)
                            powerInfo.pockelsValue = pockels(1);
                        end
                    end
                end
                
            catch ME
                FoilviewUtils.logException('ScanImageMetadata', ME, 'Error getting laser power info');
            end
        end
        
        function motorPositions = getMotorPositions(obj, hSI)
            %GETMOTORPOSITIONS Get motor position information
            motorPositions = struct('x', 0, 'y', 0, 'z', 0);
            
            try
                if isprop(hSI, 'hMotors') && ~isempty(hSI.hMotors)
                    if isprop(hSI.hMotors, 'axesPosition') && ~isempty(hSI.hMotors.axesPosition)
                        pos = hSI.hMotors.axesPosition;
                        if numel(pos) >= 3 && all(isfinite(pos))
                            motorPositions.x = pos(2);
                            motorPositions.y = pos(1);
                            motorPositions.z = pos(3);
                        end
                    elseif isprop(hSI.hMotors, 'motorPosition') && ~isempty(hSI.hMotors.motorPosition)
                        pos = hSI.hMotors.motorPosition;
                        if numel(pos) >= 3 && all(isfinite(pos))
                            motorPositions.x = pos(2);
                            motorPositions.y = pos(1);
                            motorPositions.z = pos(3);
                        end
                    end
                end
                
            catch ME
                FoilviewUtils.logException('ScanImageMetadata', ME, 'Error getting motor positions');
            end
        end
        
        function writeMetadataToFile(obj, metadata, filePath, append)
            %WRITEMETADATATOFILE Write metadata to file
            if nargin < 4
                append = true;
            end
            
            try
                if isempty(metadata) || isempty(filePath)
                    return;
                end
                
                % Convert metadata to JSON string
                jsonStr = jsonencode(metadata);
                
                % Write to file
                if append
                    fileID = fopen(filePath, 'a');
                else
                    fileID = fopen(filePath, 'w');
                end
                
                if fileID == -1
                    obj.Logger.error('Could not open metadata file: %s', filePath);
                    return;
                end
                
                fprintf(fileID, '%s\n', jsonStr);
                fclose(fileID);
                
            catch ME
                obj.Logger.error('Error writing metadata to file: %s', ME.message);
            end
        end
        
        function cleanupMetadataLogging(obj)
            %CLEANUPMETADATALOGGING Cleanup metadata logging resources
            obj.LastFrameTime = [];
            obj.Logger.info('Metadata logging cleanup completed');
        end
        
        function [hSI, metadataFile] = getHandles(obj, src)
            %GETHANDLES Get handles with minimal overhead
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
            %ISVALIDFRAME Check if frame is valid for metadata logging
            valid = ~isempty(hSI) && isprop(hSI, 'hScan2D') && ~isempty(hSI.hScan2D) && ...
                    isprop(hSI.hScan2D, 'logFileStem') && ~isempty(hSI.hScan2D.logFileStem);
        end
        
        function isGrab = isGrabMode(obj, hSI)
            %ISGRABMODE Check if we're in GRAB mode vs FOCUS mode
            try
                acqMode = hSI.acqState;
                isGrab = strcmpi(acqMode, 'grab');
            catch
                isGrab = false;
            end
        end
    end
    
    methods (Access = private)
        function value = getNumericProperty(obj, object, propertyName, defaultValue)
            %GETNUMERICPROPERTY Safely get numeric property with default
            try
                if isprop(object, propertyName) && ~isempty(object.(propertyName))
                    value = double(object.(propertyName));
                    if ~isfinite(value)
                        value = defaultValue;
                    end
                else
                    value = defaultValue;
                end
            catch
                value = defaultValue;
            end
        end
        
        function value = getStringProperty(obj, object, propertyName, defaultValue)
            %GETSTRINGPROPERTY Safely get string property with default
            try
                if isprop(object, propertyName) && ~isempty(object.(propertyName))
                    value = char(object.(propertyName));
                else
                    value = defaultValue;
                end
            catch
                value = defaultValue;
            end
        end
        
        function value = getBooleanProperty(obj, object, propertyName, defaultValue)
            %GETBOOLEANPROPERTY Safely get boolean property with default
            try
                if isprop(object, propertyName) && ~isempty(object.(propertyName))
                    value = logical(object.(propertyName));
                else
                    value = defaultValue;
                end
            catch
                value = defaultValue;
            end
        end
    end
end