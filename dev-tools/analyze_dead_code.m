function results = analyze_dead_code(varargin)
% ANALYZE_DEAD_CODE - Comprehensive dead code analysis for MATLAB projects
%
% USAGE:
%   analyze_dead_code()                    % Analyze src/ directory
%   analyze_dead_code('path', 'custom/')   % Analyze custom directory
%   analyze_dead_code('verbose', true)     % Enable detailed output
%   analyze_dead_code('export', 'json')    % Export results as JSON
%   results = analyze_dead_code()          % Return results struct
%
% FEATURES:
% - Object method calls (obj.method())
% - Static method calls (Class.method())
% - Destructor methods (automatically called)
% - Callback functions and event handlers
% - Dynamic calls via feval/str2func
% - GUI component callbacks
% - Test function detection
% - Multiple export formats (txt, json, csv)

% Parse input arguments
p = inputParser;
addParameter(p, 'path', 'src', @ischar);
addParameter(p, 'verbose', false, @islogical);
addParameter(p, 'export', 'txt', @(x) any(strcmp(x, {'txt', 'json', 'csv', 'none'})));
addParameter(p, 'includeTests', true, @islogical);
addParameter(p, 'minConfidence', 0.8, @(x) x >= 0 && x <= 1);
parse(p, varargin{:});

config = p.Results;

if config.verbose
    fprintf('🔍 Starting comprehensive dead code analysis...\n');
    fprintf('   📁 Target directory: %s\n', config.path);
    fprintf('   📊 Export format: %s\n', config.export);
    fprintf('   🧪 Include tests: %s\n', mat2str(config.includeTests));
else
    fprintf('Analyzing codebase for dead code...\n');
end

% Get all .m files in specified directory
srcPath = fullfile(pwd, config.path);
if ~exist(srcPath, 'dir')
    error('Directory "%s" not found. Run this script from the project root.', config.path);
end

files = dir(fullfile(srcPath, '**', '*.m'));

% Filter out test files if requested
if ~config.includeTests
    testPattern = '(test|Test|TEST)';
    files = files(~contains({files.name}, testPattern, 'IgnoreCase', true));
end

% Initialize data structures with better performance
allFunctions = containers.Map();
allCalls = containers.Map();
classInfo = containers.Map();
fileStats = struct('totalLines', 0, 'codeLines', 0, 'commentLines', 0);

if config.verbose
    fprintf('📂 Scanning %d files for analysis...\n', length(files));
    progressBar = waitbar(0, 'Analyzing files...', 'Name', 'Dead Code Analysis');
else
    fprintf('Scanning %d files...\n', length(files));
end

for i = 1:length(files)
    if config.verbose && exist('progressBar', 'var')
        waitbar(i/length(files), progressBar, sprintf('Analyzing %s...', files(i).name));
    end

    filePath = fullfile(files(i).folder, files(i).name);
    [funcs, calls, classData, stats] = extractFunctionsAndCalls(filePath, config.verbose);

    % Accumulate file statistics
    fileStats.totalLines = fileStats.totalLines + stats.totalLines;
    fileStats.codeLines = fileStats.codeLines + stats.codeLines;
    fileStats.commentLines = fileStats.commentLines + stats.commentLines;

    % Store functions with enhanced metadata
    storeFunctions(allFunctions, funcs, files(i).name);

    % Store function calls with enhanced context
    storeCalls(allCalls, calls);

    % Store class information
    if ~isempty(classData.name)
        classInfo(classData.name) = classData;
    end
end

if config.verbose && exist('progressBar', 'var')
    close(progressBar);
end

% Enhanced analysis with confidence scoring
[unusedFunctions, suspiciousFunctions, protectedFunctions, analysisStats] = ...
    analyzeUsagePatterns(allFunctions, allCalls, classInfo, config.minConfidence);

% Create comprehensive results structure
results = createResultsStruct(unusedFunctions, suspiciousFunctions, protectedFunctions, ...
    allFunctions, allCalls, classInfo, fileStats, analysisStats, config);

% Export results in requested format
if ~strcmp(config.export, 'none')
    exportResults(results, config.export, config.verbose);
end

if config.verbose
    fprintf('✅ Enhanced dead code analysis complete!\n');
    fprintf('   📊 Results exported as: %s\n', config.export);
    fprintf('   🎯 Code health score: %.1f%%\n', results.summary.codeHealthScore);
else
    fprintf('Enhanced dead code analysis complete. See output files for details.\n');
end

% Return results if requested
if nargout == 0
    clear results;
end
end

