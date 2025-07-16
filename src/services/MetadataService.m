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
        
        function success = writeMetadataToFile(metadata, filePath, append)
            % Write metadata to CSV file
            if nargin < 3
                append = true;
            end
            
            success = false;
            try
                if isempty(filePath) || ~exist(fileparts(filePath), 'dir')
                    return;
                end
                
                % Convert struct to table for easier CSV writing
                metadataTable = struct2table(metadata);
                
                if append && exist(filePath, 'file')
                    writetable(metadataTable, filePath, 'WriteMode', 'append');
                else
                    writetable(metadataTable, filePath);
                end
                
                success = true;
            catch ME
                FoilviewUtils.logException('MetadataService', ME);
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
            
            scannerInfo.zoom = 1.0;
            scannerInfo.frameRate = 30.0;
            scannerInfo.averaging = 1;
            scannerInfo.resolution = '512x512';
            scannerInfo.fov = '100.0x100.0';
            scannerInfo.powerPercent = 50.0;
            scannerInfo.pockelsValue = 0.5;
            scannerInfo.feedbackValue = struct('modulation', '2.5', 'feedback', '1.2', 'power', '0.025');
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
    end
end