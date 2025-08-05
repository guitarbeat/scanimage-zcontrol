%==============================================================================
% APPLICATIONINITIALIZER.M
%==============================================================================
% Robust application startup service with comprehensive error handling.
%
% This service manages the complete application initialization sequence,
% providing dependency validation, service initialization, UI setup, and
% connection establishment. It implements a phased initialization approach
% with comprehensive error handling and graceful fallback mechanisms.
%
% Key Features:
%   - Phased initialization with clear progress tracking
%   - Dependency validation and error reporting
%   - Service initialization with error recovery
%   - UI component creation and validation
%   - Connection establishment and testing
%   - Comprehensive error handling and logging
%   - Graceful fallback for missing components
%
% Initialization Phases:
%   - STARTING: Initial setup and validation
%   - DEPENDENCIES: Check required dependencies
%   - SERVICES: Initialize core services
%   - UI: Create and configure UI components
%   - CONNECTIONS: Establish external connections
%   - COMPLETE: Initialization successful
%   - FAILED: Initialization failed
%
% Dependencies:
%   - ErrorHandlerService: Error handling and logging
%   - Various Services: Stage control, metrics, metadata, etc.
%   - UiBuilder: UI component construction
%   - FoilviewUtils: Utility functions and validation
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   initializer = ApplicationInitializer(errorHandler);
%   [success, app] = initializer.initializeApplication();
%
%==============================================================================

