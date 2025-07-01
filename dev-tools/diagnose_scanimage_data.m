% diagnose_scanimage_data.m
% Comprehensive diagnostic tool for ScanImage data access and integration

function diagnose_scanimage_data(varargin)
    % diagnose_scanimage_data  Run comprehensive diagnostics on ScanImage data access.
    %
    % This tool helps you understand:
    %   - Current ScanImage status and configuration
    %   - Available data access methods and their reliability
    %   - Pixel data quality and focus metrics
    %   - Integration code for your specific setup
    %
    % USAGE:
    %   diagnose_scanimage_data()                   % Run standard diagnostics
    %   diagnose_scanimage_data('Save',true)        % Save report to timestamped file
    %   diagnose_scanimage_data('Verbose',true)     % Show detailed technical information
    %   diagnose_scanimage_data('TestFocus',false)  % Skip focus quality metrics
    %   diagnose_scanimage_data('ShowExamples',true)% Show code examples for each method
    %   diagnose_scanimage_data('DetectNoise',false)% Disable noise floor detection
    %
    % OPTIONS:
    %   'Save'         - Save report to file (default: false)
    %   'Verbose'      - Show detailed properties and internals (default: false)
    %   'TestFocus'    - Calculate focus quality metrics (default: true)
    %   'ShowExamples' - Display code examples for data access (default: true)
    %   'DetectNoise'  - Look for noise even when signal is off (default: true)
    %
    % OUTPUT:
    %   The diagnostic will analyze your ScanImage setup and provide:
    %   - Status report with actionable recommendations
    %   - Working code snippets for pixel data access
    %   - Focus quality metrics (if acquiring)
    %   - Troubleshooting guidance for common issues

    % Parse inputs
    p = inputParser;
    addParameter(p,'Save',false,@islogical);
    addParameter(p,'Verbose',false,@islogical);
    addParameter(p,'TestFocus',true,@islogical);
    addParameter(p,'ShowExamples',true,@islogical);
    addParameter(p,'DetectNoise',true,@islogical);
    parse(p,varargin{:});
    opts = p.Results;

    % Set up output
    if opts.Save
        ts = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        fname = sprintf('scanimage_diagnostic_%s.txt',ts);
        fid = fopen(fname,'w');
        out = @(varargin) fprintf(fid,varargin{:});
        colorOut = @(color,varargin) fprintf(fid,varargin{:}); % No colors in file
    else
        out = @fprintf;
        colorOut = @colorPrint; % Terminal colors
    end

    % Header with introduction
    printHeader(out);
    printIntroduction(out, opts);

    % Check ScanImage status
    [hSI, stat] = checkScanImageStatus();
    reportScanImageStatus(out, colorOut, stat, opts.Verbose);
    
    if ~stat.available
        printCriticalError(out, colorOut);
        if opts.Save
            closeFile(fid, fname);
        end
        return;
    end

    % Display component analysis
    dispInfo = diagnoseDisplayComponent(hSI, opts.Verbose);
    reportDisplayComponent(out, colorOut, dispInfo, opts.Verbose);

    % Data access tests with detailed reporting
    dataRes = testDataAccessMethods(hSI, opts.DetectNoise);
    reportDataAccessResults(out, colorOut, dataRes, opts);

    % Pixel analysis with interpretation
    pixAnalysis = struct('valid', false);  % Initialize with default invalid state
    if dataRes.hasPixelData
        pixAnalysis = analyzePixelData(dataRes.bestPixelData, opts.TestFocus);
        reportPixelDataAnalysis(out, colorOut, pixAnalysis, opts.Verbose);
    end

    % Channel windows diagnostic
    chInfo = diagnoseChannelWindows();
    reportChannelWindows(out, colorOut, chInfo, opts.Verbose);

    % Generate actionable recommendations
    recs = generateRecommendations(stat, dispInfo, dataRes, pixAnalysis);
    reportRecommendations(out, colorOut, recs);

    % Integration code examples
    if dataRes.hasPixelData && opts.ShowExamples
        generateIntegrationCode(out, colorOut, dataRes, stat);
    end

    % Summary
    printSummary(out, colorOut, stat, dataRes);

    % Close file if saved
    if opts.Save
        closeFile(fid, fname);
    end
end

%% Output Functions
function printHeader(out)
    out('\n');
    out('╔══════════════════════════════════════════════════════════════╗\n');
    out('║           ScanImage Data Access Diagnostic Report            ║\n');
    out('║                  Generated: %-28s  ║\n', string(datetime('now')));
    out('╚══════════════════════════════════════════════════════════════╝\n\n');
