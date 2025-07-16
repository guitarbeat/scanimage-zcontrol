classdef foilview_enhanced < matlab.apps.AppBase
    % foilview_enhanced - Enhanced FoilView application with robust error handling
    % 
    % This enhanced version provides comprehensive error handling, graceful fallback
    % to simulation mode, and robust initialization sequence.
    
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainPanel                   matlab.ui.container.Panel
        MainLayout                  matlab.ui.container.GridLayout
        ControlTabs                 matlab.ui.container.TabGroup
    end
    
    properties (Access = public)
        PositionDisplay
        MetricDisplay
        ManualControls
        AutoControls
        StatusControls
        MetricsPlotControls
    end
    
    properties (Access = public)
        Controller                  FoilviewController
        UIController                UIController
        PlotManager                 PlotManager
        StageViewApp
        BookmarksViewApp
        ScanImageManager
        ErrorHandler
        ApplicationInitializer
    end
    
    properties (Access = private)
        RefreshTimer
        MetricTimer
        ResizeMonitorTimer
        LastWindowSize = [0 0 0 0]
        IgnoreNextResize = false
        MetadataFile
        DataDir
        LastSetupTime
        MetadataConfig
        InitializationComplete = false
        ApplicationState = 'initializing'
    end
    
    properties (Constant)
        % Application states
        STATE_INITIALIZING = 'initializing'
        STATE_READY = 'ready'
        STATE_ERROR = 'error'
        STATE_SIMULATION = 'simulation'
    end
    
    methods (Access = public)
        function app = foilview_enhanced()
            % Enhanced constructor with comprehensive error handling
            
            try
                % Initialize error handling first
                app.initializeErrorHandling();
                
                % Use robust application initializer
                app.ApplicationInitializer = ApplicationInitializer(app.ErrorHandler);
                
                % Initialize application with error handling
                [success, appData] = app.ApplicationInitializer.initializeApplication();
                
                if success && ~isempty(appData)
                    app.finalizeInitialization(appData);
                else
                    app.handleInitializationFailure();
                end
                
            catch ME
                app.handleCriticalError(ME);
            end
            
            % Register app if initialization was successful
            if app.InitializationComplete
                registerApp(app, app.UIFigure);
            end
            
            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            % Enhanced destructor with error handling
            
            try
                if ~isempty(app.ErrorHandler)
                    app.ErrorHandler.logMessage('INFO', 'Application shutdown initiated');
                end
                
                app.cleanup();
                
            catch ME
                if ~isempty(app.ErrorHandler)
                    app.ErrorHandler.logMessage('ERROR', sprintf('Error during shutdown: %s', ME.message));
                else
                    fprintf('Error during shutdown: %s\n', ME.message);
                end
            end
        end
        
        function status = getApplicationStatus(app)
            % Get current application status
            % 
            % Returns:
            %   status - Struct with application status information
            
            status = struct();
            status.state = app.ApplicationState;
            status.initializationComplete = app.InitializationComplete;
            
            if ~isempty(app.ApplicationInitializer)
                status.initialization = app.ApplicationInitializer.getInitializationStatus();
            end
            
            if ~isempty(app.ScanImageManager)
                status.scanImage = app.ScanImageManager.getConnectionStatus();
            end
            
            if ~isempty(app.Controller)
                status.controller = struct(...
                    'isAutoRunning', app.Controller.IsAutoRunning, ...
                    'currentPosition', app.Controller.CurrentPosition);
            end
        end
        
        function showStatusDialog(app)
            % Show application status dialog
            
            try
                status = app.getApplicationStatus();
                
                message = sprintf(['Application Status:\n\n' ...
                    'State: %s\n' ...
                    'Initialization: %s\n' ...
                    'ScanImage: %s\n' ...
                    'Mode: %s'], ...
                    status.state, ...
                    ternary(status.initializationComplete, 'Complete', 'Incomplete'), ...
                    ternary(isfield(status, 'scanImage') && status.scanImage.isConnected, 'Connected', 'Disconnected'), ...
                    ternary(isfield(status, 'scanImage') && status.scanImage.isSimulation, 'Simulation', 'Real'));
                
                uialert(app.UIFigure, message, 'Application Status', 'Icon', 'info');
                
            catch ME
                if ~isempty(app.ErrorHandler)
                    app.ErrorHandler.logMessage('ERROR', sprintf('Error showing status dialog: %s', ME.message));
                end
            end
        end
    end
    
    methods (Access = private)
        function initializeErrorHandling(app)
            % Initialize error handling system
            
            try
                app.ErrorHandler = ErrorHandlerService();
                app.ErrorHandler.registerErrorCallback(@app.onErrorCallback);
                app.ErrorHandler.logMessage('INFO', 'Enhanced FoilView application starting');
                
            catch ME
                % Fallback error handling if ErrorHandlerService fails
                fprintf('[ERROR] Failed to initialize error handling: %s\n', ME.message);
                fprintf('[INFO] Continuing with basic error handling\n');
                app.ErrorHandler = [];
            end
        end
        
        function finalizeInitialization(app, appData)
            % Finalize application initialization with provided data
            % 
            % Args:
            %   appData - Struct with initialized application components
            
            try
                % Extract components from initialization data
                if isfield(appData, 'ui') && ~isempty(appData.ui)
                    app.UIFigure = appData.ui.mainFigure;
                    app.MainLayout = appData.ui.components.mainLayout;
                    
                    % Extract UI components
                    if isfield(appData.ui.components, 'metricsDisplay')
                        app.MetricDisplay = appData.ui.components.metricsDisplay;
                    end
                    if isfield(appData.ui.components, 'positionDisplay')
                        app.PositionDisplay = appData.ui.components.positionDisplay;
                    end
                    if isfield(appData.ui.components, 'manualControls')
                        app.ManualControls = appData.ui.components.manualControls;
                    end
                    if isfield(appData.ui.components, 'autoControls')
                        app.AutoControls = appData.ui.components.autoControls;
                    end
                end
                
                % Extract services
                if isfield(appData, 'services') && ~isempty(appData.services)
                    app.ScanImageManager = appData.services.scanImageManager;
                    
                    % Create controller with services
                    if isfield(appData.services, 'stageControlService')
                        app.Controller = FoilviewController();
                        app.Controller.StageControlService = appData.services.stageControlService;
                    end
                    
                    if isfield(appData.services, 'metricCalculationService')
                        if ~isempty(app.Controller)
                            app.Controller.MetricCalculationService = appData.services.metricCalculationService;
                        end
                    end
                end
                
                % Create UI controller
                app.UIController = UIController();
                
                % Set up callbacks with error handling
                app.setupCallbacksWithErrorHandling();
                
                % Set application state based on connection status
                if isfield(appData, 'connections') && isfield(appData.connections, 'scanImage')
                    if appData.connections.scanImage.success
                        app.ApplicationState = app.STATE_READY;
                    else
                        app.ApplicationState = app.STATE_SIMULATION;
                    end
                else
                    app.ApplicationState = app.STATE_SIMULATION;
                end
                
                % Start timers with error handling
                app.startTimersWithErrorHandling();
                
                app.InitializationComplete = true;
                app.ErrorHandler.logMessage('INFO', sprintf('Application initialization completed - State: %s', app.ApplicationState));
                
                % Show welcome message
                app.showWelcomeMessage();
                
            catch ME
                app.ErrorHandler.handleInitializationError(ME, 'finalization');
                app.handleInitializationFailure();
            end
        end
        
        function handleInitializationFailure(app)
            % Handle initialization failure with graceful degradation
            
            app.ApplicationState = app.STATE_ERROR;
            app.InitializationComplete = false;
            
            try
                % Create minimal error UI
                app.createErrorUI();
                
                if ~isempty(app.ErrorHandler)
                    app.ErrorHandler.logMessage('ERROR', 'Application initialization failed - minimal UI created');
                end
                
            catch ME
                % Complete failure - show console message
                fprintf('\n=== CRITICAL ERROR ===\n');
                fprintf('FoilView application failed to initialize.\n');
                fprintf('Error: %s\n', ME.message);
                fprintf('Please check the error log for details.\n');
                fprintf('======================\n\n');
            end
        end
        
        function handleCriticalError(app, error)
            % Handle critical errors during initialization
            
            fprintf('\n=== CRITICAL INITIALIZATION ERROR ===\n');
            fprintf('FoilView application encountered a critical error during startup.\n');
            fprintf('Error: %s\n', error.message);
            
            if ~isempty(error.stack)
                fprintf('\nStack trace:\n');
                for i = 1:length(error.stack)
                    fprintf('  at %s (line %d)\n', error.stack(i).name, error.stack(i).line);
                end
            end
            
            fprintf('\nTroubleshooting steps:\n');
            fprintf('1. Ensure MATLAB R2019b or later is installed\n');
            fprintf('2. Check that all required files are in the MATLAB path\n');
            fprintf('3. Verify write permissions in the current directory\n');
            fprintf('4. Try restarting MATLAB\n');
            fprintf('=====================================\n\n');
            
            app.ApplicationState = app.STATE_ERROR;
            app.InitializationComplete = false;
        end
        
        function createErrorUI(app)
            % Create minimal error UI when full initialization fails
            
            try
                % Create basic figure
                app.UIFigure = uifigure('Name', 'FoilView - Error', ...
                                       'Position', [100, 100, 400, 300], ...
                                       'Resize', 'off');
                
                % Create error layout
                layout = uigridlayout(app.UIFigure, [3, 1]);
                layout.RowHeight = {'fit', '1x', 'fit'};
                
                % Error title
                titleLabel = uilabel(layout, 'Text', 'FoilView Initialization Error', ...
                                    'FontSize', 16, 'FontWeight', 'bold', ...
                                    'HorizontalAlignment', 'center');
                titleLabel.Layout.Row = 1;
                
                % Error message
                messageArea = uitextarea(layout, 'Value', {
                    'The FoilView application failed to initialize properly.', ...
                    '', ...
                    'This may be due to:', ...
                    '• ScanImage not being available', ...
                    '• Missing dependencies', ...
                    '• File permission issues', ...
                    '', ...
                    'Check the MATLAB command window for detailed error messages.', ...
                    '', ...
                    'You can try:', ...
                    '• Restarting MATLAB', ...
                    '• Running "startup" to add paths', ...
                    '• Checking ScanImage installation'
                }, 'Editable', 'off');
                messageArea.Layout.Row = 2;
                
                % Close button
                closeButton = uibutton(layout, 'Text', 'Close', ...
                                      'ButtonPushedFcn', @(~,~) delete(app.UIFigure));
                closeButton.Layout.Row = 3;
                
            catch ME
                fprintf('Failed to create error UI: %s\n', ME.message);
            end
        end
        
        function setupCallbacksWithErrorHandling(app)
            % Set up UI callbacks with comprehensive error handling
            
            try
                if ~isempty(app.ManualControls)
                    % Manual control callbacks
                    if isfield(app.ManualControls, 'UpButton')
                        app.ManualControls.UpButton.ButtonPushedFcn = @app.onUpButtonPushedSafe;
                    end
                    if isfield(app.ManualControls, 'DownButton')
                        app.ManualControls.DownButton.ButtonPushedFcn = @app.onDownButtonPushedSafe;
                    end
                    if isfield(app.ManualControls, 'StepSizeDropDown')
                        app.ManualControls.StepSizeDropDown.ValueChangedFcn = @app.onStepSizeChangedSafe;
                    end
                end
                
                if ~isempty(app.AutoControls)
                    % Auto control callbacks
                    if isfield(app.AutoControls, 'StartStopButton')
                        app.AutoControls.StartStopButton.ButtonPushedFcn = @app.onStartStopButtonPushedSafe;
                    end
                    if isfield(app.AutoControls, 'StepField')
                        app.AutoControls.StepField.ValueChangedFcn = @app.onAutoStepSizeChangedSafe;
                    end
                    if isfield(app.AutoControls, 'StepsField')
                        app.AutoControls.StepsField.ValueChangedFcn = @app.onAutoStepsChangedSafe;
                    end
                    if isfield(app.AutoControls, 'DelayField')
                        app.AutoControls.DelayField.ValueChangedFcn = @app.onAutoDelayChangedSafe;
                    end
                end
                
                % Window callbacks
                if ~isempty(app.UIFigure)
                    app.UIFigure.CloseRequestFcn = @app.onCloseRequestSafe;
                    app.UIFigure.SizeChangedFcn = @app.onSizeChangedSafe;
                end
                
                app.ErrorHandler.logMessage('INFO', 'Callbacks set up with error handling');
                
            catch ME
                app.ErrorHandler.handleInitializationError(ME, 'callback_setup');
            end
        end
        
        function startTimersWithErrorHandling(app)
            % Start application timers with error handling
            
            try
                % Refresh timer for UI updates
                app.RefreshTimer = timer('ExecutionMode', 'fixedRate', ...
                                        'Period', 0.1, ...
                                        'TimerFcn', @app.onRefreshTimerSafe);
                start(app.RefreshTimer);
                
                % Metric calculation timer
                app.MetricTimer = timer('ExecutionMode', 'fixedRate', ...
                                       'Period', 0.5, ...
                                       'TimerFcn', @app.onMetricTimerSafe);
                start(app.MetricTimer);
                
                app.ErrorHandler.logMessage('INFO', 'Timers started successfully');
                
            catch ME
                app.ErrorHandler.logMessage('WARNING', sprintf('Timer initialization failed: %s', ME.message));
            end
        end
        
        function showWelcomeMessage(app)
            % Show welcome message based on application state
            
            try
                switch app.ApplicationState
                    case app.STATE_READY
                        message = 'FoilView is ready! ScanImage connection established.';
                        icon = 'success';
                    case app.STATE_SIMULATION
                        message = 'FoilView is running in simulation mode. ScanImage not available.';
                        icon = 'warning';
                    otherwise
                        return; % Don't show message for error states
                end
                
                % Show non-blocking notification
                uialert(app.UIFigure, message, 'FoilView Ready', 'Icon', icon);
                
            catch ME
                app.ErrorHandler.logMessage('WARNING', sprintf('Welcome message failed: %s', ME.message));
            end
        end
        
        function cleanup(app)
            % Clean up application resources
            
            try
                % Stop timers
                if ~isempty(app.RefreshTimer) && isvalid(app.RefreshTimer)
                    stop(app.RefreshTimer);
                    delete(app.RefreshTimer);
                end
                
                if ~isempty(app.MetricTimer) && isvalid(app.MetricTimer)
                    stop(app.MetricTimer);
                    delete(app.MetricTimer);
                end
                
                % Clean up other resources
                if ~isempty(app.ScanImageManager)
                    % ScanImageManager cleanup would go here
                end
                
            catch ME
                if ~isempty(app.ErrorHandler)
                    app.ErrorHandler.logMessage('WARNING', sprintf('Cleanup error: %s', ME.message));
                end
            end
        end
        
        % Safe callback wrappers
        function onUpButtonPushedSafe(app, ~, ~)
            app.executeWithErrorHandling(@() app.onUpButtonPushed(), 'up_button');
        end
        
        function onDownButtonPushedSafe(app, ~, ~)
            app.executeWithErrorHandling(@() app.onDownButtonPushed(), 'down_button');
        end
        
        function onStartStopButtonPushedSafe(app, ~, ~)
            app.executeWithErrorHandling(@() app.onStartStopButtonPushed(), 'start_stop_button');
        end
        
        function onStepSizeChangedSafe(app, ~, ~)
            app.executeWithErrorHandling(@() app.onStepSizeChanged(), 'step_size_changed');
        end
        
        function onAutoStepSizeChangedSafe(app, ~, ~)
            app.executeWithErrorHandling(@() app.onAutoStepSizeChanged(), 'auto_step_size_changed');
        end
        
        function onAutoStepsChangedSafe(app, ~, ~)
            app.executeWithErrorHandling(@() app.onAutoStepsChanged(), 'auto_steps_changed');
        end
        
        function onAutoDelayChangedSafe(app, ~, ~)
            app.executeWithErrorHandling(@() app.onAutoDelayChanged(), 'auto_delay_changed');
        end
        
        function onCloseRequestSafe(app, ~, ~)
            app.executeWithErrorHandling(@() app.onCloseRequest(), 'close_request');
        end
        
        function onSizeChangedSafe(app, ~, ~)
            app.executeWithErrorHandling(@() app.onSizeChanged(), 'size_changed');
        end
        
        function onRefreshTimerSafe(app, ~, ~)
            app.executeWithErrorHandling(@() app.onRefreshTimer(), 'refresh_timer');
        end
        
        function onMetricTimerSafe(app, ~, ~)
            app.executeWithErrorHandling(@() app.onMetricTimer(), 'metric_timer');
        end
        
        function executeWithErrorHandling(app, func, operation)
            % Execute function with comprehensive error handling
            
            try
                func();
            catch ME
                if ~isempty(app.ErrorHandler)
                    app.ErrorHandler.handleRuntimeError(ME, operation);
                else
                    fprintf('Error in %s: %s\n', operation, ME.message);
                end
            end
        end
        
        function onErrorCallback(app, errorType, error)
            % Handle error callbacks from ErrorHandlerService
            
            switch errorType
                case 'scanimage_unavailable'
                    app.ApplicationState = app.STATE_SIMULATION;
                case 'ui_critical_error'
                    app.ApplicationState = app.STATE_ERROR;
                case 'connection_error'
                    % Handle connection errors
                case 'runtime_error'
                    % Handle runtime errors
            end
        end
        
        % Placeholder methods for actual functionality
        function onUpButtonPushed(app)
            if ~isempty(app.Controller)
                app.Controller.moveUp();
            end
        end
        
        function onDownButtonPushed(app)
            if ~isempty(app.Controller)
                app.Controller.moveDown();
            end
        end
        
        function onStartStopButtonPushed(app)
            if ~isempty(app.Controller)
                if app.Controller.IsAutoRunning
                    app.Controller.stopAutoStepping();
                else
                    app.Controller.startAutoStepping();
                end
            end
        end
        
        function onStepSizeChanged(app)
            % Handle step size change
        end
        
        function onAutoStepSizeChanged(app)
            % Handle auto step size change
        end
        
        function onAutoStepsChanged(app)
            % Handle auto steps change
        end
        
        function onAutoDelayChanged(app)
            % Handle auto delay change
        end
        
        function onCloseRequest(app)
            delete(app);
        end
        
        function onSizeChanged(app)
            % Handle window size change
        end
        
        function onRefreshTimer(app)
            % Handle refresh timer
            if ~isempty(app.UIController) && ~isempty(app.Controller)
                app.UIController.updateAll(app.Controller, app.ManualControls, app.AutoControls);
            end
        end
        
        function onMetricTimer(app)
            % Handle metric timer
            if ~isempty(app.Controller)
                app.Controller.updateMetric();
            end
        end
    end
end

% Helper function
function result = ternary(condition, trueValue, falseValue)
    if condition
        result = trueValue;
    else
        result = falseValue;
    end
end