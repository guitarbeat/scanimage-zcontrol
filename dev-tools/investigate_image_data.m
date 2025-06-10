% Investigate image data access and brightness metrics in ScanImage
% This script tests different methods to access image data and calculate brightness

fprintf('--- Testing Image Data Access ---\n');

try
    % Get hSI object
    hSI = evalin('base', 'hSI');
    
    % Method 1: Check data scope configuration
    fprintf('\nMethod 1: Data Scope Configuration\n');
    try
        if ~isempty(hSI.hScan2D.hDataScope)
            fprintf('Data Scope Configuration:\n');
            fprintf('  Active: %d\n', hSI.hScan2D.hDataScope.active);
            fprintf('  Sample rate: %.2f Hz\n', hSI.hScan2D.hDataScope.digitizerSampleRate);
            fprintf('  Current data rate: %.2f Hz\n', hSI.hScan2D.hDataScope.currentDataRate);
            fprintf('  Trigger available: %d\n', hSI.hScan2D.hDataScope.triggerAvailable);
            fprintf('  Trigger hold-off time: %.3f s\n', hSI.hScan2D.hDataScope.triggerHoldOffTime);
            fprintf('  Acquisition time: %.3f s\n', hSI.hScan2D.hDataScope.acquisitionTime);
        end
    catch ME
        fprintf('Error checking data scope configuration: %s\n', ME.message);
    end
    
    % Method 2: Try to access data through callback
    fprintf('\nMethod 2: Callback Access\n');
    try
        if ~isempty(hSI.hScan2D.hDataScope.callbackFcn)
            fprintf('Callback Information:\n');
            % Try to get callback function details
            cbFcn = hSI.hScan2D.hDataScope.callbackFcn;
            fprintf('  Callback type: %s\n', class(cbFcn));
            
            % Try to get function handle information
            try
                fcnInfo = functions(cbFcn);
                fprintf('  Function name: %s\n', fcnInfo.function);
                fprintf('  Function type: %s\n', fcnInfo.type);
                if isfield(fcnInfo, 'workspace')
                    fprintf('  Has workspace: %d\n', ~isempty(fcnInfo.workspace));
                end
            catch
                fprintf('  Could not get function details\n');
            end
        end
    catch ME
        fprintf('Error accessing callback: %s\n', ME.message);
    end
    
    % Method 3: Try to access through hScan2D configuration
    fprintf('\nMethod 3: Scan2D Configuration\n');
    try
        fprintf('Scan2D Configuration:\n');
        fprintf('  Scanner type: %s\n', hSI.hScan2D.scannerType);
        fprintf('  Scan mode: %s\n', hSI.hScan2D.scanMode);
        fprintf('  Pixel bin factor: %d\n', hSI.hScan2D.pixelBinFactor);
        fprintf('  Fill fraction spatial: %.3f\n', hSI.hScan2D.fillFractionSpatial);
        fprintf('  Fill fraction temporal: %.3f\n', hSI.hScan2D.fillFractionTemporal);
        fprintf('  Flyback time per frame: %.3f s\n', hSI.hScan2D.flybackTimePerFrame);
    catch ME
        fprintf('Error accessing Scan2D configuration: %s\n', ME.message);
    end
    
    % Method 4: Try to access through hDisplay with more detailed error handling
    fprintf('\nMethod 4: Display Access\n');
    try
        % Try to access lastAveragedFrame with more detailed error handling
        try
            frameData = hSI.hDisplay.lastAveragedFrame;
            fprintf('lastAveragedFrame:\n');
            fprintf('  Type: %s\n', class(frameData));
            fprintf('  Size: %s\n', mat2str(size(frameData)));
            if ~isempty(frameData)
                fprintf('  Min value: %d\n', min(frameData(:)));
                fprintf('  Max value: %d\n', max(frameData(:)));
                fprintf('  Mean value: %.2f\n', mean(double(frameData(:))));
            end
        catch ME
            fprintf('Error accessing lastAveragedFrame: %s\n', ME.message);
        end
        
        % Try to access lastFrame with more detailed error handling
        try
            frameData = hSI.hDisplay.lastFrame;
            fprintf('lastFrame:\n');
            fprintf('  Type: %s\n', class(frameData));
            fprintf('  Size: %s\n', mat2str(size(frameData)));
            if ~isempty(frameData)
                fprintf('  Min value: %d\n', min(frameData(:)));
                fprintf('  Max value: %d\n', max(frameData(:)));
                fprintf('  Mean value: %.2f\n', mean(double(frameData(:))));
            end
        catch ME
            fprintf('Error accessing lastFrame: %s\n', ME.message);
        end
        
        % Try to access display settings
        fprintf('\nDisplay Settings:\n');
        fprintf('  Rolling average factor: %d\n', hSI.hDisplay.displayRollingAverageFactor);
        fprintf('  Auto scale saturation fraction: %s\n', mat2str(hSI.hDisplay.autoScaleSaturationFraction));
        fprintf('  Line scan history length: %d\n', hSI.hDisplay.lineScanHistoryLength);
    catch ME
        fprintf('Error in display access: %s\n', ME.message);
    end
    
catch
    fprintf('hSI not found in base workspace.\n');
end

fprintf('\n--- Investigation Complete ---\n'); 