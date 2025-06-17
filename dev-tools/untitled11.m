% diagnose_scanimage_data.m
% Comprehensive diagnostic tool for ScanImage data access

function diagnose_scanimage_data(varargin)
% DIAGNOSE_SCANIMAGE_DATA - Comprehensive diagnostic tool for ScanImage data access
%
% Usage:
%   diagnose_scanimage_data()                    - Full diagnostic
%   diagnose_scanimage_data('save', true)        - Save output to file
%   diagnose_scanimage_data('verbose', true)     - Show detailed properties
%   diagnose_scanimage_data('test_focus', true)  - Test focus metrics
%
% Options:
%   'save'       - Save output to timestamped file (default: false)
%   'verbose'    - Show detailed object properties (default: false)
%   'test_focus' - Calculate and test focus metrics (default: true)

    % Parse inputs
    p = inputParser;
    addParameter(p, 'save', false, @islogical);
    addParameter(p, 'verbose', false, @islogical);
    addParameter(p, 'test_focus', true, @islogical);
    parse(p, varargin{:});
    opts = p.Results;
    
    % Initialize output
    if opts.save
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        filename = sprintf('scanimage_data_diagnostic_%s.txt', timestamp);
        fid = fopen(filename, 'w');
        outputFunc = @(varargin) fprintf(fid, varargin{:});
    else
        outputFunc = @fprintf;
    end
    
    % Header
    outputFunc('===============================================\n');
    outputFunc('ScanImage Data Access Diagnostic Report\n');
    outputFunc('Generated: %s\n', datestr(now));
    outputFunc('===============================================\n\n');
    
    % Check ScanImage availability
    [hSI, siStatus] = checkScanImageStatus();
    reportScanImageStatus(outputFunc, hSI, siStatus);
    
    if ~siStatus.available
        outputFunc('\n❌ Cannot proceed - ScanImage not available\n');
        if opts.save, fclose(fid); end
        return;
    end
    
    % Diagnose display component
    displayInfo = diagnoseDisplayComponent(hSI, opts.verbose);
    reportDisplayComponent(outputFunc, displayInfo);
    
    % Test data access methods
    dataAccessResults = testDataAccessMethods(hSI);
    reportDataAccessResults(outputFunc, dataAccessResults);
    
    % Analyze successful data
    if dataAccessResults.hasPixelData
        pixelDataAnalysis = analyzePixelData(dataAccessResults.bestPixelData, opts.test_focus);
        reportPixelDataAnalysis(outputFunc, pixelDataAnalysis);
    end
    
    % Check channel windows
    channelInfo = diagnoseChannelWindows();
    reportChannelWindows(outputFunc, channelInfo);
    
    % Generate integration recommendations
    recommendations = generateRecommendations(siStatus, displayInfo, dataAccessResults);
    reportRecommendations(outputFunc, recommendations);
    
    % Generate ready-to-use code
    if dataAccessResults.hasPixelData
        generateIntegrationCode(outputFunc, dataAccessResults.bestMethod);
    end
    
    % Close file if saving
    if opts.save
        fclose(fid);
        fprintf('Diagnostic report saved to: %s\n', filename);
    end
end

function [hSI, status] = checkScanImageStatus()
    status = struct();
    hSI = [];
    
    try
        % Check if hSI exists
        hSI = evalin('base', 'hSI');
        status.available = true;
        status.active = safeGet(hSI, 'active', false);
        status.acqState = safeGet(hSI, 'acqState', 'unknown');
        
        % Check components
        status.hasDisplay = ~isempty(safeGet(hSI, 'hDisplay', []));
        status.hasChannels = ~isempty(safeGet(hSI, 'hChannels', []));
        status.hasMotors = ~isempty(safeGet(hSI, 'hMotors', []));
        status.hasScan2D = ~isempty(safeGet(hSI, 'hScan2D', []));
        
        % Get active channels
        if status.hasChannels
            status.activeChannels = safeGet(hSI.hChannels, 'channelsActive', []);
        else
            status.activeChannels = [];
        end
        
        % Get Z position
        if status.hasMotors
            try
                axesPos = hSI.hMotors.axesPosition;
                if length(axesPos) >= 3
                    status.zPosition = axesPos(3);
                else
                    status.zPosition = NaN;
                end
            catch
                status.zPosition = NaN;
            end
        else
            status.zPosition = NaN;
        end
        
    catch
        status.available = false;
        status.active = false;
        status.acqState = 'not_found';
        status.hasDisplay = false;
        status.hasChannels = false;
        status.hasMotors = false;
        status.hasScan2D = false;
        status.activeChannels = [];
        status.zPosition = NaN;
    end
