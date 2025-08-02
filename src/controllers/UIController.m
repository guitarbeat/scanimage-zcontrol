%==============================================================================
% UICONTROLLER.M
%==============================================================================
% UI state management and update controller for the Foilview application.
%
% This controller handles all UI-related operations, including display updates,
% control state management, and user interface synchronization. It separates
% UI logic from business logic to maintain clean architecture and provides
% throttled updates to prevent UI performance issues.
%
% Key Features:
%   - Throttled UI updates to prevent performance issues
%   - Position display management (X, Y, Z coordinates)
%   - Metric display updates and formatting
%   - Control state management (enable/disable during operations)
%   - Status display updates and error handling
%   - Component validation and error recovery
%
% Update Throttling:
%   - Default throttle: 50ms between updates
%   - Prevents excessive UI updates during rapid changes
%   - Maintains responsive interface while reducing CPU usage
%
% Dependencies:
%   - FoilviewUtils: Utility functions for formatting and error handling
%   - Main application: Access to controller and UI components
%   - MATLAB UI components: Display and control elements
%
% Author: Aaron W. (alw4834)
% Created: 2024
% Last Modified: 2024
% Version: 1.0
%
% Usage:
%   uiController = UIController(app);
%   uiController.updateAllUI();  % Update all UI components
%   uiController.updatePositionDisplay();  % Update position display only
%
%==============================================================================

