% src\FocusGUI.m
classdef FocusGUI < handle
    % FocusGUI - Manages the graphical user interface for the FocalSweep tool.

    properties (Constant)
        UI_COLORS = struct(...
            'Primary', [0.2, 0.4, 0.8], 'Success', [0.2, 0.7, 0.3],...
            'Warning', [0.9, 0.6, 0.1], 'Danger', [0.8, 0.2, 0.2],...
            'Background', [0.96, 0.96, 0.98], 'Border', [0.8, 0.8, 0.8],...
            'Text', [0.2, 0.2, 0.2], 'ActionButton', [0.85, 0.95, 0.95]);
    end

    properties
        controller
        hFig
        hCurrentZLabel
        hStatusText
        hStatusBar
        
        % Parameter controls
        stepSizeSpinner
        initialStepSizeSpinner
        scanPauseTimeSpinner
        rangeLowSpinner
        rangeHighSpinner
        smoothingWindowSpinner
        autoUpdateFreqSpinner
    end

    properties (Access = private)
        previousZValue = NaN
    end

    methods
        function obj = FocusGUI(controller)
            obj.controller = controller;
        end

        function create(obj)
            obj.hFig = uifigure('Name', 'FocalSweep Z-Control', ...
                'Position', [100, 100, 400, 600], ...
                'Color', obj.UI_COLORS.Background, ...
                'CloseRequestFcn', @(~,~) obj.closeFigure(), ...
                'KeyPressFcn', @(~,evt) obj.handleKeyPress(evt));

            mainGrid = uigridlayout(obj.hFig, [5,1]);
            mainGrid.RowHeight = {'fit', 'fit', '1x', 'fit', 25};
            mainGrid.Padding = [10, 10, 10, 10];
            mainGrid.RowSpacing = 10;

            obj.createZControls(mainGrid);
            obj.createSIControls(mainGrid);
            obj.createParameterControls(mainGrid);
            obj.createStatusBar(mainGrid);

            obj.updateStatus('Ready');
        end

        function updateStatus(obj, message, messageType)
            if nargin < 3, messageType = 'info'; end
            colors = struct('info', obj.UI_COLORS.Text, 'success', obj.UI_COLORS.Success, ...
                            'warning', obj.UI_COLORS.Warning, 'error', obj.UI_COLORS.Danger);
            bgColors = struct('info', [0.9, 0.9, 0.95], 'success', [0.9, 1.0, 0.9], ...
                              'warning', [1.0, 0.95, 0.9], 'error', [1.0, 0.9, 0.9]);

            obj.hStatusText.Text = message;
            obj.hStatusText.FontColor = colors.(messageType);
            obj.hStatusBar.BackgroundColor = bgColors.(messageType);
            drawnow('limitrate');
        end

        function updateZPosition(obj)
            currentZ = obj.controller.getZ();
            direction = '';
            if ~isnan(obj.previousZValue)
                if currentZ > obj.previousZValue, direction = ' (▲)';
                elseif currentZ < obj.previousZValue, direction = ' (▼)'; end
            end
            obj.hCurrentZLabel.Text = sprintf('Current Z: %.2f µm%s', currentZ, direction);
            obj.previousZValue = currentZ;
        end

        function closeFigure(obj)
            obj.controller.abortAllOperations();
            if isvalid(obj.hFig), delete(obj.hFig); end
        end
    end

    methods (Access = private)
        function createZControls(obj, parent)
            panel = uipanel(parent, 'BackgroundColor', obj.UI_COLORS.Background);
            grid = uigridlayout(panel, [2,1]);
            grid.RowHeight = {'fit', 'fit'};

            obj.hCurrentZLabel = uilabel(grid, 'Text', 'Current Z: -- µm', ...
                'FontWeight', 'bold', 'FontSize', 14);

            buttonsGrid = uigridlayout(grid, [1,2]);
            buttonsGrid.ColumnWidth = {'1x', '1x'};

            uibutton(buttonsGrid, 'Text', 'Z Up', ...
                'ButtonPushedFcn', @(~,~) obj.controller.moveZUp());
            uibutton(buttonsGrid, 'Text', 'Z Down', ...
                'ButtonPushedFcn', @(~,~) obj.controller.moveZDown());
        end

        function createSIControls(obj, parent)
            panel = uipanel(parent, 'BackgroundColor', obj.UI_COLORS.Background);
            grid = uigridlayout(panel, [1,3]);
            grid.ColumnWidth = {'1x', '1x', '1x'};

            uibutton(grid, 'Text', 'Focus', 'ButtonPushedFcn', @(~,~) obj.startSIFocus());
            uibutton(grid, 'Text', 'Grab', 'ButtonPushedFcn', @(~,~) obj.grabSIFrame());
            uibutton(grid, 'Text', 'Abort', 'ButtonPushedFcn', @(~,~) obj.controller.abortAllOperations());
        end

        function createParameterControls(obj, parent)
            panel = uipanel(parent, 'Title', 'Parameters', ...
                'BackgroundColor', obj.UI_COLORS.Background, ...
                'FontWeight', 'bold');
            
            grid = uigridlayout(panel, [7,2]);
            grid.RowHeight = repmat({'fit'}, 1, 7);
            grid.ColumnWidth = {'fit', '1x'};
            grid.Padding = [10 10 10 10];
            
            % Step Size
            uilabel(grid, 'Text', 'Step Size (µm):', 'HorizontalAlignment', 'right');
            stepSize = obj.getValidValue('stepSize', obj.controller.DEFAULT_STEP_SIZE);
            obj.stepSizeSpinner = uispinner(grid, 'Value', stepSize, ...
                'Limits', [0.1 100], 'ValueChangedFcn', @(src,~) obj.updateStepSize(src.Value));
            
            % Initial Step Size
            uilabel(grid, 'Text', 'Initial Step Size (µm):', 'HorizontalAlignment', 'right');
            initialStepSize = obj.getValidValue('initialStepSize', obj.controller.DEFAULT_INITIAL_STEP_SIZE);
            obj.initialStepSizeSpinner = uispinner(grid, 'Value', initialStepSize, ...
                'Limits', [1 200], 'ValueChangedFcn', @(src,~) obj.updateParameter('initialStepSize', src.Value));
            
            % Scan Pause Time
            uilabel(grid, 'Text', 'Scan Pause Time (s):', 'HorizontalAlignment', 'right');
            scanPauseTime = obj.getValidValue('scanPauseTime', obj.controller.DEFAULT_SCAN_PAUSE_TIME);
            obj.scanPauseTimeSpinner = uispinner(grid, 'Value', scanPauseTime, ...
                'Limits', [0.05 5], 'Step', 0.05, 'ValueChangedFcn', @(src,~) obj.updateParameter('scanPauseTime', src.Value));
            
            % Range Low
            uilabel(grid, 'Text', 'Range Low (µm):', 'HorizontalAlignment', 'right');
            rangeLow = obj.getValidValue('rangeLow', obj.controller.DEFAULT_RANGE_LOW);
            obj.rangeLowSpinner = uispinner(grid, 'Value', rangeLow, ...
                'Limits', [-1000 0], 'ValueChangedFcn', @(src,~) obj.updateParameter('rangeLow', src.Value));
            
            % Range High
            uilabel(grid, 'Text', 'Range High (µm):', 'HorizontalAlignment', 'right');
            rangeHigh = obj.getValidValue('rangeHigh', obj.controller.DEFAULT_RANGE_HIGH);
            obj.rangeHighSpinner = uispinner(grid, 'Value', rangeHigh, ...
                'Limits', [0 1000], 'ValueChangedFcn', @(src,~) obj.updateParameter('rangeHigh', src.Value));
            
            % Smoothing Window
            uilabel(grid, 'Text', 'Smoothing Window:', 'HorizontalAlignment', 'right');
            smoothingWindow = obj.getValidValue('smoothingWindow', obj.controller.DEFAULT_SMOOTHING_WINDOW);
            obj.smoothingWindowSpinner = uispinner(grid, 'Value', smoothingWindow, ...
                'Limits', [0 10], 'Step', 1, 'ValueChangedFcn', @(src,~) obj.updateParameter('smoothingWindow', src.Value));
            
            % Auto Update Frequency
            uilabel(grid, 'Text', 'Auto Update (Hz):', 'HorizontalAlignment', 'right');
            autoUpdateFreq = obj.getValidValue('autoUpdateFrequency', obj.controller.DEFAULT_AUTO_UPDATE_FREQUENCY);
            obj.autoUpdateFreqSpinner = uispinner(grid, 'Value', autoUpdateFreq, ...
                'Limits', [0.1 10], 'Step', 0.1, 'ValueChangedFcn', @(src,~) obj.updateParameter('autoUpdateFrequency', src.Value));
        end
        
        function value = getValidValue(obj, propName, defaultVal)
            % Helper function to get valid value or default
            if isprop(obj.controller, propName) && ~isempty(obj.controller.(propName))
                value = obj.controller.(propName);
            else
                value = defaultVal;
            end
        end

        function createStatusBar(obj, parent)
            obj.hStatusBar = uipanel(parent, 'BackgroundColor', [0.9, 0.9, 0.95], 'BorderType', 'none');
            statusGrid = uigridlayout(obj.hStatusBar, [1,1]);
            statusGrid.Padding = [5 0 5 0];
            obj.hStatusText = uilabel(statusGrid, 'Text', '');
        end
        
        function handleKeyPress(obj, evt)
            if strcmp(evt.Key, 'uparrow'), obj.controller.moveZUp(); end
            if strcmp(evt.Key, 'downarrow'), obj.controller.moveZDown(); end
        end
        
        function updateStepSize(obj, value)
            obj.controller.stepSize = value;
            obj.updateStatus(sprintf('Step size set to %.2f µm', value), 'success');
        end
        
        function updateParameter(obj, paramName, value)
            obj.controller.updateParameters(struct(paramName, value));
        end
        
        function startSIFocus(obj)
            try
                if obj.controller.simulationMode
                    obj.updateStatus('Focus mode activated (simulation)', 'info');
                else
                    obj.controller.hSI.startFocus();
                    obj.updateStatus('Focus mode activated', 'success');
                end
            catch e
                obj.updateStatus(['Error starting focus mode: ' e.message], 'error');
            end
        end
        
        function grabSIFrame(obj)
            try
                if obj.controller.simulationMode
                    obj.updateStatus('Frame grabbed (simulation)', 'info');
                else
                    obj.controller.hSI.startGrab();
                    obj.updateStatus('Frame grabbed successfully', 'success');
                end
            catch e
                obj.updateStatus(['Error grabbing frame: ' e.message], 'error');
            end
        end
    end
end