end

function displayInfo = diagnoseDisplayComponent(hSI, verbose)
    displayInfo = struct();
    displayInfo.available = false;
    displayInfo.properties = {};
    displayInfo.dataProperties = {};
    displayInfo.bufferProperties = {};
    
    try
        hDisplay = hSI.hDisplay;
        displayInfo.available = true;
        displayInfo.class = class(hDisplay);
        
        % Get all properties
        mc = metaclass(hDisplay);
        allProps = {mc.PropertyList.Name};
        displayInfo.totalProperties = length(allProps);
        
        % Categorize properties
        dataProps = {};
        bufferProps = {};
        otherProps = {};
        
        for i = 1:length(allProps)
            propName = allProps{i};
            propLower = lower(propName);
            
            if contains(propLower, {'frame', 'stripe', 'data', 'roi'})
                dataProps{end+1} = propName;
            elseif contains(propLower, {'buffer', 'rolling'})
                bufferProps{end+1} = propName;
            else
                otherProps{end+1} = propName;
            end
        end
        
        displayInfo.dataProperties = dataProps;
        displayInfo.bufferProperties = bufferProps;
        displayInfo.otherProperties = otherProps;
        
        % Test property accessibility
        displayInfo.accessibleProps = {};
        displayInfo.inaccessibleProps = {};
        
        for i = 1:length(allProps)
            propName = allProps{i};
            try
                value = hDisplay.(propName);
                displayInfo.accessibleProps{end+1} = propName;
                
                % Store key property values
                if strcmp(propName, 'lastFrameNumber')
                    displayInfo.lastFrameNumber = value;
                elseif strcmp(propName, 'lastFrameNumberAcquisition')
                    displayInfo.lastFrameNumberAcquisition = value;
                elseif strcmp(propName, 'displayRollingAverageFactor')
                    displayInfo.rollingAverageFactor = value;
                end
            catch
                displayInfo.inaccessibleProps{end+1} = propName;
            end
        end
        
    catch ME
        displayInfo.error = ME.message;
    end
end

function results = testDataAccessMethods(hSI)
    results = struct();
    results.methods = {};
    results.success = {};
    results.dataInfo = {};
    results.hasPixelData = false;
    results.bestMethod = '';
    results.bestPixelData = [];
    
    % Method 1: lastFrame
    [success, data, info] = testMethod1_lastFrame(hSI);
    results.methods{end+1} = 'lastFrame';
    results.success{end+1} = success;
    results.dataInfo{end+1} = info;
    if success && ~results.hasPixelData
        results.hasPixelData = true;
        results.bestMethod = 'lastFrame';
        results.bestPixelData = data;
    end
    
    % Method 2: lastAveragedFrame
    [success, data, info] = testMethod2_lastAveragedFrame(hSI);
    results.methods{end+1} = 'lastAveragedFrame';
    results.success{end+1} = success;
    results.dataInfo{end+1} = info;
    if success && ~results.hasPixelData
        results.hasPixelData = true;
        results.bestMethod = 'lastAveragedFrame';
        results.bestPixelData = data;
    end
    
    % Method 3: getRoiDataArray
    [success, data, info] = testMethod3_getRoiDataArray(hSI);
    results.methods{end+1} = 'getRoiDataArray';
    results.success{end+1} = success;
    results.dataInfo{end+1} = info;
    if success && ~results.hasPixelData
        results.hasPixelData = true;
        results.bestMethod = 'getRoiDataArray';
        results.bestPixelData = data;
    end
    
    % Method 4: lastStripeData navigation
    [success, data, info] = testMethod4_stripeDataNavigation(hSI);
    results.methods{end+1} = 'stripeDataNavigation';
    results.success{end+1} = success;
    results.dataInfo{end+1} = info;
    if success && ~results.hasPixelData
        results.hasPixelData = true;
        results.bestMethod = 'stripeDataNavigation';
        results.bestPixelData = data;
    end
    
    % Method 5: Buffer exploration
    [success, data, info] = testMethod5_bufferExploration(hSI);
    results.methods{end+1} = 'bufferExploration';
    results.success{end+1} = success;
    results.dataInfo{end+1} = info;
    if success && ~results.hasPixelData
        results.hasPixelData = true;
        results.bestMethod = 'bufferExploration';
        results.bestPixelData = data;
    end
    
    results.successCount = sum([results.success{:}]);
