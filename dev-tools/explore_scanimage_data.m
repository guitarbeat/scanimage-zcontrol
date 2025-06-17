function explore_scanimage_data_v2()
% EXPLORE_SCANIMAGE_DATA_V2 - Better exploration of ScanImage data structure
%
% This version properly handles ScanImage's component architecture

    fprintf('\n========================================\n');
    fprintf('ScanImage Data Exploration Tool v2\n');
    fprintf('========================================\n\n');
    
    % Get hSI object
    try
        hSI = evalin('base', 'hSI');
        fprintf('✓ Found hSI in base workspace\n');
    catch
        error('❌ ScanImage (hSI) not found in base workspace');
    end
    
    % Check scanning status
    fprintf('\n📊 SCANNING STATUS:\n');
    fprintf('-------------------\n');
    fprintf('Active: %s\n', mat2str(hSI.active));
    fprintf('Acquisition state: %s\n', hSI.acqState);
    
    if ~hSI.active
        fprintf('\n⚠️  ScanImage is NOT actively scanning!\n');
        fprintf('\n📌 To see available data, you need to:\n');
        fprintf('   1. Press "FOCUS" or "GRAB" button in ScanImage\n');
        fprintf('   2. Or run: hSI.startFocus() or hSI.startGrab()\n');
        fprintf('\nWould you like to start a focus session? (y/n): ');
        
        answer = input('', 's');
        if lower(answer) == 'y'
            try
                fprintf('Starting focus mode...\n');
                hSI.startFocus();
                pause(1); % Give it time to start
                fprintf('✓ Focus mode started\n\n');
            catch ME
                fprintf('❌ Could not start focus: %s\n', ME.message);
            end
        end
    end
    
    % Explore hDisplay component properly
    fprintf('\n🖼️ DISPLAY COMPONENT EXPLORATION:\n');
    fprintf('----------------------------------\n');
    
    if ~isempty(hSI.hDisplay)
        % Get all properties using metaclass
        mc = metaclass(hSI.hDisplay);
        props = {mc.PropertyList.Name};
        
        fprintf('Total properties: %d\n\n', length(props));
        
        % Categorize properties
        categories = struct();
        categories.data = {};
        categories.settings = {};
        categories.channels = {};
        categories.display = {};
        categories.other = {};
        
        for i = 1:length(props)
            propName = props{i};
            
            % Skip dependent properties that might cause errors
            propMeta = findobj(mc.PropertyList, 'Name', propName);
            if propMeta.Dependent
                continue;
            end
            
            % Categorize
            if contains(lower(propName), {'frame', 'data', 'stripe', 'roi'})
                categories.data{end+1} = propName;
            elseif contains(lower(propName), {'channel', 'chan'})
                categories.channels{end+1} = propName;
            elseif contains(lower(propName), {'display', 'show', 'renderer'})
                categories.display{end+1} = propName;
            elseif contains(lower(propName), {'enable', 'factor', 'mode', 'type'})
                categories.settings{end+1} = propName;
            else
                categories.other{end+1} = propName;
            end
        end
        
        % Display categorized properties
        fprintf('📁 DATA-RELATED PROPERTIES:\n');
        exploreProperties(hSI.hDisplay, categories.data);
        
        fprintf('\n📺 DISPLAY-RELATED PROPERTIES:\n');
        exploreProperties(hSI.hDisplay, categories.display);
        
        fprintf('\n🔧 CHANNEL PROPERTIES:\n');
        exploreProperties(hSI.hDisplay, categories.channels);
        
        fprintf('\n⚙️ KEY SETTINGS:\n');
        exploreProperties(hSI.hDisplay, categories.settings);
    end
    
    % Explore channel configuration
    fprintf('\n📡 CHANNEL CONFIGURATION:\n');
    fprintf('-------------------------\n');
    
    if ~isempty(hSI.hChannels)
        channelProps = {'channelsAvailable', 'channelsActive', 'channelDisplay', ...
                       'channelSave', 'channelsSubtractOffsets', 'channelLUT'};
        
        for i = 1:length(channelProps)
            try
                val = hSI.hChannels.(channelProps{i});
                fprintf('%s: %s\n', channelProps{i}, mat2str(val));
            catch
                % Skip if property doesn't exist
            end
        end
    end
    
    % Look for actual image data in different ways
    fprintf('\n🔍 HUNTING FOR IMAGE DATA:\n');
    fprintf('--------------------------\n');
    
    % Method 1: Check if any channel windows are open
    fprintf('\n1. Looking for channel figure windows:\n');
    figs = findall(0, 'Type', 'figure');
    channelFigs = [];
    
    for i = 1:length(figs)
        figName = get(figs(i), 'Name');
        if contains(figName, 'Channel #')
            channelFigs(end+1) = figs(i);
            fprintf('   ✓ Found: %s\n', figName);
            
            % Try to get image data from the figure
            ax = findall(figs(i), 'Type', 'axes');
            if ~isempty(ax)
                img = findall(ax(1), 'Type', 'image');
                if ~isempty(img)
                    cdata = get(img(1), 'CData');
                    if ~isempty(cdata)
                        fprintf('     → Image data: %s, range [%.1f, %.1f]\n', ...
                            mat2str(size(cdata)), min(cdata(:)), max(cdata(:)));
                    end
                end
            end
        end
    end
    
    if isempty(channelFigs)
        fprintf('   ❌ No channel display windows found\n');
    end
    
    % Method 2: Try to access display data directly
    fprintf('\n2. Direct data access attempts:\n');
    
    % Try different property names that might exist
    dataProps = {'lastFrame', 'stripeData', 'lastStripeData', ...
                'displayFrameData', 'rollingStripeDataBuffer', ...
                'lastAcquiredFrame', 'currentFrameData'};
    
    for i = 1:length(dataProps)
        try
            % Use dynamic field reference
            if isprop(hSI.hDisplay, dataProps{i})
                data = hSI.hDisplay.(dataProps{i});
                if ~isempty(data)
                    fprintf('   ✓ hSI.hDisplay.%s: %s\n', dataProps{i}, getDataSummary(data));
                end
            end
        catch
            % Skip errors
        end
    end
    
    % Method 3: Check for listeners or callbacks
    fprintf('\n3. Event listeners and callbacks:\n');
    
    % Look for frameAcquired events
    events = {'frameAcquired', 'stripeAcquired', 'frameDisplayed'};
    for i = 1:length(events)
        try
            if isprop(hSI.hDisplay, events{i})
                fprintf('   ✓ Event: %s\n', events{i});
            end
        catch
            % Skip
        end
    end
    
    % Practical data access test
    fprintf('\n📋 PRACTICAL DATA ACCESS TEST:\n');
    fprintf('------------------------------\n');
    
    if hSI.active
        fprintf('ScanImage is active. Attempting to capture current data...\n');
        
        % Try to get a snapshot of current data
        pause(0.1); % Wait for a frame
        
        % Method 1: Look for specific properties
        testProps = {'stripeData', 'lastFrame', 'lastStripeData'};
        
        for i = 1:length(testProps)
            try
                if isprop(hSI.hDisplay, testProps{i})
                    data = hSI.hDisplay.(testProps{i});
                    if ~isempty(data)
                        fprintf('✓ Found data in %s\n', testProps{i});
                        analyzeData(data);
                    end
                end
            catch ME
                fprintf('Error accessing %s: %s\n', testProps{i}, ME.message);
            end
        end
    else
        fprintf('❌ Cannot test data access - ScanImage is not scanning\n');
    end
    
    % Summary and recommendations
    fprintf('\n📝 SUMMARY & RECOMMENDATIONS:\n');
    fprintf('-----------------------------\n');
    
    if hSI.active
        fprintf('✓ ScanImage is active\n');
        fprintf('\nTo access image data, try:\n');
        fprintf('1. Look for image data in channel figure windows\n');
        fprintf('2. Monitor hSI.hDisplay properties during acquisition\n');
        fprintf('3. Set up event listeners for frame acquisition\n');
    else
        fprintf('❌ ScanImage is NOT active\n');
        fprintf('\nTo see available data:\n');
        fprintf('1. Start scanning: hSI.startFocus() or hSI.startGrab()\n');
        fprintf('2. Run this script again while scanning\n');
    end
    
    % Save detailed report
    fprintf('\nGenerating detailed property report...\n');
    generateDetailedReport(hSI);
