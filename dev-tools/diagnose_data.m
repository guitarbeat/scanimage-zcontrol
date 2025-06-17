function diagnose_data()
% DIAGNOSE_DATA.M - Concise ScanImage System Information Collector
%
% Collects essential information about your specific ScanImage configuration
% for data access and focus analysis

    fprintf('\n🔬 SCANIMAGE SYSTEM DIAGNOSTIC\n');
    fprintf('==============================\n\n');
    
    % Get hSI
    try
        hSI = evalin('base', 'hSI');
    catch
        error('ScanImage not found in base workspace');
    end
    
    % Section 1: System Information
    fprintf('📋 SYSTEM CONFIGURATION:\n');
    fprintf('   Version: %d.%d.%d\n', hSI.VERSION_MAJOR, hSI.VERSION_MINOR, hSI.VERSION_UPDATE);
    fprintf('   Scanner: %s\n', hSI.hScan2D.scannerType);
    fprintf('   Imaging System: %s\n', hSI.imagingSystem);
    fprintf('   Active: %s | State: %s\n', mat2str(hSI.active), hSI.acqState);
    
    % Section 2: Channel Configuration Details
    fprintf('\n📡 CHANNEL CONFIGURATION:\n');
    if ~isempty(hSI.hChannels)
        fprintf('   Available: %s\n', mat2str(hSI.hChannels.channelsAvailable));
        fprintf('   Active: %s\n', mat2str(hSI.hChannels.channelsActive));
        fprintf('   Save: %s\n', mat2str(hSI.hChannels.channelSave));
        fprintf('   Display: %s\n', mat2str(hSI.hChannels.channelDisplay));
        
        % Check LUTs for each channel
        for i = 1:4
            try
                lutProp = sprintf('chan%dLUT', i);
                if isprop(hSI.hDisplay, lutProp)
                    lut = hSI.hDisplay.(lutProp);
                    fprintf('   Channel %d LUT: %s\n', i, mat2str(lut));
                end
            catch
                % Skip if property doesn't exist
            end
        end
    end
    
    % Section 3: Display Component Deep Dive
    fprintf('\n🖼️ DISPLAY COMPONENT ANALYSIS:\n');
    collectDisplayInfo(hSI.hDisplay);
    
    % Section 4: Scanner-Specific Information  
    fprintf('\n⚙️ SCANNER CONFIGURATION:\n');
    collectScannerInfo(hSI.hScan2D);
    
    % Section 5: Live Data Analysis
    fprintf('\n📊 LIVE DATA ANALYSIS:\n');
    analyzeLiveData(hSI);
    
    % Section 6: ROI Configuration
    fprintf('\n🎯 ROI CONFIGURATION:\n');
    analyzeRoiConfig(hSI);
    
    % Section 7: Available Methods
    fprintf('\n🔧 AVAILABLE METHODS:\n');
    listKeyMethods(hSI);
    
    % Section 8: Hardware Status
    fprintf('\n🔌 HARDWARE STATUS:\n');
    checkHardwareStatus(hSI);
    
    % Section 9: Data Access Summary
    fprintf('\n📝 DATA ACCESS SUMMARY:\n');
    fprintf('   Confirmed Path: hSI.hDisplay.lastStripeData.roiData{1}.imageData{1}{1}\n');
    fprintf('   Current Status: ');
    
    try
        data = hSI.hDisplay.lastStripeData.roiData{1}.imageData{1}{1};
        if ~isempty(data)
            fprintf('✅ WORKING\n');
            fprintf('   Data Size: [%s]\n', mat2str(size(data)));
            fprintf('   Data Type: %s\n', class(data));
            fprintf('   Value Range: [%.0f, %.0f]\n', min(data(:)), max(data(:)));
        else
            fprintf('❌ NO DATA\n');
        end
    catch ME
        fprintf('❌ ERROR: %s\n', ME.message);
    end
    
    fprintf('\n✅ Diagnostic Complete\n');