end

function printIntroduction(out, opts)
    out('WHAT THIS DIAGNOSTIC DOES:\n');
    out('─────────────────────────\n');
    out('• Verifies ScanImage is running and accessible\n');
    out('• Tests multiple methods to extract pixel data\n');
    out('• Analyzes data quality and focus metrics\n');
    out('• Provides working code for your specific setup\n');
    out('• Identifies potential integration issues\n\n');
    
    out('CURRENT SETTINGS:\n');
    out('• Verbose mode: %s\n', ternary(opts.Verbose,'ON (detailed output)','OFF (standard output)'));
    out('• Focus testing: %s\n', ternary(opts.TestFocus,'ON','OFF'));
    out('• Code examples: %s\n', ternary(opts.ShowExamples,'ON','OFF'));
    out('• Noise detection: %s\n', ternary(opts.DetectNoise,'ON','OFF'));
    out('\n');
end

function printCriticalError(out, colorOut)
    colorOut('red','\n❌ CRITICAL ERROR: ScanImage not found in workspace!\n\n');
    out('TROUBLESHOOTING STEPS:\n');
    out('1. Ensure ScanImage is running\n');
    out('2. Check that ''hSI'' exists in base workspace:\n');
    out('   >> whos hSI\n');
    out('3. If using from a function, try:\n');
    out('   >> global hSI\n');
    out('4. Verify ScanImage initialization completed without errors\n\n');
end

function printSummary(out, colorOut, stat, dataRes)
    out('\n╔══════════════════════════════════════════════════════════════╗\n');
    out('║                          SUMMARY                             ║\n');
    out('╚══════════════════════════════════════════════════════════════╝\n\n');
    
    if stat.available && dataRes.hasPixelData
        colorOut('green','✅ SYSTEM READY FOR INTEGRATION\n\n');
        out('Key findings:\n');
        out('• ScanImage is %s\n', ternary(stat.active,'actively acquiring','idle but ready'));
        out('• Pixel data accessible via: %s\n', strrep(dataRes.bestMethod,'testMethod','Method '));
        out('• %d of %d data access methods work\n', dataRes.successCount, numel(dataRes.methods));
        out('\nNext steps:\n');
        out('1. Use the integration code above in your analysis\n');
        out('2. Test with different acquisition modes if needed\n');
        out('3. Monitor focus metrics during experiments\n');
    elseif stat.available
        colorOut('yellow','⚠️  SYSTEM PARTIALLY READY\n\n');
        out('Issues found:\n');
        out('• ScanImage is available but no pixel data accessible\n');
        out('• Check if acquisition is running (FOCUS/GRAB)\n');
        out('• Verify display settings and ROI configuration\n');
    else
        colorOut('red','❌ SYSTEM NOT READY\n\n');
        out('• ScanImage not found in workspace\n');
        out('• See troubleshooting steps above\n');
    end
    out('\n');
end

%% Enhanced Reporting Functions
function reportScanImageStatus(out, colorOut, stat, verbose)
    out('\n┌─────────────────────────────────────────────────────────────┐\n');
    out('│ SCANIMAGE STATUS                                            │\n');
    out('└─────────────────────────────────────────────────────────────┘\n\n');
    
    if stat.available
        colorOut('green','✅ ScanImage Found\n\n');
        out('Core Status:\n');
        out('  • Acquisition active: %s\n', formatStatus(stat.active));
        out('  • Current state: %s\n', upper(stat.acqState));
        
        if verbose
            out('\nComponents:\n');
            out('  • Display system: %s\n', formatStatus(stat.hasDisplay));
            out('  • Channel manager: %s\n', formatStatus(stat.hasChannels));
        end
        
        if stat.hasChannels && ~isempty(stat.activeChannels)
            out('\nActive channels: %s\n', mat2str(stat.activeChannels));
        end
        
        if ~isempty(stat.error)
            colorOut('yellow', '\n⚠️  Warning: %s\n', stat.error);
        end
    else
        colorOut('red','❌ ScanImage Not Found\n');
        if ~isempty(stat.error)
            out('\nError: %s\n', stat.error);
            out('\nTroubleshooting steps:\n');
            out('1. Ensure ScanImage is running\n');
            out('2. Check that ''hSI'' exists in base workspace:\n');
            out('   >> whos hSI\n');
            out('3. If using from a function, try:\n');
            out('   >> global hSI\n');
            out('4. Verify ScanImage initialization completed without errors\n');
        end
    end
    out('\n');
