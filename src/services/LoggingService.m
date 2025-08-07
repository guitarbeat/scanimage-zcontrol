%==============================================================================
% LOGGINGSERVICE.M
%==============================================================================
% Unified logging service for the Foilview application.
%
% This service provides consistent, structured logging across all components
% with proper log levels, timestamps, and component context. It replaces
% scattered fprintf statements with a centralized logging system.
%
% Key Features:
%   - Structured logging with timestamps and component context
%   - Multiple log levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
%   - Colored console output using cprintf for better readability
%   - Configurable output (console, file, or both)
%   - Component-specific logging with automatic context
%   - Performance-optimized logging with level filtering
%   - Error handling and recovery mechanisms
%
% Log Levels:
%   - DEBUG: Detailed diagnostic information
%   - INFO: General information about program execution
%   - WARNING: Warning messages for potentially harmful situations
%   - ERROR: Error events that might still allow the application to continue
%   - CRITICAL: Critical events that may prevent the application from running
%
% Dependencies:
%   - cprintf (optional): For colored console output
%     Download from: https://www.mathworks.com/matlabcentral/fileexchange/24093
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   logger = LoggingService('ComponentName');
%   logger.info('Application started');
%   logger.warning('Connection timeout');
%   logger.error('Failed to initialize hardware');
%
%==============================================================================

