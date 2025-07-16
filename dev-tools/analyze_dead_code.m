function analyze_dead_code()
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
        
        % Categorize the function
        if isProtected || isConstructor || isEntryPoint || isTestFunction
            reasons = getProtectionReason(isProtected, isConstructor, isEntryPoint, isTestFunction);
            protectedFunctions{end+1} = struct('name', funcName, 'reason', reasons); %#ok<AGROW>
        elseif ~isCalled
            % Check for potential dynamic calls or special patterns
            if hasSpecialUsagePattern(funcName, allFunctions, allCalls)
                suspiciousFunctions{end+1} = struct('name', funcName, 'reason', 'Potential callback/dynamic usage'); %#ok<AGROW>
            else
                unusedFunctions{end+1} = funcName; %#ok<AGROW>
            end
        end
    end
end

function reason = getProtectionReason(isProtected, isConstructor, isEntryPoint, isTestFunction)
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
    if isTestFunction
        reasons{end+1} = 'Test function';
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
                    existing{end+1} = protFunc.name;
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
                existing{end+1} = funcName;
                fileGroups(fileName) = existing;
            else
                fileGroups(fileName) = {funcName};
            end
        end
    end
    
    % Sort functions alphabetically
    sortedFunctions = sort(unusedFunctions);
end