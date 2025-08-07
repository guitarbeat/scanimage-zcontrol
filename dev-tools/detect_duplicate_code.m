%==============================================================================
% DETECT_DUPLICATE_CODE.M
%==============================================================================
% Advanced duplicate code detection tool for MATLAB codebase analysis.
%
% This tool identifies copy-pasted code patterns, similar functions,
% and code duplication across your MATLAB project. It uses multiple
% detection strategies to find both exact duplicates and similar code.
%
% Detection Strategies:
%   - Exact string matching (copy-paste detection)
%   - Similar function signatures
%   - Common code patterns
%   - Repeated utility functions
%   - Similar error handling patterns
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Version: 1.0
%
% Usage:
%   detect_duplicate_code()                    % Analyze src/ directory
%   detect_duplicate_code('verbose', true)     % Enable detailed output
%   detect_duplicate_code('minLength', 10)     % Minimum duplicate length
%   detect_duplicate_code('similarity', 0.8)   % Similarity threshold
%
%==============================================================================

function results = detect_duplicate_code(varargin)
    % Parse input arguments
    config = parseArguments(varargin);
    
    % Initialize results structure
    results = struct();
    results.summary = struct();
    results.duplicates = {};
    results.similarFunctions = {};
    results.commonPatterns = {};
    results.recommendations = {};
    
    % Get all MATLAB files
    files = getAllMatlabFiles(config.path);
    
    if config.verbose
        fprintf('🔍 Duplicate Code Detection Tool\n');
        fprintf('📂 Scanning %d MATLAB files...\n', length(files));
        progressBar = waitbar(0, 'Analyzing files...', 'Name', 'Duplicate Detection');
    end
    
    % Extract code blocks from all files
    allCodeBlocks = {};
    fileMap = containers.Map();
    
    for i = 1:length(files)
        if config.verbose && exist('progressBar', 'var')
            waitbar(i/length(files), progressBar, sprintf('Analyzing %s...', files(i).name));
        end
        
        [blocks, fileInfo] = extractCodeBlocks(fullfile(files(i).folder, files(i).name), config);
        
        % Store blocks with file context
        for j = 1:length(blocks)
            blocks{j}.file = files(i).name;
            blocks{j}.filePath = fullfile(files(i).folder, files(i).name);
            blocks{j}.lineStart = blocks{j}.lineStart;
            blocks{j}.lineEnd = blocks{j}.lineEnd;
        end
        
        allCodeBlocks = [allCodeBlocks, blocks];
        fileMap(files(i).name) = fileInfo;
    end
    
    if config.verbose && exist('progressBar', 'var')
        close(progressBar);
    end
    
    % Find exact duplicates
    exactDuplicates = findExactDuplicates(allCodeBlocks, config);
    
    % Find similar functions
    similarFunctions = findSimilarFunctions(allCodeBlocks, config);
    
    % Find common patterns
    commonPatterns = findCommonPatterns(allCodeBlocks, config);
    
    % Generate recommendations
    recommendations = generateRecommendations(exactDuplicates, similarFunctions, commonPatterns, config);
    
    % Compile results
    results.duplicates = exactDuplicates;
    results.similarFunctions = similarFunctions;
    results.commonPatterns = commonPatterns;
    results.recommendations = recommendations;
    results.summary = createSummary(exactDuplicates, similarFunctions, commonPatterns, fileMap);
    
    % Export results
    exportResults(results, config);
    
    % Display summary
    displaySummary(results, config);
    
    if nargout == 0
        clear results;
    end
end

function config = parseArguments(args)
    % Parse command line arguments
    config = struct();
    config.path = 'src/';
    config.verbose = false;
    config.minLength = 5;      % Minimum lines for duplicate
    config.similarity = 0.8;   % Similarity threshold
    config.outputFile = '';
    config.ignoreComments = true;
    config.ignoreWhitespace = true;
    
    for i = 1:2:length(args)
        switch lower(args{i})
            case 'path'
                config.path = args{i+1};
            case 'verbose'
                config.verbose = args{i+1};
            case 'minlength'
                config.minLength = args{i+1};
            case 'similarity'
                config.similarity = args{i+1};
            case 'outputfile'
                config.outputFile = args{i+1};
            case 'ignorecomments'
                config.ignoreComments = args{i+1};
            case 'ignorewhitespace'
                config.ignoreWhitespace = args{i+1};
        end
    end
    
    % Set default output file
    if isempty(config.outputFile)
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        config.outputFile = fullfile('dev-tools', 'output', sprintf('duplicate_code_analysis_%s.txt', timestamp));
    end
