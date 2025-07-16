function analyzeDeadCode()
    % analyzeDeadCode - Identify potentially unused functions and methods
    % Enhanced version that handles MATLAB-specific patterns including:
    % - Object method calls (obj.method())
    % - Static method calls (Class.method())
    % - Destructor methods (automatically called)
    % - Callback functions and event handlers
    
    fprintf('Analyzing codebase for dead code (Enhanced MATLAB Analysis)...\n');
    
    % Get all .m files in src/
    srcPath = fullfile(pwd, 'src');
    if ~exist(srcPath, 'dir')
        error('src/ directory not found. Run this script from the project root.');
    end
    
    files = dir(fullfile(srcPath, '**', '*.m'));
    
    allFunctions = containers.Map();
    allCalls = containers.Map();
    classInfo = containers.Map(); % Track class definitions and their methods
    
    fprintf('Scanning %d files...\n', length(files));
    
    for i = 1:length(files)
        filePath = fullfile(files(i).folder, files(i).name);
        [funcs, calls, classData] = extractFunctionsAndCalls(filePath);
        
        % Store functions with their file locations and context
        for j = 1:length(funcs)
            funcInfo = funcs{j};
            funcName = funcInfo.name;
            
            if allFunctions.isKey(funcName)
                % Function defined in multiple files
                existing = allFunctions(funcName);
                existing{end+1} = struct('file', files(i).name, 'type', funcInfo.type, ...
                    'class', funcInfo.class, 'line', funcInfo.line);
                allFunctions(funcName) = existing;
            else
                allFunctions(funcName) = {struct('file', files(i).name, 'type', funcInfo.type, ...
                    'class', funcInfo.class, 'line', funcInfo.line)};
            end
        end
        
        % Store function calls with context
        for j = 1:length(calls)
            callInfo = calls{j};
            callName = callInfo.name;
            
            if allCalls.isKey(callName)
                existing = allCalls(callName);
                existing{end+1} = callInfo;
                allCalls(callName) = existing;
            else
                allCalls(callName) = {callInfo};
            end
        end
        
        % Store class information
        if ~isempty(classData.name)
            classInfo(classData.name) = classData;
        end
    end
    
    % Enhanced analysis with MATLAB-specific patterns
    [unusedFunctions, suspiciousFunctions, protectedFunctions] = ...
        analyzeUsagePatterns(allFunctions, allCalls, classInfo);
    
    % Generate enhanced report
    generateEnhancedDeadCodeReport(unusedFunctions, suspiciousFunctions, ...
        protectedFunctions, allFunctions, allCalls, classInfo);
    
    fprintf('Enhanced dead code analysis complete. See dead_code_report.txt for details.\n');
end

function [functions, calls, classData] = extractFunctionsAndCalls(filePath)
    % Enhanced extraction that handles MATLAB-specific patterns
    
    functions = {};
    calls = {};
    classData = struct('name', '', 'methods', {{}}, 'properties', {{}});
    
    try
        content = fileread(filePath);
        lines = strsplit(content, '\n');
        
        currentClass = '';
        inClassDef = false;
        
        for i = 1:length(lines)
            line = strtrim(lines{i});
            
            % Skip comments and empty lines
            if isempty(line) || startsWith(line, '%')
                continue;
            end
            
            % Detect class definition
            classDefMatch = regexp(line, '^\s*classdef\s+(\w+)', 'tokens');
            if ~isempty(classDefMatch)
                currentClass = classDefMatch{1}{1};
                classData.name = currentClass;
                inClassDef = true;
                continue;
            end
            
            % Find function definitions with enhanced context
            funcDefMatch = regexp(line, '^\s*function\s+(?:\[?[\w,\s]*\]?\s*=\s*)?(\w+)\s*\(', 'tokens');
            if ~isempty(funcDefMatch)
                funcName = funcDefMatch{1}{1};
                funcInfo = struct();
                funcInfo.name = funcName;
                funcInfo.line = i;
                funcInfo.class = currentClass;
                
                % Determine function type
                if inClassDef
                    funcInfo.type = 'method';
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
        fprintf('Warning: Could not analyze file %s: %s\n', filePath, ME.message);
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
               'cell', 'zeros', 'ones', 'nan', 'inf', 'pi', 'rand', 'randn'};
    
    isBuiltin = any(strcmp(funcName, builtins));
end

function [unusedFunctions, suspiciousFunctions, protectedFunctions] = analyzeUsagePatterns(allFunctions, allCalls, classInfo)
    % Enhanced analysis that considers MATLAB-specific usage patterns
    
    definedFunctions = keys(allFunctions);
    calledFunctions = keys(allCalls);
    
    unusedFunctions = {};
    suspiciousFunctions = {};
    protectedFunctions = {};
    
    % Define protected function patterns (automatically called by MATLAB)
    protectedPatterns = {'delete', 'get', 'set', 'subsref', 'subsasgn', 'display', ...
                        'disp', 'char', 'string', 'double', 'logical', 'size', ...
                        'length', 'end', 'numel', 'isempty', 'isequal', 'copy', ...
                        'loadobj', 'saveobj', 'eq', 'ne', 'lt', 'le', 'gt', 'ge', ...
                        'plus', 'minus', 'times', 'rdivide', 'ldivide', 'power', ...
                        'and', 'or', 'not', 'transpose', 'ctranspose'};
    
    for i = 1:length(definedFunctions)
        funcName = definedFunctions{i};
        funcDefs = allFunctions(funcName);
        
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
        
        % Categorize the function
        if isProtected || isConstructor || isEntryPoint
            protectedFunctions{end+1} = struct('name', funcName, 'reason', ...
                getProtectionReason(isProtected, isConstructor, isEntryPoint)); %#ok<AGROW>
        elseif ~isCalled
            % Check for potential dynamic calls or special patterns
            if hasSpecialUsagePattern(funcName, allFunctions, allCalls)
                suspiciousFunctions{end+1} = funcName; %#ok<AGROW>
            else
                unusedFunctions{end+1} = funcName; %#ok<AGROW>
            end
        end
    end