end

function [success, data, info] = testMethod1_lastFrame(hSI)
    success = false;
    data = [];
    info = struct();
    
    try
        data = hSI.hDisplay.lastFrame;
        if isnumeric(data) && ~isempty(data)
            success = true;
            info.description = 'Direct lastFrame property access';
            info.dataSize = size(data);
            info.dataClass = class(data);
        else
            info.error = 'lastFrame exists but not numeric or empty';
            info.dataClass = class(data);
        end
    catch ME
        info.error = ME.message;
    end
end

function [success, data, info] = testMethod2_lastAveragedFrame(hSI)
    success = false;
    data = [];
    info = struct();
    
    try
        data = hSI.hDisplay.lastAveragedFrame;
        if isnumeric(data) && ~isempty(data)
            success = true;
            info.description = 'Direct lastAveragedFrame property access';
            info.dataSize = size(data);
            info.dataClass = class(data);
        else
            info.error = 'lastAveragedFrame exists but not numeric or empty';
            info.dataClass = class(data);
        end
    catch ME
        info.error = ME.message;
    end
end

function [success, data, info] = testMethod3_getRoiDataArray(hSI)
    success = false;
    data = [];
    info = struct();
    
    try
        roiArray = hSI.hDisplay.getRoiDataArray();
        if ~isempty(roiArray)
            for i = 1:length(roiArray)
                roi = roiArray(i);
                if isprop(roi, 'imageData') && ~isempty(roi.imageData)
                    imgData = roi.imageData;
                    if iscell(imgData)
                        for j = 1:numel(imgData)
                            if ~isempty(imgData{j}) && isnumeric(imgData{j})
                                data = imgData{j};
                                success = true;
                                info.description = sprintf('getRoiDataArray, ROI %d, channel %d', i, j);
                                info.dataSize = size(data);
                                info.dataClass = class(data);
                                return;
                            end
                        end
                    elseif isnumeric(imgData)
                        data = imgData;
                        success = true;
                        info.description = sprintf('getRoiDataArray, ROI %d direct', i);
                        info.dataSize = size(data);
                        info.dataClass = class(data);
                        return;
                    end
                end
            end
            info.error = 'getRoiDataArray returned data but no numeric imageData found';
        else
            info.error = 'getRoiDataArray returned empty';
        end
    catch ME
        info.error = ME.message;
    end
end

function [success, data, info] = testMethod4_stripeDataNavigation(hSI)
    success = false;
    data = [];
    info = struct();
    
    try
        sd = hSI.hDisplay.lastStripeData;
        if ~isempty(sd)
            info.stripeDataClass = class(sd);
            
            if isprop(sd, 'roiData') && ~isempty(sd.roiData)
                roiData = sd.roiData;
                info.roiDataSize = size(roiData);
                
                if iscell(roiData) && ~isempty(roiData{1})
                    roi = roiData{1};
                    info.roiClass = class(roi);
                    
                    if isprop(roi, 'imageData') && ~isempty(roi.imageData)
                        imageData = roi.imageData;
                        info.imageDataSize = size(imageData);
                        
                        if iscell(imageData) && ~isempty(imageData{1})
                            imgCell = imageData{1};
                            info.imageCellSize = size(imgCell);
                            
                            if iscell(imgCell) && ~isempty(imgCell{1})
                                pixelData = imgCell{1};
                                if isnumeric(pixelData) && ~isempty(pixelData)
                                    data = pixelData;
                                    success = true;
                                    info.description = 'lastStripeData.roiData{1}.imageData{1}{1}';
                                    info.dataSize = size(data);
                                    info.dataClass = class(data);
                                    
                                    % Additional metadata
                                    if isprop(roi, 'frameNumberAcq')
                                        info.frameNumber = roi.frameNumberAcq;
                                    end
                                    if isprop(roi, 'zs')
                                        info.zPosition = roi.zs;
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            if ~success
                info.error = 'Could not navigate to numeric pixel data';
            end
        else
            info.error = 'lastStripeData is empty';
        end
    catch ME
        info.error = ME.message;
    end
