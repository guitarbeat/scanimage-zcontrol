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
                'Position', [100, 100, 320, 400], ...
                'Color', obj.UI_COLORS.Background, ...
                'CloseRequestFcn', @(~,~) obj.closeFigure(), ...
                'KeyPressFcn', @(~,evt) obj.handleKeyPress(evt));

            mainGrid = uigridlayout(obj.hFig, [3,1]);
            mainGrid.RowHeight = {'fit', 'fit', '1x'};
            mainGrid.Padding = [10, 10, 10, 10];

            obj.createZControls(mainGrid);
            obj.createSIControls(mainGrid);
            obj.createStatusBar();

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

            uibutton(grid, 'Text', 'Focus', 'ButtonPushedFcn', @(~,~) obj.controller.startSIFocus());
            uibutton(grid, 'Text', 'Grab', 'ButtonPushedFcn', @(~,~) obj.controller.grabSIFrame());
            uibutton(grid, 'Text', 'Abort', 'ButtonPushedFcn', @(~,~) obj.controller.abortAllOperations());
        end

        function createStatusBar(obj)
            obj.hStatusBar = uipanel(obj.hFig, 'Position', [0, 0, obj.hFig.Position(3), 25], ...
                'BackgroundColor', [0.9, 0.9, 0.95]);
            obj.hStatusText = uilabel(obj.hStatusBar, 'Position', [10, 5, obj.hFig.Position(3)-20, 15]);
            obj.hFig.SizeChangedFcn = @(~,~) obj.resizeStatusBar();
        end

        function resizeStatusBar(obj)
            obj.hStatusBar.Position(3) = obj.hFig.Position(3);
            obj.hStatusText.Position(3) = obj.hFig.Position(3) - 20;
        end

        function handleKeyPress(obj, evt)
            if strcmp(evt.Key, 'uparrow'), obj.controller.moveZUp(); end
            if strcmp(evt.Key, 'downarrow'), obj.controller.moveZDown(); end
        end
    end
end