end

function reportDisplayComponent(out, colorOut, info, verbose)
    out('┌─────────────────────────────────────────────────────────────┐\n');
    out('│ DISPLAY COMPONENT ANALYSIS                                  │\n');
    out('└─────────────────────────────────────────────────────────────┘\n\n');
    
    if info.available
        colorOut('green','✅ Display Component Accessible\n\n');
        out('Component details:\n');
        out('  • Class: %s\n', info.class);
        out('  • Total properties: %d\n', info.totalProps);
        out('  • Data-related properties: %d\n', numel(info.dataProps));
        out('  • Buffer properties: %d\n', numel(info.bufferProps));
        
        if ~isempty(info.lastFrameNumber)
            out('  • Last frame number: %d\n', info.lastFrameNumber);
        end
        if ~isempty(info.rollingAverageFactor)
            out('  • Rolling average factor: %d\n', info.rollingAverageFactor);
        end
        
        if verbose && ~isempty(info.dataProps)
            out('\nData properties found:\n');
            for i = 1:numel(info.dataProps)
                out('  - %s\n', info.dataProps{i});
            end
        end
        
        if verbose && ~isempty(info.inaccessible)
            out('\nInaccessible properties (%d):\n', numel(info.inaccessible));
            for i = 1:min(5,numel(info.inaccessible))
                out('  - %s\n', info.inaccessible{i});
            end
            if numel(info.inaccessible) > 5
                out('  ... and %d more\n', numel(info.inaccessible)-5);
            end
        end
        
        if ~isempty(info.error)
            colorOut('yellow', '\n⚠️  Warning: %s\n', info.error);
        end
    else
        colorOut('red','❌ Display Component Not Accessible\n');
        if ~isempty(info.error)
            out('\nError: %s\n', info.error);
            out('\nTroubleshooting steps:\n');
            out('1. Verify ScanImage is properly initialized\n');
            out('2. Check if display component is enabled in ScanImage\n');
            out('3. Try restarting ScanImage\n');
            out('4. Check ScanImage logs for any display-related errors\n');
        end
    end
    out('\n');
end

function reportDataAccessResults(out, colorOut, res, opts)
    out('┌─────────────────────────────────────────────────────────────┐\n');
    out('│ DATA ACCESS METHOD TESTING                                  │\n');
    out('└─────────────────────────────────────────────────────────────┘\n\n');
    
    out('Testing %d different methods to access pixel data...\n\n', numel(res.methods));
    
    methodNames = {'Direct Frame Access (hDisplay.lastFrame)',...
                   'Averaged Frame Access (hDisplay.lastAveragedFrame)',...
                   'ROI Data Array Method (getRoiDataArray)',...
                   'Stripe Data Navigation (lastStripeData)',...
                   'Buffer Exploration (stripeDataBuffer)'};
    
    for i = 1:numel(res.methods)
        if res.success(i)
            colorOut('green',sprintf('[✓] %s\n', methodNames{i}));
            if ~isempty(res.info{i}) && isfield(res.info{i},'size')
                out('    → Data size: %s\n', mat2str(res.info{i}.size));
            end
        else
            colorOut('red',sprintf('[✗] %s\n', methodNames{i}));
            if opts.Verbose && isfield(res.info{i},'error')
                out('    → Error: %s\n', res.info{i}.error);
            end
        end
    end
    
    out('\nSummary: %d/%d methods successful\n', res.successCount, numel(res.methods));
    
    if res.hasPixelData
        colorOut('green','\n✅ Pixel data is accessible!\n');
        methodIdx = strcmp(res.methods,res.bestMethod);
        out('Recommended method: %s\n', methodNames{methodIdx});
    else
        colorOut('red','\n❌ No pixel data could be accessed\n');
        out('Possible causes:\n');
        out('  • Acquisition not running (start FOCUS or GRAB)\n');
        out('  • Display update disabled in ScanImage\n');
        out('  • ROI configuration issues\n');
    end
    out('\n');
end

