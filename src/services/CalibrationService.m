%==============================================================================
% CALIBRATIONSERVICE.M
%==============================================================================
% Calibration service for MJC3 joystick axes.
%
% This service provides comprehensive calibration functionality for the MJC3
% joystick controller, including automatic calibration, manual calibration,
% and persistent storage of calibration data. It handles the conversion
% between raw joystick values and calibrated, normalized values for precise
% control.
%
% Key Features:
%   - Multi-axis calibration (X, Y, Z)
%   - Automatic calibration from sample data
%   - Manual calibration with user input
%   - Persistent calibration storage
%   - Dead zone handling
%   - Sensitivity adjustment
%   - Default calibration fallback
%
% Calibration Process:
%   1. Collect raw joystick samples
%   2. Calculate center, min, max values
%   3. Determine dead zone and sensitivity
%   4. Store calibration data
%   5. Apply calibration to real-time values
%
% Dependencies:
%   - FoilviewUtils: Utility functions and error handling
%   - LoggingService: Unified logging system
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   service = CalibrationService();
%   service.calibrateAxis('Z', rawValues);
%   calibratedValue = service.applyCalibration('Z', rawValue);
%
%==============================================================================

classdef CalibrationService < handle
    % CalibrationService - Comprehensive calibration for MJC3 joystick axes
    % Provides automatic and manual calibration with persistent storage
    
    properties (Access = private)
        CalibrationData    % Structure containing calibration data for each axis
        CalibrationFile    % File path for persistent calibration storage
        DefaultCalibration % Default calibration values
        Logger             % Logging service for structured output
    end
    
    properties (Constant)
        % Default calibration parameters (matching Thorlabs proprietary settings)
        DEFAULT_CENTER = 0
        DEFAULT_MIN = -127
        DEFAULT_MAX = 127
        DEFAULT_DEADZONE = 10        % Dead Zone from Thorlabs settings
        DEFAULT_RESOLUTION = 20      % Resolution from Thorlabs settings
        DEFAULT_DAMPING = 0          % Damping from Thorlabs settings
        DEFAULT_SENSITIVITY = 1.0
        DEFAULT_INVERT_SENSE = false % Invert Sense from Thorlabs settings
    end
    
    methods
        function obj = CalibrationService()
            % Constructor: Initialize calibration service
            
            % Initialize logger
            obj.Logger = LoggingService('CalibrationService');
            
            % Set up calibration file path
            obj.CalibrationFile = fullfile(pwd, 'calibration_data.mat');
            
            % Create default calibration
            obj.DefaultCalibration = obj.createDefaultCalibration();
            
            % Load existing calibration or create new
            obj.loadCalibration();
            
            obj.Logger.info('Calibration service initialized');
        end
        

        
        function calibratedValue = applyCalibration(obj, axisName, rawValue)
            % Apply calibration to a raw joystick value
            % axisName: 'X', 'Y', or 'Z'
            % rawValue: Raw joystick value
            % Returns: Calibrated value (-1.0 to 1.0)
            
            try
                fieldName = obj.axisNameToField(axisName);
                
                if ~isfield(obj.CalibrationData, fieldName)
                    % Use default calibration if not calibrated
                    calibratedValue = obj.applyDefaultCalibration(rawValue);
                    return;
                end
                
                calibration = obj.CalibrationData.(fieldName);
                
                % Apply dead zone
                if abs(rawValue - calibration.center) <= calibration.deadzone
                    calibratedValue = 0;
                    return;
                end
                
                % Calculate normalized position (-1 to 1)
                if rawValue > calibration.center
                    % Positive direction
                    range = calibration.max - calibration.center;
                    if range > 0
                        normalized = (rawValue - calibration.center) / range;
                    else
                        normalized = 0;
                    end
                else
                    % Negative direction
                    range = calibration.center - calibration.min;
                    if range > 0
                        normalized = -(calibration.center - rawValue) / range;
                    else
                        normalized = 0;
                    end
                end
                
                % Apply sensitivity and clamp to [-1, 1]
                calibratedValue = normalized * calibration.sensitivity;
                calibratedValue = max(-1.0, min(1.0, calibratedValue));
                
                % Apply invert sense if enabled
                if isfield(calibration, 'invertSense') && calibration.invertSense
                    calibratedValue = -calibratedValue;
                end
                
                % Apply damping (simple exponential smoothing)
                if isfield(calibration, 'damping') && calibration.damping > 0
                    % Store previous value for damping calculation
                    fieldName = obj.axisNameToField(axisName);
                    prevFieldName = [fieldName '_prev'];
                    
                    if ~isfield(obj.CalibrationData, prevFieldName)
                        obj.CalibrationData.(prevFieldName) = 0;
                    end
                    
                    dampingFactor = calibration.damping / 100; % Convert to 0-1 range
                    calibratedValue = (1 - dampingFactor) * calibratedValue + dampingFactor * obj.CalibrationData.(prevFieldName);
                    obj.CalibrationData.(prevFieldName) = calibratedValue;
                end
                
            catch ME
                obj.Logger.error('Error applying calibration to %s axis: %s', axisName, ME.message);
                obj.Logger.debug('Calibration application error details: %s', ME.getReport());
                FoilviewUtils.logException('CalibrationService.applyCalibration', ME);
                % Fallback to default calibration
                calibratedValue = obj.applyDefaultCalibration(rawValue);
            end
        end
        
        function calibration = getCalibration(obj, axisName)
            % Get calibration data for a specific axis
            % axisName: 'X', 'Y', or 'Z'
            % Returns: Calibration structure or empty if not calibrated
            
            try
                fieldName = obj.axisNameToField(axisName);
                
                if isfield(obj.CalibrationData, fieldName)
                    calibration = obj.CalibrationData.(fieldName);
                else
                    calibration = [];
                end
                
            catch ME
                obj.Logger.error('Failed to get calibration for %s axis: %s', axisName, ME.message);
                obj.Logger.debug('Get calibration error details: %s', ME.getReport());
                FoilviewUtils.logException('CalibrationService.getCalibration', ME);
                calibration = [];
            end
        end
        
        function resetCalibration(obj, axisName)
            % Reset calibration for a specific axis
            % axisName: 'X', 'Y', 'Z', or 'all'
            
            try
                if strcmpi(axisName, 'all')
                    % Reset all axes
                    obj.CalibrationData = obj.createDefaultCalibration();
                    obj.Logger.info('All axes reset to default calibration');
                else
                    % Reset specific axis
                    fieldName = obj.axisNameToField(axisName);
                    if isfield(obj.CalibrationData, fieldName)
                        obj.CalibrationData = rmfield(obj.CalibrationData, fieldName);
                        obj.Logger.info('%s axis reset to default calibration', axisName);
                    else
                        obj.Logger.debug('%s axis was already using default calibration', axisName);
                    end
                end
                
                % Save changes
                obj.saveCalibration();
                
            catch ME
                obj.Logger.error('Failed to reset calibration for %s: %s', axisName, ME.message);
                obj.Logger.debug('Reset calibration error details: %s', ME.getReport());
                FoilviewUtils.logException('CalibrationService.resetCalibration', ME);
                error('Failed to reset calibration for %s: %s', axisName, ME.message);
            end
        end
        
        function isCalibrated = isAxisCalibrated(obj, axisName)
            % Check if an axis has been calibrated
            % axisName: 'X', 'Y', or 'Z'
            % Returns: true if calibrated, false otherwise
            
            try
                fieldName = obj.axisNameToField(axisName);
                isCalibrated = isfield(obj.CalibrationData, fieldName);
                obj.Logger.debug('%s axis calibration status: %s', axisName, mat2str(isCalibrated));
            catch ME
                obj.Logger.error('Failed to check calibration status for %s: %s', axisName, ME.message);
                obj.Logger.debug('Calibration status check error details: %s', ME.getReport());
                FoilviewUtils.logException('CalibrationService.isAxisCalibrated', ME);
                isCalibrated = false;
            end
        end
        
        function status = getCalibrationStatus(obj)
            % Get calibration status for all axes
            % Returns: Structure with calibration status for each axis
            
            try
                status = struct();
                axes = {'X', 'Y', 'Z'};
                
                for i = 1:length(axes)
                    axisName = axes{i};
                    fieldName = obj.axisNameToField(axisName);
                    
                    if isfield(obj.CalibrationData, fieldName)
                        status.(fieldName) = obj.CalibrationData.(fieldName);
                    else
                        status.(fieldName) = obj.DefaultCalibration.(fieldName);
                    end
                end
                
                obj.Logger.debug('Calibration status retrieved: %s', jsonencode(status));
                
            catch ME
                obj.Logger.error('Failed to get calibration status: %s', ME.message);
                obj.Logger.debug('Calibration status error details: %s', ME.getReport());
                FoilviewUtils.logException('CalibrationService.getCalibrationStatus', ME);
                status = obj.DefaultCalibration;
            end
        end
        
        function setManualCalibration(obj, axisName, negativePos, centerPos, positivePos, deadzone, resolution, damping, invertSense)
            % Manually set calibration parameters for an axis
            % axisName: 'X', 'Y', or 'Z'
            % negativePos: Raw value at maximum negative deflection
            % centerPos: Raw value at center/rest position
            % positivePos: Raw value at maximum positive deflection
            % deadzone: Dead zone around center (optional, default: 10)
            % resolution: Movement resolution/sensitivity (optional, default: 20)
            % damping: Movement damping factor (optional, default: 0)
            % invertSense: Invert axis direction (optional, default: false)
            
            try
                % Set default values for optional parameters
                if nargin < 5, deadzone = obj.DEFAULT_DEADZONE; end
                if nargin < 6, resolution = obj.DEFAULT_RESOLUTION; end
                if nargin < 7, damping = obj.DEFAULT_DAMPING; end
                if nargin < 8, invertSense = obj.DEFAULT_INVERT_SENSE; end
                
                % Validate inputs
                if negativePos >= positivePos
                    error('Negative position must be less than positive position');
                end
                
                if centerPos < negativePos || centerPos > positivePos
                    error('Center position must be between negative and positive positions');
                end
                
                if deadzone < 0
                    error('Dead zone must be non-negative');
                end
                
                fieldName = obj.axisNameToField(axisName);
                
                % Calculate sensitivity based on range
                totalRange = positivePos - negativePos;
                if totalRange > 0
                    sensitivity = 127 / (totalRange / 2); % Normalize to standard range
                else
                    sensitivity = obj.DEFAULT_SENSITIVITY;
                end
                
                % Create calibration structure
                calibration = struct(...
                    'center', centerPos, ...
                    'min', negativePos, ...
                    'max', positivePos, ...
                    'deadzone', deadzone, ...
                    'resolution', resolution, ...
                    'damping', damping, ...
                    'sensitivity', sensitivity, ...
                    'invertSense', invertSense);
                
                % Store calibration data
                obj.CalibrationData.(fieldName) = calibration;
                
                % Save to file
                obj.saveCalibration();
                
                obj.Logger.info('Manual calibration set for %s axis', axisName);
                obj.Logger.debug('Manual calibration parameters - Neg: %d, Center: %d, Pos: %d, Deadzone: %d, Resolution: %d, Damping: %d, Invert: %s', ...
                    negativePos, centerPos, positivePos, deadzone, resolution, damping, mat2str(invertSense));
                
            catch ME
                obj.Logger.error('Failed to set manual calibration for %s axis: %s', axisName, ME.message);
                obj.Logger.debug('Manual calibration error details: %s', ME.getReport());
                FoilviewUtils.logException('CalibrationService.setManualCalibration', ME);
                error('Failed to set manual calibration for %s axis: %s', axisName, ME.message);
            end
        end
        
        function setAxisParameter(obj, axisName, parameterName, value)
            % Set a specific parameter for an axis
            % axisName: 'X', 'Y', or 'Z'
            % parameterName: 'deadzone', 'resolution', 'damping', 'invertSense', 'sensitivity'
            % value: New parameter value
            
            try
                fieldName = obj.axisNameToField(axisName);
                
                % Ensure axis has calibration data
                if ~isfield(obj.CalibrationData, fieldName)
                    obj.CalibrationData.(fieldName) = obj.DefaultCalibration.(fieldName);
                end
                
                % Validate parameter name
                validParams = {'deadzone', 'resolution', 'damping', 'invertSense', 'sensitivity'};
                if ~ismember(parameterName, validParams)
                    error('Invalid parameter name: %s. Valid parameters: %s', parameterName, strjoin(validParams, ', '));
                end
                
                % Validate parameter value
                switch parameterName
                    case 'deadzone'
                        if value < 0
                            error('Dead zone must be non-negative');
                        end
                    case 'resolution'
                        if value <= 0
                            error('Resolution must be positive');
                        end
                    case 'damping'
                        if value < 0
                            error('Damping must be non-negative');
                        end
                    case 'sensitivity'
                        if value <= 0
                            error('Sensitivity must be positive');
                        end
                    case 'invertSense'
                        if ~islogical(value)
                            error('Invert sense must be true or false');
                        end
                end
                
                % Set parameter
                obj.CalibrationData.(fieldName).(parameterName) = value;
                
                % Save to file
                obj.saveCalibration();
                
                obj.Logger.info('Parameter %s set to %s for %s axis', parameterName, mat2str(value), axisName);
                
            catch ME
                obj.Logger.error('Failed to set parameter %s for %s axis: %s', parameterName, axisName, ME.message);
                obj.Logger.debug('Parameter setting error details: %s', ME.getReport());
                FoilviewUtils.logException('CalibrationService.setAxisParameter', ME);
                error('Failed to set parameter %s for %s axis: %s', parameterName, axisName, ME.message);
            end
        end
        
        function value = getAxisParameter(obj, axisName, parameterName)
            % Get a specific parameter value for an axis
            % axisName: 'X', 'Y', or 'Z'
            % parameterName: 'center', 'min', 'max', 'deadzone', 'resolution', 'damping', 'invertSense', 'sensitivity'
            % Returns: Parameter value
            
            try
                fieldName = obj.axisNameToField(axisName);
                
                if isfield(obj.CalibrationData, fieldName)
                    calibration = obj.CalibrationData.(fieldName);
                else
                    calibration = obj.DefaultCalibration.(fieldName);
                end
                
                if isfield(calibration, parameterName)
                    value = calibration.(parameterName);
                else
                    error('Invalid parameter name: %s', parameterName);
                end
                
            catch ME
                obj.Logger.error('Failed to get parameter %s for %s axis: %s', parameterName, axisName, ME.message);
                obj.Logger.debug('Parameter retrieval error details: %s', ME.getReport());
                FoilviewUtils.logException('CalibrationService.getAxisParameter', ME);
                value = [];
            end
        end
    end
    
    methods (Access = private)
        function loadCalibration(obj)
            % Load calibration data from file
            try
                if exist(obj.CalibrationFile, 'file')
                    loadedData = load(obj.CalibrationFile);
                    if isfield(loadedData, 'calibrationData')
                        obj.CalibrationData = loadedData.calibrationData;
                        obj.Logger.info('Loaded calibration from %s', obj.CalibrationFile);
                        obj.Logger.debug('Loaded calibration data: %s', jsonencode(obj.CalibrationData));
                    else
                        obj.CalibrationData = obj.createDefaultCalibration();
                        obj.Logger.warning('Calibration file exists but has invalid format, using defaults');
                    end
                else
                    obj.CalibrationData = obj.createDefaultCalibration();
                    obj.Logger.info('Created new calibration data (no existing file found)');
                end
            catch ME
                obj.Logger.error('Failed to load calibration: %s', ME.message);
                obj.Logger.debug('Load calibration error details: %s', ME.getReport());
                FoilviewUtils.logException('CalibrationService.loadCalibration', ME);
                obj.CalibrationData = obj.createDefaultCalibration();
            end
        end
        
        function saveCalibration(obj)
            % Save calibration data to file
            try
                calibrationData = obj.CalibrationData;
                save(obj.CalibrationFile, 'calibrationData');
                obj.Logger.info('Saved calibration to %s', obj.CalibrationFile);
                obj.Logger.debug('Saved calibration data: %s', jsonencode(calibrationData));
            catch ME
                obj.Logger.error('Failed to save calibration: %s', ME.message);
                obj.Logger.debug('Save calibration error details: %s', ME.getReport());
                FoilviewUtils.logException('CalibrationService.saveCalibration', ME);
                error('Failed to save calibration data: %s', ME.message);
            end
        end
        
        function calibration = createDefaultCalibration(obj)
            % Create default calibration structure with Thorlabs-compatible parameters
            calibration = struct();
            axes = {'X', 'Y', 'Z'};
            
            for i = 1:length(axes)
                axisName = axes{i};
                fieldName = obj.axisNameToField(axisName);
                
                calibration.(fieldName) = struct(...
                    'center', obj.DEFAULT_CENTER, ...
                    'min', obj.DEFAULT_MIN, ...
                    'max', obj.DEFAULT_MAX, ...
                    'deadzone', obj.DEFAULT_DEADZONE, ...
                    'resolution', obj.DEFAULT_RESOLUTION, ...
                    'damping', obj.DEFAULT_DAMPING, ...
                    'sensitivity', obj.DEFAULT_SENSITIVITY, ...
                    'invertSense', obj.DEFAULT_INVERT_SENSE);
            end
        end
        
        function calibration = calculateCalibration(~, rawValues)
            % Calculate calibration parameters from raw values
            % rawValues: Array of raw joystick values (signed 8-bit: -127 to 127)
            % Returns: Calibration structure
            
            % Calculate basic statistics
            center = median(rawValues);
            minVal = min(rawValues);
            maxVal = max(rawValues);
            
            % Calculate dead zone (5% of total range)
            totalRange = maxVal - minVal;
            deadzone = max(1, round(totalRange * 0.05));
            
            % Calculate sensitivity based on range (normalized to 127 max range)
            if totalRange > 0
                sensitivity = 127 / max(abs(minVal), abs(maxVal));
            else
                sensitivity = 1.0;
            end
            
            calibration = struct(...
                'center', center, ...
                'min', minVal, ...
                'max', maxVal, ...
                'deadzone', deadzone, ...
                'sensitivity', sensitivity);
        end
        
        function calibratedValue = applyDefaultCalibration(~, rawValue)
            % Apply default calibration to raw value
            % rawValue: Raw joystick value (signed 8-bit: -127 to 127)
            % Returns: Calibrated value (-1.0 to 1.0)
            
            % Simple linear mapping from [-127, 127] to [-1, 1]
            % Note: MEX function returns signed 8-bit values, not unsigned
            calibratedValue = rawValue / 127;
            calibratedValue = max(-1.0, min(1.0, calibratedValue));
        end
        
        function fieldName = axisNameToField(~, axisName)
            % Convert axis name to field name
            % axisName: 'X', 'Y', or 'Z'
            % Returns: Field name for calibration data
            
            switch upper(axisName)
                case 'X'
                    fieldName = 'xAxis';
                case 'Y'
                    fieldName = 'yAxis';
                case 'Z'
                    fieldName = 'zAxis';
                otherwise
                    error('Invalid axis name: %s', axisName);
            end
        end
    end
end 