end

function collectDisplayInfo(hDisplay)
% Collect comprehensive display information
    
    % Get all properties systematically
    mc = metaclass(hDisplay);
    props = {mc.PropertyList.Name};
    
    % Categorize and display important ones
    dataProps = {};
    settingProps = {};
    
    for i = 1:length(props)
        propName = props{i};
        try
            propMeta = findobj(mc.PropertyList, 'Name', propName);
            if propMeta.Dependent || strcmp(propMeta.GetAccess, 'private')
                continue;
            end
            
            val = hDisplay.(propName);
            
            % Categorize by name patterns
            if contains(lower(propName), {'data', 'frame', 'stripe', 'buffer'})
                dataProps{end+1} = propName;
                fprintf('   📊 %s: %s\n', propName, formatValue(val));
            elseif contains(lower(propName), {'factor', 'enable', 'mode', 'rate'})
                settingProps{end+1} = propName;
                fprintf('   ⚙️ %s: %s\n', propName, formatValue(val));
            end
        catch
            % Skip inaccessible properties
        end
    end
end

function collectScannerInfo(hScan2D)
% Collect scanner-specific information
    
    % Key scanner properties
    scannerProps = {'scannerType', 'scanMode', 'sampleRate', 'pixelsPerLine', ...
                   'linesPerFrame', 'flybackTimePerFrame', 'fillFractionSpatial', ...
                   'fillFractionTemporal', 'bidirectional'};
    
    for i = 1:length(scannerProps)
        try
            if isprop(hScan2D, scannerProps{i})
                val = hScan2D.(scannerProps{i});
                fprintf('   %s: %s\n', scannerProps{i}, formatValue(val));
            end
        catch
            % Skip
        end
    end
    
    % Check for scanner-specific data access
    fprintf('   Data-related properties:\n');
    props = properties(hScan2D);
    for i = 1:length(props)
        if contains(lower(props{i}), {'data', 'callback', 'buffer'})
            try
                val = hScan2D.(props{i});
                fprintf('     %s: %s\n', props{i}, formatValue(val));
            catch
                % Skip
            end
        end
    end
end

function analyzeLiveData(hSI)
% Analyze current live data in detail
    
    try
        if ~hSI.active
            fprintf('   Status: Not scanning - start with hSI.startFocus()\n');
            return;
        end
        
        stripeData = hSI.hDisplay.lastStripeData;
        
        if isempty(stripeData)
            fprintf('   Status: No stripe data available\n');
            return;
        end
        
        fprintf('   StripeData Properties:\n');
        stripeProps = {'frameNumberAcq', 'acqNumber', 'stripeNumber', 'channelNumbers', ...
                      'startOfFrame', 'endOfFrame', 'zSeries'};
        
        for i = 1:length(stripeProps)
            try
                if isprop(stripeData, stripeProps{i})
                    val = stripeData.(stripeProps{i});
                    fprintf('     %s: %s\n', stripeProps{i}, formatValue(val));
                end
            catch
                % Skip
            end
        end
        
        % Analyze ROI data structure
        roiData = stripeData.roiData;
        fprintf('   ROI Structure: {%s} cell array\n', mat2str(size(roiData)));
        
        if ~isempty(roiData)
            roiObj = roiData{1};
            fprintf('   ROI Object Properties:\n');
            roiProps = {'channels', 'zs', 'stripeFullFrameNumLines', 'transposed'};
            
            for i = 1:length(roiProps)
                try
                    if isprop(roiObj, roiProps{i})
                        val = roiObj.(roiProps{i});
                        fprintf('     %s: %s\n', roiProps{i}, formatValue(val));
                    end
                catch
                    % Skip
                end
            end
            
            % Image data analysis
            imageData = roiObj.imageData;
            fprintf('   ImageData: %s\n', formatValue(imageData));
            
            if iscell(imageData) && ~isempty(imageData{1})
                if iscell(imageData{1}) && ~isempty(imageData{1}{1})
                    actualData = imageData{1}{1};
                    fprintf('   Actual Pixel Data:\n');
                    fprintf('     Size: [%s]\n', mat2str(size(actualData)));
                    fprintf('     Type: %s\n', class(actualData));
                    fprintf('     Range: [%.1f, %.1f]\n', min(actualData(:)), max(actualData(:)));
                    fprintf('     Mean±Std: %.1f±%.1f\n', mean(actualData(:)), std(actualData(:)));
                    
                    % Memory usage
                    info = whos('actualData');
                    fprintf('     Memory: %.1f MB\n', info.bytes / 1024^2);
                end
            end
        end
        
    catch ME
        fprintf('   Error accessing live data: %s\n', ME.message);
    end
