function diagnose_data()
% DIAGNOSE_DATA.M - Deep ScanImage System Investigation for Focus Finding
%
% Comprehensive analysis of ScanImage data access, motor control, and
% potential focus finding pathways

    fprintf('\n🔬 SCANIMAGE DEEP SYSTEM INVESTIGATION\n');
    fprintf('=====================================\n\n');
    
    % Get hSI
    try
        hSI = evalin('base', 'hSI');
    catch
        error('ScanImage not found in base workspace');
    end
    
    % Section 1: Motor & Position Investigation
    fprintf('🎯 MOTOR & Z-POSITION INVESTIGATION:\n');
    investigateMotors(hSI);
    
    % Section 2: UI Windows & Controls Investigation  
    fprintf('\n🖼️ UI WINDOWS & CONTROLS:\n');
    investigateUIElements(hSI);
    
    % Section 3: Deep Data Access Investigation
    fprintf('\n📊 DATA ACCESS INVESTIGATION:\n');
    investigateDataAccess(hSI);
    
    % Section 4: Focus-Specific Features
    fprintf('\n🔍 FOCUS-SPECIFIC FEATURES:\n');
    investigateFocusFeatures(hSI);
    
    % Section 5: Event Listeners & Callbacks
    fprintf('\n📡 EVENT LISTENERS & CALLBACKS:\n');
    investigateCallbacks(hSI);
    
    % Section 6: Alternative Data Paths
    fprintf('\n🗂️ ALTERNATIVE DATA PATHS:\n');
    findAlternativeDataPaths(hSI);
    
    % Section 7: Test Live Data Acquisition
    fprintf('\n🧪 LIVE DATA ACQUISITION TEST:\n');
    testLiveDataAcquisition(hSI);
    
    fprintf('\n✅ Investigation Complete\n');
end

function investigateMotors(hSI)
% Deep dive into motor system for Z positioning
    
    if isempty(hSI.hMotors)
        fprintf('   ❌ No motor system configured\n');
        return;
    end
    
    fprintf('   Motor System Class: %s\n', class(hSI.hMotors));
    
    % List all motor properties
    props = properties(hSI.hMotors);
    fprintf('   Available Properties:\n');
    for i = 1:length(props)
        try
            val = hSI.hMotors.(props{i});
            if contains(lower(props{i}), {'position', 'axis', 'motor', 'z'})
                fprintf('     📍 %s: %s\n', props{i}, formatValue(val));
            end
        catch
            % Skip
        end
    end
    
    % Check for motor methods
    methods_list = methods(hSI.hMotors);
    fprintf('   Useful Methods:\n');
    relevantMethods = methods_list(contains(lower(methods_list), {'position', 'move', 'zero', 'get', 'set'}));
    for i = 1:length(relevantMethods)
        fprintf('     • %s\n', relevantMethods{i});
    end
    
    % Try to get current position
    fprintf('   Current Position Attempts:\n');
    tryGetPosition(hSI, 'motorPosition');
    tryGetPosition(hSI, 'axesPosition');
    tryGetPosition(hSI, 'position');
    
    % Find Motor Controls window
    fprintf('   Motor Controls Window:\n');
    motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
    if ~isempty(motorFig)
        fprintf('     ✅ Found: Handle=%g, Name="%s"\n', motorFig.Number, motorFig.Name);
        
        % Find Z-related controls
        zControls = findall(motorFig, '-regexp', 'Tag', '.*[Zz].*');
        fprintf('     Z-Related Controls (%d found):\n', length(zControls));
        for i = 1:min(length(zControls), 10)
            ctrl = zControls(i);
            fprintf('       • Tag="%s", Type=%s', ctrl.Tag, ctrl.Type);
            if isprop(ctrl, 'String')
                fprintf(', Value="%s"', ctrl.String);
            elseif isprop(ctrl, 'Value')
                fprintf(', Value=%g', ctrl.Value);
            end
            fprintf('\n');
        end
    else
        fprintf('     ❌ Motor Controls window not found\n');
    end
end

