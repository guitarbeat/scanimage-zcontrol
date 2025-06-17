function scanimage_data_extractor()
% SCANIMAGE_DATA_EXTRACTOR - Simple tool to extract and test ScanImage data
% 
% Focused on understanding data access for integration with Z-stage apps
% Tests: data extraction, timing, focus metrics, data structure

    fprintf('\n🔬 SCANIMAGE DATA EXTRACTOR\n');
    fprintf('===========================\n\n');
    
    while true
        fprintf('📋 TOOLS:\n');
        fprintf('1. 🧪 Test Data Extraction\n');
        fprintf('2. ⏱️  Test Real-time Data Access\n');
        fprintf('3. 📊 Analyze Data Structure\n');
        fprintf('4. 🎯 Focus Metrics Demo\n');
        fprintf('5. 💻 Show Integration Code\n');
        fprintf('6. ❌ Exit\n\n');
        
        choice = input('Select (1-6): ');
        fprintf('\n');
        
        switch choice
            case 1, testDataExtraction();
            case 2, testRealTimeAccess();
            case 3, analyzeDataStructure();
            case 4, focusMetricsDemo();
            case 5, showIntegrationCode();
            case 6, break;
            otherwise, fprintf('❌ Invalid choice\n');
        end
        
        if choice ~= 6
            fprintf('\n' + repmat('-', 1, 40) + '\n');
        end
    end
end

%% Core Data Extraction Function
function [pixelData, success, info] = getImageData()
    % Main function to extract current image data from ScanImage
    success = false;
    pixelData = [];
    info = struct();
    
    try
        % Get ScanImage handle
        hSI = evalin('base', 'hSI');
        info.scanImageActive = hSI.active;
        info.acquisitionState = hSI.acqState;
        
        if ~hSI.active
            info.error = 'ScanImage not actively acquiring';
            return;
        end
        
        % Navigate to pixel data
        sd = hSI.hDisplay.lastStripeData;
        if isempty(sd) || isempty(sd.roiData)
            info.error = 'No stripe data available';
            return;
        end
        
        % Extract the actual pixel data
        roiData = sd.roiData{1};           % First ROI
        imageData = roiData.imageData{1};  % First channel
        pixelData = imageData{1};          % Actual pixel array
        
        % Verify data quality
        if isnumeric(pixelData) && ~isempty(pixelData) && numel(pixelData) > 100
            success = true;
            
            % Collect metadata
            info.frameNumber = sd.frameNumberAcq;
            info.zPosition = sd.zSeries;
            info.channels = roiData.channels;
            info.dataSize = size(pixelData);
            info.dataType = class(pixelData);
            info.dataRange = [min(pixelData(:)), max(pixelData(:))];
            info.timestamp = now;
        else
            info.error = 'Invalid pixel data format';
        end
        
    catch ME
        info.error = ME.message;
        success = false;
    end
end

function focusValue = calculateFocus(pixelData)
    % Calculate primary focus metric (Laplacian variance)
    focusValue = NaN;
    
    if ~isnumeric(pixelData) || isempty(pixelData)
        return;
    end
    
    try
        img = double(pixelData);
        if ndims(img) > 2
            img = img(:,:,1);
        end
        
        % Laplacian variance (best focus metric)
        if size(img, 1) > 2 && size(img, 2) > 2
            laplacianKernel = [0 -1 0; -1 4 -1; 0 -1 0];
            laplacianImg = conv2(img, laplacianKernel, 'valid');
            focusValue = var(laplacianImg(:));
        else
            focusValue = var(img(:)); % Fallback to image variance
        end
    catch
        focusValue = NaN;
    end
end

%% Test Functions
function testDataExtraction()
    fprintf('🧪 TESTING DATA EXTRACTION\n');
    fprintf('===========================\n');
    
    [pixelData, success, info] = getImageData();
    
    if success
        fprintf('✅ Data extraction SUCCESSFUL\n');
        fprintf('   Size: %s\n', mat2str(info.dataSize));
        fprintf('   Type: %s\n', info.dataType);
        fprintf('   Range: [%.0f, %.0f]\n', info.dataRange(1), info.dataRange(2));
        fprintf('   Frame: #%d\n', info.frameNumber);
        fprintf('   Z Position: %.2f μm\n', info.zPosition);
        fprintf('   Memory: %.2f MB\n', numel(pixelData) * 8 / 1024 / 1024);
        
        % Test focus calculation
        focusValue = calculateFocus(pixelData);
        fprintf('   Focus metric: %.2e\n', focusValue);
        
        % Save for inspection
        assignin('base', 'extractedData', pixelData);
        assignin('base', 'extractedInfo', info);
        fprintf('\n📁 Data saved to workspace as "extractedData" and "extractedInfo"\n');
        
    else
        fprintf('❌ Data extraction FAILED\n');
        fprintf('   Error: %s\n', info.error);
        fprintf('   ScanImage active: %s\n', mat2str(info.scanImageActive));
        fprintf('   Acquisition state: %s\n', info.acquisitionState);
    end