function reportPixelDataAnalysis(out, colorOut, analysis, verbose)
    out('┌─────────────────────────────────────────────────────────────┐\n');
    out('│ PIXEL DATA QUALITY ANALYSIS                                 │\n');
    out('└─────────────────────────────────────────────────────────────┘\n\n');
    
    if analysis.valid
        out('Data characteristics:\n');
        out('  • Data type: %s\n', analysis.class);
        out('  • Image size: %d × %d pixels\n', analysis.size(1), analysis.size(2));
        out('  • Intensity range: [%.1f, %.1f]\n', analysis.min, analysis.max);
        out('  • Mean ± StdDev: %.1f ± %.1f\n', analysis.mean, analysis.std);
        
        % Check if this is likely just noise data
        if isfield(analysis, 'isPossiblyNoise') && analysis.isPossiblyNoise
            colorOut('yellow', '  ⚠️  Very low signal - possibly only noise floor (PMT off?)\n');
        end
        
        % Interpret the data
        range = analysis.max - analysis.min;
        if range < 10
            colorOut('yellow','  ⚠️  Very low dynamic range - check laser power/PMT gain\n');
        elseif analysis.max > 60000 && strcmp(analysis.class,'uint16')
            colorOut('yellow','  ⚠️  Near saturation - consider reducing gain\n');
        else
            colorOut('green','  ✅ Good dynamic range\n');
        end
        
        if isfield(analysis,'focusGradient')
            out('\nFocus quality metrics:\n');
            out('  • Gradient magnitude: %.2f\n', analysis.focusGradient);
            out('  • Laplacian variance: %.2f\n', analysis.focusLaplacian);
            
            if analysis.focusGradient < 5
                colorOut('yellow','  ⚠️  Low contrast - sample may be out of focus\n');
            elseif analysis.focusGradient > 50
                colorOut('green','  ✅ High contrast - good focus likely\n');
            else
                out('  → Moderate contrast\n');
            end
        end
        
        if verbose
            out('\nSignal quality assessment:\n');
            snr = analysis.mean / analysis.std;
            out('  • Signal-to-noise ratio: %.1f\n', snr);
            out('  • Coefficient of variation: %.1f%%\n', (analysis.std/analysis.mean)*100);
        end
    else
        colorOut('red','❌ Invalid pixel data\n');
    end
    out('\n');
end

function reportChannelWindows(out, colorOut, chInfo, verbose)
    out('┌─────────────────────────────────────────────────────────────┐\n');
    out('│ CHANNEL DISPLAY WINDOWS                                     │\n');
    out('└─────────────────────────────────────────────────────────────┘\n\n');
    
    if chInfo.count > 0
        colorOut('green',sprintf('✅ Found %d channel window(s)\n\n', chInfo.count));
        if verbose
            for i = 1:numel(chInfo.windows)
                win = chInfo.windows{i};
                out('  Window %d: "%s"\n', i, win.name);
                out('    • Axes count: %d\n', win.axesCount);
                out('    • Has image: %s\n', formatBoolean(win.hasImage));
            end
        end
    else
        colorOut('yellow','⚠️  No channel windows found\n');
        out('This is normal if using programmatic access only\n');
    end
    out('\n');
end

function reportRecommendations(out, colorOut, recs)
    out('┌─────────────────────────────────────────────────────────────┐\n');
    out('│ RECOMMENDATIONS                                             │\n');
    out('└─────────────────────────────────────────────────────────────┘\n\n');
    
    for i = 1:numel(recs)
        rec = recs{i};
        if startsWith(rec.text,'✅')
            colorOut('green',sprintf('%s\n', rec.text));
        elseif startsWith(rec.text,'⚠️')
            colorOut('yellow',sprintf('%s\n', rec.text));
        elseif startsWith(rec.text,'❌')
            colorOut('red',sprintf('%s\n', rec.text));
        else
            out('%s\n', rec.text);
        end
        
        if ~isempty(rec.action)
            out('   → %s\n', rec.action);
        end
    end
    out('\n');
end

