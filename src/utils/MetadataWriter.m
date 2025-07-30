classdef MetadataWriter
    % MetadataWriter - Shared utility class for metadata writing operations
    % This class extracts common metadata writing logic to eliminate duplication
    % between ScanImageManager and MetadataService
    
    methods (Static)
        function success = writeMetadataToFile(metadata, filePath, verbose)
            % Write metadata to CSV file with common formatting and error handling
            % metadata: metadata structure to write
            % filePath: path to the metadata file
            % verbose: whether to print status messages
            
            if nargin < 3
                verbose = false;
            end
            
            success = false;
            try
                if isempty(filePath) || ~exist(fileparts(filePath), 'dir')
                    return;
                end
                
                % Extract bookmark fields with defaults
                bookmarkFields = MetadataWriter.extractBookmarkFields(metadata);
                
                % Format metadata string
                metadataStr = MetadataWriter.formatMetadataString(metadata, bookmarkFields);
                
                if verbose
                    fprintf('Writing to file: %s\n', filePath);
                end
                
                % Write to file with error handling
                success = MetadataWriter.writeToFile(filePath, metadataStr);
                
            catch ME
                FoilviewUtils.logException('MetadataWriter.writeMetadataToFile', ME);
            end
        end
        
        function bookmarkFields = extractBookmarkFields(metadata)
            % Extract bookmark fields from metadata with defaults
            % metadata: metadata structure
            % Returns: struct with bookmarkLabel, bookmarkMetricType, bookmarkMetricValue
            
            bookmarkFields = struct();
            bookmarkFields.bookmarkLabel = '';
            bookmarkFields.bookmarkMetricType = '';
            bookmarkFields.bookmarkMetricValue = '';
            
            if isfield(metadata, 'bookmarkLabel')
                bookmarkFields.bookmarkLabel = metadata.bookmarkLabel;
            end
            if isfield(metadata, 'bookmarkMetricType')
                bookmarkFields.bookmarkMetricType = metadata.bookmarkMetricType;
            end
            if isfield(metadata, 'bookmarkMetricValue')
                bookmarkFields.bookmarkMetricValue = metadata.bookmarkMetricValue;
            end
        end
        
        function metadataStr = formatMetadataString(metadata, bookmarkFields)
            % Format metadata into CSV string
            % metadata: metadata structure
            % bookmarkFields: struct with bookmark fields
            % Returns: formatted CSV string
            
            if isstruct(metadata.feedbackValue)
                metadataStr = sprintf('%s,%s,%s,%.2f,%.1f,%d,%s,%s,%.1f,%.3f,%s,%s,%s,%.1f,%.1f,%.1f,%s,%s,%s,\n',...
                    metadata.timestamp, metadata.filename, metadata.scanner, ...
                    metadata.zoom, metadata.frameRate, metadata.averaging,...
                    metadata.resolution, metadata.fov, metadata.powerPercent, ...
                    metadata.pockelsValue, metadata.feedbackValue.modulation,...
                    metadata.feedbackValue.feedback, metadata.feedbackValue.power,...
                    metadata.zPos, metadata.xPos, metadata.yPos, ...
                    bookmarkFields.bookmarkLabel, bookmarkFields.bookmarkMetricType, bookmarkFields.bookmarkMetricValue);
            else
                % Handle case where feedbackValue is not a struct
                metadataStr = sprintf('%s,%s,%s,%.2f,%.1f,%d,%s,%s,%.1f,%.3f,NA,NA,NA,%.1f,%.1f,%.1f,%s,%s,%s,\n',...
                    metadata.timestamp, metadata.filename, metadata.scanner, ...
                    metadata.zoom, metadata.frameRate, metadata.averaging,...
                    metadata.resolution, metadata.fov, metadata.powerPercent, ...
                    metadata.pockelsValue, metadata.zPos, metadata.xPos, metadata.yPos, ...
                    bookmarkFields.bookmarkLabel, bookmarkFields.bookmarkMetricType, bookmarkFields.bookmarkMetricValue);
            end
        end
        
        function success = writeToFile(filePath, content)
            % Write content to file with error handling
            % filePath: path to the file
            % content: string content to write
            % Returns: boolean success status
            
            success = false;
            fid = -1;
            
            try
                fid = fopen(filePath, 'a');
                if fid == -1
                    return;
                end
                
                fprintf(fid, content);
                fclose(fid);
                success = true;
                
            catch ME
                if fid ~= -1
                    fclose(fid);
                end
                FoilviewUtils.logException('MetadataWriter.writeToFile', ME);
            end
        end
    end
end 