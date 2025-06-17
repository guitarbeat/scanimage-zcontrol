% stripe-data.m
% LUT Value Recording Script for Focus Tracking
% Records Channel LUT values at different Z positions for focus analysis

fprintf('\n🔬 SCANIMAGE LUT VALUE RECORDER\n');
fprintf('==============================\n');
fprintf('Investigation Time: %s\n\n', datestr(now));

% Check if ScanImage is available
if ~evalin('base', 'exist(''hSI'', ''var'') && isa(hSI, ''scanimage.SI'')')
    fprintf('❌ ERROR: ScanImage (hSI) not found in base workspace\n');
    fprintf('   This script requires an active ScanImage session\n');
    return;
end

% Get ScanImage handle
hSI = evalin('base', 'hSI');
hDisp = hSI.hDisplay;

%% Configuration
numRecordings = 10;  % Number of recordings to take
recordingInterval = 1.0;  % Seconds between recordings
movementStep = 1.0;  % μm to move between recordings (set to 0 for manual control)

fprintf('📊 RECORDING CONFIGURATION:\n');
fprintf('   Number of recordings: %d\n', numRecordings);
fprintf('   Recording interval: %.1f seconds\n', recordingInterval);
fprintf('   Z movement step: %.1f μm (0 = manual)\n\n', movementStep);

%% Initialize Data Storage
recordings = struct();
recordings.timestamp = [];
recordings.zPosition = [];
recordings.frameNumber = [];
recordings.chan1Range = [];
recordings.chan1Min = [];
recordings.chan1Max = [];
recordings.chan2Range = [];
recordings.chan3Range = [];
recordings.chan4Range = [];
recordings.acquisitionState = {};

%% Get Initial State
fprintf('🎯 INITIAL SYSTEM STATE:\n');
fprintf('   Acquisition State: %s\n', hSI.acqState);

% Get initial Z position
try
    currentZ = hSI.hMotors.axesPosition(3);
    fprintf('   Current Z Position: %.2f μm\n', currentZ);
catch
    currentZ = NaN;
    fprintf('   Z Position: Unable to read\n');
end

% Get active channels
activeChannels = hSI.hChannels.channelsActive;
fprintf('   Active Channels: %s\n', mat2str(activeChannels));

fprintf('\n🔄 STARTING DATA COLLECTION:\n');
fprintf('   Recording LUT values over time/positions...\n\n');