classdef LoggingService < handle
    % LoggingService - Unified logging service for consistent output
    
    properties (Access = private)
        ComponentName     % Name of the component using this logger
        LogLevel         % Minimum log level to display
        IncludeTimestamp % Whether to include timestamps
        OutputToConsole  % Whether to output to console
        OutputToFile     % Whether to output to file
        LogFile          % Log file path (if file logging enabled)
        LogLevels        % Available log levels and their numeric values
        UseColoredOutput % Whether to use colored console output
        CprintfAvailable % Whether cprintf is available
        ColorScheme      % Color scheme for different log levels
    end
    
    properties (Constant)
        % Log level definitions (higher number = higher priority)
        DEBUG = 1
        INFO = 2
        WARNING = 3
        ERROR = 4
        CRITICAL = 5
        
        % Default settings
        DEFAULT_LOG_LEVEL = 'INFO'
        DEFAULT_INCLUDE_TIMESTAMP = true
        DEFAULT_OUTPUT_TO_CONSOLE = true
        DEFAULT_OUTPUT_TO_FILE = false
        DEFAULT_USE_COLORED_OUTPUT = true
    end
    
    methods
        function obj = LoggingService(componentName, varargin)
            % Constructor
            % componentName: Name of the component using this logger
            % varargin: Optional parameter-value pairs for configuration
            
            if nargin < 1
                componentName = 'Unknown';
            end
            
            obj.ComponentName = componentName;
            
            % Parse optional parameters
            p = inputParser;
            addParameter(p, 'LogLevel', obj.DEFAULT_LOG_LEVEL, @ischar);
            addParameter(p, 'IncludeTimestamp', obj.DEFAULT_INCLUDE_TIMESTAMP, @islogical);
            addParameter(p, 'OutputToConsole', obj.DEFAULT_OUTPUT_TO_CONSOLE, @islogical);
            addParameter(p, 'OutputToFile', obj.DEFAULT_OUTPUT_TO_FILE, @islogical);
            addParameter(p, 'LogFile', '', @ischar);
            addParameter(p, 'SuppressInitMessage', false, @islogical);
            addParameter(p, 'UseColoredOutput', obj.DEFAULT_USE_COLORED_OUTPUT, @islogical);
            parse(p, varargin{:});
            
            % Set properties
            obj.LogLevel = p.Results.LogLevel;
            obj.IncludeTimestamp = p.Results.IncludeTimestamp;
            obj.OutputToConsole = p.Results.OutputToConsole;
            obj.OutputToFile = p.Results.OutputToFile;
            obj.LogFile = p.Results.LogFile;
            obj.UseColoredOutput = p.Results.UseColoredOutput;
            
            % Initialize log levels mapping
            obj.LogLevels = containers.Map(...
                {'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'}, ...
                {obj.DEBUG, obj.INFO, obj.WARNING, obj.ERROR, obj.CRITICAL});
            
            % Initialize colored output
            obj.initializeColoredOutput();
            
            % Initialize file logging if requested
            if obj.OutputToFile && isempty(obj.LogFile)
                obj.initializeFileLogging();
            end
            
            % Log initialization (unless suppressed)
            if ~p.Results.SuppressInitMessage
                obj.info('Logging service initialized');
            end
        end
        
        function debug(obj, message, varargin)
            % Log debug message
            obj.log(obj.DEBUG, 'DEBUG', message, varargin{:});
        end
        
        function info(obj, message, varargin)
            % Log info message
            obj.log(obj.INFO, 'INFO', message, varargin{:});
        end
        
        function warning(obj, message, varargin)
            % Log warning message
            obj.log(obj.WARNING, 'WARNING', message, varargin{:});
        end
        
        function error(obj, message, varargin)
            % Log error message
            obj.log(obj.ERROR, 'ERROR', message, varargin{:});
        end
        
        function critical(obj, message, varargin)
            % Log critical message
            obj.log(obj.CRITICAL, 'CRITICAL', message, varargin{:});
        end
        
        function setLogLevel(obj, level)
            % Set minimum log level
            if ischar(level) && isKey(obj.LogLevels, level)
                obj.LogLevel = level;
                obj.info('Log level set to %s', level);
            else
                obj.warning('Invalid log level: %s', level);
            end
        end
        
        function setComponentName(obj, name)
            % Update component name
            oldName = obj.ComponentName;
            obj.ComponentName = name;
            obj.info('Component name changed from "%s" to "%s"', oldName, name);
        end
        
        function enableFileLogging(obj, logFile)
            % Enable file logging with optional custom log file
            if nargin < 2
                obj.initializeFileLogging();
            else
                obj.LogFile = logFile;
            end
            obj.OutputToFile = true;
            obj.info('File logging enabled: %s', obj.LogFile);
        end
        
        function disableFileLogging(obj)
            % Disable file logging
            obj.OutputToFile = false;
            obj.LogFile = '';
            obj.info('File logging disabled');
        end
        
        function enableColoredOutput(obj)
            % Enable colored console output
            obj.UseColoredOutput = true;
            obj.info('Colored output enabled');
        end
        
        function disableColoredOutput(obj)
            % Disable colored console output
            obj.UseColoredOutput = false;
            obj.info('Colored output disabled');
        end
        
        function progress(obj, message, varargin)
            % Log progress message with cross-platform overwrite support
            % Uses carriage return for reliable progress updates
            if ~obj.shouldLog(obj.INFO)
                return;
            end
            
            if ~isempty(varargin)
                try
                    formattedMessage = sprintf(message, varargin{:});
                catch ME
                    formattedMessage = sprintf('Message formatting error: %s', ME.message);
                end
            else
                formattedMessage = message;
            end
            
            % Create progress entry without newline
            if obj.IncludeTimestamp
                timestamp = datestr(now, 'HH:MM:SS');
                progressEntry = sprintf('\r[%s] [PROGRESS] [%s] %s', timestamp, obj.ComponentName, formattedMessage);
            else
                progressEntry = sprintf('\r[PROGRESS] [%s] %s', obj.ComponentName, formattedMessage);
            end
            
            % Output to console only (file logging would be messy for progress)
            if obj.OutputToConsole
                fprintf('%s', progressEntry);
            end
        end
        
        function progressComplete(obj, finalMessage)
            % Complete progress logging with final message and newline
            if nargin < 2
                finalMessage = 'Complete';
            end
            obj.progress(finalMessage);
            fprintf('\n'); % Add newline to finish progress display
        end
    end
    
    methods (Access = private)
        function log(obj, level, levelName, message, varargin)
            % Internal logging method
            % level: Numeric log level
            % levelName: String representation of log level
            % message: Message to log
            % varargin: Optional format arguments
            
            % Check if we should log this level
            if ~obj.shouldLog(level)
                return;
            end
            
            % Format message if arguments provided
            if ~isempty(varargin)
                try
                    formattedMessage = sprintf(message, varargin{:});
                catch ME
                    formattedMessage = sprintf('Message formatting error: %s (original: %s)', ME.message, message);
                end
            else
                formattedMessage = message;
            end
            
            % Create log entry
            logEntry = obj.createLogEntry(levelName, formattedMessage);
            
            % Output to console
            if obj.OutputToConsole
                obj.outputToConsole(levelName, logEntry);
            end
            
            % Output to file
            if obj.OutputToFile && ~isempty(obj.LogFile)
                obj.writeToFile(logEntry);
            end
        end
        
        function shouldLog = shouldLog(obj, level)
            % Check if we should log at the given level
            currentLevel = obj.LogLevels(obj.LogLevel);
            shouldLog = level >= currentLevel;
        end
        
                               function logEntry = createLogEntry(obj, levelName, message)
            % Create formatted log entry
            if obj.IncludeTimestamp
                timestamp = datestr(now, 'HH:MM:SS');
                logEntry = sprintf('[%s] [%s] [%s] %s', timestamp, levelName, obj.ComponentName, message);
            else
                logEntry = sprintf('[%s] [%s] %s', levelName, obj.ComponentName, message);
            end
        end
        
        function writeToFile(obj, logEntry)
            % Write log entry to file
            try
                fid = fopen(obj.LogFile, 'a');
                if fid > 0
                    fprintf(fid, '%s\n', logEntry);
                    fclose(fid);
                end
            catch ME
                % Silently continue if file logging fails
                % Don't use obj.error here to avoid infinite recursion
                fprintf('[ERROR] [LoggingService] Failed to write to log file: %s\n', ME.message);
            end
        end
        
        function initializeFileLogging(obj)
            % Initialize file logging with default log file
            logDir = fullfile(pwd, 'logs');
            if ~exist(logDir, 'dir')
                mkdir(logDir);
            end
            
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            obj.LogFile = fullfile(logDir, sprintf('foilview_%s.log', timestamp));
        end
        
        function initializeColoredOutput(obj)
            % Initialize colored output settings
            % Check if cprintf is available
            obj.CprintfAvailable = obj.checkCprintfAvailability();
            
            % Define color scheme for different log levels
            obj.ColorScheme = containers.Map(...
                {'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'}, ...
                {'Comments', 'Text', 'SystemCommands', 'Errors', '*Errors'});
        end
        
        function available = checkCprintfAvailability(~)
            % Check if cprintf function is available
            try
                % Try to call cprintf with minimal arguments to test availability
                cprintf('Text', '');
                available = true;
            catch
                available = false;
            end
        end
        
        function outputToConsole(obj, levelName, logEntry)
            % Output log entry to console with optional coloring
            if obj.UseColoredOutput && obj.CprintfAvailable
                try
                    % Get color for this log level
                    color = obj.ColorScheme(levelName);
                    
                    % Use cprintf for colored output
                    cprintf(color, '%s\n', logEntry);
                catch ME
                    % Fallback to regular fprintf if cprintf fails
                    fprintf('%s\n', logEntry);
                    
                    % Disable colored output if cprintf consistently fails
                    if obj.UseColoredOutput
                        obj.UseColoredOutput = false;
                        fprintf('[WARNING] [LoggingService] cprintf failed, disabling colored output: %s\n', ME.message);
                    end
                end
            else
                % Use regular fprintf
                fprintf('%s\n', logEntry);
            end
        end
    end
    
    methods (Static)
        function logger = getLogger(componentName, varargin)
            % Static factory method to get a logger instance
            % This allows for easy logger creation across the application
            logger = LoggingService(componentName, varargin{:});
        end
        
        function setGlobalLogLevel(~)
            % Set global log level for all loggers
            % This is a simple implementation - in a more complex system,
            % you might want a global logger registry
            warning('Global log level setting not implemented in this version');
        end
    end
end 