end

function analyzeRoiConfig(hSI)
% Analyze ROI configuration
    
    try
        if ~isempty(hSI.hRoiManager)
            fprintf('   ROI Manager Available: Yes\n');
            
            % Get ROI properties
            roiProps = {'scanVolumeRate', 'forceSquarePixels', 'forceSquarePixelation'};
            for i = 1:length(roiProps)
                try
                    if isprop(hSI.hRoiManager, roiProps{i})
                        val = hSI.hRoiManager.(roiProps{i});
                        fprintf('   %s: %s\n', roiProps{i}, formatValue(val));
                    end
                catch
                    % Skip
                end
            end
        else
            fprintf('   ROI Manager: Not available\n');
        end
    catch
        fprintf('   ROI Manager: Error accessing\n');
    end
end

function listKeyMethods(hSI)
% List key available methods
    
    % Check hSI methods
    methods_hSI = methods(hSI);
    dataMethodsHSI = methods_hSI(contains(lower(methods_hSI), {'start', 'stop', 'grab', 'focus'}));
    
    if ~isempty(dataMethodsHSI)
        fprintf('   hSI Control Methods:\n');
        for i = 1:length(dataMethodsHSI)
            fprintf('     %s\n', dataMethodsHSI{i});
        end
    end
    
    % Check hDisplay methods
    methods_display = methods(hSI.hDisplay);
    dataMethodsDisplay = methods_display(contains(lower(methods_display), {'get', 'data', 'update'}));
    
    if ~isempty(dataMethodsDisplay)
        fprintf('   hDisplay Methods:\n');
        for i = 1:length(dataMethodsDisplay)
            fprintf('     %s\n', dataMethodsDisplay{i});
        end
    end
end

function checkHardwareStatus(hSI)
% Check hardware component status
    
    % PMT status
    if ~isempty(hSI.hPmts)
        fprintf('   PMTs: Available\n');
    else
        fprintf('   PMTs: Not configured\n');
    end
    
    % Motors
    if ~isempty(hSI.hMotors)
        fprintf('   Motors: Available\n');
    else
        fprintf('   Motors: Not configured\n');
    end
    
    % Beams/Shutters
    if ~isempty(hSI.hBeams)
        fprintf('   Beam Control: Available\n');
    else
        fprintf('   Beam Control: Not configured\n');
    end
    
    if ~isempty(hSI.hShutters)
        fprintf('   Shutters: Available\n');
    else
        fprintf('   Shutters: Not configured\n');
    end
end

function str = formatValue(val)
% Format values for display
    if isempty(val)
        str = '<empty>';
    elseif isnumeric(val)
        if numel(val) == 1
            str = num2str(val);
        elseif numel(val) <= 10
            str = mat2str(val);
        else
            str = sprintf('[%s] %s', mat2str(size(val)), class(val));
        end
    elseif islogical(val)
        str = mat2str(val);
    elseif ischar(val)
        str = sprintf('"%s"', val);
    elseif iscell(val)
        str = sprintf('{%s} cell', mat2str(size(val)));
    else
        str = sprintf('<%s>', class(val));
    end
end