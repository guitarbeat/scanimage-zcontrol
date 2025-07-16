% Startup script for FoilView in simulation mode
% This script sets up the environment and launches FoilView without requiring ScanImage

fprintf('\n🚀 ===== FoilView Simulation Mode ===== 🚀\n');

try
    % Clear workspace to avoid conflicts
    clear all
    close all
    clc

    % Add source directories to MATLAB path
    fprintf('Adding source directories to path...\n');
    addpath(genpath('src'));

    % Verify critical classes are available
    required_classes = {'foilview', 'FoilviewController', 'UIController', 'ScanImageManager'};
    for i = 1:length(required_classes)
        if exist(required_classes{i}, 'class') ~= 8
            error('Required class %s not found. Please check your path.', required_classes{i});
        end
    end
    fprintf('✓ All required classes found\n');

    % Set up simulation environment
    fprintf('Setting up simulation environment...\n');

    % Create a dummy hSI variable to prevent connection attempts
    % (This will be overridden by the ScanImageManager's simulation mode)
    hSI = [];

    % Set up metadata directory
    metadata_dir = fullfile(pwd, 'simulation_data');
    if ~exist(metadata_dir, 'dir')
        mkdir(metadata_dir);
    end

    % Initialize metadata configuration
    metadataConfig = struct();
    metadataConfig.baseDir = metadata_dir;
    metadataConfig.dirFormat = 'yyyy-MM-dd';
    metadataConfig.metadataFileName = 'imaging_metadata.csv';
    metadataConfig.headers = ['Timestamp,Filename,Scanner,Zoom,FrameRate,Averaging,',...
        'Resolution,FOV_um,PowerPercent,PockelsValue,',...
        'ModulationVoltage,FeedbackVoltage,PowerWatts,',...
        'ZPosition,XPosition,YPosition,BookmarkLabel,BookmarkMetricType,BookmarkMetricValue,Notes\n'];

    % Set up metadata file path
    today_str = char(datetime('now', 'Format', 'yyyy-MM-dd'));
    data_dir = fullfile(metadata_dir, today_str);
    if ~exist(data_dir, 'dir')
        mkdir(data_dir);
    end
    metadataFilePath = fullfile(data_dir, metadataConfig.metadataFileName);

    fprintf('✓ Simulation environment configured\n');
    fprintf('   Data directory: %s\n', data_dir);
    fprintf('   Metadata file: %s\n', metadataFilePath);

    % Launch FoilView
    fprintf('\nLaunching FoilView...\n');
    app = foilview();

    fprintf('✓ FoilView launched successfully in simulation mode!\n');
    fprintf('\nUsage Notes:\n');
    fprintf('- The application is running in simulation mode\n');
    fprintf('- Stage movements will be simulated (no hardware required)\n');
    fprintf('- Metadata will be logged to: %s\n', metadataFilePath);
    fprintf('- Use the Metadata button to initialize logging\n');
    fprintf('- All controls should work normally for testing\n');

catch ME
    fprintf('❌ Failed to start FoilView: %s\n', ME.message);
    fprintf('\nTroubleshooting:\n');
    fprintf('1. Ensure all source files are in the src/ directory\n');
    fprintf('2. Check that MATLAB can find all required classes\n');
    fprintf('3. Verify file permissions for creating directories\n');
    fprintf('\nError details:\n');
    for i = 1:length(ME.stack)
        fprintf('   %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end