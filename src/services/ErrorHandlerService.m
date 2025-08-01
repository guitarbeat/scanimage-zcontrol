classdef ErrorHandlerService < handle
    % ErrorHandlerService - Centralized error handling and logging
    % 
    % This service provides robust error handling, user-friendly error messages,
    % and comprehensive logging for the foilview application.
    
    properties (Access = private)
        LogLevel = 'INFO'
        ErrorCallbacks = {}
        LogFile = ''
        IsInitialized = false
    end
    
    properties (Constant)
        % Error severity levels
        CRITICAL = 'CRITICAL'
        ERROR = 'ERROR'
        WARNING = 'WARNING'
        INFO = 'INFO'
        DEBUG = 'DEBUG'
    end
    
    methods
        function obj = ErrorHandlerService()
            % Constructor - Initialize error handler
            try
                obj.initializeLogging();
                obj.IsInitialized = true;
                obj.logMessage('INFO', 'ErrorHandlerService initialized successfully');
            catch ME
                % Fallback to console logging if file logging fails
                fprintf('[ERROR] Failed to initialize ErrorHandlerService: %s\n', ME.message);
            end
        end
        
        function handleInitializationError(obj, error, context)
            % Handle application initialization errors
            % 
            % Args:
            %   error - Exception object
            %   context - String describing where error occurred
            
            errorMsg = sprintf('Initialization failed in %s: %s', context, error.message);
            obj.logMessage(obj.ERROR, errorMsg);
            
            % Determine recovery strategy based on error type
            if contains(error.message, 'ScanImage')
                obj.logMessage(obj.WARNING, 'ScanImage connection failed - will attempt simulation mode');
                obj.notifyCallbacks('scanimage_unavailable', error);
            elseif contains(error.message, 'UI') || contains(error.message, 'uifigure')
                obj.logMessage(obj.CRITICAL, 'UI initialization failed - application cannot continue');
                obj.notifyCallbacks('ui_critical_error', error);
            else
                obj.logMessage(obj.ERROR, 'General initialization error - attempting recovery');
                obj.notifyCallbacks('general_error', error);
            end
        end
        
        function handleConnectionError(obj, error, connectionType)
            % Handle ScanImage connection errors
            % 
            % Args:
            %   error - Exception object
            %   connectionType - 'initial' or 'retry'
            
            errorMsg = sprintf('Connection error (%s): %s', connectionType, error.message);
            obj.logMessage(obj.WARNING, errorMsg);
            
            % Provide specific guidance based on error
            if contains(error.message, 'hSI')
                obj.logMessage(obj.INFO, 'ScanImage variable not found - ensure ScanImage is running');
            elseif contains(error.message, 'timeout')
                obj.logMessage(obj.INFO, 'Connection timeout - ScanImage may be busy');
            end
            
            obj.notifyCallbacks('connection_error', error);
        end
        
        function handleRuntimeError(obj, error, operation)
            % Handle runtime errors during normal operation
            % 
            % Args:
            %   error - Exception object
            %   operation - String describing the operation that failed
            
            errorMsg = sprintf('Runtime error during %s: %s', operation, error.message);
            obj.logMessage(obj.ERROR, errorMsg);
            
            % Log stack trace for debugging
            if ~isempty(error.stack)
                obj.logMessage(obj.DEBUG, sprintf('Stack trace: %s', obj.formatStackTrace(error.stack)));
            end
            
            obj.notifyCallbacks('runtime_error', error);
        end
        
        function userMsg = getUserFriendlyMessage(obj, error, context)
            % Convert technical error to user-friendly message
            % 
            % Args:
            %   error - Exception object
            %   context - Context where error occurred
            % 
            % Returns:
            %   userMsg - User-friendly error message
            
            if contains(error.message, 'hSI') || contains(error.message, 'ScanImage')
                userMsg = 'ScanImage is not available. The application will run in simulation mode.';
            elseif contains(error.message, 'uifigure') || contains(error.message, 'UI')
                userMsg = 'There was a problem creating the user interface. Please restart the application.';
            elseif contains(error.message, 'timeout')
                userMsg = 'Connection timed out. Please check that ScanImage is running and try again.';
            elseif contains(error.message, 'memory') || contains(error.message, 'Memory')
                userMsg = 'The application is running low on memory. Please close other applications and try again.';
            else
                userMsg = sprintf('An unexpected error occurred: %s', error.message);
            end
            
            obj.logMessage(obj.DEBUG, sprintf('Generated user message for %s: %s', context, userMsg));
        end
        
        function registerErrorCallback(obj, callback)
            % Register callback function for error notifications
            % 
            % Args:
            %   callback - Function handle to call on errors
            
            obj.ErrorCallbacks{end+1} = callback;
            obj.logMessage(obj.DEBUG, 'Error callback registered');
        end
        
        function logMessage(obj, level, message)
            % Log message with timestamp and severity level
            % 
            % Args:
            %   level - Severity level (CRITICAL, ERROR, WARNING, INFO, DEBUG)
            %   message - Message to log
            
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            logEntry = sprintf('[%s] %s: %s', timestamp, level, message);
            
            % Always output to console for immediate feedback
            fprintf('%s\n', logEntry);
            
            % Write to log file if available
            if obj.IsInitialized && ~isempty(obj.LogFile)
                try
                    fid = fopen(obj.LogFile, 'a');
                    if fid > 0
                        fprintf(fid, '%s\n', logEntry);
                        fclose(fid);
                    end
                catch
                    % Silently continue if file logging fails
                end
            end
        end
        
        function setLogLevel(obj, level)
            % Set minimum logging level
            % 
            % Args:
            %   level - Minimum level to log (DEBUG, INFO, WARNING, ERROR, CRITICAL)
            
            obj.LogLevel = level;
            obj.logMessage(obj.INFO, sprintf('Log level set to %s', level));
        end
    end
    
    methods (Access = private)
        function initializeLogging(obj)
            % Initialize logging system
            
                    % Create logs directory if it doesn't exist
        logDir = fullfile(pwd, 'dev-tools', 'logs');
            if ~exist(logDir, 'dir')
                mkdir(logDir);
            end
            
            % Create timestamped log file
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            obj.LogFile = fullfile(logDir, sprintf('foilview_%s.log', timestamp));
            
            % Write initial log entry
            obj.logMessage(obj.INFO, 'Logging system initialized');
        end
        
        function notifyCallbacks(obj, errorType, error)
            % Notify registered callbacks of errors
            % 
            % Args:
            %   errorType - Type of error ('scanimage_unavailable', 'ui_critical_error', etc.)
            %   error - Exception object
            
            for i = 1:length(obj.ErrorCallbacks)
                try
                    callback = obj.ErrorCallbacks{i};
                    callback(errorType, error);
                catch callbackError
                    obj.logMessage(obj.WARNING, sprintf('Error callback failed: %s', callbackError.message));
                end
            end
        end
        
        function stackStr = formatStackTrace(obj, stack)
            % Format stack trace for logging
            % 
            % Args:
            %   stack - Stack trace from exception
            % 
            % Returns:
            %   stackStr - Formatted stack trace string
            
            stackStr = '';
            for i = 1:length(stack)
                stackStr = sprintf('%s\n  at %s (line %d)', stackStr, stack(i).name, stack(i).line);
            end
        end
    end
end