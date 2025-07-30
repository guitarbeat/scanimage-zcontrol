classdef MetadataService < handle
    % MetadataService - Handles all metadata logging operations
    % Pure business logic, no UI dependencies
    
    methods (Static)
        function metadata = createBookmarkMetadata(label, xPos, yPos, zPos, metricStruct, scannerInfo)
            % Create metadata structure for bookmark entries
            metadata = struct();
            
            % Basic info
            metadata.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
            metadata.filename = sprintf('bookmark_%s.tif', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
            
            % Scanner and imaging parameters
            if nargin >= 6 && ~isempty(scannerInfo)
                metadata.scanner = scannerInfo.scanner;
                metadata.zoom = scannerInfo.zoom;
                metadata.frameRate = scannerInfo.frameRate;
                metadata.averaging = scannerInfo.averaging;
                metadata.resolution = scannerInfo.resolution;
                metadata.fov = scannerInfo.fov;
                metadata.powerPercent = scannerInfo.powerPercent;
                metadata.pockelsValue = scannerInfo.pockelsValue;
                metadata.feedbackValue = scannerInfo.feedbackValue;
            else
                % Default values
                metadata.scanner = 'Unknown';
                metadata.zoom = 1.0;
                metadata.frameRate = 30.0;
                metadata.averaging = 1;
                metadata.resolution = '512x512';
                metadata.fov = '100.0x100.0';
                metadata.powerPercent = 50.0;
                metadata.pockelsValue = 0.5;
                metadata.feedbackValue = struct('modulation', 'NA', 'feedback', 'NA', 'power', 'NA');
            end
            
            % Position data
            metadata.xPos = xPos;
            metadata.yPos = yPos;
            metadata.zPos = zPos;
            
            % Bookmark information
            metadata.bookmarkLabel = label;
            if ~isempty(metricStruct) && isstruct(metricStruct)
                metadata.bookmarkMetricType = metricStruct.Type;
                metadata.bookmarkMetricValue = num2str(metricStruct.Value);
            else
                metadata.bookmarkMetricType = '';
                metadata.bookmarkMetricValue = '';
            end
        end
        
        function success = writeMetadataToFile(metadata, filePath, verbose)
            % Write metadata to CSV file (compatible with original format)
            % Use the shared MetadataWriter utility to eliminate duplication
            success = MetadataWriter.writeMetadataToFile(metadata, filePath, verbose);
        end
        
        function success = saveBookmarkMetadata(label, xPos, yPos, zPos, metricStruct, metadataFile, controller)
            % Save bookmark information to the metadata file
            % This method combines metadata creation and file writing
            success = false;
            
            try
                if isempty(metadataFile) || ~exist(fileparts(metadataFile), 'dir')
                    return;
                end
                
                % Create scanner info from controller
                scannerInfo = MetadataService.extractScannerInfo(controller);
                
                % Create metadata structure
                metadata = MetadataService.createBookmarkMetadata(label, xPos, yPos, zPos, metricStruct, scannerInfo);
                
                % Write to file
                success = MetadataService.writeMetadataToFile(metadata, metadataFile, false);
                
                if success
                    fprintf('Bookmark metadata saved: %s at X:%.1f, Y:%.1f, Z:%.1f μm\n', ...
                        label, xPos, yPos, zPos);
                end
                
            catch ME
                FoilviewUtils.logException('MetadataService.saveBookmarkMetadata', ME);
            end
        end
        
        function scannerInfo = extractScannerInfo(controller)
            % Extract scanner information from controller
            scannerInfo = struct();
            
            try
                if ~isempty(controller) && isvalid(controller)
                    if controller.SimulationMode
                        scannerInfo.scanner = 'Simulation';
                        % Use the common scanner info initialization
                        scannerInfo = MetadataService.initializeScannerInfoFields(scannerInfo, true);
                    else
                        % Try to get real values from ScanImage
                        try
                            evalin('base', 'hSI'); % Check if hSI exists
                            scannerInfo.scanner = 'ScanImage';
                            % Use the common scanner info initialization
                            scannerInfo = MetadataService.initializeScannerInfoFields(scannerInfo, false);
                        catch
                            % Fallback to simulation values
                            scannerInfo = MetadataService.createDefaultScannerInfo(true);
                        end
                    end
                else
                    % Default values if controller not available
                    scannerInfo = MetadataService.createDefaultScannerInfo(false);
                    scannerInfo.scanner = 'Unknown';
                end
                
            catch ME
                FoilviewUtils.logException('MetadataService.extractScannerInfo', ME);
                scannerInfo = MetadataService.createDefaultScannerInfo(false);
            end
        end
        
        function scannerInfo = createDefaultScannerInfo(simulationMode)
            % Create default scanner information structure
            if nargin < 1
                simulationMode = true;
            end
            
            scannerInfo = struct();
            if simulationMode
                scannerInfo.scanner = 'Simulation';
            else
                scannerInfo.scanner = 'ScanImage';
            end
            
            % Use the common scanner info initialization
            scannerInfo = MetadataService.initializeScannerInfoFields(scannerInfo, simulationMode);
        end
        
        function stats = generateSessionStats(metadataFile)
            % Generate session statistics from metadata file
            stats = struct();
            stats.frameCount = 0;
            stats.duration = 0;
            stats.avgFrameRate = 0;
            stats.fileSize = 0;
            
            try
                if ~exist(metadataFile, 'file')
                    return;
                end
                
                content = fileread(metadataFile);
                lines = regexp(content, '\r?\n', 'split');
                validLines = lines(~cellfun('isempty', lines));
                stats.frameCount = max(0, length(validLines)-1);
                
                if stats.frameCount > 0
                    timestamps = MetadataService.parseTimestamps(validLines);
                    stats.duration = MetadataService.calculateDuration(timestamps);
                    
                    if stats.duration > 0
                        stats.avgFrameRate = stats.frameCount / stats.duration;
                    end
                    
                    fileInfo = dir(metadataFile);
                    if ~isempty(fileInfo)
                        stats.fileSize = fileInfo(1).bytes / 1024; % KB
                    end
                end
                
            catch ME
                FoilviewUtils.logException('MetadataService', ME);
            end
        end
        
        function timestamps = parseTimestamps(lines)
            % Parse timestamps from metadata lines
            timestamps = {};
            try
                validLines = lines(~cellfun('isempty', lines));
                if length(validLines) > 1
                    timestamps = cell(length(validLines) - 1, 1);
                    timestampIdx = 1;
                    for i = 2:length(lines)
                        parts = strsplit(lines{i}, ',');
                        if ~isempty(parts) && ~isempty(parts{1})
                            timestamps{timestampIdx} = parts{1};
                            timestampIdx = timestampIdx + 1;
                        end
                    end
                    timestamps = timestamps(1:timestampIdx-1);
                end
            catch
                timestamps = {};
            end
        end
        
        function duration = calculateDuration(timestamps)
            % Calculate duration from timestamps
            try
                if length(timestamps) >= 2
                    startTime = datetime(timestamps{1}, 'Format', 'yyyy-MM-dd HH:mm:ss');
                    endTime = datetime(timestamps{end}, 'Format', 'yyyy-MM-dd HH:mm:ss');
                    duration = seconds(endTime - startTime);
                else
                    duration = 0;
                end
            catch
                duration = 0;
            end
        end
        
        function scannerInfo = initializeScannerInfoFields(scannerInfo, simulationMode)
            % Helper method to initialize common scanner info fields
            % This extracts the duplicated logic from extractScannerInfo and createDefaultScannerInfo
            % scannerInfo: the scanner info struct to initialize
            % simulationMode: boolean indicating if in simulation mode
            
            % Initialize common fields
            scannerInfo.zoom = 1.0;
            scannerInfo.frameRate = 30.0;
            scannerInfo.averaging = 1;
            scannerInfo.resolution = '512x512';
            scannerInfo.fov = '100.0x100.0';
            scannerInfo.powerPercent = 50.0;
            scannerInfo.pockelsValue = 0.5;
            
            % Set feedback values based on simulation mode
            if simulationMode
                scannerInfo.feedbackValue = struct('modulation', '2.5', 'feedback', '1.2', 'power', '0.025');
            else
                scannerInfo.feedbackValue = struct('modulation', 'NA', 'feedback', 'NA', 'power', 'NA');
            end
        end
    end
end