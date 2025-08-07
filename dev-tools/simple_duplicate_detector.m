%==============================================================================
% SIMPLE_DUPLICATE_DETECTOR.M
%==============================================================================
% Simple and robust duplicate code detection for MATLAB files.
%
% This tool identifies common duplicate patterns in your codebase:
% - Repeated error handling patterns
% - Similar logging calls
% - Common UI setup code
% - Repeated validation patterns
% - Similar file operations
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Version: 1.0
%
% Usage:
%   simple_duplicate_detector()                    % Analyze src/ directory
%   simple_duplicate_detector('verbose', true)     % Enable detailed output
%
%==============================================================================

function results = simple_duplicate_detector(varargin)
    % Parse arguments
    verbose = false;
    for i = 1:2:length(varargin)
        if strcmp(varargin{i}, 'verbose')
            verbose = varargin{i+1};
        end
    end
    
    if verbose
        fprintf('🔍 Simple Duplicate Code Detection\n');
        fprintf('📂 Scanning MATLAB files...\n');
    end
    
    % Get all MATLAB files
    files = dir('src/**/*.m');
    
    % Define patterns to look for
    patterns = {
        'Error Handling', {'try', 'catch', 'ME', 'error', 'warning'};
        'Logging', {'fprintf', 'LoggingService', 'log', 'info', 'warning', 'error'};
        'UI Setup', {'uifigure', 'uipanel', 'uibutton', 'uilabel', 'uieditfield'};
        'File Operations', {'fopen', 'fclose', 'fread', 'fwrite', 'exist', 'dir'};
        'Validation', {'validateattributes', 'assert', 'error', 'isempty', 'ischar'};
        'Timer Setup', {'timer', 'start', 'stop', 'delete'};
        'Event Handling', {'addlistener', 'event', 'callback', 'ButtonPushedFcn'};
        'Path Management', {'addpath', 'rmpath', 'fileparts', 'fullfile'};
        'String Operations', {'strtrim', 'strrep', 'strsplit', 'strjoin'};
        'Array Operations', {'length', 'size', 'numel', 'isempty'};
    };
    
    % Initialize results
    results = struct();
    results.patterns = {};
    results.files = {};
    results.recommendations = {};
    results.summary = struct();
    results.summary.totalPatterns = 0;
    results.summary.totalFiles = 0;
    results.summary.uniquePatternTypes = 0;
    
    % Analyze each file
    for i = 1:length(files)
        filePath = fullfile(files(i).folder, files(i).name);
        
        try
            % Read file content
            fid = fopen(filePath, 'r');
            if fid == -1
                continue;
            end
            
            content = '';
            while ~feof(fid)
                line = fgetl(fid);
                if ischar(line)
                    content = [content, line, newline];
                end
            end
            fclose(fid);
            
            % Analyze patterns
            for p = 1:size(patterns, 1)
                patternName = patterns{p, 1};
                keywords = patterns{p, 2};
                
                count = 0;
                for k = 1:length(keywords)
                    count = count + length(strfind(lower(content), lower(keywords{k})));
                end
                
                if count > 0
                    % Add to results
                    pattern = struct();
                    pattern.name = patternName;
                    pattern.file = files(i).name;
                    pattern.count = count;
                    pattern.keywords = keywords;
                    
                    results.patterns{end+1} = pattern;
                end
            end
            
            % Store file info
            fileInfo = struct();
            fileInfo.name = files(i).name;
            fileInfo.path = filePath;
            fileInfo.size = files(i).bytes;
            results.files{end+1} = fileInfo;
            
        catch ME
            if verbose
                fprintf('⚠️  Error reading %s: %s\n', files(i).name, ME.message);
            end
        end
    end
    
    % Analyze results
    analyzeResults(results, verbose);
    
    % Generate recommendations
    results.recommendations = generateRecommendations(results);
    
    % Export results
    exportResults(results, verbose);
    
    if verbose
        displaySummary(results);
    end
    
    if nargout == 0
        clear results;
    end
end

function analyzeResults(results, verbose)
    % Analyze the collected results
    
    % Count pattern occurrences
    patternCounts = containers.Map();
    filePatterns = containers.Map();
    
    for i = 1:length(results.patterns)
        pattern = results.patterns{i};
        
        % Count by pattern type
        if patternCounts.isKey(pattern.name)
            patternCounts(pattern.name) = patternCounts(pattern.name) + pattern.count;
        else
            patternCounts(pattern.name) = pattern.count;
        end
        
        % Count by file
        if filePatterns.isKey(pattern.file)
            filePatterns(pattern.file) = filePatterns(pattern.file) + pattern.count;
        else
            filePatterns(pattern.file) = pattern.count;
        end
    end
    
    % Find most common patterns
    if ~isempty(patternCounts)
        patternNames = keys(patternCounts);
        patternValues = values(patternCounts);
        [~, maxIdx] = max([patternValues{:}]);
        results.mostCommonPattern = patternNames{maxIdx};
        results.mostCommonCount = patternValues{maxIdx};
    end
    
    % Find files with most patterns
    if ~isempty(filePatterns)
        fileNames = keys(filePatterns);
        fileValues = values(filePatterns);
        [~, maxIdx] = max([fileValues{:}]);
        results.mostPatternFile = fileNames{maxIdx};
        results.mostPatternCount = fileValues{maxIdx};
    end
    
    % Calculate statistics
    results.summary.totalPatterns = length(results.patterns);
    results.summary.totalFiles = length(results.files);
    results.summary.uniquePatternTypes = length(patternCounts);
    
    if verbose
            fprintf('📊 Found %d pattern instances across %d files\n', ...
        results.summary.totalPatterns, results.summary.totalFiles);
    end