end

function testRealTimeAccess()
    fprintf('⏱️  TESTING REAL-TIME DATA ACCESS\n');
    fprintf('==================================\n');
    
    numTests = input('Number of samples to test (default 10): ');
    if isempty(numTests), numTests = 10; end
    
    interval = input('Sampling interval in seconds (default 0.5): ');
    if isempty(interval), interval = 0.5; end
    
    fprintf('\nSampling %d times every %.1f seconds...\n\n', numTests, interval);
    fprintf('Sample | Time(s) | Frame# | Z(μm)  | Focus Value | Status\n');
    fprintf('-------|---------|--------|--------|-------------|--------\n');
    
    results = struct();
    results.timestamps = NaN(1, numTests);
    results.frameNumbers = NaN(1, numTests);
    results.zPositions = NaN(1, numTests);
    results.focusValues = NaN(1, numTests);
    results.success = false(1, numTests);
    
    startTime = tic;
    
    for i = 1:numTests
        elapsed = toc(startTime);
        
        [pixelData, success, info] = getImageData();
        
        if success
            focusValue = calculateFocus(pixelData);
            results.timestamps(i) = elapsed;
            results.frameNumbers(i) = info.frameNumber;
            results.zPositions(i) = info.zPosition;
            results.focusValues(i) = focusValue;
            results.success(i) = true;
            
            fprintf('%6d | %7.1f | %6d | %6.2f | %11.2e | OK\n', ...
                i, elapsed, info.frameNumber, info.zPosition, focusValue);
        else
            fprintf('%6d | %7.1f | %6s | %6s | %11s | FAIL\n', ...
                i, elapsed, '---', '---', '---');
        end
        
        if i < numTests
            pause(interval);
        end
    end
    
    % Analysis
    successRate = sum(results.success) / numTests * 100;
    fprintf('\n📊 REAL-TIME ACCESS ANALYSIS:\n');
    fprintf('   Success rate: %.1f%% (%d/%d)\n', successRate, sum(results.success), numTests);
    
    if sum(results.success) > 1
        validIdx = results.success;
        fprintf('   Frame rate: %.1f fps\n', mean(diff(results.frameNumbers(validIdx))) / mean(diff(results.timestamps(validIdx))));
        fprintf('   Focus stability: %.2f%% CV\n', 100 * std(results.focusValues(validIdx)) / mean(results.focusValues(validIdx)));
        
        % Check if Z position changed
        zRange = range(results.zPositions(validIdx));
        if zRange > 0.1
            fprintf('   Z movement detected: %.2f μm range\n', zRange);
        else
            fprintf('   Z position stable: %.2f μm\n', mean(results.zPositions(validIdx)));
        end
    end
    
    % Save results
    assignin('base', 'realTimeResults', results);
    fprintf('\n📁 Results saved to workspace as "realTimeResults"\n');
end

