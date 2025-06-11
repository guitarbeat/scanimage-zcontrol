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
                obj.verbosity = 0;
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
                    if obj.verbosity > 1
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
            
            % Get ScanImage handle
            hSI = evalin('base', 'hSI');
            
            % Silently check acquisition state without warnings
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
                
                % If in debug mode, print state but don't warn
                if ~isIdle && obj.verbosity > 1
                    fprintf('Debug: ScanImage is not idle, continuing initialization.\n');
                end
            catch
                % Silently continue if we can't verify state
            end
            
            % Silently check for active channels without warnings
            try
                if isfield(hSI, 'hChannels')
                    channelsActive = hSI.hChannels.channelsActive;
                    if isempty(channelsActive) || ~ismember(1, channelsActive)
                        if obj.verbosity > 1
                            fprintf('Debug: Channel 1 not active, will use first available channel.\n');
                        end
                    end
                end
            catch
                % Silently continue if we can't verify channel settings
            end
            
            % Silently check display initialization without warnings
            try
                if isfield(hSI, 'hDisplay')
                    if isempty(hSI.hDisplay) || ~isfield(hSI.hDisplay, 'lastAveragedFrame') || isempty(hSI.hDisplay.lastAveragedFrame)
                        if obj.verbosity > 1
                            fprintf('Debug: Display not fully initialized, will initialize when acquisition starts.\n');
                        end
                    end
                end
            catch
                % Silently continue if we can't verify display initialization
            end
        end
        
        function initializeComponents(obj)
            % Initialize all system components
            try
                obj.initializeCoordinateSystems();
                % Disable channel settings initialization as it's causing errors
                % obj.initializeChannelSettings();
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
                    if obj.verbosity > 0
                        warning('Coordinate systems not fully initialized');
                    end
                end
            catch ME
                error('Failed to initialize coordinate systems: %s', ME.message);
            end
        end
        
        function initializeChannelSettings(obj)
            % Initialize channel settings - DISABLED in MVP version
            try
                % Don't set channelSettings property as it's causing errors
                % obj.controller.channelSettings = obj.controller.hSI.hChannels;
                
                % Just check if the monitor's active channel is available
                if isfield(obj.controller, 'monitor') && ...
                   isfield(obj.controller.hSI, 'hChannels') && ...
                   isfield(obj.controller.hSI.hChannels, 'channelsActive')
                    
                    channelsActive = obj.controller.hSI.hChannels.channelsActive;
                    
                    if ~ismember(obj.controller.monitor.activeChannel, channelsActive)
                        if obj.verbosity > 0
                            warning('Channel %d is not active', obj.controller.monitor.activeChannel);
                        end
                        obj.controller.monitor.activeChannel = channelsActive(1);
                    end
                end
            catch ME
                % Just log the error but don't fail
                if obj.verbosity > 0
                    warning('Channel settings not initialized: %s', ME.message);
                end
            end
        end
    end
end 