end

function recommendations = generateRecommendations(results)
    % Generate recommendations based on findings
    recommendations = {};
    
    % Check for high pattern counts
    if isfield(results, 'mostCommonCount') && results.mostCommonCount > 10
        recommendations{end+1} = sprintf('Create utility class for %s (found %d times)', ...
            results.mostCommonPattern, results.mostCommonCount);
    end
    
    % Check for files with many patterns
    if isfield(results, 'mostPatternCount') && results.mostPatternCount > 20
        recommendations{end+1} = sprintf('Refactor %s - has %d pattern instances', ...
            results.mostPatternFile, results.mostPatternCount);
    end
    
    % General recommendations
    if results.summary.totalPatterns > 50
        recommendations{end+1} = 'Consider implementing shared utility classes';
        recommendations{end+1} = 'Create base classes for common patterns';
        recommendations{end+1} = 'Implement configuration-driven approach';
    end
    
    % Specific pattern recommendations
    patternTypes = {};
    for i = 1:length(results.patterns)
        patternTypes{end+1} = results.patterns{i}.name;
    end
    
    if any(strcmp(patternTypes, 'Error Handling'))
        recommendations{end+1} = 'Create centralized error handling service';
    end
    
    if any(strcmp(patternTypes, 'Logging'))
        recommendations{end+1} = 'Ensure consistent logging service usage';
    end
    
    if any(strcmp(patternTypes, 'UI Setup'))
        recommendations{end+1} = 'Create UI component factory for common patterns';
    end
    
    if any(strcmp(patternTypes, 'File Operations'))
        recommendations{end+1} = 'Implement file operation utilities';
    end
    
    if any(strcmp(patternTypes, 'Validation'))
        recommendations{end+1} = 'Create validation utility functions';
    end
end

function exportResults(results, verbose)
    % Export results to file
    try
        % Create output directory
        if ~exist('dev-tools/output', 'dir')
            mkdir('dev-tools/output');
        end
        
        % Generate filename
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        filename = fullfile('dev-tools', 'output', sprintf('simple_duplicate_analysis_%s.txt', timestamp));
        
        % Write results
        fid = fopen(filename, 'w');
        if fid == -1
            error('Could not create output file');
        end
        
        fprintf(fid, 'SIMPLE DUPLICATE CODE ANALYSIS\n');
        fprintf(fid, 'Generated: %s\n\n', datestr(now));
        
        fprintf(fid, 'SUMMARY\n');
        fprintf(fid, '=======\n');
        fprintf(fid, 'Total pattern instances: %d\n', results.summary.totalPatterns);
        fprintf(fid, 'Total files analyzed: %d\n', results.summary.totalFiles);
        fprintf(fid, 'Unique pattern types: %d\n', results.summary.uniquePatternTypes);
        
        if isfield(results, 'mostCommonPattern')
            fprintf(fid, 'Most common pattern: %s (%d instances)\n', ...
                results.mostCommonPattern, results.mostCommonCount);
        end
        
        if isfield(results, 'mostPatternFile')
            fprintf(fid, 'File with most patterns: %s (%d instances)\n', ...
                results.mostPatternFile, results.mostPatternCount);
        end
        
        fprintf(fid, '\nPATTERN BREAKDOWN\n');
        fprintf(fid, '=================\n');
        
        % Group by pattern type
        patternGroups = containers.Map();
        for i = 1:length(results.patterns)
            pattern = results.patterns{i};
            if patternGroups.isKey(pattern.name)
                patternGroups(pattern.name) = patternGroups(pattern.name) + pattern.count;
            else
                patternGroups(pattern.name) = pattern.count;
            end
        end
        
        % Sort by count
        if ~isempty(patternGroups)
            patternNames = keys(patternGroups);
            patternValues = values(patternGroups);
            [counts, sortIdx] = sort([patternValues{:}], 'descend');
            
            for i = 1:length(patternNames)
                fprintf(fid, '%s: %d instances\n', patternNames{sortIdx(i)}, counts(i));
            end
        end
        
        fprintf(fid, '\nRECOMMENDATIONS\n');
        fprintf(fid, '===============\n');
        for i = 1:length(results.recommendations)
            fprintf(fid, '%d. %s\n', i, results.recommendations{i});
        end
        
        fclose(fid);
        
        if verbose
            fprintf('✅ Results exported to: %s\n', filename);
        end
        
    catch ME
        if verbose
            fprintf('❌ Error exporting results: %s\n', ME.message);
        end
    end
end

function displaySummary(results)
    % Display summary to console
    fprintf('\n📊 SIMPLE DUPLICATE ANALYSIS SUMMARY\n');
    fprintf('=====================================\n');
    fprintf('🔍 Pattern instances found: %d\n', results.summary.totalPatterns);
    fprintf('📁 Files analyzed: %d\n', results.summary.totalFiles);
    fprintf('🎯 Unique pattern types: %d\n', results.summary.uniquePatternTypes);
    
    if isfield(results, 'mostCommonPattern')
        fprintf('🏆 Most common pattern: %s (%d instances)\n', ...
            results.mostCommonPattern, results.mostCommonCount);
    end
    
    if isfield(results, 'mostPatternFile')
        fprintf('📁 File with most patterns: %s (%d instances)\n', ...
            results.mostPatternFile, results.mostPatternCount);
    end
    
    fprintf('\n💡 Key recommendations:\n');
    for i = 1:min(length(results.recommendations), 3)
        fprintf('   • %s\n', results.recommendations{i});
    end
end