function analyzeDataStructure()
    fprintf('📊 ANALYZING DATA STRUCTURE\n');
    fprintf('============================\n');
    
    try
        hSI = evalin('base', 'hSI');
        sd = hSI.hDisplay.lastStripeData;
        
        fprintf('📋 SCANIMAGE DATA PATH:\n');
        fprintf('hSI.hDisplay.lastStripeData\n');
        fprintf('  └─ roiData{1} (ROI #1)\n');
        fprintf('     ├─ channels: %s\n', mat2str(sd.roiData{1}.channels));
        fprintf('     ├─ zs: %.2f\n', sd.roiData{1}.zs);
        fprintf('     ├─ frameNumberAcq: %d\n', sd.roiData{1}.frameNumberAcq);
        fprintf('     └─ imageData{1} (Channel #1)\n');
        fprintf('        └─ {1} → PIXEL DATA\n');
        
        % Extract and analyze pixel data
        pixelData = sd.roiData{1}.imageData{1}{1};
        
        fprintf('\n🔍 PIXEL DATA DETAILS:\n');
        fprintf('   Class: %s\n', class(pixelData));
        fprintf('   Size: %s (%d total pixels)\n', mat2str(size(pixelData)), numel(pixelData));
        fprintf('   Memory: %.2f MB\n', numel(pixelData) * 8 / 1024 / 1024);
        
        if isnumeric(pixelData)
            dataVec = double(pixelData(:));
            fprintf('   Range: [%.3f, %.3f]\n', min(dataVec), max(dataVec));
            fprintf('   Mean: %.3f ± %.3f\n', mean(dataVec), std(dataVec));
            fprintf('   Non-zero: %d/%d (%.1f%%)\n', nnz(pixelData), numel(pixelData), 100*nnz(pixelData)/numel(pixelData));
            
            % Bit depth analysis
            uniqueVals = length(unique(dataVec));
            fprintf('   Unique values: %d\n', uniqueVals);
            
            if uniqueVals < 65536
                fprintf('   Apparent bit depth: ~%d bits\n', ceil(log2(uniqueVals)));
            end
        end
        
        fprintf('\n💻 EXTRACTION CODE:\n');
        fprintf('```matlab\n');
        fprintf('hSI = evalin(''base'', ''hSI'');\n');
        fprintf('pixelData = hSI.hDisplay.lastStripeData.roiData{1}.imageData{1}{1};\n');
        fprintf('```\n');
        
    catch ME
        fprintf('❌ Error analyzing structure: %s\n', ME.message);
    end
end

function focusMetricsDemo()
    fprintf('🎯 FOCUS METRICS DEMONSTRATION\n');
    fprintf('===============================\n');
    
    [pixelData, success, info] = getImageData();
    
    if ~success
        fprintf('❌ Cannot get image data: %s\n', info.error);
        return;
    end
    
    fprintf('📊 Testing different focus metrics on current frame:\n\n');
    
    img = double(pixelData);
    if ndims(img) > 2
        img = img(:,:,1);
    end
    
    % 1. Image variance
    variance = var(img(:));
    fprintf('1. Image Variance:     %12.2e\n', variance);
    
    % 2. Gradient magnitude
    if size(img, 1) > 1 && size(img, 2) > 1
        [Gx, Gy] = gradient(img);
        gradMag = sqrt(Gx.^2 + Gy.^2);
        gradMean = mean(gradMag(:));
        fprintf('2. Gradient Magnitude: %12.2e\n', gradMean);
    end
    
    % 3. Laplacian variance (BEST)
    if size(img, 1) > 2 && size(img, 2) > 2
        laplacianKernel = [0 -1 0; -1 4 -1; 0 -1 0];
        laplacianImg = conv2(img, laplacianKernel, 'valid');
        laplacianVar = var(laplacianImg(:));
        fprintf('3. Laplacian Variance: %12.2e ⭐ RECOMMENDED\n', laplacianVar);
    end
    
    % 4. Sobel edges
    if size(img, 1) > 2 && size(img, 2) > 2
        sobelH = [-1 -2 -1; 0 0 0; 1 2 1];
        sobelV = [-1 0 1; -2 0 2; -1 0 1];
        edgeH = conv2(img, sobelH, 'valid');
        edgeV = conv2(img, sobelV, 'valid');
        edgeMag = sqrt(edgeH.^2 + edgeV.^2);
        sobelMean = mean(edgeMag(:));
        fprintf('4. Sobel Edge:         %12.2e\n', sobelMean);
    end
    
    fprintf('\n💡 RECOMMENDATION:\n');
    fprintf('   Use Laplacian variance as your focus metric\n');
    fprintf('   Higher values = better focus\n');
    fprintf('   Very sensitive to focus changes\n');
    
    % Demonstrate sensitivity
    fprintf('\n🔬 SENSITIVITY TEST:\n');
    fprintf('   Testing focus metric on blurred versions...\n');
    
    try
        % Create slightly blurred versions
        blur1 = imgaussfilt(img, 0.5);
        blur2 = imgaussfilt(img, 1.0);
        blur3 = imgaussfilt(img, 2.0);
        
        focus_orig = calculateFocus(img);
        focus_blur1 = calculateFocus(blur1);
        focus_blur2 = calculateFocus(blur2);
        focus_blur3 = calculateFocus(blur3);
        
        fprintf('   Original:      %.2e (100.0%%)\n', focus_orig);
        fprintf('   Slight blur:   %.2e (%.1f%%)\n', focus_blur1, 100*focus_blur1/focus_orig);
        fprintf('   Medium blur:   %.2e (%.1f%%)\n', focus_blur2, 100*focus_blur2/focus_orig);
        fprintf('   Heavy blur:    %.2e (%.1f%%)\n', focus_blur3, 100*focus_blur3/focus_orig);
        
    catch
        fprintf('   Could not perform blur test (no Image Processing Toolbox)\n');
    end
