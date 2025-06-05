classdef SIZControl < handle
    % SIZControl - ScanImage Z position control class
    %
    % This class provides an interface to control Z position in ScanImage
    % using the ScanImage API where available.
    %
    % Usage:
    %   z = SIZControl(@statusCallback);
    %   z.moveUp();
    %   z.moveDown();
    %   z.absoluteMove(position);
    %
    % Author: Manus AI (2025)
    
    properties
        % Movement properties
        stepSize = 1.0          % Step size for relative movements (µm)
        numSteps = 10           % Number of steps for automated scanning
        delayBetweenSteps = 0.5 % Delay between steps (seconds)
        direction = 1           % Direction: 1=up, -1=down
        
        % Status properties
        isRunning = false       % Whether automated movement is running
        startPosition = 0       % Starting position for return function
        
        % Callback function
        statusCallback          % Function handle for status updates
    end
    
    properties (Access = private)
        hSI                     % Handle to ScanImage
        movementTimer           % Timer for automated movement
    end
    
    methods
        function obj = SIZControl(statusCallback)
            % Constructor - Initialize the SIZControl object
            
            % Get ScanImage handle
            try
                obj.hSI = evalin('base', 'hSI');
                if isempty(obj.hSI)
                    error('ScanImage handle (hSI) is empty');
                end
            catch
                error('ScanImage must be running. Please start ScanImage first.');
            end
            
            % Set status callback
            if nargin >= 1 && isa(statusCallback, 'function_handle')
                obj.statusCallback = statusCallback;
            else
                obj.statusCallback = @(msg) fprintf('%s\n', msg);
            end
            
            % Log initialization
            obj.log('SIZControl initialized.');
            
            % Get current position as starting position
            obj.startPosition = obj.getCurrentZPosition();
            obj.log(sprintf('Current Z position: %.2f', obj.startPosition));
        end
        
        function delete(obj)
            % Destructor - Clean up timers
            obj.stopZMovement();
        end
        
        function pos = getCurrentZPosition(obj)
            % Get the current Z position using ScanImage API
            pos = 0;
            
            try
                % Try different methods to get Z position
                methods = {
                    @() obj.getZPositionFromMotors(),
                    @() obj.getZPositionFromStackManager(),
                    @() obj.getZPositionFromFastZ()
                };
                
                for i = 1:length(methods)
                    try
                        pos = methods{i}();
                        if ~isempty(pos) && ~isnan(pos)
                            return;
                        end
                    catch
                        % Try next method
                    end
                end
                
                obj.log('Could not determine Z position, returning 0', 'warning');
            catch ME
                obj.log(['Error getting Z position: ' ME.message], 'error');
            end
        end
        
        function success = moveUp(obj)
            % Move up by one step
            success = obj.relativeMove(obj.stepSize);
        end
        
        function success = moveDown(obj)
            % Move down by one step
            success = obj.relativeMove(-obj.stepSize);
        end
        
        function success = relativeMove(obj, distance)
            % Move by a relative distance
            success = false;
            
            try
                % Get current position
                currentPos = obj.getCurrentZPosition();
                
                % Calculate target position
                targetPos = currentPos + distance;
                
                % Move to target position
                success = obj.absoluteMove(targetPos);
                
                if success
                    obj.log(sprintf('Moved by %.2f to position %.2f', distance, targetPos));
                end
            catch ME
                obj.log(['Error in relative move: ' ME.message], 'error');
            end
        end
        
        function success = absoluteMove(obj, targetPosition)
            % Move to an absolute Z position
            success = false;
            
            try
                % Try different methods to set Z position
                methods = {
                    @() obj.setZPositionViaMotors(targetPosition),
                    @() obj.setZPositionViaStackManager(targetPosition),
                    @() obj.setZPositionViaFastZ(targetPosition)
                };
                
                for i = 1:length(methods)
                    try
                        success = methods{i}();
                        if success
                            obj.log(sprintf('Moved to position %.2f', targetPosition));
                            return;
                        end
                    catch
                        % Try next method
                    end
                end
                
                obj.log('Failed to set Z position using any available method', 'error');
            catch ME
                obj.log(['Error in absolute move: ' ME.message], 'error');
            end
        end
        
        function startZMovement(obj)
            % Start automated Z movement
            
            % Stop any existing movement
            obj.stopZMovement();
            
            % Store starting position
            obj.startPosition = obj.getCurrentZPosition();
            obj.log(sprintf('Starting Z movement from position %.2f', obj.startPosition));
            
            % Set running flag
            obj.isRunning = true;
            
            % Create timer for movement
            obj.movementTimer = timer('Period', obj.delayBetweenSteps, ...
                                     'ExecutionMode', 'fixedRate', ...
                                     'TimerFcn', @(~,~) obj.moveNextStep());
            start(obj.movementTimer);
        end
        
        function stopZMovement(obj)
            % Stop automated Z movement
            
            % Stop and delete timer if it exists
            if ~isempty(obj.movementTimer) && isvalid(obj.movementTimer)
                stop(obj.movementTimer);
                delete(obj.movementTimer);
                obj.movementTimer = [];
            end
            
            % Clear running flag
            obj.isRunning = false;
            
            obj.log('Z movement stopped');
        end
        
        function returnToStart(obj)
            % Return to starting position
            
            % Stop any existing movement
            obj.stopZMovement();
            
            % Move to starting position
            obj.log(sprintf('Returning to starting position: %.2f', obj.startPosition));
            obj.absoluteMove(obj.startPosition);
        end
    end
    
    methods (Access = private)
        function moveNextStep(obj)
            % Move one step in the current direction
            
            % Check if we've reached the end
            if ~obj.isRunning
                return;
            end
            
            % Move one step
            distance = obj.direction * obj.stepSize;
            success = obj.relativeMove(distance);
            
            % If move failed, stop movement
            if ~success
                obj.log('Movement failed, stopping automated scan', 'warning');
                obj.stopZMovement();
            end
        end
        
        function pos = getZPositionFromMotors(obj)
            % Get Z position from hMotors
            pos = [];
            
            % Check if motors are available
            if ~isfield(obj.hSI, 'hMotors') || isempty(obj.hSI.hMotors)
                return;
            end
            
            try
                % Try to query position
                pos = obj.hSI.hMotors.queryPosition(3); % 3 = Z axis
            catch
                % Try to access Z motor directly
                try
                    motorXYZ = obj.hSI.hMotors.motorXYZ;
                    if iscell(motorXYZ) && length(motorXYZ) >= 3 && ~isempty(motorXYZ{3})
                        pos = motorXYZ{3}.lastKnownPosition;
                    end
                catch
                    % Failed to get position from motors
                end
            end
        end
        
        function pos = getZPositionFromStackManager(obj)
            % Get Z position from hStackManager
            pos = [];
            
            % Check if stack manager is available
            if ~isfield(obj.hSI, 'hStackManager') || isempty(obj.hSI.hStackManager)
                return;
            end
            
            try
                % Try to get zPosition property
                pos = obj.hSI.hStackManager.zPosition;
            catch
                % Failed to get position from stack manager
            end
        end
        
        function pos = getZPositionFromFastZ(obj)
            % Get Z position from hFastZ
            pos = [];
            
            % Check if FastZ is available
            if ~isfield(obj.hSI, 'hFastZ') || isempty(obj.hSI.hFastZ)
                return;
            end
            
            try
                % Try to get positionTarget property
                pos = obj.hSI.hFastZ.positionTarget;
            catch
                % Failed to get position from FastZ
            end
        end
        
        function success = setZPositionViaMotors(obj, position)
            % Set Z position via hMotors
            success = false;
            
            % Check if motors are available
            if ~isfield(obj.hSI, 'hMotors') || isempty(obj.hSI.hMotors)
                return;
            end
            
            try
                % Try to move using moveXYZ
                obj.hSI.hMotors.moveXYZ([0, 0, position]);
                success = true;
            catch
                % Try to access Z motor directly
                try
                    motorXYZ = obj.hSI.hMotors.motorXYZ;
                    if iscell(motorXYZ) && length(motorXYZ) >= 3 && ~isempty(motorXYZ{3})
                        motorXYZ{3}.moveToPosition(position);
                        success = true;
                    end
                catch
                    % Failed to set position via motors
                end
            end
        end
        
        function success = setZPositionViaStackManager(obj, position)
            % Set Z position via hStackManager
            success = false;
            
            % Check if stack manager is available
            if ~isfield(obj.hSI, 'hStackManager') || isempty(obj.hSI.hStackManager)
                return;
            end
            
            try
                % Try to set zPosition property
                obj.hSI.hStackManager.zPosition = position;
                success = true;
            catch
                % Failed to set position via stack manager
            end
        end
        
        function success = setZPositionViaFastZ(obj, position)
            % Set Z position via hFastZ
            success = false;
            
            % Check if FastZ is available
            if ~isfield(obj.hSI, 'hFastZ') || isempty(obj.hSI.hFastZ)
                return;
            end
            
            try
                % Try to set positionTarget property
                obj.hSI.hFastZ.positionTarget = position;
                success = true;
            catch
                % Failed to set position via FastZ
            end
        end
        
        function log(obj, message, level)
            % Log a message using the status callback
            
            if nargin < 3
                level = 'info';
            end
            
            % Add level prefix to message
            if strcmp(level, 'error')
                message = ['ERROR: ' message];
            elseif strcmp(level, 'warning')
                message = ['WARNING: ' message];
            end
            
            % Call status callback if available
            if ~isempty(obj.statusCallback)
                obj.statusCallback(message);
            end
        end
    end
end
