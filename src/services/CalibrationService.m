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
        % Default calibration parameters
        DEFAULT_CENTER = 128
        DEFAULT_MIN = 0
        DEFAULT_MAX = 255
        DEFAULT_DEADZONE = 10
        DEFAULT_SENSITIVITY = 1.0
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
        
        function calibrateAxis(obj, axisName, rawValues)
            % Calibrate a specific axis using raw joystick samples
            % axisName: 'X', 'Y', or 'Z'
            % rawValues: Array of raw joystick values for the axis
            
            try
                if isempty(rawValues)
                    error('No raw values provided for calibration');
                end
                
                obj.Logger.info('Calibrating %s axis with %d samples...', axisName, length(rawValues));
                obj.Logger.debug('Raw values range: [%d, %d]', min(rawValues), max(rawValues));
                
                fieldName = obj.axisNameToField(axisName);
                
                % Calculate calibration parameters
                calibration = obj.calculateCalibration(rawValues);
                
                % Store calibration data
                obj.CalibrationData.(fieldName) = calibration;
                
                % Save to file
                obj.saveCalibration();
                
                obj.Logger.info('%s axis calibrated successfully', axisName);
                obj.Logger.debug('Calibration parameters - Center: %d, Range: [%d, %d], Sensitivity: %.2f', ...
                    calibration.center, calibration.min, calibration.max, calibration.sensitivity);
                
            catch ME
                obj.Logger.error('Failed to calibrate %s axis: %s', axisName, ME.message);
                obj.Logger.debug('Calibration error details: %s', ME.getReport());
                FoilviewUtils.logException('CalibrationService.calibrateAxis', ME);
                error('Failed to calibrate %s axis: %s', axisName, ME.message);
            end
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
            % Create default calibration structure
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
                    'sensitivity', obj.DEFAULT_SENSITIVITY);
            end
        end
        
        function calibration = calculateCalibration(obj, rawValues)
            % Calculate calibration parameters from raw values
            % rawValues: Array of raw joystick values
            % Returns: Calibration structure
            
            % Calculate basic statistics
            center = median(rawValues);
            minVal = min(rawValues);
            maxVal = max(rawValues);
            
            % Calculate dead zone (5% of total range)
            totalRange = maxVal - minVal;
            deadzone = max(1, round(totalRange * 0.05));
            
            % Calculate sensitivity based on range
            if totalRange > 0
                sensitivity = 255 / totalRange;
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
        
        function calibratedValue = applyDefaultCalibration(obj, rawValue)
            % Apply default calibration to raw value
            % rawValue: Raw joystick value
            % Returns: Calibrated value (-1.0 to 1.0)
            
            % Simple linear mapping from [0, 255] to [-1, 1]
            calibratedValue = (rawValue - obj.DEFAULT_CENTER) / obj.DEFAULT_CENTER;
            calibratedValue = max(-1.0, min(1.0, calibratedValue));
        end
        
        function fieldName = axisNameToField(obj, axisName)
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