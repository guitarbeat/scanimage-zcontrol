%==============================================================================
% CALIBRATIONSERVICE.M
%==============================================================================
% Calibration service for MJC3 joystick axes and stage control.
%
% This service handles the calibration logic for MJC3 joystick axes, providing
% persistent storage and retrieval of calibration data for X, Y, and Z axes.
% It implements dead zone detection, sensitivity adjustment, and range mapping
% to ensure accurate and responsive joystick control.
%
% Key Features:
%   - Multi-axis calibration (X, Y, Z) with individual parameters
%   - Dead zone detection and compensation
%   - Sensitivity adjustment and range mapping
%   - Persistent calibration storage and retrieval
%   - Default calibration fallback
%   - Real-time calibration application
%   - Calibration validation and error handling
%
% Calibration Parameters:
%   - Center: Expected center value for each axis (typically 128)
%   - Dead Zone: Inactive region around center (±5 units default)
%   - Min/Max: Calibrated range limits for each axis
%   - Sensitivity: Multiplier for movement sensitivity
%
% Dependencies:
%   - FoilviewUtils: Utility functions for error handling
%   - MATLAB file I/O: Calibration data persistence
%   - MJC3 controllers: Raw joystick value input
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
    % CalibrationService - Handles calibration logic for MJC3 joystick axes
    % Provides persistent storage and retrieval of calibration data for X, Y, Z axes
    
    properties (Access = private)
        CalibrationData     % Structure containing calibration data for all axes
        CalibrationFile     % Path to calibration data file
        DefaultCalibration  % Default calibration values
    end
    
    properties (Constant)
        DEFAULT_CALIBRATION_FILE = 'mjc3_calibration.mat';
        DEFAULT_CENTER_VALUE = 128;  % Expected center value for joystick axes
        DEFAULT_DEADZONE = 5;        % Dead zone around center (±5 units)
        DEFAULT_SENSITIVITY = 1.0;   % Default sensitivity multiplier
    end
    
    methods
        function obj = CalibrationService(calibrationDir)
            % Constructor
            % calibrationDir: Directory to store calibration data (optional)
            
            if nargin < 1
                calibrationDir = pwd;
            end
            
            % Set up calibration file path
            obj.CalibrationFile = fullfile(calibrationDir, obj.DEFAULT_CALIBRATION_FILE);
            
            % Initialize default calibration structure
            obj.DefaultCalibration = obj.createDefaultCalibration();
            
            % Load existing calibration or create new
            obj.loadCalibration();
        end
        
        function calibrateAxis(obj, axisName, rawValues)
            % Calibrate a specific axis using raw joystick values
            % axisName: 'X', 'Y', or 'Z'
            % rawValues: Array of raw joystick values for this axis
            
            try
                if isempty(rawValues)
                    error('No calibration data provided');
                end
                
                % Convert axis name to field name
                fieldName = obj.axisNameToField(axisName);
                
                % Calculate calibration parameters
                calibration = obj.calculateCalibration(rawValues);
                
                % Store calibration data
                obj.CalibrationData.(fieldName) = calibration;
                
                % Save to file
                obj.saveCalibration();
                
                fprintf('CalibrationService: %s axis calibrated successfully\n', axisName);
                fprintf('  Center: %d, Range: [%d, %d], Sensitivity: %.2f\n', ...
                    calibration.center, calibration.min, calibration.max, calibration.sensitivity);
                
            catch ME
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
                    fprintf('CalibrationService: All axes reset to default\n');
                else
                    % Reset specific axis
                    fieldName = obj.axisNameToField(axisName);
                    if isfield(obj.CalibrationData, fieldName)
                        obj.CalibrationData = rmfield(obj.CalibrationData, fieldName);
                        fprintf('CalibrationService: %s axis reset to default\n', axisName);
                    end
                end
                
                % Save changes
                obj.saveCalibration();
                
            catch ME
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
            catch ME
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
                
            catch ME
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
                        fprintf('CalibrationService: Loaded calibration from %s\n', obj.CalibrationFile);
                    else
                        obj.CalibrationData = obj.createDefaultCalibration();
                    end
                else
                    obj.CalibrationData = obj.createDefaultCalibration();
                    fprintf('CalibrationService: Created new calibration data\n');
                end
            catch ME
                FoilviewUtils.logException('CalibrationService.loadCalibration', ME);
                obj.CalibrationData = obj.createDefaultCalibration();
            end
        end
        
        function saveCalibration(obj)
            % Save calibration data to file
            try
                calibrationData = obj.CalibrationData;
                save(obj.CalibrationFile, 'calibrationData');
                fprintf('CalibrationService: Saved calibration to %s\n', obj.CalibrationFile);
            catch ME
                FoilviewUtils.logException('CalibrationService.saveCalibration', ME);
                error('Failed to save calibration data: %s', ME.message);
            end
        end
        
        function calibration = createDefaultCalibration(obj)
            % Create default calibration structure
            calibration = struct();
            
            axes = {'X', 'Y', 'Z'};
            for i = 1:length(axes)
                fieldName = obj.axisNameToField(axes{i});
                calibration.(fieldName) = struct(...
                    'center', obj.DEFAULT_CENTER_VALUE, ...
                    'min', 0, ...
                    'max', 255, ...
                    'deadzone', obj.DEFAULT_DEADZONE, ...
                    'sensitivity', obj.DEFAULT_SENSITIVITY, ...
                    'calibrated', false, ...
                    'calibrationDate', []);
            end
        end
        
        function calibration = calculateCalibration(obj, rawValues)
            % Calculate calibration parameters from raw values
            % rawValues: Array of raw joystick values
            
            % Calculate center (median of values)
            center = median(rawValues);
            
            % Calculate range
            minVal = min(rawValues);
            maxVal = max(rawValues);
            
            % Calculate dead zone (5% of total range)
            range = maxVal - minVal;
            deadzone = max(obj.DEFAULT_DEADZONE, round(range * 0.05));
            
            % Calculate sensitivity based on range
            sensitivity = 255 / range;  % Normalize to full range
            sensitivity = max(0.1, min(2.0, sensitivity));  % Clamp to reasonable range
            
            calibration = struct(...
                'center', center, ...
                'min', minVal, ...
                'max', maxVal, ...
                'deadzone', deadzone, ...
                'sensitivity', sensitivity, ...
                'calibrated', true, ...
                'calibrationDate', datetime('now'));
        end
        
        function calibratedValue = applyDefaultCalibration(obj, rawValue)
            % Apply default calibration (no calibration applied)
            % Returns normalized value between -1 and 1
            
            center = obj.DEFAULT_CENTER_VALUE;
            deadzone = obj.DEFAULT_DEADZONE;
            
            % Apply dead zone
            if abs(rawValue - center) <= deadzone
                calibratedValue = 0;
                return;
            end
            
            % Simple linear mapping
            if rawValue > center
                normalized = (rawValue - center) / (255 - center);
            else
                normalized = -(center - rawValue) / center;
            end
            
            calibratedValue = max(-1.0, min(1.0, normalized));
        end
        
        function fieldName = axisNameToField(obj, axisName)
            % Convert axis name to field name
            % axisName: 'X', 'Y', or 'Z'
            % Returns: 'xAxis', 'yAxis', or 'zAxis'
            
            switch upper(axisName)
                case 'X'
                    fieldName = 'xAxis';
                case 'Y'
                    fieldName = 'yAxis';
                case 'Z'
                    fieldName = 'zAxis';
                otherwise
                    error('Invalid axis name: %s. Must be X, Y, or Z.', axisName);
            end
        end
    end
end 