%% Data Collection Loop
for i = 1:numRecordings
    fprintf('📸 Recording %d/%d: ', i, numRecordings);
    
    % Get timestamp
    currentTime = now;
    
    % Get current Z position
    try
        currentZ = hSI.hMotors.axesPosition(3);
    catch
        currentZ = NaN;
    end
    
    % Get frame number
    try
        frameNum = hDisp.lastFrameNumber;
    catch
        frameNum = NaN;
    end
    
    % Get acquisition state
    try
        acqState = hSI.acqState;
    catch
        acqState = 'unknown';
    end
    
    % Extract LUT values for all channels
    lutValues = [];
    for ch = 1:4
        lutName = sprintf('chan%dLUT', ch);
        if isprop(hDisp, lutName)
            lut = hDisp.(lutName);
            lutValues(ch, :) = [lut(1), lut(end)]; % [min, max]
        else
            lutValues(ch, :) = [NaN, NaN];
        end
    end
    
    % Store data
    recordings.timestamp(i) = currentTime;
    recordings.zPosition(i) = currentZ;
    recordings.frameNumber(i) = frameNum;
    recordings.acquisitionState{i} = acqState;
    
    % Store LUT ranges
    recordings.chan1Min(i) = lutValues(1, 1);
    recordings.chan1Max(i) = lutValues(1, 2);
    recordings.chan1Range(i) = lutValues(1, 2) - lutValues(1, 1);
    recordings.chan2Range(i) = lutValues(2, 2) - lutValues(2, 1);
    recordings.chan3Range(i) = lutValues(3, 2) - lutValues(3, 1);
    recordings.chan4Range(i) = lutValues(4, 2) - lutValues(4, 1);
    
    % Display current reading
    fprintf('Z=%.2f, Ch1=[%d,%d], Range=%d, Frame=%d\n', ...
        currentZ, lutValues(1,1), lutValues(1,2), lutValues(1,2)-lutValues(1,1), frameNum);
    
    % Move Z stage if automatic movement is enabled
    if movementStep > 0 && i < numRecordings
        try
            % Move Z stage up by specified step
            newZ = currentZ + movementStep;
            hSI.hMotors.moveSample([0, 0, movementStep]);
            fprintf('   → Moved Z stage +%.1f μm to %.2f μm\n', movementStep, newZ);
            
            % Wait a bit for movement to complete
            pause(0.5);
        catch ME
            fprintf('   ⚠️ Could not move Z stage: %s\n', ME.message);
        end
    end
    
    % Wait before next recording (unless it's the last one)
    if i < numRecordings
        pause(recordingInterval);
    end
end

%% Data Analysis
fprintf('\n📈 DATA ANALYSIS:\n');
fprintf('================\n');

% Basic statistics
fprintf('\nChannel 1 LUT Statistics:\n');
fprintf('   Min Value Range: [%.0f, %.0f]\n', min(recordings.chan1Min), max(recordings.chan1Min));
fprintf('   Max Value Range: [%.0f, %.0f]\n', min(recordings.chan1Max), max(recordings.chan1Max));
fprintf('   LUT Range Variation: [%.0f, %.0f]\n', min(recordings.chan1Range), max(recordings.chan1Range));

if ~isnan(recordings.zPosition(1))
    fprintf('\nZ Position Statistics:\n');
    fprintf('   Start Position: %.2f μm\n', recordings.zPosition(1));
    fprintf('   End Position: %.2f μm\n', recordings.zPosition(end));
    fprintf('   Total Movement: %.2f μm\n', recordings.zPosition(end) - recordings.zPosition(1));
    fprintf('   Average Step: %.2f μm\n', mean(diff(recordings.zPosition)));
end

% Look for correlations
if length(recordings.zPosition) > 1 && ~any(isnan(recordings.zPosition))
    % Correlation between Z position and LUT values
    corrZMin = corr(recordings.zPosition', recordings.chan1Min');
    corrZMax = corr(recordings.zPosition', recordings.chan1Max');
    corrZRange = corr(recordings.zPosition', recordings.chan1Range');
    
    fprintf('\nCorrelations with Z Position:\n');
    fprintf('   Z vs Chan1 Min: %.3f\n', corrZMin);
    fprintf('   Z vs Chan1 Max: %.3f\n', corrZMax);
    fprintf('   Z vs Chan1 Range: %.3f\n', corrZRange);
    
    % Find most variable parameter
    if abs(corrZRange) > 0.5
        fprintf('   → Strong correlation with LUT range - could indicate focus dependency!\n');
    elseif abs(corrZMin) > 0.5 || abs(corrZMax) > 0.5
        fprintf('   → Strong correlation with LUT min/max - systematic change detected\n');
    else
        fprintf('   → Weak correlations - values may be stable or noise-dominated\n');
    end
end

%% Data Export
fprintf('\n💾 DATA EXPORT:\n');

% Create results table
resultsTable = table(recordings.timestamp', recordings.zPosition', ...
    recordings.frameNumber', recordings.chan1Min', recordings.chan1Max', ...
    recordings.chan1Range', recordings.acquisitionState', ...
    'VariableNames', {'Timestamp', 'ZPosition_um', 'FrameNumber', ...
    'Chan1Min', 'Chan1Max', 'Chan1Range', 'AcqState'});

% Display table
fprintf('\nRecorded Data:\n');
disp(resultsTable);

% Save to workspace
assignin('base', 'lutRecordings', recordings);
assignin('base', 'lutTable', resultsTable);
fprintf('\nData saved to workspace as "lutRecordings" and "lutTable"\n');

% Save to file
filename = sprintf('LUT_Recording_%s.mat', datestr(now, 'yyyymmdd_HHMMSS'));
save(filename, 'recordings', 'resultsTable');
fprintf('Data saved to file: %s\n', filename);

%% Plot Results (if possible)
try
    figure('Name', 'LUT Value Tracking', 'Position', [100 100 800 600]);
    
    if ~any(isnan(recordings.zPosition))
        % Plot vs Z position
        subplot(2,2,1);
        plot(recordings.zPosition, recordings.chan1Min, 'ro-', 'LineWidth', 2);
        xlabel('Z Position (μm)');
        ylabel('Channel 1 LUT Min');
        title('LUT Min vs Z Position');
        grid on;
        
        subplot(2,2,2);
        plot(recordings.zPosition, recordings.chan1Max, 'bo-', 'LineWidth', 2);
        xlabel('Z Position (μm)');
        ylabel('Channel 1 LUT Max');
        title('LUT Max vs Z Position');
        grid on;
        
        subplot(2,2,3);
        plot(recordings.zPosition, recordings.chan1Range, 'go-', 'LineWidth', 2);
        xlabel('Z Position (μm)');
        ylabel('Channel 1 LUT Range');
        title('LUT Range vs Z Position');
        grid on;
    else
        % Plot vs time
        timeVec = (recordings.timestamp - recordings.timestamp(1)) * 24 * 3600; % seconds
        
        subplot(2,2,1);
        plot(timeVec, recordings.chan1Min, 'ro-', 'LineWidth', 2);
        xlabel('Time (seconds)');
        ylabel('Channel 1 LUT Min');
        title('LUT Min vs Time');
        grid on;
        
        subplot(2,2,2);
        plot(timeVec, recordings.chan1Max, 'bo-', 'LineWidth', 2);
        xlabel('Time (seconds)');
        ylabel('Channel 1 LUT Max');
        title('LUT Max vs Time');
        grid on;
        
        subplot(2,2,3);
        plot(timeVec, recordings.chan1Range, 'go-', 'LineWidth', 2);
        xlabel('Time (seconds)');
        ylabel('Channel 1 LUT Range');
        title('LUT Range vs Time');
        grid on;
    end
    
    % Combined plot
    subplot(2,2,4);
    hold on;
    plot(1:length(recordings.chan1Min), recordings.chan1Min, 'ro-', 'DisplayName', 'Min');
    plot(1:length(recordings.chan1Max), recordings.chan1Max, 'bo-', 'DisplayName', 'Max');
    plot(1:length(recordings.chan1Range), recordings.chan1Range, 'go-', 'DisplayName', 'Range');
    xlabel('Recording Number');
    ylabel('LUT Values');
    title('All LUT Values');
    legend('show');
    grid on;
    
    fprintf('\n📊 Plots generated and displayed\n');
    
catch ME
    fprintf('\n⚠️ Could not generate plots: %s\n', ME.message);
end

fprintf('\n✅ LUT Recording Complete\n');
fprintf('==========================\n\n');

%% Summary and Recommendations
fprintf('🎯 SUMMARY & RECOMMENDATIONS:\n');
fprintf('-----------------------------\n');

if any(abs([corrZMin, corrZMax, corrZRange]) > 0.5, 'omitnan')
    fprintf('✅ Strong correlations detected between Z position and LUT values!\n');
    fprintf('   This suggests the LUT values could be used for focus tracking.\n');
    fprintf('   Consider using the most correlated parameter as a focus metric.\n');
else
    fprintf('⚠️ Weak correlations detected.\n');
    fprintf('   LUT values may not be suitable for focus tracking, or\n');
    fprintf('   more data points or larger Z movements may be needed.\n');
end

fprintf('\nNext steps:\n');
fprintf('• Repeat with PMT on to see if signal enhances correlations\n');
fprintf('• Try larger Z movements to see bigger changes\n');
fprintf('• Test around known focus positions\n');
fprintf('• Consider other metrics like image variance or contrast\n');