end

function showIntegrationCode()
    fprintf('💻 INTEGRATION CODE FOR Z-STAGE APP\n');
    fprintf('====================================\n\n');
    
    fprintf('🔸 1. SIMPLE DATA EXTRACTION FUNCTION:\n');
    fprintf('```matlab\n');
    fprintf('function [pixelData, focusValue] = getCurrentImageAndFocus()\n');
    fprintf('    pixelData = [];\n');
    fprintf('    focusValue = NaN;\n');
    fprintf('    \n');
    fprintf('    try\n');
    fprintf('        hSI = evalin(''base'', ''hSI'');\n');
    fprintf('        if ~hSI.active, return; end\n');
    fprintf('        \n');
    fprintf('        %% Extract pixel data\n');
    fprintf('        sd = hSI.hDisplay.lastStripeData;\n');
    fprintf('        pixelData = sd.roiData{1}.imageData{1}{1};\n');
    fprintf('        \n');
    fprintf('        %% Calculate focus (Laplacian variance)\n');
    fprintf('        if isnumeric(pixelData) && ~isempty(pixelData)\n');
    fprintf('            img = double(pixelData);\n');
    fprintf('            laplacianKernel = [0 -1 0; -1 4 -1; 0 -1 0];\n');
    fprintf('            laplacianImg = conv2(img, laplacianKernel, ''valid'');\n');
    fprintf('            focusValue = var(laplacianImg(:));\n');
    fprintf('        end\n');
    fprintf('    catch\n');
    fprintf('        %% Silently fail\n');
    fprintf('    end\n');
    fprintf('end\n');
    fprintf('```\n\n');
    
    fprintf('🔸 2. ADD TO YOUR Z-STAGE APP:\n');
    fprintf('```matlab\n');
    fprintf('%% Add this property:\n');
    fprintf('properties (Access = private)\n');
    fprintf('    CurrentFocusValue (1,1) double = NaN\n');
    fprintf('end\n\n');
    
    fprintf('%% Add this method:\n');
    fprintf('function updateFocusQuality(app)\n');
    fprintf('    [~, focusValue] = getCurrentImageAndFocus();\n');
    fprintf('    app.CurrentFocusValue = focusValue;\n');
    fprintf('    \n');
    fprintf('    %% Update display (if you have a focus display)\n');
    fprintf('    if ~isnan(focusValue)\n');
    fprintf('        app.FocusDisplay.Text = sprintf(''Focus: %%.0f'', focusValue);\n');
    fprintf('    else\n');
    fprintf('        app.FocusDisplay.Text = ''Focus: ---'';\n');
    fprintf('    end\n');
    fprintf('end\n');
    fprintf('```\n\n');
    
    fprintf('🔸 3. FOR YOUR SWEEP FUNCTION:\n');
    fprintf('```matlab\n');
    fprintf('function recordFocusAtCurrentZ(app)\n');
    fprintf('    %% Call this after each Z movement in your sweep\n');
    fprintf('    \n');
    fprintf('    pause(0.2); %% Wait for new frame\n');
    fprintf('    [pixelData, focusValue] = getCurrentImageAndFocus();\n');
    fprintf('    \n');
    fprintf('    if ~isnan(focusValue)\n');
    fprintf('        currentZ = app.CurrentPosition;\n');
    fprintf('        fprintf(''Z=%%.1f μm: Focus=%%.0f\\n'', currentZ, focusValue);\n');
    fprintf('        \n');
    fprintf('        %% Store in your sweep data structure\n');
    fprintf('        app.SweepData.zPositions(end+1) = currentZ;\n');
    fprintf('        app.SweepData.focusValues(end+1) = focusValue;\n');
    fprintf('    end\n');
    fprintf('end\n');
    fprintf('```\n\n');
    
    fprintf('🔸 4. KEY POINTS:\n');
    fprintf('• Data is available immediately after Z movement\n');
    fprintf('• Wait ~0.2s after movement for new frame\n');
    fprintf('• Focus values are typically 10^6 to 10^7 range\n');
    fprintf('• Higher values = better focus\n');
    fprintf('• Very sensitive to small focus changes\n');
    fprintf('• Works with PMT on (gives noise pattern with PMT off)\n\n');
    
    fprintf('📁 Copy these functions to use in your Z-stage app!\n');
end

fprintf('👋 ScanImage Data Extractor ready!\n');