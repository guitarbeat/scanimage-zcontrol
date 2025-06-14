classdef FocalSweep < core.MotorGUI_ZControl
    % FocalSweep - Z-position focus optimization using brightness monitoring
    %
    % This class provides automated Z-focus finding based on image brightness.
    % It combines a user interface, brightness monitoring, and Z scanning
    % into an integrated system for microscope focus management.
    %
    % Usage:
    %   core.FocalSweep.launch();     % Create and launch the focus tool
    %   zb = core.FocalSweep();       % Create instance directly
    %
    % Requirements:
    %   - ScanImage must be running with 'hSI' in base workspace
    %   - App requires access to Motor Controls in ScanImage
    
    properties (Access = public)
        % Component Handles
        gui             % GUI Manager
        monitor         % Brightness Monitor
        scanner         % Z-Scanner
        params          % Parameter manager
        
        % ScanImage handles
        hSI             % Main ScanImage handle
        
        % Scan parameters
        scanPauseTime = 0.2   % Pause time between Z steps (seconds)
    end
    
    properties (Access = private)
        % ScanImage handles
        hCSFocus         % Focus coordinate system handle
        hCSSample        % Sample coordinate system handle
        channelSettings = []  % Channel settings handle (optional in MVP)
        
        % Closing flag to prevent duplicate destruction
        isClosing = false % Flag to prevent recursive closing
        
        % Simulation mode
        simulationMode = false % Flag for simulation mode
    end
    
    properties
        % GUI and display handles
        hFig            % Main figure handle
        hAxes           % Main plot axes
        hLine           % Plot line handle
        hText           % Text label handle
        
        % State variables
        isInitialized   % Flag for initialization state
        isRunning       % Flag for running state
        currentZ        % Current Z position
        bestZ           % Best focus Z position
        startZ          % Starting Z position
        
        % Focus calculation variables - now handled by BrightnessMonitor and FocalParameters
        
        % Verbosity control
        verbosity = 0       % Level of output messages (0=quiet, 1=normal, 2=debug)
    end
    
    methods
        %% GUI Construction and Initialization
        function obj = FocalSweep(varargin)
            % FocalSweep constructor
            %
            % Optional parameter/value pairs:
            %   'verbosity' - Level of output messages (0=quiet, 1=normal, 2=debug)
            
            % Parse inputs
            p = inputParser;
            p.addParameter('verbosity', 0, @isnumeric);
            p.parse(varargin{:});
            
            % Must call superclass constructor FIRST before any object use
            obj@core.MotorGUI_ZControl();
            
            % Initialize properties
            obj.verbosity = p.Results.verbosity;
            obj.isInitialized = false;
            obj.isRunning = false;
            obj.currentZ = 0;
            obj.bestZ = [];
            obj.startZ = [];
            
            try
                obj.initializeSI();
                obj.initializeComponents();
                obj.isInitialized = true;
            catch ME
                % Cleanup on failure
                if obj.verbosity > 0
                    fprintf('Error during initialization: %s\n', ME.message);
                end
                
                % Try to clean up
                obj.cleanupOnError();
                
                % Rethrow the error
                rethrow(ME);
            end
        end
        
        %% Initialization Methods - Refactored from constructor
        function initializeSI(obj)
            % Create initializer for ScanImage validation and setup
            initializer = core.Initializer(obj, obj.verbosity);
            
            % Check for simulation mode
            try
                obj.simulationMode = evalin('base', 'exist(''SIM_MODE'', ''var'') && SIM_MODE == true');
            catch
                obj.simulationMode = false;
            end
            
            if obj.simulationMode
                if obj.verbosity > 1
                    fprintf('Creating simulated ScanImage handle...\n');
                end
                
                % Create a simulated hSI structure in base workspace
                evalin('base', ['hSI = struct(' ...
                    '''acqState'', struct(''acqState'', ''idle''), ' ...
                    '''hChannels'', struct(''channelsActive'', 1), ' ...
                    '''hDisplay'', struct(''lastAveragedFrame'', rand(512)), ' ...
                    '''hScan2D'', struct, ' ...
                    '''hCoordinateSystems'', struct(''hCSFocus'', struct, ''hCSSampleRelative'', struct) ' ...
                    ');']);
                
                % Get the simulated handle
                obj.hSI = evalin('base', 'hSI');
                
                if obj.verbosity > 1
                    fprintf('Simulated ScanImage handle created.\n');
                end
            else
                % Validate ScanImage environment for real usage
                initializer.validateScanImageEnvironment();
                
                % Get ScanImage handle
                if obj.verbosity > 1
                    fprintf('Getting ScanImage handle...\n');
                end
                try
                    obj.hSI = evalin('base', 'hSI');
                    if ~isobject(obj.hSI)
                        error('hSI is not a valid object');
                    end
                    if obj.verbosity > 1
                        fprintf('ScanImage handle acquired.\n');
                    end
                catch ME
                    error('Failed to access ScanImage handle. Make sure ScanImage is running.');
                end
            end
        end
        
        function initializeComponents(obj)
            try
                % Create parameters object
                obj.params = core.FocalParameters();
                
                % Create monitoring component
                obj.createMonitor();
                
                % Create scanner component
                obj.createScanner();
                
                % Initialize other components
                obj.initializeOtherComponents();
                
                % Create GUI last to avoid incomplete initialization issues
                obj.createGUI();
                
                % Initialize the current Z position display
                obj.updateZPosition();
            catch ME
                core.CoreUtils.handleError(obj, ME, 'Component initialization failed');
                rethrow(ME);
            end
        end
        
        function createMonitor(obj)
            if obj.verbosity > 1
                fprintf('Creating monitoring component...\n');
            end
            try
                obj.monitor = monitoring.BrightnessMonitor(obj, obj.hSI);
            catch ME
                error('Error creating monitor: %s', ME.message);
            end
        end
        
        function createScanner(obj)
            if obj.verbosity > 1
                fprintf('Creating scanner component...\n');
            end
            try
                obj.scanner = scan.ZScanner(obj);
            catch ME
                error('Error creating scanner: %s', ME.message);
            end
        end
        
        function initializeOtherComponents(obj)
            if obj.verbosity > 1
                fprintf('Initializing components...\n');
            end
            initializer = core.Initializer(obj, obj.verbosity);
            initializer.initializeComponents();
        end
        
        function createGUI(obj)
            if obj.verbosity > 1
                fprintf('Creating GUI...\n');
            end
            try
                % Create the modern FocusGUI interface
                obj.gui = gui.FocusGUI(obj);
            catch ME
                error('Failed to create GUI: %s', ME.message);
            end
            
            obj.gui.create();
        end
        
        function cleanupOnError(obj)
            % Clean up components on error
            try
                if isfield(obj, 'gui') && ~isempty(obj.gui)
                    delete(obj.gui);
                end
            catch
                % Ignore cleanup errors
            end
        end
        

        
        %% Public Methods for Component Callbacks
        function updateStatus(obj, message, varargin)
            % Update status text in the GUI
            core.CoreUtils.updateStatus(obj, message, varargin{:});
        end
        
        function updatePlot(obj)
            % Update the plot in the GUI with the latest data - delegate to monitor
            obj.monitor.updatePlot();
        end

        function metric = getBrightnessMetric(obj)
            % Get the selected brightness metric - delegate to monitor
            metric = obj.monitor.getBrightnessMetric();
        end
        
        function val = getZLimit(obj, which)
            % Get Z min or max limit from motor controls - delegate to scanner
            val = obj.scanner.getZLimit(which);
        end

        %% GUI Actions
        function toggleMonitor(obj, state)
            % Toggle monitoring state - delegate to monitor
            obj.monitor.toggleMonitor(state);
        end
        
        function toggleZScan(obj, state, stepSize, pauseTime, metricType)
            % Toggle Z-scan state - delegate to scanner
            if nargin < 3
                obj.scanner.toggleZScan(state);
            else
                obj.scanner.toggleZScan(state, stepSize, pauseTime, metricType);
            end
        end
        
        function moveToMaxBrightness(obj)
            % Move to the Z position with maximum brightness
            % Delegate to monitor component
            try
                obj.monitor.moveToMaxBrightness();
            catch ME
                core.CoreUtils.handleError(obj, ME, 'Failed to delegate moveToMaxBrightness');
            end
        end
        
        function updateStepSizeImmediate(obj, value)
            % Update step size in ScanImage motor controls immediately
            % Update both params and delegate to scanner
            obj.params.stepSize = round(value);
            obj.scanner.updateStepSizeImmediate(value);
        end
        
        function setMinZLimit(obj)
            % Set the minimum Z limit - delegate to scanner
            obj.scanner.setMinZLimit();
        end
        
        function setMaxZLimit(obj)
            % Set the maximum Z limit - delegate to scanner
            obj.scanner.setMaxZLimit();
        end

        function moveZUp(obj)
            % Move Z stage up (decrease Z in ScanImage) - delegate to scanner
            try
                % Get current step size from slider
                stepSize = max(1, round(obj.gui.hStepSizeSlider.Value));
                
                % Delegate to scanner component
                obj.scanner.moveZUp(stepSize);
            catch ME
                obj.updateStatus(sprintf('Error delegating moveZUp: %s', ME.message));
            end
        end
        
        function moveZDown(obj)
            % Move Z stage down (increase Z in ScanImage) - delegate to scanner
            try
                % Get current step size from slider
                stepSize = max(1, round(obj.gui.hStepSizeSlider.Value));
                
                % Delegate to scanner component
                obj.scanner.moveZDown(stepSize);
            catch ME
                obj.updateStatus(sprintf('Error delegating moveZDown: %s', ME.message));
            end
        end

        function pressZdec(obj)
            % Press the Zdec button (up arrow) in ScanImage Motor Controls - delegate to scanner
            obj.scanner.pressZdec();
        end
        
        function pressZinc(obj)
            % Press the Zinc button (down arrow) in ScanImage Motor Controls - delegate to scanner
            obj.scanner.pressZinc();
        end

        function startSIFocus(obj)
            % Start Focus mode in ScanImage - delegate to GUI
            try
                if core.CoreUtils.isGuiValid(obj)
                    obj.gui.startSIFocus();
                else
                    obj.updateStatus('GUI not available to start ScanImage Focus');
                end
            catch ME
                obj.updateStatus(sprintf('Error delegating startSIFocus: %s', ME.message));
            end
        end
        
        function grabSIFrame(obj)
            % Grab a single frame in ScanImage - delegate to GUI
            try
                if core.CoreUtils.isGuiValid(obj)
                    obj.gui.grabSIFrame();
                else
                    obj.updateStatus('GUI not available to grab ScanImage frame');
                end
            catch ME
                obj.updateStatus(sprintf('Error delegating grabSIFrame: %s', ME.message));
            end
        end
        
        function abortAllOperations(obj)
            % Abort all ongoing operations - delegate to GUI
            try
                if core.CoreUtils.isGuiValid(obj)
                    obj.gui.abortAllOperations();
                else
                    obj.updateStatus('GUI not available to abort operations');
                end
            catch ME
                obj.updateStatus(sprintf('Error delegating abortAllOperations: %s', ME.message));
            end
        end

        function closeFigure(obj)
            % Handle figure close request - delegate to GUI
            % Only proceed if not already closing to prevent recursion
            if obj.isClosing
                return;
            end
            
            obj.isClosing = true;
            
            try
                % Stop monitoring and scanning before closing
                if isfield(obj, 'monitor') && ~isempty(obj.monitor) && isvalid(obj.monitor)
                    try
                        obj.monitor.toggleMonitor(false);
                    catch
                        % Ignore errors during shutdown
                    end
                end
                
                if isfield(obj, 'scanner') && ~isempty(obj.scanner) && isvalid(obj.scanner)
                    try
                        obj.scanner.toggleZScan(false);
                    catch
                        % Ignore errors during shutdown
                    end
                end
                
                if core.CoreUtils.isGuiValid(obj)
                    obj.gui.closeFigure();
                end
            catch ME
                if obj.verbosity > 0
                    warning('Error during close: %s', ME.message);
                end
            end
            
            obj.isClosing = false;
        end

        % Override absoluteMove to update current Z display
        function absoluteMove(obj, targetZ)
            % Move to an absolute Z position and update the display
            try
                % Call parent method to perform the actual move
                absoluteMove@core.MotorGUI_ZControl(obj, targetZ);
                
                % Update current Z position display in the GUI
                if core.CoreUtils.isGuiValid(obj)
                    obj.gui.updateCurrentZDisplay();
                end
            catch ME
                obj.updateStatus(sprintf('Error moving to Z=%.2f: %s', targetZ, ME.message));
            end
        end
        
        function updateCurrentZDisplay(obj)
            % Update the current Z position display in the GUI
            % Delegate to GUI component
            if core.CoreUtils.isGuiValid(obj)
                obj.gui.updateCurrentZDisplay();
            end
        end
        
        function updateZPosition(obj)
            % Update the current Z position value and display in the GUI
            try
                % Get current Z position from ScanImage
                currentZ = obj.getZ();
                obj.currentZ = currentZ;
                
                % Delegate to GUI component if available
                if core.CoreUtils.isGuiValid(obj)
                    try
                        obj.gui.updateZPosition();
                    catch
                        % Silently ignore GUI update errors
                    end
                end
            catch
                % Silently ignore position update errors
            end
        end
        
        %% Utility Functions
        function handleError(obj, ME, prefix)
            % Handle and display error information - delegate to CoreUtils
            core.CoreUtils.handleError(obj, ME, prefix);
        end
        
        %% Destructor
        function delete(obj)
            % Destructor to clean up resources when the object is destroyed
            % Only proceed if not already closing to prevent recursion
            if obj.isClosing
                return;
            end
            
            obj.isClosing = true;
            
            try
                if obj.verbosity > 1
                    fprintf('Cleaning up FocalSweep resources...\n');
                end
                
                % Stop monitoring if running
                try
                    if ~isempty(obj.monitor) && isvalid(obj.monitor)
                        obj.monitor.toggleMonitor(false);
                    end
                catch
                    % Ignore errors during shutdown
                end
                
                % Stop scanning if running
                try
                    if ~isempty(obj.scanner) && isvalid(obj.scanner)
                        obj.scanner.toggleZScan(false);
                    end
                catch
                    % Ignore errors during shutdown
                end
                
                % Close and delete GUI
                try
                    if core.CoreUtils.isGuiValid(obj)
                        obj.gui.delete();
                    end
                catch
                    % Ignore errors during shutdown
                end
                
                % Clear the persistent instance in FocalSweepFactory
                try
                    % Access the persistent variable indirectly using eval
                    evalin('base', 'clear core.FocalSweepFactory');
                catch
                    % Ignore errors during shutdown
                end
                
                if obj.verbosity > 1
                    fprintf('FocalSweep resources cleaned up.\n');
                end
            catch
                % Silently ignore errors during cleanup
            end
            
            obj.isClosing = false;
        end
    end
end 