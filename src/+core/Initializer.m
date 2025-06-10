classdef Initializer < handle
    % Initializer - Handles initialization of ScanImage environment and components
    
    properties (Access = private)
        controller      % Handle to the main controller
        verbosity       % Verbosity level
    end
    
    methods
        function obj = Initializer(controller, verbosity)
            obj.controller = controller;
            if nargin < 2
                obj.verbosity = 1;
            else
                obj.verbosity = verbosity;
            end
        end
        
        function validateScanImageEnvironment(obj)
            % Validate ScanImage environment and components
            if ~evalin('base', 'exist(''hSI'', ''var'')')
                % Check if we should run in simulation mode
                simMode = false;
                try
                    simMode = evalin('base', 'exist(''SIM_MODE'', ''var'') && SIM_MODE == true');
                catch
                    simMode = false;
                end
                
                if simMode
                    if obj.verbosity > 0
                        fprintf('Running in SIMULATION MODE - no ScanImage connection.\n');
                    end
                    % Create a simulated hSI structure in base workspace
                    evalin('base', ['hSI = struct(' ...
                        '''acqState'', struct(''acqState'', ''idle''), ' ...
                        '''hChannels'', struct(''channelsActive'', 1), ' ...
                        '''hDisplay'', struct(''lastAveragedFrame'', rand(512)), ' ...
                        '''hScan2D'', struct, ' ...
                        '''hCoordinateSystems'', struct(''hCSFocus'', struct, ''hCSSampleRelative'', struct) ' ...
                        ');']);
                    return;
                else
                    error('ScanImage must be running with hSI in base workspace');
                end
            end
            
            % Get ScanImage handle and check basic properties
            hSI = evalin('base', 'hSI');
            
            % Check acquisition state - handle different ScanImage versions
            try
                % Different ScanImage versions have different ways to check state
                isIdle = false;
                if isfield(hSI, 'acqState')
                    if ischar(hSI.acqState)
                        isIdle = strcmp(hSI.acqState, 'idle');
                    elseif isstruct(hSI.acqState) && isfield(hSI.acqState, 'acqState')
                        isIdle = strcmp(hSI.acqState.acqState, 'idle');
                    end
                end
                
                if ~isIdle && obj.verbosity > 0
                    warning('ScanImage may not be idle. This is usually fine during startup.');
                end
            catch ME
                if obj.verbosity > 0
                    warning('Could not verify ScanImage state: %s', ME.message);
                end
            end
            
            % Check for active channels
            try
                if isfield(hSI, 'hChannels')
                    channelsActive = hSI.hChannels.channelsActive;
                    if isempty(channelsActive) || ~ismember(1, channelsActive)
                        if obj.verbosity > 0
                            warning('Channel 1 not active. Will use first available channel.');
                        end
                    end
                else
                    if obj.verbosity > 0
                        warning('Channel settings not accessible. Will work with default settings.');
                    end
                end
            catch ME
                if obj.verbosity > 0
                    warning('Could not verify channel settings: %s', ME.message);
                end
            end
            
            % Check display initialization
            try
                if isfield(hSI, 'hDisplay')
                    if isempty(hSI.hDisplay) || ~isfield(hSI.hDisplay, 'lastAveragedFrame') || isempty(hSI.hDisplay.lastAveragedFrame)
                        if obj.verbosity > 0
                            warning('Display not fully initialized. Will initialize when acquisition starts.');
                        end
                    end
                else
                    if obj.verbosity > 0
                        warning('Display handle not accessible. Will work with limited functionality.');
                    end
                end
            catch ME
                if obj.verbosity > 0
                    warning('Could not verify display initialization: %s', ME.message);
                end
            end
        end
        
        function initializeComponents(obj)
            % Initialize all system components
            try
                obj.initializeCoordinateSystems();
                obj.initializeChannelSettings();
            catch ME
                core.CoreUtils.handleError(obj.controller, ME, 'Component initialization failed');
            end
        end
        
        function initializeCoordinateSystems(obj)
            % Initialize coordinate system handles
            try
                % Check if the properties exist before trying to set them
                props = properties(obj.controller);
                
                if ismember('hCSFocus', props)
                    obj.controller.hCSFocus = obj.controller.hSI.hCoordinateSystems.hCSFocus;
                end
                
                if ismember('hCSSample', props)
                    obj.controller.hCSSample = obj.controller.hSI.hCoordinateSystems.hCSSampleRelative;
                end
                
                % Just verify they exist
                hCSFocus = obj.controller.hSI.hCoordinateSystems.hCSFocus;
                hCSSample = obj.controller.hSI.hCoordinateSystems.hCSSampleRelative;
                
                if isempty(hCSFocus) || isempty(hCSSample)
                    warning('Coordinate systems not fully initialized');
                end
            catch ME
                error('Failed to initialize coordinate systems: %s', ME.message);
            end
        end
        
        function initializeChannelSettings(obj)
            % Initialize channel settings
            try
                obj.controller.channelSettings = obj.controller.hSI.hChannels;
                
                if ~ismember(obj.controller.monitor.activeChannel, obj.controller.channelSettings.channelsActive)
                    warning('Channel %d is not active', obj.controller.monitor.activeChannel);
                    obj.controller.monitor.activeChannel = obj.controller.channelSettings.channelsActive(1);
                end
            catch ME
                error('Failed to initialize channel settings: %s', ME.message);
            end
        end
    end
end 