end

function files = getAllMatlabFiles(path)
    % Get all MATLAB files in the specified path
    files = dir(fullfile(path, '**/*.m'));
    
    % Filter out test files and temporary files
    excludePatterns = {'test_', '_test', 'temp_', 'tmp_'};
    validFiles = true(length(files), 1);
    
    for i = 1:length(files)
        filename = lower(files(i).name);
        for j = 1:length(excludePatterns)
            if contains(filename, excludePatterns{j})
                validFiles(i) = false;
                break;
            end
        end
    end
    
    files = files(validFiles);
end

function [blocks, fileInfo] = extractCodeBlocks(filePath, config)
    % Extract code blocks from a MATLAB file
    blocks = {};
    fileInfo = struct('name', '', 'lines', 0, 'functions', 0, 'classes', 0);
    
    try
        % Read file content
        fid = fopen(filePath, 'r');
        if fid == -1
            if config.verbose
                fprintf('⚠️  Could not open file: %s\n', filePath);
            end
            return;
        end
        
        lines = {};
        lineNum = 1;
        while ~feof(fid)
            line = fgetl(fid);
            if ischar(line)
                lines{lineNum} = line;
                lineNum = lineNum + 1;
            end
        end
        fclose(fid);
        
        % Extract file info
        [~, fileName, ~] = fileparts(filePath);
        fileInfo.name = fileName;
        fileInfo.lines = length(lines);
        
        % Extract function blocks
        functionBlocks = extractFunctionBlocks(lines, config);
        blocks = [blocks, functionBlocks];
        
        % Extract method blocks
        methodBlocks = extractMethodBlocks(lines, config);
        blocks = [blocks, methodBlocks];
        
        % Extract common patterns
        patternBlocks = extractPatternBlocks(lines, config);
        blocks = [blocks, patternBlocks];
        
        % Update file info
        fileInfo.functions = length(functionBlocks);
        fileInfo.classes = countClasses(lines);
        
    catch ME
        if config.verbose
            fprintf('⚠️  Error reading file %s: %s\n', filePath, ME.message);
        end
        % Return empty blocks and basic file info
        [~, fileName, ~] = fileparts(filePath);
        fileInfo.name = fileName;
        fileInfo.lines = 0;
    end
end

function blocks = extractFunctionBlocks(lines, config)
    % Extract function definitions
    blocks = {};
    
    for i = 1:length(lines)
        line = strtrim(lines{i});
        
        % Look for function definitions
        if startsWith(line, 'function')
            % Find function end
            endLine = findFunctionEnd(lines, i);
            if endLine > i
                % Extract function block
                functionLines = lines(i:endLine);
                code = strjoin(functionLines, '\n');
                
                % Clean code if requested
                if config.ignoreComments
                    code = removeComments(code);
                end
                if config.ignoreWhitespace
                    code = normalizeWhitespace(code);
                end
                
                % Only include if long enough
                if length(functionLines) >= config.minLength
                    block = struct();
                    block.type = 'function';
                    block.code = code;
                    block.lineStart = i;
                    block.lineEnd = endLine;
                    block.length = length(functionLines);
                    block.name = extractFunctionName(line);
                    blocks{end+1} = block;
                end
            end
        end
    end
end

function blocks = extractMethodBlocks(lines, config)
    % Extract method definitions from classes
    blocks = {};
    inClass = false;
    classStart = 0;
    
    for i = 1:length(lines)
        line = strtrim(lines{i});
        
        % Detect class start
        if startsWith(line, 'classdef')
            inClass = true;
            classStart = i;
        elseif inClass && startsWith(line, 'end')
            inClass = false;
        elseif inClass && startsWith(line, 'function')
            % Find method end
            endLine = findMethodEnd(lines, i);
            if endLine > i
                % Extract method block
                methodLines = lines(i:endLine);
                code = strjoin(methodLines, '\n');
                
                % Clean code if requested
                if config.ignoreComments
                    code = removeComments(code);
                end
                if config.ignoreWhitespace
                    code = normalizeWhitespace(code);
                end
                
                % Only include if long enough
                if length(methodLines) >= config.minLength
                    block = struct();
                    block.type = 'method';
                    block.code = code;
                    block.lineStart = i;
                    block.lineEnd = endLine;
                    block.length = length(methodLines);
                    block.name = extractFunctionName(line);
                    blocks{end+1} = block;
                end
            end
        end
    end