function investigateUIElements(hSI)
% Find all relevant UI windows and their elements
    
    % Find all ScanImage-related figures
    allFigs = findall(0, 'Type', 'figure');
    siFigs = [];
    
    fprintf('   ScanImage Windows:\n');
    for i = 1:length(allFigs)
        fig = allFigs(i);
        if contains(lower(fig.Name), {'scanimage', 'si ', 'motor', 'channel', 'image'})
            siFigs(end+1) = fig;
            fprintf('     📌 Figure #%g: "%s" (Tag="%s")\n', fig.Number, fig.Name, fig.Tag);
        end
    end
    
    % Find channel window for potential data access
    channelFig = findall(0, 'Type', 'figure', '-regexp', 'Name', '.*[Cc]hannel.*');
    if ~isempty(channelFig)
        fprintf('\n   Channel Window Analysis:\n');
        for i = 1:length(channelFig)
            fprintf('     Window: "%s"\n', channelFig(i).Name);
            
            % Look for image display axes
            axes_handles = findall(channelFig(i), 'Type', 'axes');
            fprintf('     Found %d axes\n', length(axes_handles));
            
            % Look for image objects
            images = findall(channelFig(i), 'Type', 'image');
            fprintf('     Found %d image objects\n', length(images));
            
            if ~isempty(images)
                for j = 1:min(length(images), 3)
                    img = images(j);
                    cdata = img.CData;
                    fprintf('       Image %d: Size=%s, Type=%s\n', j, mat2str(size(cdata)), class(cdata));
                end
            end
        end
    end
end

function investigateDataAccess(hSI)
% Deep investigation of all data access methods
    
    % Test getRoiDataArray method
    fprintf('   getRoiDataArray() Method Test:\n');
    try
        if hSI.active
            data = hSI.hDisplay.getRoiDataArray();
            fprintf('     ✅ Success! Data info:\n');
            fprintf('       Type: %s\n', class(data));
            fprintf('       Size: %s\n', mat2str(size(data)));
            if ~isempty(data)
                fprintf('       Dimensions: %dD array\n', ndims(data));
                fprintf('       Value range: [%.1f, %.1f]\n', min(data(:)), max(data(:)));
            end
        else
            fprintf('     ⚠️ System not active - start focus mode first\n');
        end
    catch ME
        fprintf('     ❌ Error: %s\n', ME.message);
    end
    
    % Investigate display object properties
    fprintf('\n   Display Object Deep Scan:\n');
    mc = metaclass(hSI.hDisplay);
    
    % Find all data-related properties
    for i = 1:length(mc.PropertyList)
        prop = mc.PropertyList(i);
        if ~prop.Dependent && strcmp(prop.GetAccess, 'public')
            propName = prop.Name;
            
            % Focus on data/buffer properties
            if contains(lower(propName), {'data', 'buffer', 'frame', 'image', 'stripe'})
                try
                    val = hSI.hDisplay.(propName);
                    fprintf('     %s:\n', propName);
                    fprintf('       Value: %s\n', formatValue(val));
                    
                    % If it's a cell array, investigate contents
                    if iscell(val) && ~isempty(val)
                        fprintf('       Cell contents: ');
                        for j = 1:min(numel(val), 3)
                            fprintf('[%d]=%s ', j, formatValue(val{j}));
                        end
                        fprintf('\n');
                    end
                catch
                    % Skip
                end
            end
        end
    end
    
    % Check for data in scan2D object
    fprintf('\n   Scan2D Data Investigation:\n');
    if isprop(hSI.hScan2D, 'hAcq')
        fprintf('     hAcq property exists\n');
        try
            if ~isempty(hSI.hScan2D.hAcq)
                acqProps = properties(hSI.hScan2D.hAcq);
                dataProps = acqProps(contains(lower(acqProps), {'data', 'buffer'}));
                for i = 1:length(dataProps)
                    fprintf('       • %s\n', dataProps{i});
                end
            end
        catch
            % Skip
        end
    end
end

