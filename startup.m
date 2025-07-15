% Startup script for FoilView application
% This script adds all necessary paths to the MATLAB path

% Get the directory where this script is located
scriptDir = fileparts(mfilename('fullpath'));

% Add all necessary subdirectories to the path
addpath(fullfile(scriptDir, 'src'));
addpath(fullfile(scriptDir, 'src', 'app'));
addpath(fullfile(scriptDir, 'src', 'views'));
addpath(fullfile(scriptDir, 'src', 'views', 'components'));
addpath(fullfile(scriptDir, 'src', 'controllers'));
addpath(fullfile(scriptDir, 'src', 'utils'));
addpath(fullfile(scriptDir, 'src', 'managers'));

fprintf('FoilView paths added successfully.\n');
fprintf('Run "foilview" to start the application.\n'); 