end

function [success, data, info] = testMethod5_bufferExploration(hSI)
    success = false;
    data = [];
    info = struct();
    
    try
        % Try stripeDataBuffer
        if isprop(hSI.hDisplay, 'stripeDataBuffer')
            buf = hSI.hDisplay.stripeDataBuffer;
            if iscell(buf) && ~isempty(buf{1})
                sd = buf{1};
                if isa(sd, 'scanimage.interfaces.StripeData')
                    % Try the same navigation as method 4
                    if isprop(sd, 'roiData') && ~isempty(sd.roiData)
                        roiData = sd.roiData{1};
                        if isprop(roiData, 'imageData')
                            imageData = roiData.imageData{1}{1};
                            if isnumeric(imageData) && ~isempty(imageData)
                                data = imageData;
                                success = true;
                                info.description = 'stripeDataBuffer{1}.roiData{1}.imageData{1}{1}';
                                info.dataSize = size(data);
                                info.dataClass = class(data);
                            end
                        end
                    end
                end
            end
        end
        
        if ~success
            info.error = 'No data found in buffer exploration';
        end
        
    catch ME
        info.error = ME.message;
    end
end

function analysis = analyzePixelData(pixelData, testFocus)
    analysis = struct();
    
    if ~isnumeric(pixelData) || isempty(pixelData)
        analysis.valid = false;
        analysis.error = 'Data is not numeric or empty';
        return;
    end
    
    analysis.valid = true;
    analysis.class = class(pixelData);
    analysis.size = size(pixelData);
    analysis.dimensions = ndims(pixelData);
    analysis.totalPixels = numel(pixelData);
    analysis.memoryMB = numel(pixelData) * 8 / 1024 / 1024;
    
    % Statistical analysis
    dataVec = double(pixelData(:));
    analysis.min = min(dataVec);
    analysis.max = max(dataVec);
    analysis.mean = mean(dataVec);
    analysis.std = std(dataVec);
    analysis.range = analysis.max - analysis.min;
    analysis.nonzeroPixels = nnz(pixelData);
    analysis.nonzeroPercent = 100 * analysis.nonzeroPixels / analysis.totalPixels;
    analysis.uniqueValues = length(unique(dataVec));
    
    % Data quality assessment
    analysis.hasVariation = analysis.range > 0;
    analysis.hasSignal = analysis.nonzeroPercent > 0;
    analysis.appears2D = analysis.dimensions == 2 && min(analysis.size) > 10;
    analysis.suitableForFocus = analysis.hasVariation && analysis.appears2D;
    
    % Focus metrics (if requested)
    if testFocus && analysis.suitableForFocus
        img = double(pixelData);
        if ndims(img) > 2
            img = img(:,:,1);
        end
        
        % Image variance
        analysis.focusVariance = var(img(:));
        
        % Gradient magnitude
        if size(img, 1) > 1 && size(img, 2) > 1
            [Gx, Gy] = gradient(img);
            gradMag = sqrt(Gx.^2 + Gy.^2);
            analysis.focusGradient = mean(gradMag(:));
        else
            analysis.focusGradient = NaN;
        end
        
        % Laplacian variance
        if size(img, 1) > 2 && size(img, 2) > 2
            laplacianKernel = [0 -1 0; -1 4 -1; 0 -1 0];
            laplacianImg = conv2(img, laplacianKernel, 'valid');
            analysis.focusLaplacian = var(laplacianImg(:));
        else
            analysis.focusLaplacian = NaN;
        end
        
        % Primary focus metric
        if ~isnan(analysis.focusLaplacian)
            analysis.primaryFocus = analysis.focusLaplacian;
            analysis.primaryFocusType = 'Laplacian';
        else
            analysis.primaryFocus = analysis.focusVariance;
            analysis.primaryFocusType = 'Variance';
        end
    end