end

function exploreProperties(obj, propList)
% Explore specific properties of an object
    for i = 1:length(propList)
        propName = propList{i};
        try
            val = obj.(propName);
            fprintf('  %s: %s\n', propName, getValueDescription(val));
        catch ME
            if contains(ME.message, 'Dependent property')
                fprintf('  %s: <dependent property>\n', propName);
            else
                fprintf('  %s: <error: %s>\n', propName, ME.message);
            end
        end
    end
end

function desc = getValueDescription(val)
% Get a descriptive string for a value
    if isempty(val)
        desc = '<empty>';
    elseif isnumeric(val)
        if numel(val) == 1
            desc = num2str(val);
        else
            desc = sprintf('[%s] %s', mat2str(size(val)), class(val));
        end
    elseif ischar(val)
        desc = sprintf('"%s"', val);
    elseif islogical(val)
        if numel(val) == 1
            desc = mat2str(val);
        else
            desc = sprintf('[%s] logical', mat2str(size(val)));
        end
    elseif iscell(val)
        desc = sprintf('{%s} cell', mat2str(size(val)));
    else
        desc = sprintf('<%s>', class(val));
    end
end

function summary = getDataSummary(data)
% Get summary of data content
    if iscell(data)
        summary = sprintf('{%s} cell array', mat2str(size(data)));
        % Check first element
        if ~isempty(data) && ~isempty(data{1})
            if isnumeric(data{1})
                summary = sprintf('%s, first element: [%s] numeric', ...
                    summary, mat2str(size(data{1})));
            end
        end
    elseif isnumeric(data)
        if numel(data) > 100
            summary = sprintf('[%s] %s, range [%.1f, %.1f], mean %.1f', ...
                mat2str(size(data)), class(data), ...
                min(data(:)), max(data(:)), mean(double(data(:))));
        else
            summary = sprintf('[%s] %s', mat2str(size(data)), class(data));
        end
    elseif isstruct(data)
        fields = fieldnames(data);
        summary = sprintf('struct with fields: %s', strjoin(fields, ', '));
    else
        summary = sprintf('<%s>', class(data));
    end