classdef UIController < handle
    % UIController - Handles UI state management and updates
    % Separates UI logic from business logic
    
    properties (Access = private)
        App
        LastUpdateTime = 0
        UpdateThrottle = 0.05
    end
    
    methods
        function obj = UIController(app)
            obj.App = app;
        end
        
        function updateAllUI(obj)
            % Throttled update of all UI components
            currentTime = posixtime(datetime('now'));
            if (currentTime - obj.LastUpdateTime) < obj.UpdateThrottle
                return;
            end
            
            try
                obj.updatePositionDisplay();
                obj.updateMetricDisplay();
                obj.updateControlStates();
                obj.updateStatusDisplay();
                obj.LastUpdateTime = currentTime;
            catch ME
                FoilviewUtils.logException('UIController', ME);
            end
        end
        
        function updatePositionDisplay(obj)
            % Update position display components
            if ~obj.validateApp()
                return;
            end
            
            try
                controller = obj.App.Controller;
                posDisplay = obj.App.PositionDisplay;
                
                if obj.validateComponents(controller, posDisplay)
                    posDisplay.XValue.Text = FoilviewUtils.formatPosition(controller.CurrentXPosition);
                    posDisplay.YValue.Text = FoilviewUtils.formatPosition(controller.CurrentYPosition);
                    posDisplay.ZValue.Text = FoilviewUtils.formatPosition(controller.CurrentPosition);
                end
            catch ME
                FoilviewUtils.logException('UIController.updatePositionDisplay', ME);
            end
        end
        
        function updateMetricDisplay(obj)
            % Update metric display components
            if ~obj.validateApp()
                return;
            end
            
            try
                controller = obj.App.Controller;
                metricDisplay = obj.App.MetricDisplay;
                
                if obj.validateComponents(controller, metricDisplay)
                    metricDisplay.ValueLabel.Text = FoilviewUtils.formatMetricValue(controller.CurrentMetric);
                    metricDisplay.TypeDropdown.Value = controller.CurrentMetricType;
                end
            catch ME
                FoilviewUtils.logException('UIController.updateMetricDisplay', ME);
            end
        end
        
        function updateControlStates(obj)
            % Update control enable/disable states
            if ~obj.validateApp()
                return;
            end
            
            try
                controller = obj.App.Controller;
                manualControls = obj.App.ManualControls;
                autoControls = obj.App.AutoControls;
                
                if obj.validateComponents(controller, manualControls, autoControls)
                    isAutoRunning = controller.IsAutoRunning;
                    
                    % Manual controls - disabled during auto-stepping
                    obj.setControlsEnabled(manualControls, ~isAutoRunning, ...
                        {'UpButton', 'DownButton', 'ZeroButton', 'StepSizeDropdown'});
                    
                    % Auto controls - some disabled during auto-stepping
                    obj.setControlsEnabled(autoControls, ~isAutoRunning, ...
                        {'StepField', 'StepsField', 'DelayField', 'DirectionSwitch'});
                    
                    % Start/Stop button always enabled but changes text
                    if isAutoRunning
                        autoControls.StartStopButton.Text = 'Stop';
                        autoControls.StartStopButton.BackgroundColor = [0.8 0.2 0.2];
                    else
                        autoControls.StartStopButton.Text = 'Start';
                        autoControls.StartStopButton.BackgroundColor = [0.2 0.7 0.3];
                    end
                end
            catch ME
                FoilviewUtils.logException('UIController.updateControlStates', ME);
            end
        end
        
        function updateStatusDisplay(obj)
            % Update status display components
            if ~obj.validateApp()
                return;
            end
            
            try
                controller = obj.App.Controller;
                statusControls = obj.App.StatusControls;
                
                if obj.validateComponents(controller, statusControls)
                    statusControls.StatusLabel.Text = controller.StatusMessage;
                    
                    % Update status color based on simulation mode
                    if controller.SimulationMode
                        statusControls.StatusLabel.FontColor = [0.8 0.6 0.2]; % Orange
                    else
                        statusControls.StatusLabel.FontColor = [0.2 0.7 0.3]; % Green
                    end
                end
            catch ME
                FoilviewUtils.logException('UIController.updateStatusDisplay', ME);
            end
        end
        
        function updateAutoStepProgress(obj)
            % Update auto-stepping progress display
            if ~obj.validateApp()
                return;
            end
            
            try
                controller = obj.App.Controller;
                autoControls = obj.App.AutoControls;
                
                if obj.validateComponents(controller, autoControls) && controller.IsAutoRunning
                    progress = controller.CurrentStep / controller.TotalSteps;
                    progressText = sprintf('Step %d/%d (%.0f%%)', ...
                        controller.CurrentStep, controller.TotalSteps, progress * 100);
                    
                    if isfield(autoControls, 'ProgressLabel')
                        autoControls.ProgressLabel.Text = progressText;
                    end
                end
            catch ME
                FoilviewUtils.logException('UIController.updateAutoStepProgress', ME);
            end
        end
        
        function adjustFontSizes(obj, windowSize)
            % Adjust font sizes based on window size
            if ~obj.validateApp()
                return;
            end
            
            try
                % Calculate scale factor based on window height
                baseHeight = 600;
                scaleFactor = max(0.8, min(1.2, windowSize(4) / baseHeight));
                
                components = {obj.App.PositionDisplay, obj.App.MetricDisplay, ...
                             obj.App.ManualControls, obj.App.AutoControls, ...
                             obj.App.StatusControls};
                
                for i = 1:length(components)
                    obj.scaleComponentFonts(components{i}, scaleFactor);
                end
            catch ME
                FoilviewUtils.logException('UIController.adjustFontSizes', ME);
            end
        end
        
        function success = setControlsEnabled(obj, controlStruct, enabled, fieldNames)
            % Enable/disable multiple controls
            success = false;
            if nargin < 4
                fieldNames = obj.getAllControlFields();
            end
            
            try
                for i = 1:length(fieldNames)
                    fieldName = fieldNames{i};
                    if isfield(controlStruct, fieldName) && ...
                       FoilviewUtils.validateUIComponent(controlStruct.(fieldName))
                        controlStruct.(fieldName).Enable = FoilviewUtils.getEnableState(enabled);
                    end
                end
                success = true;
            catch ME
                FoilviewUtils.logException('UIController.setControlsEnabled', ME);
            end
        end
        
        function fields = getAllControlFields(~)
            % Get all common control field names
            fields = {'UpButton', 'DownButton', 'ZeroButton', 'StartStopButton', ...
                     'StepField', 'StepsField', 'DelayField', 'StepSizeDropdown', ...
                     'DirectionSwitch', 'TypeDropdown', 'RefreshButton'};
        end
        
        function valid = validateApp(obj)
            % Validate app reference
            valid = ~isempty(obj.App) && isvalid(obj.App);
        end
        
        function valid = validateComponents(~, varargin)
            % Validate multiple UI components
            valid = true;
            for i = 1:nargin-1
                if ~FoilviewUtils.validateUIComponent(varargin{i})
                    valid = false;
                    break;
                end
            end
        end
        
        function scaleComponentFonts(~, component, scaleFactor)
            % Scale fonts in a component structure
            if ~isstruct(component)
                return;
            end
            
            fields = fieldnames(component);
            baseFontSize = 10;
            
            for i = 1:length(fields)
                field = component.(fields{i});
                if FoilviewUtils.validateUIComponent(field) && isprop(field, 'FontSize')
                    try
                        field.FontSize = max(8, round(baseFontSize * scaleFactor));
                    catch
                        % Ignore if FontSize is read-only
                    end
                end
            end
        end
    end
end