end

function blocks = extractPatternBlocks(lines, config)
    % Extract common code patterns
    blocks = {};
    
    % Define common patterns to look for
    patterns = {
        'error handling', {'try', 'catch', 'ME'};
        'logging', {'fprintf', 'LoggingService', 'log'};
        'UI setup', {'uifigure', 'uipanel', 'uibutton'};
        'file operations', {'fopen', 'fclose', 'fread', 'fwrite'};
        'validation', {'validateattributes', 'assert', 'error'};
        'timer setup', {'timer', 'start', 'stop'};
        'event handling', {'addlistener', 'event', 'callback'};
    };
    
    for p = 1:size(patterns, 1)
        patternName = patterns{p, 1};
        keywords = patterns{p, 2};
        
        for i = 1:length(lines)
            line = lower(lines{i});
            if any(contains(line, keywords))
                % Extract pattern block (5 lines before and after)
                startLine = max(1, i - 5);
                endLine = min(length(lines), i + 5);
                
                patternLines = lines(startLine:endLine);
                code = strjoin(patternLines, '\n');
                
                % Clean code if requested
                if config.ignoreComments
                    code = removeComments(code);
                end
                if config.ignoreWhitespace
                    code = normalizeWhitespace(code);
                end
                
                block = struct();
                block.type = 'pattern';
                block.code = code;
                block.lineStart = startLine;
                block.lineEnd = endLine;
                block.length = length(patternLines);
                block.name = patternName;
                blocks{end+1} = block;
            end
        end
    end
end