function storeFunctions(allFunctions, funcs, fileName)
% Store functions with enhanced metadata and duplicate handling
for j = 1:length(funcs)
    funcInfo = funcs{j};
    funcName = funcInfo.name;

    funcData = struct('file', fileName, 'type', funcInfo.type, ...
        'class', funcInfo.class, 'line', funcInfo.line, ...
        'complexity', funcInfo.complexity, 'docString', funcInfo.docString);

    if allFunctions.isKey(funcName)
        existing = allFunctions(funcName);
        existing = [existing, {funcData}];  % Preallocate-friendly concatenation %#ok<AGROW>
        allFunctions(funcName) = existing;
    else
        allFunctions(funcName) = {funcData};
    end
end
end

function storeCalls(allCalls, calls)
% Store function calls with enhanced context
for j = 1:length(calls)
    callInfo = calls{j};
    callName = callInfo.name;

    if allCalls.isKey(callName)
        existing = allCalls(callName);
        existing = [existing, {callInfo}];  % Preallocate-friendly concatenation %#ok<AGROW>
        allCalls(callName) = existing;
    else
        allCalls(callName) = {callInfo};
    end
end
end

function [functions, calls, classData, stats] = extractFunctionsAndCalls(filePath, verbose)
% Enhanced extraction with statistics and better error handling

functions = {};
calls = {};
classData = struct('name', '', 'methods', {{}}, 'properties', {{}}, 'superclasses', {{}});
stats = struct('totalLines', 0, 'codeLines', 0, 'commentLines', 0);

try
    content = fileread(filePath);
    lines = strsplit(content, '\n');
    stats.totalLines = length(lines);

    currentClass = '';
    inClassDef = false;
    inBlockComment = false;

    for i = 1:length(lines)
        line = strtrim(lines{i});

        % Track statistics
        if isempty(line)
            % Empty line - don't count
        elseif startsWith(line, '%') || inBlockComment
            stats.commentLines = stats.commentLines + 1;
            % Handle block comments
            if contains(line, '%{')
                inBlockComment = true;
            end
            if contains(line, '%}')
                inBlockComment = false;
            end
            continue;
        else
            stats.codeLines = stats.codeLines + 1;
        end

        % Skip empty lines and comments
        if isempty(line) || startsWith(line, '%') || inBlockComment
            continue;
        end

        % Detect class definition with inheritance
        classDefMatch = regexp(line, '^\s*classdef\s+(\w+)(?:\s*<\s*(.+))?', 'tokens');
        if ~isempty(classDefMatch)
            currentClass = classDefMatch{1}{1};
            classData.name = currentClass;
            if length(classDefMatch{1}) > 1 && ~isempty(classDefMatch{1}{2})
                % Parse superclasses
                superclassStr = classDefMatch{1}{2};
                classData.superclasses = strsplit(strrep(superclassStr, '&', ','), ',');
                classData.superclasses = strtrim(classData.superclasses);
            end
            inClassDef = true;
            continue;
        end

        % Find function definitions with enhanced metadata
        funcDefMatch = regexp(line, '^\s*function\s+(?:\[?[\w,\s]*\]?\s*=\s*)?(\w+)\s*\(', 'tokens');
        if ~isempty(funcDefMatch)
            funcName = funcDefMatch{1}{1};
            funcInfo = struct();
            funcInfo.name = funcName;
            funcInfo.line = i;
            funcInfo.class = currentClass;

            % Calculate basic complexity (count control structures)
            funcInfo.complexity = calculateFunctionComplexity(lines, i);

            % Extract documentation string
            funcInfo.docString = extractDocString(lines, i);

            % Determine function type with more precision
            if inClassDef
                funcInfo.type = determineMatlabMethodType(funcName, currentClass, line);
                classData.methods{end+1} = funcName;
            else
                funcInfo.type = 'function';
            end

            functions{end+1} = funcInfo; %#ok<AGROW>
        end

        % Enhanced call detection
        callsInLine = extractCallsFromLine(line, i);
        calls = [calls, callsInLine]; %#ok<AGROW>
    end

catch ME
    if verbose
        fprintf('⚠️  Warning: Could not analyze file %s: %s\n', filePath, ME.message);
    else
        fprintf('Warning: Could not analyze file %s: %s\n', filePath, ME.message);
    end
end
end

function complexity = calculateFunctionComplexity(lines, startLine)
% Calculate cyclomatic complexity for a function
complexity = 1; % Base complexity
controlKeywords = {'if', 'elseif', 'for', 'while', 'switch', 'case', 'catch', 'try'};

% Find function end
endLine = findFunctionEnd(lines, startLine);

for i = startLine:endLine
    line = strtrim(lines{i});
    if startsWith(line, '%')
        continue;
    end

    for keyword = controlKeywords
        if contains(line, keyword{1})
            complexity = complexity + 1;
        end
    end
end
end

function endLine = findFunctionEnd(lines, startLine)
% Find the end of a function definition
endLine = length(lines);
indentLevel = 0;