function investigateFocusFeatures(hSI)
% Look for any built-in focus features
    
    % Check for focus-related methods
    allMethods = methods(hSI);
    focusMethods = allMethods(contains(lower(allMethods), 'focus'));
    
    fprintf('   Focus-Related Methods:\n');
    for i = 1:length(focusMethods)
        fprintf('     • %s', focusMethods{i});
        
        % Try to get method info
        try
            help_text = help(['scanimage.SI.' focusMethods{i}]);
            if ~isempty(help_text)
                first_line = strtok(help_text, newline);
                fprintf(' - %s', strtrim(first_line));
            end
        catch
            % Skip
        end
        fprintf('\n');
    end
    
    % Check for focus properties
    fprintf('\n   Focus-Related Properties:\n');
    props = properties(hSI);
    focusProps = props(contains(lower(props), {'focus', 'sharp', 'quality'}));
    
    for i = 1:length(focusProps)
        try
            val = hSI.(focusProps{i});
            fprintf('     • %s: %s\n', focusProps{i}, formatValue(val));
        catch
            % Skip
        end
    end
    
    % Check display for focus metrics
    if isprop(hSI.hDisplay, 'displayRollingAverageFactor')
        fprintf('\n   Display Averaging Settings:\n');
        fprintf('     Rolling Average Factor: %d\n', hSI.hDisplay.displayRollingAverageFactor);
        fprintf('     Rolling Average Lock: %s\n', mat2str(hSI.hDisplay.displayRollingAverageFactorLock));
    end
end

function investigateCallbacks(hSI)
% Find callbacks and listeners that might help with data access
    
    fprintf('   Event Listeners:\n');
    
    % Check for frame acquired callbacks
    events = {'frameAcquired', 'stripeAcquired', 'sliceDone', 'volumeDone'};
    
    for i = 1:length(events)
        try
            if hSI.hUserFunctions.isUserFunctionEventRegistered(events{i})
                fprintf('     ✅ %s event registered\n', events{i});
            else
                fprintf('     ○ %s event available\n', events{i});
            end
        catch
            % Event might not exist
        end
    end
    
    % Look for user functions
    fprintf('\n   User Function Capabilities:\n');
    ufMethods = methods(hSI.hUserFunctions);
    relevantMethods = ufMethods(contains(lower(ufMethods), {'register', 'event', 'callback'}));
    for i = 1:min(length(relevantMethods), 5)
        fprintf('     • %s\n', relevantMethods{i});
    end
end

function findAlternativeDataPaths(hSI)
% Search for alternative ways to access image data
    
    fprintf('   Alternative Data Access Routes:\n');
    
    % Check workspace for other data variables
    baseVars = evalin('base', 'who');
    dataVars = baseVars(contains(lower(baseVars), {'data', 'img', 'frame', 'image'}));
    
    if ~isempty(dataVars)
        fprintf('     Base Workspace Data Variables:\n');
        for i = 1:length(dataVars)
            try
                var = evalin('base', dataVars{i});
                fprintf('       • %s: %s\n', dataVars{i}, formatValue(var));
            catch
                % Skip
            end
        end
    end
    
    % Check for data logging
    if isprop(hSI, 'hChannels') && isprop(hSI.hChannels, 'loggingEnable')
        fprintf('\n     Logging Status:\n');
        fprintf('       Logging Enabled: %s\n', mat2str(hSI.hChannels.loggingEnable));
        
        if hSI.hChannels.loggingEnable
            fprintf('       Log File Path: %s\n', hSI.hChannels.channelSavePath);
        end
    end
    
    % Check for most recent data
    if isprop(hSI, 'mostRecentData')
        fprintf('\n     Most Recent Data Property: %s\n', formatValue(hSI.mostRecentData));
    end
end

