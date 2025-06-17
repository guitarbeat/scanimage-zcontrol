% diagnose_scanimage_data.m
% Diagnostic tool for ScanImage data access with detailed reporting

function diagnose_scanimage_data(varargin)
    % diagnose_scanimage_data  Run diagnostics on ScanImage data with verbose logs.
    %
    % USAGE:
    %   diagnose_scanimage_data()                  % full report
    %   diagnose_scanimage_data('Save',true)       % save report to file
    %   diagnose_scanimage_data('TestFocus',false) % skip focus metrics
    %
    % OPTIONS:
    %   'Save'      (logical) save report to file (default false)
    %   'Verbose'   (logical) include detailed output (default true)
    %   'TestFocus' (logical) include focus metrics (default true)

    % Parse inputs
    p = inputParser;
    addParameter(p,'Save',false,@islogical);
    addParameter(p,'Verbose',true,@islogical);
    addParameter(p,'TestFocus',true,@islogical);
    parse(p,varargin{:});
    opts = p.Results;

    % Output setup
    if opts.Save
        ts = datestr(now,'yyyymmdd_HHMMSS');
        fname = sprintf('scanimage_report_%s.txt',ts);
        fid = fopen(fname,'w');
        out = @(varargin) fprintf(fid,varargin{:});
    else
        out = @fprintf;
    end

    % Header
    out('===============================================\n');
    out('ScanImage Diagnostic Report\n');
    out('Generated: %s\n',datestr(now));
    out('===============================================\n\n');

    % 1. ScanImage Status
    [hSI, stat] = checkScanImageStatus();
    reportScanImageStatus(out,stat);
    if ~stat.available
        out('❌ ScanImage not available. Exiting.\n');
        if opts.Save, closeFile(fid,fname); end
        return;
    end

    % 2. Display Component
    dispInfo = diagnoseDisplayComponent(out,hSI,opts.Verbose);
    reportDisplayComponent(out,dispInfo,opts.Verbose);

    % 3. Data Access
    dataRes = testDataAccessMethods(out,hSI);

    % 4. Pixel Analysis
    if dataRes.hasPixelData
        pixAnalysis = analyzePixelData(dataRes.bestInfo,opts.TestFocus);
        reportPixelDataAnalysis(out,pixAnalysis);
    end

    % 5. Channel Windows
    chInfo = diagnoseChannelWindows();
    reportChannelWindows(out,chInfo);

    % 6. Recommendations
    recs = generateRecommendations(stat,dispInfo,dataRes);
    reportRecommendations(out,recs);

    % 7. Integration Code
    if dataRes.hasPixelData
        generateIntegrationCode(out,dataRes);
    end

    % Close file
    if opts.Save, closeFile(fid,fname); end
end

%% Utility
function closeFile(fid,fname)
    fclose(fid);
    fprintf('Report saved to %s\n',fname);
end

%% 1. ScanImage Status
function [hSI, stat] = checkScanImageStatus()
    stat = struct('available',false,'active',false,'acqState','unknown',...
                  'hasDisplay',false,'hasChannels',false,'hasMotors',false,...
                  'hasScan2D',false,'activeChannels',[],'zPosition',NaN);
    try
        hSI = evalin('base','hSI');
        stat.available = true;
        stat.active    = safeGet(hSI,'active',false);
        stat.acqState  = safeGet(hSI,'acqState','unknown');
        stat.hasDisplay = ~isempty(safeGet(hSI,'hDisplay',[]));
        stat.hasChannels= ~isempty(safeGet(hSI,'hChannels',[]));
        stat.hasMotors = ~isempty(safeGet(hSI,'hMotors',[]));
        stat.hasScan2D= ~isempty(safeGet(hSI,'hScan2D',[]));
        if stat.hasChannels
            stat.activeChannels = safeGet(hSI.hChannels,'channelsActive',[]);
        end
        if stat.hasMotors
            pos = safeGet(hSI.hMotors,'axesPosition',[]);
            if numel(pos)>=3, stat.zPosition = pos(3); end
        end
    catch
        hSI = [];
    end
end

function reportScanImageStatus(out,stat)
    out('SCANIMAGE STATUS:\n'); out('-----------------\n');
    out('Available    : %s\n',ternary(stat.available,'Yes','No'));
    if stat.available
        out('Active       : %s\n',ternary(stat.active,'Yes','No'));
        out('State        : %s\n',stat.acqState);
        out('Channels     : %s\n',mat2str(stat.activeChannels));
        out('Z Position   : %s\n',ternary(~isnan(stat.zPosition),sprintf('%.2f μm',stat.zPosition),'Unknown'));
    end
    out('\n');