for i = startLine:length(lines)
    line = strtrim(lines{i});
    if startsWith(line, '%') || isempty(line)
        continue;
    end

    if startsWith(line, 'function')
        indentLevel = indentLevel + 1;
    elseif strcmp(line, 'end')
        indentLevel = indentLevel - 1;
        if indentLevel == 0
            endLine = i;
            break;
        end
    end
end
end

function docString = extractDocString(lines, funcLine)
% Extract documentation string from function
docString = '';

for i = funcLine+1:min(funcLine+10, length(lines))
    line = strtrim(lines{i});
    if startsWith(line, '%')
        if isempty(docString)
            docString = line(2:end);
        else
            docString = [docString, ' ', line(2:end)]; %#ok<AGROW>
        end
    elseif ~isempty(line)
        break;
    end
end

docString = strtrim(docString);
end

function methodType = determineMatlabMethodType(funcName, className, line)
% Determine specific MATLAB method type
if strcmp(funcName, className)
    methodType = 'constructor';
elseif strcmp(funcName, 'delete')
    methodType = 'destructor';
elseif contains(line, 'Static')
    methodType = 'static_method';
elseif startsWith(funcName, 'get') || startsWith(funcName, 'set')
    methodType = 'accessor';
else
    methodType = 'method';
end
end

function calls = extractCallsFromLine(line, lineNum)
% Extract all function calls from a single line with context
calls = {};

