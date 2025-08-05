%==============================================================================
% CONFIGUTILS.M
%==============================================================================
% Configuration loading and saving utility class for Foilview.
%
% This class provides static methods for loading, saving, and merging
% configuration structures, as well as providing default application
% configuration values. It is used throughout the application for
% robust configuration management.
%
% Key Features:
%   - Configuration file loading with fallback to defaults
%   - Configuration saving with error handling
%   - Merging of user and default configurations
%   - Default application configuration structure
%
% Dependencies:
%   - MATLAB: File I/O
%   - FoilviewUtils: Error handling
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   config = ConfigUtils.loadConfig('config.mat');
%   ConfigUtils.saveConfig(config, 'config.mat');
%
%==============================================================================

classdef ConfigUtils < handle
    % ConfigUtils - Configuration loading and saving utilities
    
    methods (Static)
        function config = loadConfig(configFile, defaultConfig)
            % Load configuration from file with fallback to defaults
            if nargin < 2
                defaultConfig = struct();
            end
            
            config = defaultConfig;
            
            try
                if exist(configFile, 'file')
                    loadedConfig = load(configFile);
                    if isstruct(loadedConfig)
                        config = ConfigUtils.mergeConfigs(defaultConfig, loadedConfig);
                    end
                end
            catch ME
                FoilviewUtils.logException('ConfigUtils', ME);
            end
        end
        
        function success = saveConfig(config, configFile)
            % Save configuration to file
            success = false;
            try
                save(configFile, '-struct', 'config');
                success = true;
            catch ME
                FoilviewUtils.logException('ConfigUtils', ME);
            end
        end
        
        function merged = mergeConfigs(defaultConfig, userConfig)
            % Merge user configuration with defaults
            merged = defaultConfig;
            
            if isstruct(userConfig)
                fields = fieldnames(userConfig);
                for i = 1:length(fields)
                    merged.(fields{i}) = userConfig.(fields{i});
                end
            end
        end
        
        function config = getDefaultAppConfig()
            % Get default application configuration
            config = struct();
            config.refreshPeriod = 0.5;
            config.metricRefreshPeriod = 1.0;
            config.autoSaveEnabled = true;
            config.logLevel = 2; % WARN
            config.maxDataPoints = 1000;
            config.plotUpdateThrottle = 0.1;
        end
    end
end