function testLiveDataAcquisition(hSI)
% Test acquiring live data in different ways
    
    if ~hSI.active
        fprintf('   ⚠️ System not active. Start focus mode to test data acquisition.\n');
        fprintf('   Use: hSI.startFocus()\n');
        return;
    end
    
    fprintf('   Testing Data Acquisition Methods:\n');
    
    % Method 1: getRoiDataArray
    fprintf('\n   Method 1 - getRoiDataArray():\n');
    try
        tic;
        data1 = hSI.hDisplay.getRoiDataArray();
        t1 = toc;
        fprintf('     ✅ Success (%.3f ms)\n', t1*1000);
        analyzeData(data1, '     ');
    catch ME
        fprintf('     ❌ Failed: %s\n', ME.message);
    end
    
    % Method 2: Direct buffer access
    fprintf('\n   Method 2 - Direct Buffer Access:\n');
    buffers = {'stripeDataBuffer', 'rollingStripeDataBuffer', 'lastAcqStripeDataBuffer'};
    
    for i = 1:length(buffers)
        try
            buffer = hSI.hDisplay.(buffers{i});
            if iscell(buffer) && ~isempty(buffer{1})
                fprintf('     • %s: Found data\n', buffers{i});
                if iscell(buffer{1}) && ~isempty(buffer{1}{1})
                    analyzeData(buffer{1}{1}, '       ');
                end
            end
        catch
            % Skip
        end
    end
    
    % Method 3: Through image window
    fprintf('\n   Method 3 - Image Window Data:\n');
    channelWindows = findall(0, 'Type', 'figure', '-regexp', 'Name', '.*Channel.*');
    
    for i = 1:length(channelWindows)
        images = findall(channelWindows(i), 'Type', 'image');
        if ~isempty(images)
            fprintf('     • Window "%s":\n', channelWindows(i).Name);
            cdata = images(1).CData;
            analyzeData(cdata, '       ');
        end
    end
end

function analyzeData(data, indent)
% Analyze data for focus metric calculation
    if isempty(data)
        fprintf('%sEmpty data\n', indent);
        return;
    end
    
    fprintf('%sSize: %s\n', indent, mat2str(size(data)));
    fprintf('%sType: %s\n', indent, class(data));
    
    if isnumeric(data) && numel(data) > 100
        % Calculate focus metrics
        fprintf('%sValue Range: [%.1f, %.1f]\n', indent, min(data(:)), max(data(:)));
        fprintf('%sMean±Std: %.1f ± %.1f\n', indent, mean(data(:)), std(double(data(:))));
        
        % Calculate simple sharpness metric (variance)
        sharpness = var(double(data(:)));
        fprintf('%sSharpness (variance): %.2e\n', indent, sharpness);
        
        % Edge strength
        if ndims(data) == 2
            [gx, gy] = gradient(double(data));
            edgeStrength = mean(sqrt(gx(:).^2 + gy(:).^2));
            fprintf('%sEdge Strength: %.2f\n', indent, edgeStrength);
        end
    end
end

function tryGetPosition(hSI, propName)
% Try to get position from various properties
    try
        if isprop(hSI.hMotors, propName)
            pos = hSI.hMotors.(propName);
            fprintf('     • %s: %s\n', propName, formatValue(pos));
            
            % If it's a vector, show Z component
            if isnumeric(pos) && length(pos) >= 3
                fprintf('       Z-position: %.3f\n', pos(3));
            end
        end
    catch ME
        fprintf('     • %s: Error - %s\n', propName, ME.message);
    end
end

function str = formatValue(val)
% Enhanced value formatting
    if isempty(val)
        str = '<empty>';
    elseif isnumeric(val)
        if numel(val) == 1
            str = num2str(val);
        elseif numel(val) <= 10
            str = mat2str(val);
        else
            str = sprintf('[%s] %s array', mat2str(size(val)), class(val));
        end
    elseif islogical(val)
        str = mat2str(val);
    elseif ischar(val)
        if length(val) > 50
            str = sprintf('"%s..."', val(1:47));
        else
            str = sprintf('"%s"', val);
        end
    elseif iscell(val)
        str = sprintf('{%s} cell', mat2str(size(val)));
        if numel(val) == 1
            str = sprintf('%s containing %s', str, formatValue(val{1}));
        end
    elseif isobject(val)
        str = sprintf('<%s object>', class(val));
    else
        str = sprintf('<%s>', class(val));
    end
end