function generateIntegrationCode(out, colorOut, dataRes, ~)
    out('┌─────────────────────────────────────────────────────────────┐\n');
    out('│ INTEGRATION CODE                                            │\n');
    out('└─────────────────────────────────────────────────────────────┘\n\n');
    
    colorOut('green','Copy and use this code in your application:\n\n');
    
    % Basic pixel access
    out('%% Basic pixel data access\n');
    switch dataRes.bestMethod
        case 'testMethod1_lastFrame'
            out('pixelData = hSI.hDisplay.lastFrame;\n');
        case 'testMethod2_lastAveragedFrame'
            out('pixelData = hSI.hDisplay.lastAveragedFrame;\n');
        case 'testMethod3_getRoiDataArray'
            out('roiData = hSI.hDisplay.getRoiDataArray();\n');
            out('pixelData = roiData(1).imageData{1}{1};  %% First ROI, first channel\n');
        case 'testMethod4_stripeDataNavigation'
            out('stripeData = hSI.hDisplay.lastStripeData;\n');
            out('pixelData = stripeData.roiData{1}.imageData{1}{1};\n');
        case 'testMethod5_bufferExploration'
            out('buffer = hSI.hDisplay.stripeDataBuffer;\n');
            out('pixelData = buffer{1}.roiData{1}.imageData{1}{1};\n');
    end
    
    out('\n%% Convert to double for processing\n');
    out('pixelData = double(pixelData);\n');
    
    out('\n%% Calculate focus metric\n');
    out('[Gx, Gy] = gradient(pixelData);\n');
    out('focusScore = mean(sqrt(Gx.^2 + Gy.^2), ''all'');\n');
    out('fprintf(''Focus score: %%.2f\\n'', focusScore);\n');
    
    out('\n%% Display the image\n');
    out('figure(''Name'',''ScanImage Data'');\n');
    out('imagesc(pixelData);\n');
    out('colormap(gray);\n');
    out('axis image;\n');
    out('colorbar;\n');
    out('title(sprintf(''Frame, Focus=%%.1f'', focusScore));\n');
    
    out('\n');
end

%% Enhanced Utility Functions
function recs = generateRecommendations(stat, dispInfo, dataRes, pixAnalysis)
    recs = {};
    
    % ScanImage availability
    if ~stat.available
        recs{end+1} = struct('text','❌ ScanImage not available in workspace',...
                           'action','Run ScanImage and ensure hSI is in base workspace');
        return;
    end
    
    % Acquisition status
    if ~stat.active
        recs{end+1} = struct('text','⚠️  ScanImage is idle - no data being acquired',...
                           'action','Click FOCUS or GRAB to start acquisition');
    else
        recs{end+1} = struct('text','✅ ScanImage is actively acquiring data',...
                           'action','');
    end
    
    % Data access
    if dataRes.hasPixelData
        methodName = strrep(dataRes.bestMethod,'testMethod','Method ');
        recs{end+1} = struct('text',sprintf('✅ Pixel data accessible via %s',methodName),...
                           'action','Use the integration code provided above');
        
        % Check if it might be just noise data
        if isfield(pixAnalysis, 'isPossiblyNoise') && pixAnalysis.isPossiblyNoise
            recs{end+1} = struct('text','⚠️  Only noise floor data detected (PMT may be off)',...
                               'action','Turn on PMT/increase gain to see signal');
        end
    else
        recs{end+1} = struct('text','❌ Cannot access pixel data',...
                           'action','Start acquisition and check display settings');
                           
        % Add special recommendation for noise detection
        recs{end+1} = struct('text','ℹ️  To check even for noise floor, run with option:',...
                           'action','diagnose_scanimage_data(''DetectNoise'',true)');
    end
    
    % Focus quality
    if dataRes.hasPixelData && isfield(pixAnalysis,'focusGradient')
        if pixAnalysis.focusGradient < 5
            recs{end+1} = struct('text','⚠️  Low image contrast detected',...
                               'action','Adjust focus or check sample/illumination');
        elseif pixAnalysis.focusGradient > 50
            recs{end+1} = struct('text','✅ Good image contrast for focus detection',...
                               'action','');
        end
    end
    
    % Display component
    if dispInfo.available && numel(dispInfo.dataProps) < 3
        recs{end+1} = struct('text','⚠️  Limited data properties in display component',...
                           'action','Update ScanImage or check configuration');
    end
    
    % Overall readiness
    if dataRes.hasPixelData
        recs{end+1} = struct('text','🎯 READY for image data integration!',...
                           'action','Implement using code examples above');
    end
end

function colorPrint(color, varargin)
    % Simple color printing for terminal (ANSI codes)
    % Falls back to regular printing if not supported
    try
        colors = struct('red',31,'green',32,'yellow',33,'blue',34,'magenta',35,'cyan',36);
        if isfield(colors, color)
            fprintf('\033[%dm%s\033[0m', colors.(color), sprintf(varargin{:}));
        else
            fprintf(varargin{:});
        end
    catch
        fprintf(varargin{:});
    end
end

