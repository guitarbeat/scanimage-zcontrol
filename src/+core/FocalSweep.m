classdef FocalSweep < core.MotorGUI_ZControl
    % FocalSweep - Z-position focus optimization for motor control
    %
    % This class provides automated Z-focus finding and motor control
    % with an integrated system for microscope focus management.
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
        autoMoveTimer
        autoMoveCount
        autoMoveTotal
        autoMoveDirection
        autoMoveStepSize
    end
    
    methods
        %% GUI Construction and Initialization
        function obj = FocalSweep(varargin)
            % FocalSweep constructor
            
            % Must call superclass constructor FIRST before any object use
            obj@core.MotorGUI_ZControl();
            
            % Initialize properties
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
                % Try to clean up
                obj.cleanupOnError();
                
                % Rethrow the error
                rethrow(ME);
            end
        end
        
        %% Initialization Methods
        function initializeSI(obj)
            % Create initializer for ScanImage validation and setup
            initializer = core.Initializer(obj);
            
            % Check for simulation mode
            try
                obj.simulationMode = evalin('base', 'exist(''SIM_MODE'', ''var'') && SIM_MODE == true');
            catch
                obj.simulationMode = false;
            end
            
            if obj.simulationMode
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
            else
                % Validate ScanImage environment for real usage
                initializer.validateScanImageEnvironment();
                
                % Get ScanImage handle
                try
                    obj.hSI = evalin('base', 'hSI');
                    if ~isobject(obj.hSI)
                        error('hSI is not a valid object');
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
        
        function createScanner(obj)
            try
                obj.scanner = scan.ZScanner(obj);
            catch ME
                error('Error creating scanner: %s', ME.message);
            end
        end
        
        function initializeOtherComponents(obj)
            initializer = core.Initializer(obj);
            initializer.initializeComponents();
        end
        
        function createGUI(obj)
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
            % Update the plot in the GUI with the latest data
            if ~isempty(obj.gui)
                obj.gui.updatePlot();
            end
        end
        
        function updateZPosition(obj)
            % Update the current Z position display
            if ~isempty(obj.gui)
                obj.gui.updateZPosition();
            end
        end
        
        function moveZUp(obj, stepSize)
            % Move Z stage up
            if nargin < 2
                stepSize = 10; % Default step size
            end
            
            % Use scanner to move Z up
            if ~isempty(obj.scanner)
                try
                    currentZ = obj.getZ();
                    obj.scanner.moveToZ(currentZ + stepSize);
                    obj.updateZPosition();
                catch ME
                    warning('Error moving Z up: %s', ME.message);
                end
            end
        end
        
        function moveZDown(obj, stepSize)
            % Move Z stage down
            if nargin < 2
                stepSize = 10; % Default step size
            end
            
            % Use scanner to move Z down
            if ~isempty(obj.scanner)
                try
                    currentZ = obj.getZ();
                    obj.scanner.moveToZ(currentZ - stepSize);
                    obj.updateZPosition();
                catch ME
                    warning('Error moving Z down: %s', ME.message);
                end
            end
        end
        
        function z = getZ(obj)
            % Get current Z position
            if ~isempty(obj.scanner)
                z = obj.scanner.getZ();
            else
                z = 0;
            end
        end
        
        function startScan(obj)
            % Start the Z-scan process
            if ~obj.isRunning
                obj.isRunning = true;
                obj.scanner.start();
            end
        end
        
        function stopScan(obj)
            % Stop the Z-scan process
            if obj.isRunning
                obj.isRunning = false;
                obj.scanner.stop();
            end
        end
        
        function moveToBestZ(obj)
            % Move to the best Z position
            if ~isempty(obj.bestZ)
                obj.scanner.moveToZ(obj.bestZ);
            end
        end
        
        function delete(obj)
            % Destructor
            if ~obj.isClosing
                obj.isClosing = true;
                
                % Stop scanning if running
                if obj.isRunning
                    obj.stopScan();
                end
                
                % Clean up components
                if ~isempty(obj.gui)
                    delete(obj.gui);
                end
                
                if ~isempty(obj.scanner)
                    delete(obj.scanner);
                end
            end
        end
        
        function startAutomatedStepMove(obj, direction, stepSize, interval, count)
            % Start automated step movement (up or down)
            if ~isempty(obj.autoMoveTimer) && isvalid(obj.autoMoveTimer)
                stop(obj.autoMoveTimer);
                delete(obj.autoMoveTimer);
            end
            
            % Validate inputs
            stepSize = max(0.1, min(1000, stepSize));
            interval = max(0.1, min(60, interval));
            count = max(1, min(1000, round(count)));
            
            obj.autoMoveCount = 0;
            obj.autoMoveTotal = count;
            obj.autoMoveDirection = direction;
            obj.autoMoveStepSize = stepSize;
            obj.autoMoveTimer = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', interval, ...
                'TasksToExecute', count, ...
                'TimerFcn', @(~,~) obj.doAutoStep(), ...
                'StopFcn', @(~,~) obj.cleanupAutoMove());
            start(obj.autoMoveTimer);
            
            % Calculate estimated time
            estimatedTime = interval * count;
            if estimatedTime < 60
                timeStr = sprintf('%.1f seconds', estimatedTime);
            else
                timeStr = sprintf('%.1f minutes', estimatedTime/60);
            end
            
            obj.updateStatus(sprintf('Automated %s: %d steps of %.2f µm every %.2f s (Est. time: %s)', ...
                direction, count, stepSize, interval, timeStr));
        end
        
        function stopAutomatedStepMove(obj)
            % Stop the automated movement
            if ~isempty(obj.autoMoveTimer) && isvalid(obj.autoMoveTimer)
                stop(obj.autoMoveTimer);
                delete(obj.autoMoveTimer);
                obj.autoMoveTimer = [];
                obj.updateStatus('Automated movement stopped by user');
            end
        end

        function doAutoStep(obj)
            % Perform one automated step
            if strcmpi(obj.autoMoveDirection, 'Up')
                obj.moveZUp(obj.autoMoveStepSize);
            else
                obj.moveZDown(obj.autoMoveStepSize);
            end
            obj.autoMoveCount = obj.autoMoveCount + 1;
            
            % Calculate remaining time
            if ~isempty(obj.autoMoveTimer) && isvalid(obj.autoMoveTimer)
                remainingSteps = obj.autoMoveTotal - obj.autoMoveCount;
                remainingTime = remainingSteps * obj.autoMoveTimer.Period;
                
                if remainingTime < 60
                    timeStr = sprintf('%.1f seconds', remainingTime);
                else
                    timeStr = sprintf('%.1f minutes', remainingTime/60);
                end
                
                obj.updateStatus(sprintf('Automated %s: step %d/%d (%.1f%%) - Remaining: %s', ...
                    obj.autoMoveDirection, obj.autoMoveCount, obj.autoMoveTotal, ...
                    (obj.autoMoveCount/obj.autoMoveTotal)*100, timeStr));
            end
        end
        
        function cleanupAutoMove(obj)
            % Clean up after automated move
            if ~isempty(obj.autoMoveTimer) && isvalid(obj.autoMoveTimer)
                stop(obj.autoMoveTimer);
                delete(obj.autoMoveTimer);
            end
            obj.autoMoveTimer = [];
            obj.updateStatus('Automated step movement complete');
        end
        
        function [current, total] = getAutomationProgress(obj)
            % Get current automation progress
            current = obj.autoMoveCount;
            total = obj.autoMoveTotal;
        end
        
        function running = isAutomationRunning(obj)
            % Check if automation is currently running
            running = ~isempty(obj.autoMoveTimer) && isvalid(obj.autoMoveTimer) && ...
                strcmp(obj.autoMoveTimer.Running, 'on');
        end
        
        function updateStepSize(obj, newStepSize)
            % Update step size during automation
            if obj.isAutomationRunning()
                obj.autoMoveStepSize = max(0.1, min(1000, newStepSize));
                obj.updateStatus(sprintf('Step size updated to %.2f µm', obj.autoMoveStepSize));
            end
        end
        
        function updateInterval(obj, newInterval)
            % Update interval during automation
            if obj.isAutomationRunning() && ~isempty(obj.autoMoveTimer) && isvalid(obj.autoMoveTimer)
                newInterval = max(0.1, min(60, newInterval));
                obj.autoMoveTimer.Period = newInterval;
                obj.updateStatus(sprintf('Interval updated to %.2f seconds', newInterval));
            end
        end
        
        function abortAllOperations(obj)
            % Abort all ongoing operations
            % Stop automated movement if running
            obj.stopAutomatedStepMove();
            
            % Stop Z scan if running
            try
                obj.stopScan();
                catch
                % Ignore errors
            end
            
            % Stop ScanImage focus if running
            try
                obj.stopSIFocus();
            catch
                % Ignore errors
            end
            
            obj.updateStatus('All operations aborted');
        end
        
        function showAutomationHelp(obj)
            % Show help for automation controls
            % This is a stub method that will be called from the GUI
            % The actual help dialog is implemented in the GUI class
        end
        
        function toggleZScan(obj)
            % Toggle Z scan on/off
            % This is a stub method that will be called from the GUI
            % The actual implementation depends on the scan state
            % which is tracked in the GUI
        end
    end
end 