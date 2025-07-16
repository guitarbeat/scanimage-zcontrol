classdef ScanImageManagerEnhanced < handle
    % ScanImageManagerEnhanced - Enhanced ScanImage manager with robust error handling
    % This class provides robust connection management, retry logic, and graceful
    % fallback to simulation mode when ScanImage is unavailable.
    
    properties (Access = private)
        HSI
        ErrorHandler
        ConnectionState = 'disconnected'
        RetryConfig
        LastConnectionAttempt
        RetryCount = 0
        SimulationMode = false
        IsInitialized = false
        SimulatedPosition = struct('x', 0, 'y', 0, 'z', 0)
    end
    
    properties (Constant)
        % Connection states
        DISCONNECTED = 'disconnected'
        CONNECTING = 'connecting'
        CONNECTED = 'connected'
        SIMULATION = 'simulation'
        ERROR = 'error'
        
        % Default retry configuration
        DEFAULT_MAX_RETRIES = 3
        DEFAULT_INITIAL_DELAY = 1.0
        DEFAULT_MAX_DELAY = 30.0
        DEFAULT_BACKOFF_MULTIPLIER = 2.0
    end
    
    methods (Access = public)
        function obj = ScanImageManagerEnhanced(errorHandler)
            % Constructor - Initialize enhanced ScanImage manager
            % 
            % Args:
            %   errorHandler - ErrorHandlerService instance (optional)
            
            if nargin > 0 && ~isempty(errorHandler)
                obj.ErrorHandler = errorHandler;
            else
                obj.ErrorHandler = [];
            end
            
            % Initialize retry configuration
            obj.RetryConfig = struct(...
                'maxRetries', obj.DEFAULT_MAX_RETRIES, ...
                'initialDelay', obj.DEFAULT_INITIAL_DELAY, ...
                'maxDelay', obj.DEFAULT_MAX_DELAY, ...
                'backoffMultiplier', obj.DEFAULT_BACKOFF_MULTIPLIER);
            
            obj.ConnectionState = obj.DISCONNECTED;
            obj.logMessage('INFO', 'ScanImageManagerEnhanced initialized');
        end
        
        function [success, message] = connectWithRetry(obj)
            % Connect to ScanImage with retry logic and exponential backoff
            % 
            % Returns:
            %   success - Boolean indicating connection success
            %   message - Status message
            
            obj.ConnectionState = obj.CONNECTING;
            obj.RetryCount = 0;
            
            while obj.RetryCount <= obj.RetryConfig.maxRetries
                try
                    obj.logMessage('INFO', sprintf('Connection attempt %d/%d', ...
                        obj.RetryCount + 1, obj.RetryConfig.maxRetries + 1));
                    
                    [success, message] = obj.attemptConnection();
                    
                    if success
                        obj.ConnectionState = obj.CONNECTED;
                        obj.SimulationMode = false;
                        obj.IsInitialized = true;
                        obj.RetryCount = 0;
                        obj.logMessage('INFO', 'Successfully connected to ScanImage');
                        return;
                    end
                    
                    % Connection failed - determine if we should retry
                    if obj.shouldRetry(message)
                        obj.RetryCount = obj.RetryCount + 1;
                        if obj.RetryCount <= obj.RetryConfig.maxRetries
                            delay = obj.calculateBackoffDelay();
                            obj.logMessage('WARNING', sprintf('Connection failed: %s. Retrying in %.1f seconds...', ...
                                message, delay));
                            pause(delay);
                        end
                    else
                        % Don't retry for certain types of errors
                        break;
                    end
                    
                catch ME
                    obj.handleConnectionError(ME, 'retry');
                    obj.RetryCount = obj.RetryCount + 1;
                    
                    if obj.RetryCount <= obj.RetryConfig.maxRetries
                        delay = obj.calculateBackoffDelay();
                        obj.logMessage('ERROR', sprintf('Connection error: %s. Retrying in %.1f seconds...', ...
                            ME.message, delay));
                        pause(delay);
                    end
                end
            end
            
            % All retry attempts failed - switch to simulation mode
            obj.enableSimulationMode();
            success = false;
            message = 'ScanImage connection failed - running in simulation mode';
            obj.logMessage('WARNING', message);
        end
        
        function enableSimulationMode(obj)
            % Enable simulation mode with mock ScanImage behavior
            
            obj.ConnectionState = obj.SIMULATION;
            obj.SimulationMode = true;
            obj.IsInitialized = true;
            obj.HSI = [];
            
            % Initialize simulated position
            obj.SimulatedPosition = struct('x', 0, 'y', 0, 'z', 0);
            
            obj.logMessage('INFO', 'Simulation mode enabled');
        end
        
        function status = getConnectionStatus(obj)
            % Get current connection status
            % 
            % Returns:
            %   status - Struct with connection information
            
            status = struct(...
                'state', obj.ConnectionState, ...
                'isConnected', strcmp(obj.ConnectionState, obj.CONNECTED), ...
                'isSimulation', obj.SimulationMode, ...
                'isInitialized', obj.IsInitialized, ...
                'retryCount', obj.RetryCount, ...
                'lastAttempt', obj.LastConnectionAttempt);
        end
        
        function positions = getCurrentPositions(obj)
            % Get current stage positions
            % 
            % Returns:
            %   positions - Struct with x, y, z positions
            
            if obj.SimulationMode
                positions = obj.SimulatedPosition;
                return;
            end
            
            positions = struct('x', 0, 'y', 0, 'z', 0);
            
            try
                if ~isempty(obj.HSI) && isprop(obj.HSI, 'hMotors') && ~isempty(obj.HSI.hMotors)
                    if isprop(obj.HSI.hMotors, 'axesPosition') && ~isempty(obj.HSI.hMotors.axesPosition)
                        pos = obj.HSI.hMotors.axesPosition;
                        if numel(pos) >= 3 && all(isfinite(pos))
                            positions.y = pos(1);
                            positions.x = pos(2);
                            positions.z = pos(3);
                        end
                    end
                end
            catch ME
                obj.logMessage('ERROR', sprintf('Error getting positions: %s', ME.message));
            end
        end
        
        function newPosition = moveStage(obj, axis, distance)
            % Move stage by specified distance
            % 
            % Args:
            %   axis - 'x', 'y', or 'z'
            %   distance - Distance to move in microns
            % 
            % Returns:
            %   newPosition - New position after movement
            
            if obj.SimulationMode
                % Simulate movement
                currentPos = obj.SimulatedPosition.(axis);
                newPosition = currentPos + distance;
                obj.SimulatedPosition.(axis) = newPosition;
                
                obj.logMessage('INFO', sprintf('Simulated %s movement: %.1f μm → %.1f μm', ...
                    axis, currentPos, newPosition));
                return;
            end
            
            try
                % Real ScanImage movement would go here
                % For now, return current position
                positions = obj.getCurrentPositions();
                newPosition = positions.(axis);
                
                obj.logMessage('INFO', sprintf('Stage movement requested: %s axis, %.1f μm', axis, distance));
                
            catch ME
                obj.logMessage('ERROR', sprintf('Stage movement failed: %s', ME.message));
                positions = obj.getCurrentPositions();
                newPosition = positions.(axis);
            end
        end
        
        function pixelData = getImageData(obj)
            % Get current image data from ScanImage
            % 
            % Returns:
            %   pixelData - Image data array or simulated data
            
            if obj.SimulationMode
                % Generate simulated image data
                pixelData = obj.generateSimulatedImageData();
                return;
            end
            
            pixelData = [];
            
            try
                if ~isempty(obj.HSI) && isprop(obj.HSI, 'hDisplay') && ~isempty(obj.HSI.hDisplay)
                    % Try to get real image data from ScanImage
                    if isprop(obj.HSI.hDisplay, 'lastFrame') && ~isempty(obj.HSI.hDisplay.lastFrame)
                        pixelData = obj.HSI.hDisplay.lastFrame;
                    elseif isprop(obj.HSI.hDisplay, 'lastAveragedFrame') && ~isempty(obj.HSI.hDisplay.lastAveragedFrame)
                        pixelData = obj.HSI.hDisplay.lastAveragedFrame;
                    end
                end
            catch ME
                obj.logMessage('ERROR', sprintf('Error getting image data: %s', ME.message));
            end
        end
        
        function setRetryConfig(obj, maxRetries, initialDelay, maxDelay, backoffMultiplier)
            % Configure retry behavior
            % 
            % Args:
            %   maxRetries - Maximum number of retry attempts
            %   initialDelay - Initial delay between retries (seconds)
            %   maxDelay - Maximum delay between retries (seconds)
            %   backoffMultiplier - Exponential backoff multiplier
            
            obj.RetryConfig.maxRetries = maxRetries;
            obj.RetryConfig.initialDelay = initialDelay;
            obj.RetryConfig.maxDelay = maxDelay;
            obj.RetryConfig.backoffMultiplier = backoffMultiplier;
            
            obj.logMessage('INFO', sprintf('Retry configuration updated: max=%d, initial=%.1fs, max=%.1fs, multiplier=%.1f', ...
                maxRetries, initialDelay, maxDelay, backoffMultiplier));
        end
    end
    
    methods (Access = private)
        function [success, message] = attemptConnection(obj)
            % Attempt single connection to ScanImage
            % 
            % Returns:
            %   success - Boolean indicating success
            %   message - Status message
            
            obj.LastConnectionAttempt = datetime('now');
            
            try
                % Try to get ScanImage handle
                obj.HSI = evalin('base', 'hSI');
                
                if isempty(obj.HSI)
                    success = false;
                    message = 'ScanImage handle is empty';
                    return;
                end
                
                % Validate ScanImage object
                if ~isobject(obj.HSI)
                    success = false;
                    message = 'Invalid ScanImage handle - not an object';
                    return;
                end
                
                % Check for required properties
                if ~isprop(obj.HSI, 'hScan2D')
                    success = false;
                    message = 'ScanImage handle missing hScan2D property';
                    return;
                end
                
                % Connection successful
                success = true;
                message = 'Connected to ScanImage';
                
            catch ME
                success = false;
                message = sprintf('Connection failed: %s', ME.message);
                
                if obj.ErrorHandler
                    obj.ErrorHandler.handleConnectionError(ME, 'initial');
                end
            end
        end
        
        function shouldRetry = shouldRetry(obj, errorMessage)
            % Determine if connection should be retried based on error
            % 
            % Args:
            %   errorMessage - Error message from failed connection
            % 
            % Returns:
            %   shouldRetry - Boolean indicating if retry should be attempted
            
            % Don't retry for certain types of errors
            noRetryPatterns = {'not found', 'does not exist', 'invalid', 'permission'};
            
            for i = 1:length(noRetryPatterns)
                if contains(lower(errorMessage), noRetryPatterns{i})
                    shouldRetry = false;
                    return;
                end
            end
            
            shouldRetry = true;
        end
        
        function delay = calculateBackoffDelay(obj)
            % Calculate exponential backoff delay
            % 
            % Returns:
            %   delay - Delay in seconds
            
            delay = obj.RetryConfig.initialDelay * (obj.RetryConfig.backoffMultiplier ^ (obj.RetryCount - 1));
            delay = min(delay, obj.RetryConfig.maxDelay);
        end
        
        function handleConnectionError(obj, error, context)
            % Handle connection errors
            % 
            % Args:
            %   error - Exception object
            %   context - Context string
            
            obj.ConnectionState = obj.ERROR;
            
            if obj.ErrorHandler
                obj.ErrorHandler.handleConnectionError(error, context);
            else
                obj.logMessage('ERROR', sprintf('Connection error (%s): %s', context, error.message));
            end
        end
        
        function pixelData = generateSimulatedImageData(obj)
            % Generate simulated image data for testing
            % 
            % Returns:
            %   pixelData - Simulated image data array
            
            % Generate a simple test pattern
            [X, Y] = meshgrid(1:512, 1:512);
            
            % Create a pattern that changes based on Z position
            zPos = obj.SimulatedPosition.z;
            pattern = sin(X/50 + zPos/100) .* cos(Y/50 + zPos/100);
            
            % Add some noise
            noise = 0.1 * randn(size(pattern));
            
            % Scale to uint16 range
            pixelData = uint16((pattern + noise + 1) * 32767);
        end
        
        function simulateAcquisition(obj, duration)
            % Simulate ScanImage acquisition for testing
            % 
            % Args:
            %   duration - Duration of simulated acquisition in seconds
            
            if ~obj.SimulationMode
                obj.logMessage('WARNING', 'simulateAcquisition called but not in simulation mode');
                return;
            end
            
            obj.logMessage('INFO', sprintf('Starting simulated acquisition for %.1f seconds', duration));
            
            startTime = tic;
            frameCount = 0;
            
            while toc(startTime) < duration
                % Generate new frame
                pixelData = obj.generateSimulatedImageData();
                frameCount = frameCount + 1;
                
                % Simulate frame rate (10 FPS)
                pause(0.1);
                
                % Add some variation to Z position to simulate drift
                obj.SimulatedPosition.z = obj.SimulatedPosition.z + 0.01 * randn();
            end
            
            obj.logMessage('INFO', sprintf('Simulated acquisition completed: %d frames in %.1f seconds', ...
                frameCount, toc(startTime)));
        end
        
        function metadata = generateSimulatedMetadata(obj)
            % Generate simulated metadata for testing
            % 
            % Returns:
            %   metadata - Struct with simulated metadata
            
            metadata = struct();
            metadata.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
            metadata.filename = sprintf('simulated_frame_%06d.tif', randi(999999));
            metadata.scanner = 'Simulated';
            metadata.zoom = 2.0 + randn() * 0.1;
            metadata.frameRate = 10.0 + randn() * 0.5;
            metadata.averaging = 1;
            metadata.resolution = '512x512';
            metadata.fov = sprintf('%.1fx%.1f', 256 + randn()*10, 256 + randn()*10);
            metadata.powerPercent = 5.0 + randn() * 1.0;
            metadata.pockelsValue = metadata.powerPercent / 100;
            
            % Simulated feedback values
            metadata.feedbackValue = struct();
            metadata.feedbackValue.modulation = sprintf('%.3f', 0.5 + randn() * 0.1);
            metadata.feedbackValue.feedback = sprintf('%.3f', 1.0 + randn() * 0.1);
            metadata.feedbackValue.power = sprintf('%.3f', 0.01 + randn() * 0.002);
            
            % Current simulated positions
            metadata.xPos = obj.SimulatedPosition.x;
            metadata.yPos = obj.SimulatedPosition.y;
            metadata.zPos = obj.SimulatedPosition.z;
            
            % Empty bookmark fields
            metadata.bookmarkLabel = '';
            metadata.bookmarkMetricType = '';
            metadata.bookmarkMetricValue = '';
        end
        
        function simulateMotorError(obj, axis)
            % Simulate motor error for testing error handling
            % 
            % Args:
            %   axis - Axis to simulate error on ('x', 'y', or 'z')
            
            obj.logMessage('WARNING', sprintf('Simulating motor error on %s axis', axis));
            
            % Create a mock error
            error = MException('ScanImage:MotorError', ...
                sprintf('Simulated motor error on %s axis', axis));
            
            if obj.ErrorHandler
                obj.ErrorHandler.handleRuntimeError(error, sprintf('motor_%s', axis));
            end
        end
        
        function resetSimulation(obj)
            % Reset simulation to initial state
            
            if ~obj.SimulationMode
                obj.logMessage('WARNING', 'resetSimulation called but not in simulation mode');
                return;
            end
            
            obj.SimulatedPosition = struct('x', 0, 'y', 0, 'z', 0);
            obj.logMessage('INFO', 'Simulation reset to initial state');
        end
        
        function setSimulatedPosition(obj, axis, position)
            % Set simulated position for testing
            % 
            % Args:
            %   axis - 'x', 'y', or 'z'
            %   position - Position value in microns
            
            if ~obj.SimulationMode
                obj.logMessage('WARNING', 'setSimulatedPosition called but not in simulation mode');
                return;
            end
            
            oldPosition = obj.SimulatedPosition.(axis);
            obj.SimulatedPosition.(axis) = position;
            
            obj.logMessage('INFO', sprintf('Simulated %s position changed: %.1f → %.1f μm', ...
                axis, oldPosition, position));
        end
        
        function logMessage(obj, level, message)
            % Log message using error handler or console
            % 
            % Args:
            %   level - Log level (INFO, WARNING, ERROR)
            %   message - Message to log
            
            if obj.ErrorHandler
                obj.ErrorHandler.logMessage(level, sprintf('ScanImageManager: %s', message));
            else
                timestamp = datestr(now, 'HH:MM:SS');
                fprintf('[%s] %s: ScanImageManager: %s\n', timestamp, level, message);
            end
        end
    end
end