function str = formatStatus(val)
    if val
        str = 'YES ✓';
    else
        str = 'NO ✗';
    end
end

function str = formatBoolean(val)
    str = ternary(val,'Yes','No');
end

function outStr = ternary(cond, trueVal, falseVal)
    if cond
        outStr = trueVal;
    else
        outStr = falseVal;
    end
end

function val = safeGet(obj, prop, def)
    try
        val = obj.(prop);
    catch
        val = def;
    end
end

function closeFile(fid, fname)
    fclose(fid);
    fprintf('\n📄 Diagnostic report saved to: %s\n', fname);
    fprintf('   Open with: edit(''%s'')\n\n', fname);
end

%% ScanImage Status Check
function [hSI, stat] = checkScanImageStatus()
    % Initialize status structure
    stat = struct('available', false, ...
                 'active', false, ...
                 'acqState', 'unknown', ...
                 'hasDisplay', false, ...
                 'hasChannels', false, ...
                 'activeChannels', [], ...
                 'error', '');
    
    % Try to get ScanImage handle
    try
        hSI = evalin('base', 'hSI');
        if isempty(hSI)
            stat.error = 'hSI exists but is empty';
            return;
        end
        
        % Verify it's a ScanImage object
        if ~isa(hSI, 'scanimage.SI')
            stat.error = 'hSI is not a ScanImage object';
            return;
        end
        
        stat.available = true;
        
        % Check if ScanImage is active - try different property names
        try
            % Try different possible property names for acquisition state
            if isprop(hSI, 'acqActive')
                stat.active = hSI.acqActive;
            elseif isprop(hSI, 'acquisitionActive')
                stat.active = hSI.acquisitionActive;
            elseif isprop(hSI, 'isAcquiring')
                stat.active = hSI.isAcquiring;
            end
            
            % Try different possible property names for acquisition state
            if isprop(hSI, 'acqState')
                stat.acqState = hSI.acqState;
            elseif isprop(hSI, 'acquisitionState')
                stat.acqState = hSI.acquisitionState;
            elseif isprop(hSI, 'state')
                stat.acqState = hSI.state;
            end
        catch ME
            stat.error = sprintf('Cannot access acquisition state: %s', ME.message);
            % Don't return here - continue with other checks
        end
        
        % Check for key components
        try
            stat.hasDisplay = isprop(hSI, 'hDisplay') && ~isempty(hSI.hDisplay);
            stat.hasChannels = isprop(hSI, 'hChannels') && ~isempty(hSI.hChannels);
        catch ME
            stat.error = sprintf('Error checking components: %s', ME.message);
            return;
        end
        
        % Get active channels if available
        if stat.hasChannels
            try
                stat.activeChannels = hSI.hChannels.channelDisplay;
            catch ME
                stat.error = sprintf('Error accessing channels: %s', ME.message);
                return;
            end
        end
    catch ME
        stat.error = sprintf('Error accessing hSI: %s', ME.message);
        hSI = [];
    end
end

%% Display Component Analysis
function info = diagnoseDisplayComponent(hSI, ~)
    info = struct('available', false, ...
                 'class', '', ...
                 'totalProps', 0, ...
                 'dataProps', {{}}, ...
                 'bufferProps', {{}}, ...
                 'inaccessible', {{}}, ...
                 'lastFrameNumber', [], ...
                 'rollingAverageFactor', [], ...
                 'error', '');
    
    try
        if isempty(hSI)
            info.error = 'ScanImage handle is empty';
            return;
        end
        
        if ~isprop(hSI, 'hDisplay')
            info.error = 'hDisplay property not found in ScanImage object';
            return;
        end
        
        if isempty(hSI.hDisplay)
            info.error = 'hDisplay component is empty';
            return;
        end
        
        info.available = true;
        info.class = class(hSI.hDisplay);
        
        % Get all properties
        try
            props = properties(hSI.hDisplay);
            info.totalProps = numel(props);
        catch ME
            info.error = sprintf('Error getting display properties: %s', ME.message);
            return;
        end
        
        % Categorize properties
        for i = 1:numel(props)
            prop = props{i};
            try
                val = hSI.hDisplay.(prop);
                
                % Check if it's a data-related property
                if isnumeric(val) && ~isscalar(val)
                    info.dataProps{end+1} = prop;
                end
                
                % Check if it's a buffer property
                if iscell(val) || (isstruct(val) && isfield(val, 'buffer'))
                    info.bufferProps{end+1} = prop;
                end
                
                % Get specific properties if they exist
                if strcmp(prop, 'lastFrameNumber')
                    info.lastFrameNumber = val;
                elseif strcmp(prop, 'rollingAverageFactor')
                    info.rollingAverageFactor = val;
                end
            catch ME
                info.inaccessible{end+1} = sprintf('%s (%s)', prop, ME.message);
            end
        end
        
        % Verify we found some data properties
        if isempty(info.dataProps) && isempty(info.bufferProps)
            info.error = 'No data or buffer properties found in display component';
        end
        
    catch ME
        info.error = sprintf('Error analyzing display component: %s', ME.message);
    end