% Pattern 1: Regular function calls - funcName(
regularCalls = regexp(line, '(\w+)\s*\(', 'tokens');
for i = 1:length(regularCalls)
    callName = regularCalls{i}{1};
    if ~isBuiltinFunction(callName)
        callInfo = struct('name', callName, 'type', 'regular', 'line', lineNum);
        calls{end+1} = callInfo; %#ok<AGROW>
    end
end

% Pattern 2: Object method calls - obj.method(
methodCalls = regexp(line, '\w+\.(\w+)\s*\(', 'tokens');
for i = 1:length(methodCalls)
    callName = methodCalls{i}{1};
    if ~isBuiltinFunction(callName)
        callInfo = struct('name', callName, 'type', 'method', 'line', lineNum);
        calls{end+1} = callInfo; %#ok<AGROW>
    end
end

% Pattern 3: Static method calls - Class.method(
staticCalls = regexp(line, '([A-Z]\w+)\.(\w+)\s*\(', 'tokens');
for i = 1:length(staticCalls)
    callName = staticCalls{i}{2}; % Get the method name
    if ~isBuiltinFunction(callName)
        callInfo = struct('name', callName, 'type', 'static', 'class', staticCalls{i}{1}, 'line', lineNum);
        calls{end+1} = callInfo; %#ok<AGROW>
    end
end

% Pattern 4: Callback assignments - 'Callback', @obj.method or @function
callbackMatches = regexp(line, '@\w*\.?(\w+)', 'tokens');
for i = 1:length(callbackMatches)
    callName = callbackMatches{i}{1};
    if ~isBuiltinFunction(callName)
        callInfo = struct('name', callName, 'type', 'callback', 'line', lineNum);
        calls{end+1} = callInfo; %#ok<AGROW>
    end
end

% Pattern 5: String-based calls - feval, str2func patterns
stringCallMatches = regexp(line, '(?:feval|str2func)\s*\(\s*[''"](\w+)[''"]', 'tokens');
for i = 1:length(stringCallMatches)
    callName = stringCallMatches{i}{1};
    callInfo = struct('name', callName, 'type', 'dynamic', 'line', lineNum);
    calls{end+1} = callInfo; %#ok<AGROW>
end
end

function isBuiltin = isBuiltinFunction(funcName)
% Check if function name is a common MATLAB builtin or keyword
% Enhanced with more comprehensive builtin detection

% Core MATLAB functions and keywords
builtins = {'if', 'else', 'elseif', 'end', 'for', 'while', 'switch', 'case', ...
    'otherwise', 'try', 'catch', 'function', 'return', 'break', 'continue', ...
    'fprintf', 'sprintf', 'disp', 'error', 'warning', 'length', 'size', ...
    'isempty', 'exist', 'strcmp', 'strcmpi', 'strfind', 'strrep', 'strtrim', ...
    'find', 'max', 'min', 'mean', 'std', 'sum', 'sort', 'unique', ...
    'plot', 'figure', 'axes', 'xlabel', 'ylabel', 'title', 'legend', ...
    'get', 'set', 'delete', 'clear', 'clc', 'close', 'load', 'save', ...
    'dir', 'pwd', 'cd', 'mkdir', 'rmdir', 'copyfile', 'movefile', ...
    'tic', 'toc', 'pause', 'drawnow', 'timer', 'start', 'stop', ...
    'isvalid', 'isnumeric', 'ischar', 'isstring', 'isstruct', 'iscell', ...
    'class', 'isa', 'isprop', 'isfield', 'fieldnames', 'struct', ...
    'cell', 'zeros', 'ones', 'nan', 'inf', 'pi', 'rand', 'randn', ...
    'abs', 'sqrt', 'exp', 'log', 'log10', 'sin', 'cos', 'tan', ...
    'asin', 'acos', 'atan', 'atan2', 'floor', 'ceil', 'round', 'fix', ...
    'mod', 'rem', 'sign', 'real', 'imag', 'conj', 'angle', ...
    'reshape', 'repmat', 'cat', 'horzcat', 'vertcat', 'permute', ...
    'transpose', 'ctranspose', 'flipud', 'fliplr', 'rot90', ...
    'any', 'all', 'cumsum', 'cumprod', 'diff', 'gradient', ...
    'interp1', 'interp2', 'griddata', 'meshgrid', 'ndgrid', ...
    'linspace', 'logspace', 'eye', 'diag', 'tril', 'triu', ...
    'inv', 'pinv', 'det', 'rank', 'trace', 'norm', 'cond', ...
    'eig', 'svd', 'qr', 'lu', 'chol', 'fft', 'ifft', 'fft2', 'ifft2'};

% Check against builtin list
isBuiltin = any(strcmp(funcName, builtins));

% Additional check: try to determine if it's a builtin using MATLAB's which function
% This is more robust but slower, so we do it only if not found in our list
if ~isBuiltin
    try
        whichResult = which(funcName);
        % If it's a builtin, which() returns 'built-in' or contains 'toolbox'
        isBuiltin = contains(whichResult, 'built-in') || contains(whichResult, 'toolbox');
    catch
        % If which() fails, assume it's not a builtin
        isBuiltin = false;
    end
end
end

function [unusedFunctions, suspiciousFunctions, protectedFunctions, analysisStats] = analyzeUsagePatterns(allFunctions, allCalls, classInfo, minConfidence)
% Enhanced analysis with confidence scoring and detailed statistics

definedFunctions = keys(allFunctions);
calledFunctions = keys(allCalls);

unusedFunctions = {};
suspiciousFunctions = {};
protectedFunctions = {};

% Initialize analysis statistics
analysisStats = struct();
analysisStats.totalAnalyzed = length(definedFunctions);
analysisStats.confidenceThreshold = minConfidence;
analysisStats.callPatterns = containers.Map();
analysisStats.complexityStats = struct('mean', 0, 'max', 0, 'min', inf);

% Define protected function patterns (automatically called by MATLAB)
protectedPatterns = {'delete', 'get', 'set', 'subsref', 'subsasgn', 'display', ...
    'disp', 'char', 'string', 'double', 'logical', 'size', ...
    'length', 'end', 'numel', 'isempty', 'isequal', 'copy', ...
    'loadobj', 'saveobj', 'eq', 'ne', 'lt', 'le', 'gt', 'ge', ...
    'plus', 'minus', 'times', 'rdivide', 'ldivide', 'power', ...
    'and', 'or', 'not', 'transpose', 'ctranspose', 'clear', 'error'};

for i = 1:length(definedFunctions)
    funcName = definedFunctions{i};
    funcDefs = allFunctions(funcName);

    % Skip if this is actually a builtin function being redefined
    if isBuiltinFunction(funcName)
        protectedFunctions{end+1} = struct('name', funcName, 'reason', 'MATLAB builtin function'); %#ok<AGROW>
        continue;
    end

    % Check if function is called
    isCalled = any(strcmp(funcName, calledFunctions));

    % Check if it's a protected/special method
    isProtected = any(strcmp(funcName, protectedPatterns));

    % Check if it's a constructor (same name as class)
    isConstructor = false;
    classNames = keys(classInfo);
    for j = 1:length(classNames)
        if strcmp(funcName, classNames{j})
            isConstructor = true;
            break;
        end
    end

    % Check if it's an entry point (main function in file)
    isEntryPoint = false;
    for j = 1:length(funcDefs)
        funcDef = funcDefs{j};
        [~, fileName, ~] = fileparts(funcDef.file);
        if strcmp(funcName, fileName)
            isEntryPoint = true;
            break;
        end
    end

    % Check if it's a test function
    isTestFunction = startsWith(funcName, 'test') || endsWith(funcName, 'Test') || ...
        contains(funcName, 'Test') || startsWith(funcName, 'Test');

    % Calculate confidence score for unused classification
    confidence = calculateUnusedConfidence(funcName, funcDefs, allCalls, classInfo);

    % Update complexity statistics
    for j = 1:length(funcDefs)
        complexity = funcDefs{j}.complexity;
        analysisStats.complexityStats.mean = analysisStats.complexityStats.mean + complexity;
        analysisStats.complexityStats.max = max(analysisStats.complexityStats.max, complexity);
        analysisStats.complexityStats.min = min(analysisStats.complexityStats.min, complexity);
    end

    % Categorize the function with confidence scoring
    if isProtected || isConstructor || isEntryPoint || isTestFunction
        reasons = getProtectionReason(isProtected, isConstructor, isEntryPoint, isTestFunction);
        protectedFunctions{end+1} = struct('name', funcName, 'reason', reasons, 'confidence', 1.0); %#ok<AGROW>
    elseif ~isCalled
        if confidence >= minConfidence
            unusedFunctions{end+1} = struct('name', funcName, 'confidence', confidence, 'reasons', getUnusedReasons(funcName, funcDefs)); %#ok<AGROW>
        else
            reason = sprintf('Low confidence (%.2f) - potential dynamic usage', confidence);
            suspiciousFunctions{end+1} = struct('name', funcName, 'reason', reason, 'confidence', confidence); %#ok<AGROW>
        end
    end
end
end

function reason = getProtectionReason(isProtected, isConstructor, isEntryPoint, isTestFunction)
% Get reason why function is protected from removal
reasons = cell(1, 4);  % Preallocate maximum possible size
idx = 0;
if isProtected
    idx = idx + 1;
    reasons{idx} = 'MATLAB special method';
end
if isConstructor
    idx = idx + 1;
    reasons{idx} = 'Class constructor';
end
if isEntryPoint
    idx = idx + 1;
    reasons{idx} = 'File entry point';
end
if isTestFunction
    idx = idx + 1;
    reasons{idx} = 'Test function';
end
reasons = reasons(1:idx);  % Trim to actual size
reason = strjoin(reasons, ', ');
end



function generateEnhancedDeadCodeReport(unusedFunctions, suspiciousFunctions, protectedFunctions, allFunctions, allCalls, classInfo, ~)
% Generate enhanced report with detailed analysis and actionable insights

reportFile = 'dead_code_report.txt';
fid = fopen(reportFile, 'w');

if fid == -1
    error('Could not create report file');
end

try
    fprintf(fid, 'ENHANCED DEAD CODE ANALYSIS REPORT\n');
    fprintf(fid, '==================================\n');
    fprintf(fid, 'Generated: %s\n\n', char(datetime('now')));

    fprintf(fid, 'ANALYSIS SUMMARY\n');
    fprintf(fid, '----------------\n');
    fprintf(fid, 'Total functions defined: %d\n', length(keys(allFunctions)));
    fprintf(fid, 'Total unique function calls: %d\n', length(keys(allCalls)));
    fprintf(fid, 'Classes detected: %d\n', length(keys(classInfo)));
    fprintf(fid, 'Protected functions: %d\n', length(protectedFunctions));
    fprintf(fid, 'Suspicious functions: %d\n', length(suspiciousFunctions));
    fprintf(fid, 'Potentially unused functions: %d\n', length(unusedFunctions));

    % Calculate code health metrics
    totalFunctions = length(keys(allFunctions));
    unusedCount = length(unusedFunctions);
    codeHealthScore = round((1 - unusedCount/totalFunctions) * 100);
    fprintf(fid, 'Code health score: %d%% (%d/%d functions actively used)\n\n', ...
        codeHealthScore, totalFunctions - unusedCount, totalFunctions);

    % Report unused functions with enhanced details
    if ~isempty(unusedFunctions)
        fprintf(fid, 'POTENTIALLY UNUSED FUNCTIONS\n');
        fprintf(fid, '----------------------------\n');
        fprintf(fid, 'These functions are defined but no calls were detected:\n\n');

        % Sort unused functions by file for better organization
        [sortedFunctions, fileGroups] = sortFunctionsByFile(unusedFunctions, allFunctions);

        for i = 1:length(sortedFunctions)
            funcName = sortedFunctions{i};
            funcDefs = allFunctions(funcName);
            fprintf(fid, '• %s\n', funcName);
            for j = 1:length(funcDefs)
                funcDef = funcDefs{j};
                fprintf(fid, '  └─ %s (line %d, %s', funcDef.file, funcDef.line, funcDef.type);
                if ~isempty(funcDef.class)
                    fprintf(fid, ' in class %s', funcDef.class);
                end
                fprintf(fid, ')\n');
            end
            fprintf(fid, '\n');
        end

        % Add file-based summary for easier cleanup
        fprintf(fid, 'CLEANUP SUMMARY BY FILE\n');
        fprintf(fid, '-----------------------\n');
        fileNames = keys(fileGroups);
        for i = 1:length(fileNames)
            fileName = fileNames{i};
            funcsInFile = fileGroups(fileName);
            fprintf(fid, '• %s: %d unused function(s)\n', fileName, length(funcsInFile));
            for j = 1:length(funcsInFile)
                fprintf(fid, '  - %s\n', funcsInFile{j});
            end
        end
        fprintf(fid, '\n');
    else
        fprintf(fid, 'POTENTIALLY UNUSED FUNCTIONS\n');
        fprintf(fid, '----------------------------\n');
        fprintf(fid, 'No unused functions detected! 🎉\n\n');
    end

    % Report suspicious functions with enhanced analysis
    if ~isempty(suspiciousFunctions)
        fprintf(fid, 'SUSPICIOUS FUNCTIONS (Review Recommended)\n');
        fprintf(fid, '-----------------------------------------\n');
        fprintf(fid, 'These functions may be used dynamically or as callbacks:\n\n');

        for i = 1:length(suspiciousFunctions)
            suspFunc = suspiciousFunctions{i};
            funcName = suspFunc.name;
            funcDefs = allFunctions(funcName);
            fprintf(fid, '• %s (%s)\n', funcName, suspFunc.reason);
            for j = 1:length(funcDefs)
                funcDef = funcDefs{j};
                fprintf(fid, '  └─ %s (line %d)\n', funcDef.file, funcDef.line);
            end
            fprintf(fid, '\n');
        end
    end

    % Report protected functions with categorization
    if ~isempty(protectedFunctions)
        fprintf(fid, 'PROTECTED FUNCTIONS (Safe from Removal)\n');
        fprintf(fid, '---------------------------------------\n');
        fprintf(fid, 'These functions are automatically protected:\n\n');

        % Group protected functions by reason
        protectedByReason = containers.Map();
        for i = 1:length(protectedFunctions)
            protFunc = protectedFunctions{i};
            reason = protFunc.reason;
            if protectedByReason.isKey(reason)
                existing = protectedByReason(reason);
                existing = [existing, {protFunc.name}];  % Preallocate-friendly concatenation %#ok<AGROW>
                protectedByReason(reason) = existing;
            else
                protectedByReason(reason) = {protFunc.name};
            end
        end

        reasons = keys(protectedByReason);
        for i = 1:length(reasons)
            reason = reasons{i};
            funcs = protectedByReason(reason);
            fprintf(fid, '%s:\n', reason);
            for j = 1:length(funcs)
                fprintf(fid, '  • %s\n', funcs{j});
            end
            fprintf(fid, '\n');
        end
    end

    % Enhanced call pattern analysis
    fprintf(fid, 'CALL PATTERN ANALYSIS\n');
    fprintf(fid, '---------------------\n');
    callTypes = containers.Map();
    calledFunctions = keys(allCalls);

    for i = 1:length(calledFunctions)
        callInfos = allCalls(calledFunctions{i});
        for j = 1:length(callInfos)
            callType = callInfos{j}.type;
            if callTypes.isKey(callType)
                callTypes(callType) = callTypes(callType) + 1;
            else
                callTypes(callType) = 1;
            end
        end
    end

    callTypeNames = keys(callTypes);
    totalCalls = 0;
    for i = 1:length(callTypeNames)
        totalCalls = totalCalls + callTypes(callTypeNames{i});
    end

    for i = 1:length(callTypeNames)
        count = callTypes(callTypeNames{i});
        percentage = round((count / totalCalls) * 100);
        fprintf(fid, '• %s calls: %d (%d%%)\n', callTypeNames{i}, count, percentage);
    end
    fprintf(fid, '• Total calls analyzed: %d\n\n', totalCalls);

    % Enhanced recommendations with priority
    fprintf(fid, 'RECOMMENDATIONS (Priority Order)\n');
    fprintf(fid, '--------------------------------\n');
    fprintf(fid, '1. HIGH PRIORITY - SAFE TO REMOVE: Functions in "Potentially Unused" section\n');
    fprintf(fid, '   → Start with functions that have no dependencies\n');
    fprintf(fid, '   → Remove one function at a time and test\n\n');

    fprintf(fid, '2. MEDIUM PRIORITY - REVIEW CAREFULLY: Functions in "Suspicious" section\n');
    fprintf(fid, '   → Search codebase for string references to function names\n');
    fprintf(fid, '   → Check UI files for callback references\n');
    fprintf(fid, '   → Look for dynamic calls using feval() or str2func()\n\n');

    fprintf(fid, '3. LOW PRIORITY - DO NOT REMOVE: Functions in "Protected" section\n');
    fprintf(fid, '   → These are essential for MATLAB functionality\n');
    fprintf(fid, '   → Consider if functions are part of public API\n\n');

    % Actionable next steps with commands
    fprintf(fid, 'ACTIONABLE NEXT STEPS\n');
    fprintf(fid, '--------------------\n');
    fprintf(fid, '1. VERIFICATION COMMANDS:\n');
    fprintf(fid, '   For each unused function, run these searches:\n');
    if ~isempty(unusedFunctions)
        funcName = unusedFunctions{1}; % Use first unused function as example
        fprintf(fid, '   → grep -r "%s" src/  # Search for string references\n', funcName);
        fprintf(fid, '   → find src/ -name "*.m" -exec grep -l "feval.*%s\\|str2func.*%s" {} \\;\n', funcName, funcName);
    end
    fprintf(fid, '\n');

    fprintf(fid, '2. SAFE REMOVAL PROCESS:\n');
    fprintf(fid, '   → Create a backup branch: git checkout -b cleanup-dead-code\n');
    fprintf(fid, '   → Remove one function at a time\n');
    fprintf(fid, '   → Run tests after each removal\n');
    fprintf(fid, '   → Commit changes incrementally\n\n');

    fprintf(fid, '3. TESTING STRATEGY:\n');
    fprintf(fid, '   → Run full test suite after each function removal\n');
    fprintf(fid, '   → Test UI functionality if removing methods from UI classes\n');
    fprintf(fid, '   → Check for runtime errors in dynamic code paths\n\n');

    % Analysis limitations and warnings
    fprintf(fid, 'ANALYSIS LIMITATIONS\n');
    fprintf(fid, '-------------------\n');
    fprintf(fid, '⚠️  This analysis may miss:\n');
    fprintf(fid, '   • Functions called via eval() or evalin()\n');
    fprintf(fid, '   • Functions referenced in string arrays or cell arrays\n');
    fprintf(fid, '   • Functions called from external scripts or toolboxes\n');
    fprintf(fid, '   • Functions used as event handlers in GUI components\n');
    fprintf(fid, '   • Functions called through reflection or meta-programming\n\n');

    fprintf(fid, '✅ This analysis correctly identifies:\n');
    fprintf(fid, '   • Direct function calls\n');
    fprintf(fid, '   • Object method calls (obj.method)\n');
    fprintf(fid, '   • Static method calls (Class.method)\n');
    fprintf(fid, '   • Callback function references (@function)\n');
    fprintf(fid, '   • Dynamic calls via feval() and str2func()\n\n');

    fprintf(fid, 'FINAL NOTE: Always verify manually before removing any code.\n');
    fprintf(fid, 'When in doubt, comment out the function first and test thoroughly.\n');

catch ME
    fclose(fid);
    rethrow(ME);
end

fclose(fid);
end

function [sortedFunctions, fileGroups] = sortFunctionsByFile(unusedFunctions, allFunctions)
% Sort unused functions by file for better organization
fileGroups = containers.Map();

for i = 1:length(unusedFunctions)
    funcName = unusedFunctions{i};
    funcDefs = allFunctions(funcName);

    for j = 1:length(funcDefs)
        fileName = funcDefs{j}.file;
        if fileGroups.isKey(fileName)
            existing = fileGroups(fileName);
            existing = [existing, {funcName}];  % Preallocate-friendly concatenation %#ok<AGROW>
            fileGroups(fileName) = existing;
        else
            fileGroups(fileName) = {funcName};
        end
    end
end

% Sort functions alphabetically
sortedFunctions = sort(unusedFunctions);
end

function confidence = calculateUnusedConfidence(funcName, funcDefs, ~, ~)
% Calculate confidence score for unused function classification
confidence = 0.9; % Base confidence

% Reduce confidence for callback-like names
if endsWith(funcName, 'Callback') || endsWith(funcName, 'Fcn') || startsWith(funcName, 'on')
    confidence = confidence - 0.3;
end

% Reduce confidence for short function names (likely utilities)
if length(funcName) <= 3
    confidence = confidence - 0.2;
end

% Reduce confidence for functions with common utility patterns
utilityPatterns = {'get', 'set', 'is', 'has', 'can', 'should', 'init', 'setup', 'cleanup'};
for pattern = utilityPatterns
    if startsWith(funcName, pattern{1})
        confidence = confidence - 0.1;
        break;
    end
end

% Increase confidence for functions with high complexity (less likely to be utilities)
for i = 1:length(funcDefs)
    if isfield(funcDefs{i}, 'complexity') && funcDefs{i}.complexity > 5
        confidence = confidence + 0.1;
        break;
    end
end

% Ensure confidence is in valid range
confidence = max(0, min(1, confidence));
end

function reasons = getUnusedReasons(~, funcDefs)
% Get specific reasons why function appears unused
maxReasons = 2 + length(funcDefs) * 2;  % Preallocate based on maximum possible
reasons = cell(1, maxReasons);
idx = 0;

if length(funcDefs) > 1
    idx = idx + 1;
    reasons{idx} = 'Defined in multiple files';
end

for i = 1:length(funcDefs)
    if isfield(funcDefs{i}, 'complexity') && funcDefs{i}.complexity > 10
        idx = idx + 1;
        reasons{idx} = 'High complexity function';
    end

    if isfield(funcDefs{i}, 'docString') && ~isempty(funcDefs{i}.docString)
        idx = idx + 1;
        reasons{idx} = 'Has documentation';
    end
end

if idx == 0
    idx = 1;
    reasons{idx} = 'No direct calls found';
end

reasons = reasons(1:idx);  % Trim to actual size
end

function results = createResultsStruct(unusedFunctions, suspiciousFunctions, protectedFunctions, allFunctions, allCalls, classInfo, fileStats, analysisStats, config)
% Create comprehensive results structure
results = struct();

% Summary statistics
results.summary = struct();
results.summary.totalFunctions = length(keys(allFunctions));
results.summary.totalCalls = length(keys(allCalls));
results.summary.totalClasses = length(keys(classInfo));
results.summary.unusedCount = length(unusedFunctions);
results.summary.suspiciousCount = length(suspiciousFunctions);
results.summary.protectedCount = length(protectedFunctions);
results.summary.codeHealthScore = (1 - length(unusedFunctions)/length(keys(allFunctions))) * 100;
results.summary.analysisDate = char(datetime('now'));
results.summary.configuration = config;

% File statistics
results.fileStats = fileStats;
results.fileStats.codeToCommentRatio = fileStats.codeLines / max(1, fileStats.commentLines);

% Analysis results
results.unused = unusedFunctions;
results.suspicious = suspiciousFunctions;
results.protected = protectedFunctions;
results.analysisStats = analysisStats;

% Raw data (for advanced analysis)
results.rawData = struct();
results.rawData.functions = allFunctions;
results.rawData.calls = allCalls;
results.rawData.classes = classInfo;
end

function exportResults(results, format, verbose)
% Export results in specified format
timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd_HH-mm-ss'));

switch format
    case 'txt'
        filename = sprintf('dead_code_report_%s.txt', timestamp);
        exportToText(results, filename, verbose);
    case 'json'
        filename = sprintf('dead_code_analysis_%s.json', timestamp);
        exportToJson(results, filename, verbose);
    case 'csv'
        filename = sprintf('dead_code_summary_%s.csv', timestamp);
        exportToCsv(results, filename, verbose);
end
end

function exportToJson(results, filename, verbose)
% Export results as JSON
try
    % Convert containers.Map to struct for JSON export
    jsonData = results;
    jsonData.rawData = []; % Remove raw data to reduce file size

    jsonStr = jsonencode(jsonData);
    fid = fopen(filename, 'w');
    fprintf(fid, '%s', jsonStr);
    fclose(fid);

    if verbose
        fprintf('📄 JSON report exported: %s\n', filename);
    end
catch ME
    warning('analyze_dead_code:ExportError', 'Failed to export JSON: %s', ME.message);
end
end

function exportToCsv(results, filename, verbose)
% Export summary as CSV
try
    fid = fopen(filename, 'w');

    % Header
    fprintf(fid, 'Function,Status,Confidence,File,Line,Type,Complexity,Reason\n');

    % Unused functions
    for i = 1:length(results.unused)
        func = results.unused{i};
        if isstruct(func)
            fprintf(fid, '%s,Unused,%.2f,,,,,"%s"\n', func.name, func.confidence, strjoin(func.reasons, '; '));
        else
            fprintf(fid, '%s,Unused,1.00,,,,,No direct calls found\n', func);
        end
    end

    % Suspicious functions
    for i = 1:length(results.suspicious)
        func = results.suspicious{i};
        fprintf(fid, '%s,Suspicious,%.2f,,,,,"%s"\n', func.name, func.confidence, func.reason);
    end

    fclose(fid);

    if verbose
        fprintf('📊 CSV summary exported: %s\n', filename);
    end
catch ME
    warning('analyze_dead_code:ExportError', 'Failed to export CSV: %s', ME.message);
end
end

function exportToText(results, filename, verbose)
% Export enhanced text report (existing functionality with improvements)
generateEnhancedDeadCodeReport(results.unused, results.suspicious, results.protected, ...
    results.rawData.functions, results.rawData.calls, results.rawData.classes, results);

% Rename to timestamped filename
if exist('dead_code_report.txt', 'file')
    movefile('dead_code_report.txt', filename);
    if verbose
        fprintf('📝 Text report exported: %s\n', filename);
    end
end
end