end

function channelInfo = diagnoseChannelWindows()
    channelInfo = struct();
    channelInfo.windows = {};
    channelInfo.count = 0;
    
    figs = findall(0, 'Type', 'figure');
    
    for i = 1:length(figs)
        figName = get(figs(i), 'Name');
        if contains(figName, 'Channel', 'IgnoreCase', true)
            channelInfo.count = channelInfo.count + 1;
            
            winInfo = struct();
            winInfo.name = figName;
            winInfo.handle = figs(i);
            winInfo.visible = get(figs(i), 'Visible');
            
            % Look for image objects
            axes_handles = findall(figs(i), 'Type', 'axes');
            winInfo.axesCount = length(axes_handles);
            winInfo.hasImageData = false;
            
            if ~isempty(axes_handles)
                imgs = findall(axes_handles(1), 'Type', 'image');
                if ~isempty(imgs)
                    try
                        cdata = get(imgs(1), 'CData');
                        if isnumeric(cdata) && ~isempty(cdata)
                            winInfo.hasImageData = true;
                            winInfo.imageSize = size(cdata);
                            winInfo.imageClass = class(cdata);
                        end
                    catch
                        winInfo.hasImageData = false;
                    end
                end
            end
            
            channelInfo.windows{end+1} = winInfo;
        end
    end
end

function recommendations = generateRecommendations(siStatus, displayInfo, dataResults)
    recommendations = {};
    
    % ScanImage status recommendations
    if ~siStatus.available
        recommendations{end+1} = '❌ CRITICAL: ScanImage not found - ensure hSI is in base workspace';
        return;
    end
    
    if ~siStatus.active
        recommendations{end+1} = '⚠️  ScanImage not actively acquiring - start FOCUS or GRAB mode';
    else
        recommendations{end+1} = '✅ ScanImage is actively acquiring';
    end
    
    % Data access recommendations
    if dataResults.hasPixelData
        recommendations{end+1} = sprintf('✅ Pixel data accessible via %s method', dataResults.bestMethod);
        recommendations{end+1} = '✅ Ready for focus detection integration';
    else
        recommendations{end+1} = '❌ CRITICAL: No pixel data accessible';
        recommendations{end+1} = '   → Try starting acquisition first';
        recommendations{end+1} = '   → Check if PMT is enabled';
        recommendations{end+1} = '   → Verify channel configuration';
    end
    
    % Component recommendations
    if ~siStatus.hasMotors
        recommendations{end+1} = '⚠️  Motor component not accessible - Z position control may fail';
    else
        if ~isnan(siStatus.zPosition)
            recommendations{end+1} = sprintf('✅ Z position accessible: %.2f μm', siStatus.zPosition);
        else
            recommendations{end+1} = '⚠️  Z position not readable';
        end
    end
    
    % Integration recommendations
    if dataResults.hasPixelData
        recommendations{end+1} = '🔗 INTEGRATION READY:';
        recommendations{end+1} = '   → Add pixel extraction to Z-stage app';
        recommendations{end+1} = '   → Implement focus quality display';
        recommendations{end+1} = '   → Add auto-focus sweep capability';
    end
end

%% Reporting Functions

