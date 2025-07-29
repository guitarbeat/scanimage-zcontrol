function run_diagnostics(varargin)
% RUN_DIAGNOSTICS - Clean interface to run dev-tools diagnostics
%
% USAGE:
%   run_diagnostics()                    % Run both tools with default settings
%   run_diagnostics('deadcode')          % Run only dead code analysis
%   run_diagnostics('scanimage')         % Run only scanimage diagnostic
%   run_diagnostics('verbose', true)     % Run with verbose output
%   run_diagnostics('open', true)        % Open output files after running
%
% OPTIONS:
%   'deadcode'  - Run only analyze_dead_code.m
%   'scanimage' - Run only comprehensive_scanimage_diagnostic.m  
%   'verbose'   - Enable verbose output (default: false)
%   'open'      - Open output files in editor after completion (default: false)

% Parse inputs
p = inputParser;
addOptional(p, 'tool', 'both', @(x) any(strcmp(x, {'both', 'deadcode', 'scanimage'})));
addParameter(p, 'verbose', false, @islogical);
addParameter(p, 'open', false, @islogical);
parse(p, varargin{:});

tool = p.Results.tool;
verbose = p.Results.verbose;
openFiles = p.Results.open;

fprintf('🔧 Running dev-tools diagnostics...\n\n');

outputFiles = {};

% Run dead code analysis
if strcmp(tool, 'both') || strcmp(tool, 'deadcode')
    fprintf('📊 Running dead code analysis...\n');
    try
        if verbose
            analyze_dead_code('verbose', true);
        else
            analyze_dead_code();
        end
        
        % Find the most recent dead code output file
        outputDir = fullfile('dev-tools', 'output');
        files = dir(fullfile(outputDir, 'dead_code_analysis_*.txt'));
        if ~isempty(files)
            [~, idx] = max([files.datenum]);
            outputFiles{end+1} = fullfile(outputDir, files(idx).name);
        end
        
        fprintf('✅ Dead code analysis complete\n\n');
    catch ME
        fprintf('❌ Dead code analysis failed: %s\n\n', ME.message);
    end
end

% Run scanimage diagnostic
if strcmp(tool, 'both') || strcmp(tool, 'scanimage')
    fprintf('🔬 Running ScanImage diagnostic...\n');
    try
        if verbose
            comprehensive_scanimage_diagnostic('Verbose', true);
        else
            comprehensive_scanimage_diagnostic();
        end
        
        % Find the most recent scanimage output file
        outputDir = fullfile('dev-tools', 'output');
        files = dir(fullfile(outputDir, 'scanimage_diagnostic_*.txt'));
        if ~isempty(files)
            [~, idx] = max([files.datenum]);
            outputFiles{end+1} = fullfile(outputDir, files(idx).name);
        end
        
        fprintf('✅ ScanImage diagnostic complete\n\n');
    catch ME
        fprintf('❌ ScanImage diagnostic failed: %s\n\n', ME.message);
    end
end

% Display results summary
fprintf('📁 Output files saved to dev-tools/output/:\n');
for i = 1:length(outputFiles)
    [~, name, ext] = fileparts(outputFiles{i});
    fprintf('   • %s%s\n', name, ext);
end

% Open files if requested
if openFiles && ~isempty(outputFiles)
    fprintf('\n📖 Opening output files...\n');
    for i = 1:length(outputFiles)
        edit(outputFiles{i});
    end
end

fprintf('\n🎉 Diagnostics complete! Use edit() to view output files.\n');
end