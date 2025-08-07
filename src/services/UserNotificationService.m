%==============================================================================
% USERNOTIFICATIONSERVICE.M
%==============================================================================
% User-friendly error reporting and notification service for Foilview.
%
% This service provides user-friendly error dialogs, status messages, and
% troubleshooting guidance for the Foilview application. It translates
% technical errors into user-understandable messages and provides helpful
% guidance for resolving common issues.
%
% Key Features:
%   - User-friendly error dialogs with troubleshooting steps
%   - Connection-specific error handling (ScanImage, hardware, etc.)
%   - Initialization error reporting with phase identification
%   - Notification history tracking and management
%   - Context-aware error messages and guidance
%
% Notification Types:
%   - INFO: Informational messages
%   - WARNING: Warning messages
%   - ERROR: Error messages
%   - SUCCESS: Success confirmations
%
% Dependencies:
%   - ErrorHandlerService: Error handling and logging
%   - MATLAB UI: Dialog and notification components
%   - FoilviewUtils: Utility functions for formatting
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   notificationService = UserNotificationService(errorHandler, parentFigure);
%   notificationService.showCriticalError('Error Title', 'Error message');
%
%==============================================================================

classdef UserNotificationService < handle
    % UserNotificationService - User-friendly error reporting and notifications
    % 
    % This service provides user-friendly error dialogs, status messages,
    % and troubleshooting guidance for the FoilView application.
    
    properties (Access = private)
        ErrorHandler
        ParentFigure
        NotificationHistory = {}
        MaxHistorySize = 50
    end
    
    properties (Constant)
        % Notification types
        INFO = 'info'
        WARNING = 'warning'
        ERROR = 'error'
        SUCCESS = 'success'
        
        % Dialog icons
        ICON_INFO = 'info'
        ICON_WARNING = 'warning'
        ICON_ERROR = 'error'
        ICON_SUCCESS = 'success'
    end
    
    methods (Access = public)
        function obj = UserNotificationService(errorHandler, parentFigure)
            % Constructor
            % 
            % Args:
            %   errorHandler - ErrorHandlerService instance (optional)
            %   parentFigure - Parent figure for dialogs (optional)
            
            if nargin > 0 && ~isempty(errorHandler)
                obj.ErrorHandler = errorHandler;
            end
            
            if nargin > 1 && ~isempty(parentFigure)
                obj.ParentFigure = parentFigure;
            end
            
            obj.logMessage('INFO', 'UserNotificationService initialized');
        end
        
        function showCriticalError(obj, title, message, troubleshootingSteps)
            % Show critical error dialog with troubleshooting guidance
            % 
            % Args:
            %   title - Dialog title
            %   message - Error message
            %   troubleshootingSteps - Cell array of troubleshooting steps (optional)
            
            if nargin < 4
                troubleshootingSteps = obj.getDefaultTroubleshootingSteps();
            end
            
            % Create detailed error message
            fullMessage = obj.formatErrorMessage(message, troubleshootingSteps);
            
            % Show dialog
            obj.showDialog(title, fullMessage, obj.ICON_ERROR);
            
            % Log the error
            obj.logMessage('ERROR', sprintf('Critical error shown: %s - %s', title, message));
            
            % Add to history
            obj.addToHistory(obj.ERROR, title, message);
        end
        
        function showConnectionError(obj, connectionType, errorMessage)
            % Show connection-specific error dialog
            % 
            % Args:
            %   connectionType - Type of connection ('scanimage', 'hardware', etc.)
            %   errorMessage - Specific error message
            
            switch lower(connectionType)
                case 'scanimage'
                    obj.showScanImageConnectionError(errorMessage);
                case 'hardware'
                    obj.showHardwareConnectionError(errorMessage);
                otherwise
                    obj.showGenericConnectionError(connectionType, errorMessage);
            end
        end
        
        function showInitializationError(obj, phase, errorMessage)
            % Show initialization-specific error dialog
            % 
            % Args:
            %   phase - Initialization phase that failed
            %   errorMessage - Specific error message
            
            title = 'Initialization Error';
            
            switch lower(phase)
                case 'dependencies'
                    message = sprintf('Dependency validation failed: %s', errorMessage);
                    steps = obj.getDependencyTroubleshootingSteps();
                case 'services'
                    message = sprintf('Service initialization failed: %s', errorMessage);
                    steps = obj.getServiceTroubleshootingSteps();
                case 'ui'
                    message = sprintf('UI initialization failed: %s', errorMessage);
                    steps = obj.getUITroubleshootingSteps();
                case 'connections'
                    message = sprintf('Connection initialization failed: %s', errorMessage);
                    steps = obj.getConnectionTroubleshootingSteps();
                otherwise
                    message = sprintf('Initialization failed in %s phase: %s', phase, errorMessage);
                    steps = obj.getDefaultTroubleshootingSteps();
            end
            
            obj.showCriticalError(title, message, steps);
        end
        
        function showStatusMessage(obj, message, type)
            % Show status message to user
            % 
            % Args:
            %   message - Status message
            %   type - Message type (INFO, WARNING, ERROR, SUCCESS)
            
            if nargin < 3
                type = obj.INFO;
            end
            
            % Determine icon and title based on type
            switch upper(type)
                case obj.INFO
                    title = 'Information';
                    icon = obj.ICON_INFO;
                case obj.WARNING
                    title = 'Warning';
                    icon = obj.ICON_WARNING;
                case obj.ERROR
                    title = 'Error';
                    icon = obj.ICON_ERROR;
                case obj.SUCCESS
                    title = 'Success';
                    icon = obj.ICON_SUCCESS;
                otherwise
                    title = 'Notification';
                    icon = obj.ICON_INFO;
            end
            
            % Show non-blocking alert
            obj.showAlert(title, message, icon);
            
            % Log the message
            obj.logMessage(upper(type), sprintf('Status message: %s', message));
            
            % Add to history
            obj.addToHistory(type, title, message);
        end
        
        function showSimulationModeNotification(obj)
            % Show notification that application is running in simulation mode
            
            message = ['FoilView is running in simulation mode because ScanImage is not available.\n\n' ...
                      'In simulation mode:\n' ...
                      '• Stage movements are simulated\n' ...
                      '• Image data is generated artificially\n' ...
                      '• All controls remain functional for testing\n\n' ...
                      'To use real hardware, ensure ScanImage is running and restart FoilView.'];
            
            obj.showStatusMessage(message, obj.WARNING);
        end
        
        function showWelcomeMessage(obj, applicationState)
            % Show welcome message based on application state
            % 
            % Args:
            %   applicationState - Current application state
            
            switch lower(applicationState)
                case 'ready'
                    message = 'FoilView is ready! ScanImage connection established successfully.';
                    obj.showStatusMessage(message, obj.SUCCESS);
                case 'simulation'
                    obj.showSimulationModeNotification();
                case 'error'
                    message = 'FoilView started with errors. Some functionality may be limited.';
                    obj.showStatusMessage(message, obj.WARNING);
                otherwise
                    message = sprintf('FoilView started in %s mode.', applicationState);
                    obj.showStatusMessage(message, obj.INFO);
            end
        end
        
        function showHelpDialog(obj)
            % Show help dialog with troubleshooting information
            
            title = 'FoilView Help & Troubleshooting';
            
            helpText = ['FoilView - Z-Control Application Help\n\n' ...
                       'COMMON ISSUES:\n\n' ...
                       '1. ScanImage Connection Issues:\n' ...
                       '   • Ensure ScanImage is running\n' ...
                       '   • Check that hSI variable exists in MATLAB workspace\n' ...
                       '   • Restart ScanImage if connection fails\n\n' ...
                       '2. UI Display Issues:\n' ...
                       '   • Ensure MATLAB R2019b or later\n' ...
                       '   • Check graphics drivers are up to date\n' ...
                       '   • Try resizing the window\n\n' ...
                       '3. Stage Movement Issues:\n' ...
                       '   • Verify Motor Controls window is open in ScanImage\n' ...
                       '   • Check for motor error states\n' ...
                       '   • Ensure proper motor configuration\n\n' ...
                       '4. Performance Issues:\n' ...
                       '   • Close unnecessary applications\n' ...
                       '   • Increase MATLAB memory allocation\n' ...
                       '   • Check system resources\n\n' ...
                       'For additional help, check the application logs in the dev-tools/logs/ directory.'];
            
            obj.showDialog(title, helpText, obj.ICON_INFO);
        end
        
        function history = getNotificationHistory(obj)
            % Get notification history
            % 
            % Returns:
            %   history - Cell array of notification records
            
            history = obj.NotificationHistory;
        end
        
        function clearHistory(obj)
            % Clear notification history
            
            obj.NotificationHistory = {};
            obj.logMessage('INFO', 'Notification history cleared');
        end
    end
    
    methods (Access = private)
        function showScanImageConnectionError(obj, errorMessage)
            % Show ScanImage-specific connection error
            
            title = 'ScanImage Connection Error';
            message = sprintf('Failed to connect to ScanImage: %s', errorMessage);
            
            steps = {
                'Ensure ScanImage is running and fully initialized',
                'Check that the hSI variable exists in the MATLAB base workspace',
                'Verify ScanImage is not in an error state',
                'Try restarting ScanImage',
                'Check ScanImage logs for additional error information',
                'If problem persists, FoilView will run in simulation mode'
            };
            
            obj.showCriticalError(title, message, steps);
        end
        
        function showHardwareConnectionError(obj, errorMessage)
            % Show hardware-specific connection error
            
            title = 'Hardware Connection Error';
            message = sprintf('Failed to connect to hardware: %s', errorMessage);
            
            steps = {
                'Check all hardware connections',
                'Verify power supplies are on',
                'Check USB/serial cable connections',
                'Restart hardware devices',
                'Check device drivers are installed',
                'Consult hardware documentation'
            };
            
            obj.showCriticalError(title, message, steps);
        end
        
        function showGenericConnectionError(obj, connectionType, errorMessage)
            % Show generic connection error
            
            title = sprintf('%s Connection Error', connectionType);
            message = sprintf('Connection failed: %s', errorMessage);
            
            steps = obj.getDefaultTroubleshootingSteps();
            
            obj.showCriticalError(title, message, steps);
        end
        
        function steps = getDefaultTroubleshootingSteps(~)
            % Get default troubleshooting steps
            
            steps = {
                'Restart the application',
                'Check MATLAB version (R2019b or later required)',
                'Verify all required files are in the MATLAB path',
                'Check system resources (memory, disk space)',
                'Review error logs in the dev-tools/logs/ directory',
                'Contact support if the problem persists'
            };
        end
        
        function steps = getDependencyTroubleshootingSteps(~)
            % Get dependency-specific troubleshooting steps
            
            steps = {
                'Check MATLAB version (R2019b or later required)',
                'Verify required toolboxes are installed and licensed',
                'Check file system permissions in current directory',
                'Ensure sufficient memory is available',
                'Try running MATLAB as administrator',
                'Check MATLAB installation integrity'
            };
        end
        
        function steps = getServiceTroubleshootingSteps(~)
            % Get service-specific troubleshooting steps
            
            steps = {
                'Check that all source files are present',
                'Verify MATLAB path includes all required directories',
                'Check for conflicting class definitions',
                'Clear MATLAB workspace and try again',
                'Restart MATLAB',
                'Check for file corruption'
            };
        end
        
        function steps = getUITroubleshootingSteps(~)
            % Get UI-specific troubleshooting steps
            
            steps = {
                'Check MATLAB version supports uifigure (R2019b+)',
                'Update graphics drivers',
                'Check display settings and resolution',
                'Try running with different graphics renderer',
                'Close other applications using graphics resources',
                'Restart MATLAB'
            };
        end
        
        function steps = getConnectionTroubleshootingSteps(~)
            % Get connection-specific troubleshooting steps
            
            steps = {
                'Check network connectivity',
                'Verify firewall settings',
                'Check device connections and power',
                'Restart connected devices',
                'Check device drivers and software',
                'Review connection configuration'
            };
        end
        
        function fullMessage = formatErrorMessage(~, message, troubleshootingSteps)
            % Format error message with troubleshooting steps
            
            fullMessage = sprintf('%s\n\nTroubleshooting Steps:\n', message);
            
            for i = 1:length(troubleshootingSteps)
                fullMessage = sprintf('%s\n%d. %s', fullMessage, i, troubleshootingSteps{i});
            end
            
            fullMessage = sprintf('%s\n\nFor additional help, use the Help menu or check the application logs.', fullMessage);
        end
        
        function showDialog(obj, title, message, icon)
            % Show modal dialog
            
            try
                if ~isempty(obj.ParentFigure) && isvalid(obj.ParentFigure)
                    uialert(obj.ParentFigure, message, title, 'Icon', icon);
                else
                    % Create temporary figure for dialog
                    tempFig = uifigure('Visible', 'off');
                    uialert(tempFig, message, title, 'Icon', icon);
                    delete(tempFig);
                end
            catch ME
                % Fallback to command window if UI not available
                fprintf('\n=== %s ===\n', title);
                fprintf('%s\n', message);
                fprintf('==================%s\n\n', repmat('=', 1, length(title)));
                
                obj.logMessage('WARNING', sprintf('Dialog fallback used: %s', ME.message));
            end
        end
        
        function showAlert(obj, title, message, icon)
            % Show non-blocking alert
            
            try
                if ~isempty(obj.ParentFigure) && isvalid(obj.ParentFigure)
                    uialert(obj.ParentFigure, message, title, 'Icon', icon);
                else
                    fprintf('[%s] %s: %s\n', datestr(now, 'HH:MM:SS'), title, message);
                end
            catch ME
                fprintf('[%s] %s: %s\n', datestr(now, 'HH:MM:SS'), title, message);
                obj.logMessage('WARNING', sprintf('Alert fallback used: %s', ME.message));
            end
        end
        
        function addToHistory(obj, type, title, message)
            % Add notification to history
            
            record = struct(...
                'timestamp', datetime('now'), ...
                'type', type, ...
                'title', title, ...
                'message', message);
            
            obj.NotificationHistory{end+1} = record;
            
            % Limit history size
            if length(obj.NotificationHistory) > obj.MaxHistorySize
                obj.NotificationHistory(1) = [];
            end
        end
        
        function logMessage(obj, level, message)
            % Log message through error handler
            
            if ~isempty(obj.ErrorHandler)
                obj.ErrorHandler.logMessage(level, sprintf('UserNotificationService: %s', message));
            else
                timestamp = datestr(now, 'HH:MM:SS');
                fprintf('[%s] %s: UserNotificationService: %s\n', timestamp, level, message);
            end
        end
    end
end