function reportScanImageStatus(outputFunc, hSI, status)
    outputFunc('SCANIMAGE STATUS:\n');
    outputFunc('-----------------\n');
    
    if status.available
        outputFunc('✅ ScanImage available in workspace\n');
        outputFunc('   Active: %s\n', mat2str(status.active));
        outputFunc('   Acquisition state: %s\n', status.acqState);
        outputFunc('   Active channels: %s\n', mat2str(status.activeChannels));
        
        if ~isnan(status.zPosition)
            outputFunc('   Z position: %.2f μm\n', status.zPosition);
        else
            outputFunc('   Z position: Not readable\n');
        end
        
        outputFunc('\n   Component availability:\n');
        outputFunc('     hDisplay: %s\n', formatBoolean(status.hasDisplay));
        outputFunc('     hChannels: %s\n', formatBoolean(status.hasChannels));
        outputFunc('     hMotors: %s\n', formatBoolean(status.hasMotors));
        outputFunc('     hScan2D: %s\n', formatBoolean(status.hasScan2D));
    else
        outputFunc('❌ ScanImage not available\n');
        outputFunc('   Check that hSI exists in base workspace\n');
    end
    outputFunc('\n');
end

function reportDisplayComponent(outputFunc, info)
    outputFunc('DISPLAY COMPONENT ANALYSIS:\n');
    outputFunc('---------------------------\n');
    
    if info.available
        outputFunc('✅ hDisplay component accessible\n');
        outputFunc('   Class: %s\n', info.class);
        outputFunc('   Total properties: %d\n', info.totalProperties);
        outputFunc('   Accessible properties: %d\n', length(info.accessibleProps));
        outputFunc('   Data-related properties: %d\n', length(info.dataProperties));
        outputFunc('   Buffer properties: %d\n', length(info.bufferProperties));
        
        if isfield(info, 'lastFrameNumber')
            outputFunc('   Last frame number: %d\n', info.lastFrameNumber);
        end
        if isfield(info, 'rollingAverageFactor')
            outputFunc('   Rolling average factor: %d\n', info.rollingAverageFactor);
        end
        
        outputFunc('\n   Key data properties:\n');
        for i = 1:length(info.dataProperties)
            prop = info.dataProperties{i};
            if any(strcmp(prop, info.accessibleProps))
                outputFunc('     ✅ %s\n', prop);
            else
                outputFunc('     ❌ %s (inaccessible)\n', prop);
            end
        end
    else
        outputFunc('❌ hDisplay component not accessible\n');
        if isfield(info, 'error')
            outputFunc('   Error: %s\n', info.error);
        end
    end
    outputFunc('\n');
end

function reportDataAccessResults(outputFunc, results)
    outputFunc('DATA ACCESS METHOD TESTING:\n');
    outputFunc('----------------------------\n');
    outputFunc('Methods tested: %d\n', length(results.methods));
    outputFunc('Successful methods: %d\n', results.successCount);
    outputFunc('\n');
    
    for i = 1:length(results.methods)
        method = results.methods{i};
        success = results.success{i};
        info = results.dataInfo{i};
        
        if success
            outputFunc('✅ %s: SUCCESS\n', method);
            outputFunc('   %s\n', info.description);
            outputFunc('   Data size: %s\n', mat2str(info.dataSize));
            outputFunc('   Data class: %s\n', info.dataClass);
            if isfield(info, 'frameNumber')
                outputFunc('   Frame number: %d\n', info.frameNumber);
            end
            if isfield(info, 'zPosition')
                outputFunc('   Z position: %.2f\n', info.zPosition);
            end
        else
            outputFunc('❌ %s: FAILED\n', method);
            outputFunc('   Error: %s\n', info.error);
        end
        outputFunc('\n');
    end
    
    if results.hasPixelData
        outputFunc('🎯 BEST METHOD: %s\n', results.bestMethod);
    else
        outputFunc('❌ NO PIXEL DATA ACCESSIBLE\n');
    end
    outputFunc('\n');
end