end

%% 2. Display Component
function info = diagnoseDisplayComponent(out,hSI,verbose)
    info = struct('available',false,'class','',...        
                  'totalProps',0,'dataProps',{{}},'bufferProps',{{}},...
                  'accessible',{{}},'inaccessible',{{}});
    try
        hd = hSI.hDisplay;
        info.available = true;
        info.class     = class(hd);
        mc = metaclass(hd);
        props = {mc.PropertyList.Name};
        info.totalProps = numel(props);
        for i = 1:numel(props)
            n = props{i};
            if contains(lower(n),{'frame','stripe','roi'}), info.dataProps{end+1}=n; end
            if contains(lower(n),{'buffer','rolling'}), info.bufferProps{end+1}=n; end
            try hd.(n); info.accessible{end+1}=n; catch, info.inaccessible{end+1}=n; end
        end
    catch ME
        info.error = ME.message;
    end
end

function reportDisplayComponent(out,info,verbose)
    out('DISPLAY COMPONENT:\n'); out('------------------\n');
    out('Class        : %s\n',info.class);
    out('Total props  : %d\n',info.totalProps);
    out('Data props   : %d\n',numel(info.dataProps));
    out('Buffer props : %d\n',numel(info.bufferProps));
    if verbose
        out('Accessible   : %s\n',strjoin(info.accessible,', '));
        out('Inaccessible : %s\n',strjoin(info.inaccessible,', '));
    end
    out('\n');
end

%% 3. Data Access
function res = testDataAccessMethods(out,hSI)
    funcs = {@testMethod1_lastFrame,@testMethod2_lastAveragedFrame,...
             @testMethod3_getRoiDataArray,@testMethod4_stripeDataNavigation,...
             @testMethod5_bufferExploration};
    res = struct('methods',{{}},'success',[], 'info',{{}},...
                 'hasPixelData',false,'bestMethod','', 'bestInfo',struct());
    for k = 1:numel(funcs)
        [ok,data,info] = funcs{k}(hSI);
        name = func2str(funcs{k});
        res.methods{k}=name; res.success(k)=ok; res.info{k}=info;
        if ok && ~res.hasPixelData
            res.hasPixelData=true; res.bestMethod=name; res.bestInfo=info;
        end
    end
    reportDataAccessResults(out,res);
end

function reportDataAccessResults(out,res)
    out('DATA ACCESS METHODS:\n'); out('--------------------\n');
    for i = 1:numel(res.methods)
        info = res.info{i};
        if res.success(i)
            out('✅ %s: %s\n',res.methods{i},info.desc);
            out('   Size: %s, Class: %s\n',mat2str(info.size),info.dataClass);
        else
            out('❌ %s failed: %s\n',res.methods{i},info.error);
        end
    end
    out('\nBest: %s\n\n',res.bestMethod);
end

%% Pixel Extraction Methods
function [ok,data,info] = testMethod1_lastFrame(hSI)
    ok = false; data = []; info = struct();
    try
        data = hSI.hDisplay.lastFrame;
        if isnumeric(data) && ~isempty(data)
            ok = true;
            info.desc = 'lastFrame';
            info.size = size(data);
            info.dataClass = class(data);
        else
            info.error = 'not numeric or empty';
        end
    catch ME
        info.error = ME.message;
    end
end

function [ok,data,info] = testMethod2_lastAveragedFrame(hSI)
    ok = false; data = []; info = struct();
    try
        data = hSI.hDisplay.lastAveragedFrame;
        if isnumeric(data) && ~isempty(data)
            ok = true;
            info.desc = 'lastAveragedFrame';
            info.size = size(data);
            info.dataClass = class(data);
        else
            info.error = 'not numeric or empty';
        end
    catch ME
        info.error = ME.message;
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
                    if iscell(img)
                        cand = img{1}{1};
                    else
                        cand = img;
                    end
                    if isnumeric(cand)
                        ok = true;
                        data = cand;
                        info.desc = sprintf('getRoiDataArray ROI %d', i);
                        info.size = size(cand);
                        info.dataClass = class(cand);
                        if isprop(arr(i),'frameNumberAcq')
                            info.frameNumber = arr(i).frameNumberAcq;
                        end
                        break;
                    end
                end
            end
        else
            info.error = 'empty array';
        end
    catch ME
        info.error = ME.message;
    end