end

%% Data Access Testing
function dataRes = testDataAccessMethods(hSI, detectNoise)
    % Initialize result structure
    dataRes = struct('methods', {{}}, ...
                    'success', [], ...
                    'info', {{}}, ...
                    'successCount', 0, ...
                    'hasPixelData', false, ...
                    'bestMethod', '', ...
                    'bestPixelData', []);
    
    % Define methods to test
    methods = {'testMethod1_lastFrame', ...
               'testMethod2_lastAveragedFrame', ...
               'testMethod3_getRoiDataArray', ...
               'testMethod4_stripeDataNavigation', ...
               'testMethod5_bufferExploration'};
    
    dataRes.methods = methods;
    dataRes.success = false(1, numel(methods));
    dataRes.info = cell(1, numel(methods));
    
    % If detectNoise is true, temporarily force acquisition so we can see noise
    forceAcquisition = false;
    if exist('detectNoise', 'var') && detectNoise
        try
            % Check if hSI has the required properties
            hasAcqActive = isprop(hSI, 'acqActive');
            hasAcqState = isprop(hSI, 'acqState');
            
            if hasAcqActive && hasAcqState
                isActive = hSI.acqActive;
                if ~isActive
                    % Store original state to restore later
                    originalState = hSI.acqState;
                    % Try to start acquisition to measure noise
                    hSI.startFocus();
                    forceAcquisition = true;
                    % Brief pause to let acquisition start
                    pause(0.5); 
                end
            end
        catch ME
            % Log the error but continue with testing
            fprintf('Note: Could not force acquisition for noise detection: %s\n', ME.message);
        end
    end
    
    % Test each method
    for i = 1:numel(methods)
        [ok, data, info] = feval(methods{i}, hSI);
        dataRes.success(i) = ok;
        dataRes.info{i} = info;
        
        if ok
            dataRes.successCount = dataRes.successCount + 1;
            if ~dataRes.hasPixelData
                dataRes.hasPixelData = true;
                dataRes.bestMethod = methods{i};
                dataRes.bestPixelData = data;
            end
        end
    end
    
    % If we forced acquisition on, return to original state
    if forceAcquisition
        try
            hasAbort = isprop(hSI, 'abort');
            hasStartGrab = isprop(hSI, 'startGrab');
            
            if hasAbort
                hSI.abort();
                % Give time to abort
                pause(0.5);
                % Restore original state if needed
                if hasStartGrab && strcmp(originalState, 'grab')
                    hSI.startGrab();
                end
            end
        catch ME
            % Log the error but continue
            fprintf('Note: Could not restore original acquisition state: %s\n', ME.message);
        end
    end
end

%% Data Access Test Methods
function [ok,data,info] = testMethod1_lastFrame(hSI)
    ok = false; data = []; info = struct();
    try
        d = hSI.hDisplay.lastFrame;
        if isnumeric(d) && ~isempty(d)
            ok = true; 
            data = d; 
            info.desc = 'Direct lastFrame access';
            info.size = size(d);
        else
            info.error = 'Property exists but contains no numeric data';
        end
    catch ME
        info.error = sprintf('Cannot access lastFrame: %s', ME.message);
    end
end

function [ok,data,info] = testMethod2_lastAveragedFrame(hSI)
    ok = false; data = []; info = struct();
    try
        d = hSI.hDisplay.lastAveragedFrame;
        if isnumeric(d) && ~isempty(d)
            ok = true;
            data = d;
            info.desc = 'Averaged frame access';
            info.size = size(d);
        else
            info.error = 'Property exists but contains no numeric data';
        end
    catch ME
        info.error = sprintf('Cannot access lastAveragedFrame: %s', ME.message);
    end
end