function reportPixelDataAnalysis(outputFunc, analysis)
    outputFunc('PIXEL DATA ANALYSIS:\n');
    outputFunc('--------------------\n');
    
    if analysis.valid
        outputFunc('✅ Valid numeric pixel data found\n');
        outputFunc('   Class: %s\n', analysis.class);
        outputFunc('   Dimensions: %s (%dD)\n', mat2str(analysis.size), analysis.dimensions);
        outputFunc('   Total pixels: %d\n', analysis.totalPixels);
        outputFunc('   Memory usage: %.2f MB\n', analysis.memoryMB);
        outputFunc('   Value range: [%.3f, %.3f]\n', analysis.min, analysis.max);
        outputFunc('   Mean ± Std: %.3f ± %.3f\n', analysis.mean, analysis.std);
        outputFunc('   Non-zero pixels: %d (%.1f%%)\n', analysis.nonzeroPixels, analysis.nonzeroPercent);
        outputFunc('   Unique values: %d\n', analysis.uniqueValues);
        
        outputFunc('\n   Data quality assessment:\n');
        outputFunc('     Has variation: %s\n', formatBoolean(analysis.hasVariation));
        outputFunc('     Has signal: %s\n', formatBoolean(analysis.hasSignal));
        outputFunc('     Appears 2D: %s\n', formatBoolean(analysis.appears2D));
        outputFunc('     Suitable for focus: %s\n', formatBoolean(analysis.suitableForFocus));
        
        if analysis.suitableForFocus && isfield(analysis, 'primaryFocus')
            outputFunc('\n   Focus metrics:\n');
            outputFunc('     Variance: %.2e\n', analysis.focusVariance);
            if ~isnan(analysis.focusGradient)
                outputFunc('     Gradient: %.2e\n', analysis.focusGradient);
            end
            if ~isnan(analysis.focusLaplacian)
                outputFunc('     Laplacian: %.2e\n', analysis.focusLaplacian);
            end
            outputFunc('     Primary (%s): %.2e\n', analysis.primaryFocusType, analysis.primaryFocus);
        end
    else
        outputFunc('❌ Invalid pixel data\n');
        outputFunc('   Error: %s\n', analysis.error);
    end
    outputFunc('\n');
end

function reportChannelWindows(outputFunc, channelInfo)
    outputFunc('CHANNEL DISPLAY WINDOWS:\n');
    outputFunc('------------------------\n');
    outputFunc('Channel windows found: %d\n', channelInfo.count);
    
    for i = 1:length(channelInfo.windows)
        win = channelInfo.windows{i};
        outputFunc('\n   Window %d: %s\n', i, win.name);
        outputFunc('     Visible: %s\n', win.visible);
        outputFunc('     Axes count: %d\n', win.axesCount);
        outputFunc('     Has image data: %s\n', formatBoolean(win.hasImageData));
        if win.hasImageData
            outputFunc('     Image size: %s\n', mat2str(win.imageSize));
            outputFunc('     Image class: %s\n', win.imageClass);
        end
    end
    outputFunc('\n');
end

function reportRecommendations(outputFunc, recommendations)
    outputFunc('RECOMMENDATIONS:\n');
    outputFunc('----------------\n');
    for i = 1:length(recommendations)
        outputFunc('%s\n', recommendations{i});
    end
    outputFunc('\n');
end