end

function [ok,data,info] = testMethod4_stripeDataNavigation(hSI)
    ok = false; data = []; info = struct();
    try
        sd = hSI.hDisplay.lastStripeData;
        if ~isempty(sd) && isprop(sd,'roiData')
            roi = sd.roiData{1};
            pixel = roi.imageData{1}{1};
            if isnumeric(pixel)
                ok = true;
                data = pixel;
                info.desc = 'stripeDataNavigation';
                info.size = size(data);
                info.dataClass = class(data);
                if isprop(roi,'frameNumberAcq')
                    info.frameNumber = roi.frameNumberAcq;
                end
                if isprop(roi,'zs')
                    info.zPosition = roi.zs;
                end
            end
        end
    catch ME
        info.error = ME.message;
    end
end

function [ok,data,info] = testMethod5_bufferExploration(hSI)
    ok = false; data = []; info = struct();
    try
        buf = hSI.hDisplay.stripeDataBuffer;
        if iscell(buf) && ~isempty(buf{1})
            sd = buf{1};
            roi = sd.roiData{1};
            pixel = roi.imageData{1}{1};
            if isnumeric(pixel)
                ok = true;
                data = pixel;
                info.desc = 'bufferExploration';
                info.size = size(data);
                info.dataClass = class(data);
            end
        end
    catch ME
        info.error = ME.message;
    end
end

%% Pixel Data Analysis Helper
function analysis = analyzePixelData(pixelData, testFocus)
    % analyzePixelData  Compute stats and focus metrics for pixel array
    analysis = struct();
    vec = double(pixelData(:));
    analysis.valid = isnumeric(pixelData) && ~isempty(pixelData);
    if ~analysis.valid, return; end
    analysis.min          = min(vec);
    analysis.max          = max(vec);
    analysis.mean         = mean(vec);
    analysis.std          = std(vec);
    analysis.nonzero      = nnz(pixelData);
    analysis.uniqueVals   = numel(unique(vec));
    if testFocus
        [Gx,Gy] = gradient(double(pixelData));
        analysis.focusGradient = mean(sqrt(Gx.^2 + Gy.^2),'all');
        laplacianKernel = [0 -1 0; -1 4 -1; 0 -1 0];
        lap      = conv2(double(pixelData), laplacianKernel, 'valid');
        analysis.focusLaplacian = var(lap(:));
    end
end

%% 4. Pixel Analysis
function reportPixelDataAnalysis(out,analysis)
    out('PIXEL DATA ANALYSIS:\n'); out('-------------------\n');
    out('Min/Max : %.2f/%.2f\n',analysis.min,analysis.max);
    out('Mean ± Std: %.2f±%.2f\n',analysis.mean,analysis.std);
    if isfield(analysis,'focusLaplacian')
        out('Focus L: %.2e, G: %.2e\n',analysis.focusLaplacian,analysis.focusGradient);
    end
    out('\n');
end

%% 5. Channel Windows
function chInfo = diagnoseChannelWindows()
    chInfo = struct('count',0,'windows',{{}});
    figs = findall(0,'Type','figure');
    for f = figs'
        nm = get(f,'Name'); if contains(nm,'Channel','IgnoreCase',true)
            chInfo.count = chInfo.count+1;
        end
    end
end

function reportChannelWindows(out,chInfo)
    out('CHANNEL WINDOWS:\n'); out('---------------\n');
    out('Found %d windows\n\n',chInfo.count);
end

%% 6. Recommendations
function recs = generateRecommendations(stat,dispInfo,dataRes)
    recs = {};
    recs{end+1}=ternary(stat.active,'✅ Acquiring','⚠️ Not acquiring');
    recs{end+1}=ternary(dataRes.hasPixelData,sprintf('✅ Pixel via %s',dataRes.bestMethod),'❌ No pixel data');
    recs{end+1}=ternary(~isnan(stat.zPosition),sprintf('Z Pos: %.2f μm',stat.zPosition),'Z Pos unknown');
end

function reportRecommendations(out,recs)
    out('RECOMMENDATIONS:\n'); out('---------------\n');
    for r = recs, out(' - %s\n',r{1}); end
    out('\n');
end

%% 7. Integration Code
function generateIntegrationCode(out,res)
    out('INTEGRATION CODE using %s\n',res.bestMethod);
end

%% Helpers
function v = safeGet(o,p,d), try v=o.(p); catch, v=d; end; end
function s = ternary(c,t,f), if c, s=t; else, s=f; end; end