end

function analyzeData(data)
% Analyze found data
    if iscell(data)
        fprintf('  Data is a cell array of size %s\n', mat2str(size(data)));
        for i = 1:min(3, numel(data))
            if ~isempty(data{i}) && isnumeric(data{i})
                fprintf('    Cell %d: [%s] %s, range [%.1f, %.1f]\n', ...
                    i, mat2str(size(data{i})), class(data{i}), ...
                    min(data{i}(:)), max(data{i}(:)));
            end
        end
    elseif isnumeric(data) && numel(data) > 100
        fprintf('  Numeric array: %s %s\n', mat2str(size(data)), class(data));
        fprintf('    Range: [%.1f, %.1f]\n', min(data(:)), max(data(:)));
        fprintf('    Mean: %.1f, Std: %.1f\n', mean(double(data(:))), std(double(data(:))));
        
        % Check if it looks like image data
        if ndims(data) == 2 && min(size(data)) > 10
            fprintf('    → Appears to be 2D image data!\n');
        elseif ndims(data) == 3
            fprintf('    → Appears to be multi-channel/frame image data!\n');
        end
    end
end

function generateDetailedReport(hSI)
% Generate a detailed property report file
    filename = sprintf('scanimage_properties_%s.txt', datestr(now, 'yyyymmdd_HHMMSS'));
    fid = fopen(filename, 'w');
    
    fprintf(fid, 'ScanImage Property Report\n');
    fprintf(fid, 'Generated: %s\n', datestr(now));
    fprintf(fid, '=====================================\n\n');
    
    % List all display properties
    if ~isempty(hSI.hDisplay)
        fprintf(fid, 'DISPLAY COMPONENT PROPERTIES:\n');
        fprintf(fid, '-----------------------------\n');
        
        mc = metaclass(hSI.hDisplay);
        props = {mc.PropertyList.Name};
        
        for i = 1:length(props)
            propMeta = findobj(mc.PropertyList, 'Name', props{i});
            fprintf(fid, '%s:\n', props{i});
            fprintf(fid, '  GetAccess: %s\n', propMeta.GetAccess);
            fprintf(fid, '  SetAccess: %s\n', propMeta.SetAccess);
            fprintf(fid, '  Dependent: %s\n', mat2str(propMeta.Dependent));
            fprintf(fid, '  Hidden: %s\n', mat2str(propMeta.Hidden));
            
            if ~propMeta.Dependent && strcmp(propMeta.GetAccess, 'public')
                try
                    val = hSI.hDisplay.(props{i});
                    fprintf(fid, '  Current value: %s\n', getValueDescription(val));
                catch
                    fprintf(fid, '  Current value: <error accessing>\n');
                end
            end
            fprintf(fid, '\n');
        end
    end
    
    fclose(fid);
    fprintf('✓ Detailed report saved to: %s\n', filename);
end