function generateIntegrationCode(outputFunc, bestMethod)
    outputFunc('INTEGRATION CODE:\n');
    outputFunc('-----------------\n');
    outputFunc('Ready-to-use functions for your Z-stage app:\n\n');
    
    outputFunc('```matlab\n');
    outputFunc('function [pixelData, focusValue, success] = getScanImageFocusData()\n');
    outputFunc('    %% Extract current image data and calculate focus\n');
    outputFunc('    pixelData = [];\n');
    outputFunc('    focusValue = NaN;\n');
    outputFunc('    success = false;\n');
    outputFunc('    \n');
    outputFunc('    try\n');
    outputFunc('        hSI = evalin(''base'', ''hSI'');\n');
    outputFunc('        if ~hSI.active, return; end\n');
    outputFunc('        \n');
    
    switch bestMethod
        case 'lastFrame'
            outputFunc('        %% Method: lastFrame\n');
            outputFunc('        pixelData = hSI.hDisplay.lastFrame;\n');
            
        case 'lastAveragedFrame'
            outputFunc('        %% Method: lastAveragedFrame\n');
            outputFunc('        pixelData = hSI.hDisplay.lastAveragedFrame;\n');
            
        case 'getRoiDataArray'
            outputFunc('        %% Method: getRoiDataArray\n');
            outputFunc('        roiArray = hSI.hDisplay.getRoiDataArray();\n');
            outputFunc('        if ~isempty(roiArray) && isprop(roiArray(1), ''imageData'')\n');
            outputFunc('            imgData = roiArray(1).imageData;\n');
            outputFunc('            if iscell(imgData) && ~isempty(imgData{1})\n');
            outputFunc('                pixelData = imgData{1};\n');
            outputFunc('            else\n');
            outputFunc('                pixelData = imgData;\n');
            outputFunc('            end\n');
            outputFunc('        end\n');
            
        case 'stripeDataNavigation'
            outputFunc('        %% Method: stripeDataNavigation\n');
            outputFunc('        sd = hSI.hDisplay.lastStripeData;\n');
            outputFunc('        if ~isempty(sd) && ~isempty(sd.roiData)\n');
            outputFunc('            pixelData = sd.roiData{1}.imageData{1}{1};\n');
            outputFunc('        end\n');
            
        case 'bufferExploration'
            outputFunc('        %% Method: bufferExploration\n');
            outputFunc('        buf = hSI.hDisplay.stripeDataBuffer;\n');
            outputFunc('        if iscell(buf) && ~isempty(buf{1})\n');
            outputFunc('            pixelData = buf{1}.roiData{1}.imageData{1}{1};\n');
            outputFunc('        end\n');
    end
    
    outputFunc('        \n');
    outputFunc('        %% Validate and calculate focus\n');
    outputFunc('        if isnumeric(pixelData) && ~isempty(pixelData)\n');
    outputFunc('            img = double(pixelData);\n');
    outputFunc('            if ndims(img) > 2, img = img(:,:,1); end\n');
    outputFunc('            \n');
    outputFunc('            %% Calculate Laplacian variance (best focus metric)\n');
    outputFunc('            if size(img, 1) > 2 && size(img, 2) > 2\n');
    outputFunc('                laplacianKernel = [0 -1 0; -1 4 -1; 0 -1 0];\n');
    outputFunc('                laplacianImg = conv2(img, laplacianKernel, ''valid'');\n');
    outputFunc('                focusValue = var(laplacianImg(:));\n');
    outputFunc('            else\n');
    outputFunc('                focusValue = var(img(:));\n');
    outputFunc('            end\n');
    outputFunc('            \n');
    outputFunc('            success = true;\n');
    outputFunc('        end\n');
    outputFunc('        \n');
    outputFunc('    catch\n');
    outputFunc('        %% Silently fail for robustness\n');
    outputFunc('    end\n');
    outputFunc('end\n');
    outputFunc('```\n\n');
    
    outputFunc('Usage in your Z-stage app:\n');
    outputFunc('```matlab\n');
    outputFunc('%% After each Z movement:\n');
    outputFunc('pause(0.2); %% Wait for new frame\n');
    outputFunc('[pixelData, focusValue, success] = getScanImageFocusData();\n');
    outputFunc('if success\n');
    outputFunc('    fprintf(''Z=%%.1f μm: Focus=%%.0f\\n'', currentZ, focusValue);\n');
    outputFunc('    %% Store in your sweep data\n');
    outputFunc('end\n');
    outputFunc('```\n');
end

%% Helper Functions

function value = safeGet(obj, prop, default)
    try
        if isprop(obj, prop) || (isobject(obj) && isfield(get(obj), prop))
            value = get(obj, prop);
        else
            value = default;
        end
    catch
        value = default;
    end
end

function str = formatBoolean(val)
    if val
        str = 'Yes';
    else
        str = 'No';
    end
end

%% Auto-run the diagnostic when script is executed
if ~exist('hSI', 'var')
    try
        evalin('base', 'hSI');
        diagnose_scanimage_data();
    catch
        fprintf('❌ ScanImage (hSI) not found in base workspace\n');
        fprintf('   Please ensure ScanImage is running and try again\n');
    end
else
    diagnose_scanimage_data();
end