end

function reason = getProtectionReason(isProtected, isConstructor, isEntryPoint)
    % Get reason why function is protected from removal
    reasons = {};
    if isProtected
        reasons{end+1} = 'MATLAB special method';
    end
    if isConstructor
        reasons{end+1} = 'Class constructor';
    end
    if isEntryPoint
        reasons{end+1} = 'File entry point';
    end
    reason = strjoin(reasons, ', ');
end

function hasSpecial = hasSpecialUsagePattern(funcName, allFunctions, allCalls)
    % Check for special usage patterns that might indicate the function is used
    hasSpecial = false;
    
    % Check if function name appears in string literals (dynamic calls)
    calledFunctions = keys(allCalls);
    for i = 1:length(calledFunctions)
        callName = calledFunctions{i};
        callInfos = allCalls(callName);
        for j = 1:length(callInfos)
            if strcmp(callInfos{j}.type, 'dynamic') && strcmp(callInfos{j}.name, funcName)
                hasSpecial = true;
                return;
            end
        end
    end
    
    % Check if it's a callback pattern (starts with 'on' or ends with 'Callback')
    if startsWith(funcName, 'on') && length(funcName) > 2 && isstrprop(funcName(3), 'upper')
        hasSpecial = true;
        return;
    end
    
    if endsWith(funcName, 'Callback') || endsWith(funcName, 'Fcn')
        hasSpecial = true;
        return;
    end
end

function generateEnhancedDeadCodeReport(unusedFunctions, suspiciousFunctions, protectedFunctions, allFunctions, allCalls, classInfo)
    % Generate enhanced report with detailed analysis
    
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
        fprintf(fid, 'Potentially unused functions: %d\n\n', length(unusedFunctions));
        
        % Report unused functions
        if ~isempty(unusedFunctions)
            fprintf(fid, 'POTENTIALLY UNUSED FUNCTIONS\n');
            fprintf(fid, '----------------------------\n');
            fprintf(fid, 'These functions are defined but no calls were detected:\n\n');
            
            for i = 1:length(unusedFunctions)
                funcName = unusedFunctions{i};
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
        else
            fprintf(fid, 'POTENTIALLY UNUSED FUNCTIONS\n');
            fprintf(fid, '----------------------------\n');
            fprintf(fid, 'No unused functions detected! 🎉\n\n');
        end
        
        % Report suspicious functions
        if ~isempty(suspiciousFunctions)
            fprintf(fid, 'SUSPICIOUS FUNCTIONS (Review Recommended)\n');
            fprintf(fid, '-----------------------------------------\n');
            fprintf(fid, 'These functions may be used dynamically or as callbacks:\n\n');
            
            for i = 1:length(suspiciousFunctions)
                funcName = suspiciousFunctions{i};
                funcDefs = allFunctions(funcName);
                fprintf(fid, '• %s (potential callback/dynamic call)\n', funcName);
                for j = 1:length(funcDefs)
                    funcDef = funcDefs{j};
                    fprintf(fid, '  └─ %s (line %d)\n', funcDef.file, funcDef.line);
                end
                fprintf(fid, '\n');
            end
        end
        
        % Report protected functions
        if ~isempty(protectedFunctions)
            fprintf(fid, 'PROTECTED FUNCTIONS (Safe from Removal)\n');
            fprintf(fid, '---------------------------------------\n');
            fprintf(fid, 'These functions are automatically protected:\n\n');
            
            for i = 1:length(protectedFunctions)
                protFunc = protectedFunctions{i};
                fprintf(fid, '• %s (%s)\n', protFunc.name, protFunc.reason);
            end
            fprintf(fid, '\n');
        end
        
        % Call pattern analysis
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
        for i = 1:length(callTypeNames)
            fprintf(fid, '• %s calls: %d\n', callTypeNames{i}, callTypes(callTypeNames{i}));
        end
        fprintf(fid, '\n');
        
        % Recommendations
        fprintf(fid, 'RECOMMENDATIONS\n');
        fprintf(fid, '---------------\n');
        fprintf(fid, '1. SAFE TO REMOVE: Functions in "Potentially Unused" section\n');
        fprintf(fid, '2. REVIEW CAREFULLY: Functions in "Suspicious" section\n');
        fprintf(fid, '3. DO NOT REMOVE: Functions in "Protected" section\n');
        fprintf(fid, '4. Check for dynamic calls using feval() or str2func()\n');
        fprintf(fid, '5. Verify callback functions are not referenced in UI code\n');
        fprintf(fid, '6. Consider if functions are part of public API\n\n');
        
        fprintf(fid, 'NEXT STEPS\n');
        fprintf(fid, '----------\n');
        fprintf(fid, '1. Review each unused function manually\n');
        fprintf(fid, '2. Search codebase for string references to function names\n');
        fprintf(fid, '3. Check if functions are called from external scripts\n');
        fprintf(fid, '4. Remove confirmed dead code in small, testable commits\n');
        fprintf(fid, '5. Run tests after each removal to ensure nothing breaks\n\n');
        
        fprintf(fid, 'NOTE: This enhanced analysis reduces false positives but manual\n');
        fprintf(fid, 'verification is still recommended before removing any code.\n');
        
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    
    fclose(fid);
end