classdef ApplicationInitializer < handle
    % ApplicationInitializer - Robust application startup with error handling
    % 
    % This class manages the complete application initialization sequence with
    % comprehensive error handling, dependency validation, and graceful fallback.
    
    properties (Access = private)
        ErrorHandler
        InitializationState
        ComponentStatus
        StartupTime
    end
    
    properties (Constant)
        % Initialization phases
        PHASE_STARTING = 'starting'
        PHASE_DEPENDENCIES = 'dependencies'
        PHASE_SERVICES = 'services'
        PHASE_UI = 'ui'
        PHASE_CONNECTIONS = 'connections'
        PHASE_COMPLETE = 'complete'
        PHASE_FAILED = 'failed'
    end
    
    methods (Access = public)
        function obj = ApplicationInitializer(errorHandler)
            % Constructor
            % 
            % Args:
            %   errorHandler - ErrorHandlerService instance
            
            obj.ErrorHandler = errorHandler;
            obj.InitializationState = obj.PHASE_STARTING;
            obj.ComponentStatus = containers.Map();
            obj.StartupTime = datetime('now');
            
            obj.logMessage('INFO', 'Application initializer created');
        end
        
        function [success, app] = initializeApplication(obj)
            % Initialize the complete foilview application
            % 
            % Returns:
            %   success - Boolean indicating initialization success
            %   app - Initialized application object or empty on failure
            
            app = [];
            
            try
                obj.logMessage('INFO', 'Starting application initialization');
                
                % Phase 1: Validate dependencies
                if ~obj.validateDependencies()
                    success = false;
                    return;
                end
                
                % Phase 2: Initialize core services
                services = obj.initializeServices();
                if isempty(services)
                    success = false;
                    return;
                end
                
                % Phase 3: Create UI components
                ui = obj.initializeUI();
                if isempty(ui)
                    success = false;
                    return;
                end
                
                % Phase 4: Establish connections
                connections = obj.initializeConnections(services);
                
                % Phase 5: Create main application
                app = obj.createMainApplication(services, ui, connections);
                if isempty(app)
                    success = false;
                    return;
                end
                
                obj.InitializationState = obj.PHASE_COMPLETE;
                success = true;
                
                elapsedTime = seconds(datetime('now') - obj.StartupTime);
                obj.logMessage('INFO', sprintf('Application initialization completed in %.1f seconds', elapsedTime));
                
            catch ME
                obj.handleInitializationError(ME, obj.InitializationState);
                success = false;
                app = [];
            end
        end
        
        function status = getInitializationStatus(obj)
            % Get current initialization status
            % 
            % Returns:
            %   status - Struct with initialization information
            
            status = struct(...
                'phase', obj.InitializationState, ...
                'isComplete', strcmp(obj.InitializationState, obj.PHASE_COMPLETE), ...
                'isFailed', strcmp(obj.InitializationState, obj.PHASE_FAILED), ...
                'componentStatus', obj.ComponentStatus, ...
                'startupTime', obj.StartupTime, ...
                'elapsedTime', seconds(datetime('now') - obj.StartupTime));
        end
    end
    
    methods (Access = private)
        function success = validateDependencies(obj)
            % Validate critical dependencies before initialization
            % 
            % Returns:
            %   success - Boolean indicating validation success
            
            obj.InitializationState = obj.PHASE_DEPENDENCIES;
            obj.logMessage('INFO', 'Validating dependencies');
            
            try
                % Check MATLAB version
                if ~obj.validateMatlabVersion()
                    obj.ComponentStatus('matlab_version') = 'failed';
                    success = false;
                    return;
                end
                obj.ComponentStatus('matlab_version') = 'ok';
                
                % Check required toolboxes
                if ~obj.validateToolboxes()
                    obj.ComponentStatus('toolboxes') = 'warning';
                    obj.logMessage('WARNING', 'Some toolboxes missing - continuing with reduced functionality');
                else
                    obj.ComponentStatus('toolboxes') = 'ok';
                end
                
                % Check file system permissions
                if ~obj.validateFileSystem()
                    obj.ComponentStatus('filesystem') = 'failed';
                    success = false;
                    return;
                end
                obj.ComponentStatus('filesystem') = 'ok';
                
                % Check memory availability
                if ~obj.validateMemory()
                    obj.ComponentStatus('memory') = 'warning';
                    obj.logMessage('WARNING', 'Low memory detected - performance may be affected');
                else
                    obj.ComponentStatus('memory') = 'ok';
                end
                
                success = true;
                obj.logMessage('INFO', 'Dependency validation completed');
                
            catch ME
                obj.ErrorHandler.handleInitializationError(ME, 'dependency_validation');
                success = false;
            end
        end
        
        function services = initializeServices(obj)
            % Initialize core application services
            % 
            % Returns:
            %   services - Struct with initialized services or empty on failure
            
            obj.InitializationState = obj.PHASE_SERVICES;
            obj.logMessage('INFO', 'Initializing services');
            
            services = struct();
            
            try
                % Initialize ScanImage manager with enhanced error handling
                try
                    services.scanImageManager = ScanImageManagerEnhanced(obj.ErrorHandler);
                    obj.ComponentStatus('scanimage_manager') = 'ok';
                    obj.logMessage('INFO', 'ScanImage manager initialized');
                catch ME
                    obj.logMessage('ERROR', sprintf('ScanImage manager initialization failed: %s', ME.message));
                    obj.ComponentStatus('scanimage_manager') = 'failed';
                    services = [];
                    return;
                end
                
                % Initialize other services with error handling
                try
                    services.stageControlService = StageControlService(services.scanImageManager);
                    obj.ComponentStatus('stage_control') = 'ok';
                catch ME
                    obj.logMessage('ERROR', sprintf('Stage control service failed: %s', ME.message));
                    obj.ComponentStatus('stage_control') = 'failed';
                    services = [];
                    return;
                end
                
                try
                    services.metricCalculationService = MetricCalculationService();
                    obj.ComponentStatus('metric_calculation') = 'ok';
                catch ME
                    obj.logMessage('WARNING', sprintf('Metric calculation service failed: %s', ME.message));
                    obj.ComponentStatus('metric_calculation') = 'warning';
                    % Continue without this service
                end
                
                try
                    services.scanControlService = ScanControlService();
                    obj.ComponentStatus('scan_control') = 'ok';
                catch ME
                    obj.logMessage('WARNING', sprintf('Scan control service failed: %s', ME.message));
                    obj.ComponentStatus('scan_control') = 'warning';
                    % Continue without this service
                end
                
                obj.logMessage('INFO', 'Core services initialized');
                
            catch ME
                obj.ErrorHandler.handleInitializationError(ME, 'service_initialization');
                services = [];
            end
        end
        
        function ui = initializeUI(obj)
            % Initialize UI components with error handling
            % 
            % Returns:
            %   ui - Struct with UI components or empty on failure
            
            obj.InitializationState = obj.PHASE_UI;
            obj.logMessage('INFO', 'Initializing UI components');
            
            ui = struct();
            
            try
                % Create main figure with error handling
                try
                    ui.mainFigure = obj.createMainFigure();
                    obj.ComponentStatus('main_figure') = 'ok';
                catch ME
                    obj.logMessage('CRITICAL', sprintf('Main figure creation failed: %s', ME.message));
                    obj.ComponentStatus('main_figure') = 'failed';
                    ui = [];
                    return;
                end
                
                % Create UI builder with validation
                try
                    ui.builder = UiBuilder();
                    obj.ComponentStatus('ui_builder') = 'ok';
                catch ME
                    obj.logMessage('CRITICAL', sprintf('UI builder creation failed: %s', ME.message));
                    obj.ComponentStatus('ui_builder') = 'failed';
                    ui = [];
                    return;
                end
                
                % Build UI components with error handling
                try
                    ui.components = obj.buildUIComponents(ui.mainFigure, ui.builder);
                    obj.ComponentStatus('ui_components') = 'ok';
                catch ME
                    obj.logMessage('CRITICAL', sprintf('UI component creation failed: %s', ME.message));
                    obj.ComponentStatus('ui_components') = 'failed';
                    ui = [];
                    return;
                end
                
                obj.logMessage('INFO', 'UI components initialized');
                
            catch ME
                obj.ErrorHandler.handleInitializationError(ME, 'ui_initialization');
                ui = [];
            end
        end
        
        function connections = initializeConnections(obj, services)
            % Initialize external connections
            % 
            % Args:
            %   services - Initialized services struct
            % 
            % Returns:
            %   connections - Struct with connection status
            
            obj.InitializationState = obj.PHASE_CONNECTIONS;
            obj.logMessage('INFO', 'Initializing connections');
            
            connections = struct();
            
            try
                % Attempt ScanImage connection with retry logic
                if ~isempty(services) && isfield(services, 'scanImageManager')
                    [success, message] = services.scanImageManager.connectWithRetry();
                    connections.scanImage = struct('success', success, 'message', message);
                    
                    if success
                        obj.ComponentStatus('scanimage_connection') = 'ok';
                        obj.logMessage('INFO', 'ScanImage connection established');
                    else
                        obj.ComponentStatus('scanimage_connection') = 'simulation';
                        obj.logMessage('WARNING', sprintf('ScanImage connection failed: %s', message));
                    end
                else
                    connections.scanImage = struct('success', false, 'message', 'ScanImage manager not available');
                    obj.ComponentStatus('scanimage_connection') = 'failed';
                end
                
                obj.logMessage('INFO', 'Connection initialization completed');
                
            catch ME
                obj.ErrorHandler.handleInitializationError(ME, 'connection_initialization');
                connections = struct();
            end
        end
        
        function app = createMainApplication(obj, services, ui, connections)
            % Create the main application object
            % 
            % Args:
            %   services - Initialized services
            %   ui - Initialized UI components
            %   connections - Connection status
            % 
            % Returns:
            %   app - Main application object or empty on failure
            
            try
                obj.logMessage('INFO', 'Creating main application');
                
                % Create application with all components
                app = struct();
                app.services = services;
                app.ui = ui;
                app.connections = connections;
                app.errorHandler = obj.ErrorHandler;
                app.initializationStatus = obj.getInitializationStatus();
                
                obj.logMessage('INFO', 'Main application created successfully');
                
            catch ME
                obj.ErrorHandler.handleInitializationError(ME, 'main_application_creation');
                app = [];
            end
        end
        
        function success = validateMatlabVersion(obj)
            % Validate MATLAB version compatibility
            
            try
                version = version('-release');
                year = str2double(version(1:4));
                
                if year < 2019
                    obj.logMessage('ERROR', sprintf('MATLAB %s not supported. Requires R2019b or later.', version));
                    success = false;
                else
                    obj.logMessage('INFO', sprintf('MATLAB %s detected - compatible', version));
                    success = true;
                end
            catch
                obj.logMessage('WARNING', 'Could not determine MATLAB version');
                success = true; % Continue anyway
            end
        end
        
        function success = validateToolboxes(obj)
            % Validate required toolboxes
            
            requiredToolboxes = {'Image Processing Toolbox'};
            success = true;
            
            for i = 1:length(requiredToolboxes)
                toolbox = requiredToolboxes{i};
                if ~license('test', strrep(toolbox, ' ', '_'))
                    obj.logMessage('WARNING', sprintf('%s not available', toolbox));
                    success = false;
                end
            end
        end
        
        function success = validateFileSystem(obj)
            % Validate file system permissions
            
            try
                % Test write permissions in current directory
                testFile = fullfile(pwd, 'test_write_permissions.tmp');
                fid = fopen(testFile, 'w');
                if fid == -1
                    obj.logMessage('ERROR', 'No write permissions in current directory');
                    success = false;
                else
                    fclose(fid);
                    delete(testFile);
                    success = true;
                end
            catch ME
                obj.logMessage('ERROR', sprintf('File system validation failed: %s', ME.message));
                success = false;
            end
        end
        
        function success = validateMemory(obj)
            % Validate available memory
            
            try
                [~, memStats] = memory;
                availableGB = memStats.MemAvailableAllArrays / 1024^3;
                
                if availableGB < 1.0
                    obj.logMessage('WARNING', sprintf('Low memory: %.1f GB available', availableGB));
                    success = false;
                else
                    obj.logMessage('INFO', sprintf('Memory OK: %.1f GB available', availableGB));
                    success = true;
                end
            catch
                obj.logMessage('WARNING', 'Could not determine memory status');
                success = true; % Continue anyway
            end
        end
        
        function figure = createMainFigure(obj)
            % Create main application figure with error handling
            
            try
                figure = uifigure('Name', 'FoilView - Z-Control Application', ...
                                 'Position', [100, 100, 800, 600], ...
                                 'Resize', 'on', ...
                                 'CloseRequestFcn', @obj.onApplicationClose);
                
                % Set additional properties safely
                try
                    figure.WindowState = 'normal';
                catch
                    % Ignore if property not available
                end
                
                obj.logMessage('INFO', 'Main figure created successfully');
                
            catch ME
                obj.logMessage('CRITICAL', sprintf('Failed to create main figure: %s', ME.message));
                rethrow(ME);
            end
        end
        
        function components = buildUIComponents(obj, mainFigure, builder)
            % Build UI components with error handling
            
            try
                % Create main layout
                mainLayout = uigridlayout(mainFigure, [6, 1]);
                mainLayout.RowHeight = {'1x', '1x', '1x', '2x', 'fit', 'fit'};
                
                components = struct();
                components.mainLayout = mainLayout;
                
                % Create individual components with error handling
                try
                    components.metricsDisplay = builder.createMetricsDisplay(mainLayout);
                    obj.logMessage('DEBUG', 'Metrics display created');
                catch ME
                    obj.logMessage('WARNING', sprintf('Metrics display creation failed: %s', ME.message));
                end
                
                try
                    components.positionDisplay = builder.createPositionDisplay(mainLayout);
                    obj.logMessage('DEBUG', 'Position display created');
                catch ME
                    obj.logMessage('WARNING', sprintf('Position display creation failed: %s', ME.message));
                end
                
                try
                    components.manualControls = builder.createManualControlContainer(mainLayout);
                    obj.logMessage('DEBUG', 'Manual controls created');
                catch ME
                    obj.logMessage('WARNING', sprintf('Manual controls creation failed: %s', ME.message));
                end
                
                try
                    components.autoControls = builder.createAutoStepContainer(mainLayout);
                    obj.logMessage('DEBUG', 'Auto controls created');
                catch ME
                    obj.logMessage('WARNING', sprintf('Auto controls creation failed: %s', ME.message));
                end
                
                obj.logMessage('INFO', 'UI components built successfully');
                
            catch ME
                obj.logMessage('CRITICAL', sprintf('UI component building failed: %s', ME.message));
                rethrow(ME);
            end
        end
        
        function onApplicationClose(obj, ~, ~)
            % Handle application close request
            
            obj.logMessage('INFO', 'Application close requested');
            
            try
                % Perform cleanup
                obj.logMessage('INFO', 'Performing cleanup');
                
                % Close application
                delete(gcf);
                
            catch ME
                obj.logMessage('ERROR', sprintf('Error during application close: %s', ME.message));
            end
        end
        
        function handleInitializationError(obj, error, phase)
            % Handle initialization errors
            
            obj.InitializationState = obj.PHASE_FAILED;
            obj.ErrorHandler.handleInitializationError(error, phase);
            
            % Show user-friendly error dialog
            userMsg = obj.ErrorHandler.getUserFriendlyMessage(error, phase);
            obj.showErrorDialog('Initialization Error', userMsg);
        end
        
        function showErrorDialog(~, title, message)
            % Show error dialog to user
            
            try
                uialert(gcf, message, title, 'Icon', 'error');
            catch
                % Fallback to command window if UI not available
                fprintf('\n=== %s ===\n%s\n\n', title, message);
            end
        end
        
        function logMessage(obj, level, message)
            % Log message through error handler
            
            if ~isempty(obj.ErrorHandler)
                obj.ErrorHandler.logMessage(level, sprintf('ApplicationInitializer: %s', message));
            else
                timestamp = datestr(now, 'HH:MM:SS');
                fprintf('[%s] %s: ApplicationInitializer: %s\n', timestamp, level, message);
            end
        end
    end
end