function endLine = findFunctionEnd(lines, startLine)
    % Find the end of a function definition
    endLine = startLine;
    braceCount = 0;
    inString = false;
    
    for i = startLine:length(lines)
        line = lines{i};
        
        % Handle string literals
        for j = 1:length(line)
            if line(j) == ''''
                inString = ~inString;
            elseif ~inString
                if line(j) == '{'
                    braceCount = braceCount + 1;
                elseif line(j) == '}'
                    braceCount = braceCount - 1;
                elseif line(j) == '('
                    braceCount = braceCount + 1;
                elseif line(j) == ')'
                    braceCount = braceCount - 1;
                end
            end
        end
        
        % Check for function end
        if strtrim(line) == 'end' && braceCount == 0
            endLine = i;
            break;
        end
    end
end

function endLine = findMethodEnd(lines, startLine)
    % Find the end of a method definition
    endLine = findFunctionEnd(lines, startLine);
end

function name = extractFunctionName(line)
    % Extract function name from function definition line
    name = '';
    
    % Remove 'function' keyword
    line = strrep(line, 'function', '');
    line = strtrim(line);
    
    % Extract function name
    if contains(line, '=')
        % Handle: name = function(...)
        parts = strsplit(line, '=');
        if length(parts) >= 2
            name = strtrim(parts{1});
        end
    else
        % Handle: function name(...)
        if contains(line, '(')
            parts = strsplit(line, '(');
            if length(parts) >= 1
                name = strtrim(parts{1});
            end
        else
            name = strtrim(line);
        end
    end
end

function count = countClasses(lines)
    % Count class definitions in file
    count = 0;
    for i = 1:length(lines)
        if startsWith(strtrim(lines{i}), 'classdef')
            count = count + 1;
        end
    end
end

function code = removeComments(code)
    % Remove MATLAB comments from code
    lines = strsplit(code, '\n');
    cleanedLines = {};
    
    for i = 1:length(lines)
        line = lines{i};
        
        % Remove line comments
        commentPos = strfind(line, '%');
        if ~isempty(commentPos)
            line = line(1:commentPos(1)-1);
        end
        
        % Only keep non-empty lines
        if ~isempty(strtrim(line))
            cleanedLines{end+1} = line;
        end
    end
    
    code = strjoin(cleanedLines, '\n');
end

function code = normalizeWhitespace(code)
    % Normalize whitespace in code
    % Remove extra spaces and normalize indentation
    lines = strsplit(code, '\n');
    normalizedLines = {};
    
    for i = 1:length(lines)
        line = lines{i};
        
        % Remove leading/trailing whitespace
        line = strtrim(line);
        
        % Normalize multiple spaces to single space
        line = regexprep(line, '\s+', ' ');
        
        if ~isempty(line)
            normalizedLines{end+1} = line;
        end
    end
    
    code = strjoin(normalizedLines, '\n');
end

function duplicates = findExactDuplicates(blocks, config)
    % Find exact duplicate code blocks
    duplicates = {};
    
    for i = 1:length(blocks)
        for j = i+1:length(blocks)
            if strcmp(blocks{i}.code, blocks{j}.code)
                duplicate = struct();
                duplicate.type = 'exact';
                duplicate.block1 = blocks{i};
                duplicate.block2 = blocks{j};
                duplicate.similarity = 1.0;
                duplicate.length = blocks{i}.length;
                duplicates{end+1} = duplicate;
            end
        end
    end
    
    % Sort by length (longest first)
    if ~isempty(duplicates)
        lengths = cellfun(@(x) x.length, duplicates);
        [~, sortIdx] = sort(lengths, 'descend');
        duplicates = duplicates(sortIdx);
    end
end

function similar = findSimilarFunctions(blocks, config)
    % Find similar functions based on signature and structure
    similar = {};
    
    % Group blocks by type
    functionBlocks = {};
    methodBlocks = {};
    
    for i = 1:length(blocks)
        if strcmp(blocks{i}.type, 'function')
            functionBlocks{end+1} = blocks{i};
        elseif strcmp(blocks{i}.type, 'method')
            methodBlocks{end+1} = blocks{i};
        end
    end
    
    % Find similar functions
    similar = [similar, findSimilarInGroup(functionBlocks, config)];
    similar = [similar, findSimilarInGroup(methodBlocks, config)];
    
    % Sort by similarity score
    if ~isempty(similar)
        similarities = cellfun(@(x) x.similarity, similar);
        [~, sortIdx] = sort(similarities, 'descend');
        similar = similar(sortIdx);
    end
end

function similar = findSimilarInGroup(blocks, config)
    % Find similar blocks within a group
    similar = {};
    
    for i = 1:length(blocks)
        for j = i+1:length(blocks)
            similarity = calculateSimilarity(blocks{i}, blocks{j});
            
            if similarity >= config.similarity
                similarBlock = struct();
                similarBlock.type = 'similar';
                similarBlock.block1 = blocks{i};
                similarBlock.block2 = blocks{j};
                similarBlock.similarity = similarity;
                similarBlock.length = min(blocks{i}.length, blocks{j}.length);
                similar{end+1} = similarBlock;
            end
        end
    end
end

function similarity = calculateSimilarity(block1, block2)
    % Calculate similarity between two code blocks
    code1 = block1.code;
    code2 = block2.code;
    
    % Simple similarity based on common lines
    lines1 = strsplit(code1, '\n');
    lines2 = strsplit(code2, '\n');
    
    commonLines = 0;
    totalLines = max(length(lines1), length(lines2));
    
    for i = 1:min(length(lines1), length(lines2))
        if strcmp(lines1{i}, lines2{i})
            commonLines = commonLines + 1;
        end
    end
    
    similarity = commonLines / totalLines;
end

function patterns = findCommonPatterns(blocks, config)
    % Find common code patterns
    patterns = {};
    
    % Group by pattern type
    patternBlocks = {};
    for i = 1:length(blocks)
        if strcmp(blocks{i}.type, 'pattern')
            patternBlocks{end+1} = blocks{i};
        end
    end
    
    % Count pattern occurrences
    patternCounts = containers.Map();
    
    for i = 1:length(patternBlocks)
        patternName = patternBlocks{i}.name;
        if patternCounts.isKey(patternName)
            patternCounts(patternName) = patternCounts(patternName) + 1;
        else
            patternCounts(patternName) = 1;
        end
    end
    
    % Create pattern summary
    patternNames = keys(patternCounts);
    for i = 1:length(patternNames)
        pattern = struct();
        pattern.name = patternNames{i};
        pattern.count = patternCounts(patternNames{i});
        pattern.files = {};
        
        % Find files containing this pattern
        for j = 1:length(patternBlocks)
            if strcmp(patternBlocks{j}.name, patternNames{i})
                pattern.files{end+1} = patternBlocks{j}.file;
            end
        end
        
        patterns{end+1} = pattern;
    end
    
    % Sort by count (most common first)
    if ~isempty(patterns)
        counts = cellfun(@(x) x.count, patterns);
        [~, sortIdx] = sort(counts, 'descend');
        patterns = patterns(sortIdx);
    end
end

function recommendations = generateRecommendations(duplicates, similar, patterns, config)
    % Generate recommendations based on findings
    recommendations = {};
    
    % Recommendations for exact duplicates
    if ~isempty(duplicates)
        recommendations{end+1} = 'Extract exact duplicates into shared utility functions';
        recommendations{end+1} = 'Consider creating a common library for repeated code';
    end
    
    % Recommendations for similar functions
    if ~isempty(similar)
        recommendations{end+1} = 'Refactor similar functions to use common base classes';
        recommendations{end+1} = 'Implement template methods for similar patterns';
    end
    
    % Recommendations for common patterns
    if ~isempty(patterns)
        for i = 1:length(patterns)
            if patterns{i}.count > 3
                recommendations{end+1} = sprintf('Create utility class for %s pattern (found in %d files)', ...
                    patterns{i}.name, patterns{i}.count);
            end
        end
    end
    
    % General recommendations
    recommendations{end+1} = 'Consider using dependency injection to reduce code duplication';
    recommendations{end+1} = 'Implement shared configuration management';
    recommendations{end+1} = 'Create base classes for common UI patterns';
end

function summary = createSummary(duplicates, similar, patterns, fileMap)
    % Create summary statistics
    summary = struct();
    
    summary.totalDuplicates = length(duplicates);
    summary.totalSimilar = length(similar);
    summary.totalPatterns = length(patterns);
    
    % Calculate potential savings
    totalDuplicateLines = 0;
    for i = 1:length(duplicates)
        totalDuplicateLines = totalDuplicateLines + duplicates{i}.length;
    end
    
    summary.potentialSavings = totalDuplicateLines;
    
    % Calculate total lines across all files
    totalLines = 0;
    fileKeys = keys(fileMap);
    for k = 1:length(fileKeys)
        totalLines = totalLines + fileMap(fileKeys{k}).lines;
    end
    
    if totalLines > 0
        summary.estimatedReduction = sprintf('%.1f%%', (totalDuplicateLines / totalLines) * 100);
    else
        summary.estimatedReduction = '0.0%';
    end
    
    % Most common patterns
    if ~isempty(patterns)
        summary.mostCommonPattern = patterns{1}.name;
        summary.patternCount = patterns{1}.count;
    end
    
    % Files with most duplication
    fileDuplication = containers.Map();
    for i = 1:length(duplicates)
        file1 = duplicates{i}.block1.file;
        file2 = duplicates{i}.block2.file;
        
        if fileDuplication.isKey(file1)
            fileDuplication(file1) = fileDuplication(file1) + duplicates{i}.length;
        else
            fileDuplication(file1) = duplicates{i}.length;
        end
        
        if fileDuplication.isKey(file2)
            fileDuplication(file2) = fileDuplication(file2) + duplicates{i}.length;
        else
            fileDuplication(file2) = duplicates{i}.length;
        end
    end
    
    if ~isempty(fileDuplication)
        [~, maxIdx] = max([fileDuplication.values]);
        summary.mostDuplicatedFile = keys(fileDuplication);
        summary.mostDuplicatedFile = summary.mostDuplicatedFile{maxIdx};
    end
end

function exportResults(results, config)
    % Export results to file
    try
        % Ensure output directory exists
        [outputDir, ~, ~] = fileparts(config.outputFile);
        if ~exist(outputDir, 'dir')
            mkdir(outputDir);
        end
        
        % Write results
        fid = fopen(config.outputFile, 'w');
        if fid == -1
            error('Could not create output file: %s', config.outputFile);
        end
        
        % Write header
        fprintf(fid, 'DUPLICATE CODE ANALYSIS REPORT\n');
        fprintf(fid, 'Generated: %s\n\n', datestr(now));
        
        % Write summary
        fprintf(fid, 'SUMMARY\n');
        fprintf(fid, '=======\n');
        fprintf(fid, 'Total exact duplicates: %d\n', results.summary.totalDuplicates);
        fprintf(fid, 'Total similar functions: %d\n', results.summary.totalSimilar);
        fprintf(fid, 'Total common patterns: %d\n', results.summary.totalPatterns);
        fprintf(fid, 'Potential line savings: %d\n', results.summary.potentialSavings);
        fprintf(fid, 'Estimated reduction: %s\n\n', results.summary.estimatedReduction);
        
        % Write exact duplicates
        if ~isempty(results.duplicates)
            fprintf(fid, 'EXACT DUPLICATES\n');
            fprintf(fid, '================\n');
            for i = 1:min(length(results.duplicates), 10) % Limit to top 10
                dup = results.duplicates{i};
                fprintf(fid, '%d. %s (%d lines)\n', i, dup.block1.name, dup.length);
                fprintf(fid, '   File 1: %s (lines %d-%d)\n', dup.block1.file, dup.block1.lineStart, dup.block1.lineEnd);
                fprintf(fid, '   File 2: %s (lines %d-%d)\n\n', dup.block2.file, dup.block2.lineStart, dup.block2.lineEnd);
            end
        end
        
        % Write similar functions
        if ~isempty(results.similarFunctions)
            fprintf(fid, 'SIMILAR FUNCTIONS\n');
            fprintf(fid, '=================\n');
            for i = 1:min(length(results.similarFunctions), 10) % Limit to top 10
                sim = results.similarFunctions{i};
                fprintf(fid, '%d. %s vs %s (%.1f%% similar)\n', i, sim.block1.name, sim.block2.name, sim.similarity * 100);
                fprintf(fid, '   File 1: %s\n', sim.block1.file);
                fprintf(fid, '   File 2: %s\n\n', sim.block2.file);
            end
        end
        
        % Write common patterns
        if ~isempty(results.commonPatterns)
            fprintf(fid, 'COMMON PATTERNS\n');
            fprintf(fid, '===============\n');
            for i = 1:length(results.commonPatterns)
                pattern = results.commonPatterns{i};
                fprintf(fid, '%d. %s (%d occurrences)\n', i, pattern.name, pattern.count);
                fprintf(fid, '   Files: %s\n\n', strjoin(pattern.files, ', '));
            end
        end
        
        % Write recommendations
        if ~isempty(results.recommendations)
            fprintf(fid, 'RECOMMENDATIONS\n');
            fprintf(fid, '===============\n');
            for i = 1:length(results.recommendations)
                fprintf(fid, '%d. %s\n', i, results.recommendations{i});
            end
        end
        
        fclose(fid);
        
        if config.verbose
            fprintf('✅ Results exported to: %s\n', config.outputFile);
        end
        
    catch ME
        if config.verbose
            fprintf('❌ Error exporting results: %s\n', ME.message);
        end
    end
end

function displaySummary(results, config)
    % Display summary to console
    if ~config.verbose
        return;
    end
    
    fprintf('\n📊 DUPLICATE CODE ANALYSIS SUMMARY\n');
    fprintf('====================================\n');
    fprintf('🔍 Exact duplicates found: %d\n', results.summary.totalDuplicates);
    fprintf('🔍 Similar functions found: %d\n', results.summary.totalSimilar);
    fprintf('🔍 Common patterns found: %d\n', results.summary.totalPatterns);
    fprintf('💾 Potential line savings: %d\n', results.summary.potentialSavings);
    fprintf('📉 Estimated reduction: %s\n', results.summary.estimatedReduction);
    
    if isfield(results.summary, 'mostCommonPattern')
        fprintf('🏆 Most common pattern: %s (%d occurrences)\n', ...
            results.summary.mostCommonPattern, results.summary.patternCount);
    end
    
    if isfield(results.summary, 'mostDuplicatedFile')
        fprintf('📁 File with most duplication: %s\n', results.summary.mostDuplicatedFile);
    end
    
    fprintf('\n💡 Key recommendations:\n');
    for i = 1:min(length(results.recommendations), 3)
        fprintf('   • %s\n', results.recommendations{i});
    end
    
    fprintf('\n📄 Detailed report: %s\n', config.outputFile);
end