function [ok,data,info] = testMethod3_getRoiDataArray(hSI)
    ok = false; data = []; info = struct();
    try
        arr = hSI.hDisplay.getRoiDataArray();
        if ~isempty(arr)
            for i = 1:numel(arr)
                if isprop(arr(i),'imageData') && ~isempty(arr(i).imageData)
                    img = arr(i).imageData;
                    if iscell(img) && ~isempty(img)
                        cand = img{1}{1};
                    else
                        cand = img;
                    end
                    if isnumeric(cand) && ~isempty(cand)
                        ok = true;
                        data = cand;
                        info.desc = sprintf('ROI array method (ROI #%d)', i);
                        info.size = size(cand);
                        break;
                    end
                end
            end
            if ~ok
                info.error = 'ROI array exists but contains no valid image data';
            end
        else
            info.error = 'getRoiDataArray returned empty';
        end
    catch ME
        info.error = sprintf('Cannot use getRoiDataArray: %s', ME.message);
    end
end

function [ok,data,info] = testMethod4_stripeDataNavigation(hSI)
    ok = false; data = []; info = struct();
    try
        sd = hSI.hDisplay.lastStripeData;
        if ~isempty(sd) && isfield(sd,'roiData') && ~isempty(sd.roiData)
            rd = sd.roiData{1}.imageData{1}{1};
            if isnumeric(rd) && ~isempty(rd)
                ok = true;
                data = rd;
                info.desc = 'Stripe data navigation';
                info.size = size(rd);
            else
                info.error = 'Stripe data structure incomplete';
            end
        else
            info.error = 'No stripe data available';
        end
    catch ME
        info.error = sprintf('Cannot navigate stripe data: %s', ME.message);
    end
end

function [ok,data,info] = testMethod5_bufferExploration(hSI)
    ok = false; data = []; info = struct();
    try
        buf = hSI.hDisplay.stripeDataBuffer;
        if ~isempty(buf) && iscell(buf) && ~isempty(buf{1})
            sd = buf{1};
            rd = sd.roiData{1}.imageData{1}{1};
            if isnumeric(rd) && ~isempty(rd)
                ok = true;
                data = rd;
                info.desc = 'Buffer exploration';
                info.size = size(rd);
            else
                info.error = 'Buffer structure incomplete';
            end
        else
            info.error = 'Buffer is empty';
        end
    catch ME
        info.error = sprintf('Cannot explore buffer: %s', ME.message);
    end
end

%% Enhanced Analysis Functions
function analysis = analyzePixelData(px, testFocus)
    analysis = struct();
    vec = double(px(:));
    
    analysis.valid = true;
    analysis.class = class(px);
    analysis.size = size(px);
    analysis.min = min(vec);
    analysis.max = max(vec);
    analysis.mean = mean(vec);
    analysis.std = std(vec);
    
    % Check if this could be just noise (when PMT is off)
    analysis.isPossiblyNoise = (analysis.max - analysis.min < 10) && (analysis.std < 2);
    
    if testFocus && numel(px) > 100 % Only test if image is reasonable size
        try
            % Gradient-based focus metric
            [Gx, Gy] = gradient(double(px));
            analysis.focusGradient = mean(sqrt(Gx.^2 + Gy.^2), 'all');
            
            % Laplacian-based focus metric
            kernel = [0 -1 0; -1 4 -1; 0 -1 0];
            lap = conv2(double(px), kernel, 'valid');
            analysis.focusLaplacian = var(lap(:));
            
            % Brenner gradient (another focus metric)
            dx = diff(double(px), 2, 2);
            analysis.focusBrenner = sum(dx(:).^2);
        catch
            % Focus metrics failed, but don't invalidate the analysis
        end
    end
end

function chInfo = diagnoseChannelWindows()
    chInfo = struct('count', 0, 'windows', {{}});
    figs = findall(0, 'Type', 'figure');
    
    for i = 1:numel(figs)
        nm = get(figs(i), 'Name');
        if contains(nm, 'Channel', 'IgnoreCase', true)
            chInfo.count = chInfo.count + 1;
            
            win = struct();
            win.name = nm;
            win.handle = figs(i);
            
            axesH = findall(figs(i), 'Type', 'axes');
            win.axesCount = numel(axesH);
            
            imgs = findall(axesH, 'Type', 'image');
            win.hasImage = ~isempty(imgs);
            
            if win.hasImage && ~isempty(imgs(1).CData)
                win.imageSize = size(imgs(1).CData);
            end
            
            chInfo.windows{end+1} = win;
        end
    end
end