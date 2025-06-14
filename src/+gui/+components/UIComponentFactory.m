classdef UIComponentFactory < handle
    % UIComponentFactory - Modern factory class for creating UI components
    % Provides consistent styling and layout for FocusGUI application
    
    properties (Constant, Access = private)
        % Design system constants
        COLORS = struct(...
            'Primary', [0.2 0.4 0.8], ...
            'Secondary', [0.6 0.6 0.7], ...
            'Success', [0.2 0.7 0.3], ...
            'Warning', [0.9 0.6 0.1], ...
            'Danger', [0.8 0.2 0.2], ...
            'Background', [0.96 0.96 0.98], ...
            'Surface', [1 1 1], ...
            'Border', [0.8 0.8 0.8], ...
            'Text', [0.2 0.2 0.2], ...
            'TextLight', [0.5 0.5 0.5], ...
            'ActionButton', [0.85 0.95 0.95], ...
            'ScanButton', [0.7 0.85 1.0], ...
            'EmergencyButton', [1.0 0.7 0.7], ...
            'BestFocusButton', [1.0 0.85 0.85] ...
        );
        
        FONTS = struct(...
            'DefaultSize', 11, ...
            'SmallSize', 9, ...
            'LargeSize', 13, ...
            'TitleSize', 15 ...
        );
        
        SPACING = struct(...
            'Small', 5, ...
            'Medium', 8, ...
            'Large', 10, ...
            'XLarge', 15 ...
        );
    end
    
    methods (Static)
        %% Core UI Components
        function panel = createStyledPanel(parent, title, row, column, options)
            % Creates a styled panel with consistent appearance
            arguments
                parent
                title string
                row
                column
                options.BackgroundColor = gui.components.UIComponentFactory.COLORS.Background
                options.FontSize = gui.components.UIComponentFactory.FONTS.DefaultSize
            end
            
            panel = uipanel(parent, ...
                'Title', title, ...
                'FontWeight', 'bold', ...
                'FontSize', options.FontSize, ...
                'BackgroundColor', options.BackgroundColor);
            
            if ~isempty(row)
                panel.Layout.Row = row;
            end
            if ~isempty(column)
                panel.Layout.Column = column;
            end
        end
        
        function label = createStyledLabel(parent, text, row, column, options)
            % Creates a styled label with consistent appearance
            arguments
                parent
                text string
                row
                column
                options.Tooltip string = ""
                options.FontWeight string = "bold"
                options.FontSize = gui.components.UIComponentFactory.FONTS.DefaultSize
                options.FontColor = gui.components.UIComponentFactory.COLORS.Text
                options.HorizontalAlignment string = "left"
                options.VerticalAlignment string = "center"
            end
            
            label = uilabel(parent, ...
                'Text', text, ...
                'FontWeight', options.FontWeight, ...
                'FontSize', options.FontSize, ...
                'FontColor', options.FontColor, ...
                'HorizontalAlignment', options.HorizontalAlignment, ...
                'VerticalAlignment', options.VerticalAlignment);
            
            if options.Tooltip ~= ""
                label.Tooltip = options.Tooltip;
            end
            
            if ~isempty(row)
                label.Layout.Row = row;
            end
            if ~isempty(column)
                label.Layout.Column = column;
            end
        end
        
        function edit = createStyledEditField(parent, row, column, options)
            % Creates a styled numeric edit field
            arguments
                parent
                row
                column
                options.Value = 0
                options.Format string = "%.1f"
                options.Tooltip string = ""
                options.FontSize = gui.components.UIComponentFactory.FONTS.DefaultSize
                options.BackgroundColor = gui.components.UIComponentFactory.COLORS.Surface
                options.Width = []
            end
            
            edit = uieditfield(parent, 'numeric', ...
                'Value', options.Value, ...
                'HorizontalAlignment', 'center', ...
                'FontSize', options.FontSize, ...
                'ValueDisplayFormat', options.Format, ...
                'AllowEmpty', 'on', ...
                'BackgroundColor', options.BackgroundColor);
            
            if options.Tooltip ~= ""
                edit.Tooltip = options.Tooltip;
            end
            
            if ~isempty(row)
                edit.Layout.Row = row;
            end
            if ~isempty(column)
                edit.Layout.Column = column;
            end
            
            if ~isempty(options.Width)
                edit.Layout.Width = options.Width;
            end
        end
        
        function btn = createStyledButton(parent, text, row, column, callback, options)
            % Creates a styled button with consistent appearance
            arguments
                parent
                text string
                row
                column
                callback = [] % Make callback optional with empty default
                options.Tooltip string = ""
                options.BackgroundColor = [0.9 0.9 0.95]
                options.FontSize = gui.components.UIComponentFactory.FONTS.DefaultSize
                options.Enable string = "on"
                options.Icon string = ""
                options.Width = []
                options.HorizontalAlignment string = "center"
            end
            
            if options.Icon ~= ""
                displayText = sprintf('%s %s', options.Icon, text);
            else
                displayText = text;
            end
            
            % Create button properties
            btnProps = {'Text', displayText, ...
                'FontSize', options.FontSize, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', options.BackgroundColor, ...
                'Enable', options.Enable, ...
                'HorizontalAlignment', options.HorizontalAlignment};
            
            % Add callback if provided
            if ~isempty(callback)
                btnProps = [btnProps, {'ButtonPushedFcn', callback}];
            end
            
            % Create the button
            btn = uibutton(parent, btnProps{:});
            
            if options.Tooltip ~= ""
                btn.Tooltip = options.Tooltip;
            end
            
            if ~isempty(row)
                btn.Layout.Row = row;
            end
            if ~isempty(column)
                btn.Layout.Column = column;
            end
            
            if ~isempty(options.Width)
                btn.Layout.Width = options.Width;
            end
        end
        
        function panel = createValueBox(parent, row, column, options)
            % Creates a styled value display box
            arguments
                parent
                row
                column
                options.BackgroundColor = gui.components.UIComponentFactory.COLORS.Surface
                options.BorderType string = "line"
            end
            
            panel = uipanel(parent, ...
                'BorderType', options.BorderType, ...
                'BackgroundColor', options.BackgroundColor);
            
            if ~isempty(row)
                panel.Layout.Row = row;
            end
            if ~isempty(column)
                panel.Layout.Column = column;
            end
        end
        
        %% Specialized Panels
        function createInstructionPanel(parent, grid)
            % Creates an informative instruction panel
            htmlContent = gui.components.UIComponentFactory.buildInstructionHTML();
            
            instructText = uilabel(grid, ...
                'Text', htmlContent, ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'top', ...
                'Interpreter', 'html');
            instructText.Layout.Row = 1;
            instructText.Layout.Column = 1;
        end
        
        function components = createScanParametersPanel(parent, paramPanel, controller)
            % Creates the scan parameters panel with all controls
            paramGrid = gui.components.UIComponentFactory.setupParameterGrid(paramPanel);
            
            % Create components
            components = struct();
            [components.stepSizeSlider, components.stepSizeValue] = ...
                gui.components.UIComponentFactory.createStepSizeControls(paramGrid, paramPanel, controller);
            
            gui.components.UIComponentFactory.createSeparator(paramGrid, paramPanel);
            
            components.pauseTimeEdit = gui.components.UIComponentFactory.createPauseTimeControl(paramGrid, controller);
            
            % Use RangeSlider for Z limits instead of separate controls
            components.zRangeSlider = gui.components.UIComponentFactory.createZRangeSlider(paramGrid, controller);
            
            % Keep minZEdit and maxZEdit properties for backward compatibility
            components.minZEdit = components.zRangeSlider.MinValueField;
            components.maxZEdit = components.zRangeSlider.MaxValueField;
        end
        
        function components = createManualFocusTab(parent, controller)
            % Creates a simplified manual focus tab with minimal controls
            
            % Create grid layout for the tab
            grid = uigridlayout(parent, [2, 1]);
            grid.RowHeight = {'fit', 'fit'};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 10;
            
            % Create Z position display
            currentZLabel = gui.components.UIComponentFactory.createStyledLabel(grid, 'Current Z: 0.00', 1, 1, ...
                'FontSize', 14, ...
                'HorizontalAlignment', 'center');
            
            % Create Z movement controls
            zControlGrid = uigridlayout(grid, [1, 2]);
            zControlGrid.Layout.Row = 2;
            zControlGrid.Layout.Column = 1;
            zControlGrid.ColumnWidth = {'1x', '1x'};
            zControlGrid.Padding = [0 0 0 0];
            
            % Z Up button with callback
            zUpButton = gui.components.UIComponentFactory.createStyledButton(zControlGrid, 'Z Up ↑', [], 1, ...
                @(~,~) controller.moveZUp(), ...
                'BackgroundColor', [0.8 0.9 1.0], ...
                'FontSize', 14);
            
            % Z Down button with callback
            zDownButton = gui.components.UIComponentFactory.createStyledButton(zControlGrid, 'Z Down ↓', [], 2, ...
                @(~,~) controller.moveZDown(), ...
                'BackgroundColor', [0.8 0.9 1.0], ...
                'FontSize', 14);
            
            % Return components
            components = struct(...
                'CurrentZLabel', currentZLabel, ...
                'ZUpButton', zUpButton, ...
                'ZDownButton', zDownButton);
        end
        
        function components = createAutoFocusTab(parent, controller)
            % Creates the auto focus tab with scan controls
            grid = uigridlayout(parent, [4, 2]);
            grid.RowHeight = {'fit', 'fit', 'fit', '1x'};
            grid.ColumnWidth = {'1x', '1x'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 8;
            grid.ColumnSpacing = 10;
            
            % Create step size controls
            stepSizeLabel = uilabel(grid, ...
                'Text', 'Step Size:', ...
                'Tooltip', 'Z movement step size', ...
                'FontWeight', 'bold');
            stepSizeLabel.Layout.Row = 1;
            stepSizeLabel.Layout.Column = 1;
            
            stepSizeSlider = uislider(grid, ...
                'Limits', [1 100], ...
                'Value', 10, ...
                'MajorTicks', [1 25 50 75 100], ...
                'MajorTickLabels', {'1', '25', '50', '75', '100'});
            stepSizeSlider.Layout.Row = 1;
            stepSizeSlider.Layout.Column = 2;
            
            stepSizeValue = uilabel(grid, ...
                'Text', '10.0', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 11);
            stepSizeValue.Layout.Row = 2;
            stepSizeValue.Layout.Column = 2;
            
            % Create pause time control
            pauseTimeLabel = uilabel(grid, ...
                'Text', 'Pause Time (s):', ...
                'Tooltip', 'Time to pause between Z steps', ...
                'FontWeight', 'bold');
            pauseTimeLabel.Layout.Row = 3;
            pauseTimeLabel.Layout.Column = 1;
            
            pauseTimeEdit = uieditfield(grid, 'numeric', ...
                'Value', 0.2, ...
                'ValueDisplayFormat', '%.2f', ...
                'Tooltip', 'Time to pause between Z steps');
            pauseTimeEdit.Layout.Row = 3;
            pauseTimeEdit.Layout.Column = 2;
            
            % Create Z range controls
            minZLabel = uilabel(grid, ...
                'Text', 'Min Z:', ...
                'Tooltip', 'Minimum Z position', ...
                'FontWeight', 'bold');
            minZLabel.Layout.Row = 4;
            minZLabel.Layout.Column = 1;
            
            minZEdit = uieditfield(grid, 'numeric', ...
                'Value', 0, ...
                'ValueDisplayFormat', '%.1f', ...
                'Tooltip', 'Minimum Z position');
            minZEdit.Layout.Row = 4;
            minZEdit.Layout.Column = 2;
            
            maxZLabel = uilabel(grid, ...
                'Text', 'Max Z:', ...
                'Tooltip', 'Maximum Z position', ...
                'FontWeight', 'bold');
            maxZLabel.Layout.Row = 5;
            maxZLabel.Layout.Column = 1;
            
            maxZEdit = uieditfield(grid, 'numeric', ...
                'Value', 100, ...
                'ValueDisplayFormat', '%.1f', ...
                'Tooltip', 'Maximum Z position');
            maxZEdit.Layout.Row = 5;
            maxZEdit.Layout.Column = 2;
            
            % Create scan controls
            zScanToggle = uibutton(grid, ...
                'Text', 'Start Z-Scan', ...
                'ButtonPushedFcn', @(~,~) controller.toggleZScan(), ...
                'Tooltip', 'Start automatic Z scan', ...
                'BackgroundColor', [0.7 0.85 1.0]);
            zScanToggle.Layout.Row = 6;
            zScanToggle.Layout.Column = 1;
            
            moveToBestButton = uibutton(grid, ...
                'Text', 'Move to Best', ...
                'ButtonPushedFcn', @(~,~) controller.moveToBestZ(), ...
                'Tooltip', 'Move to best Z position', ...
                'BackgroundColor', [1.0 0.85 0.85]);
            moveToBestButton.Layout.Row = 6;
            moveToBestButton.Layout.Column = 2;
            
            % Return components
            components = struct(...
                'StepSizeSlider', stepSizeSlider, ...
                'StepSizeValue', stepSizeValue, ...
                'PauseTimeEdit', pauseTimeEdit, ...
                'MinZEdit', minZEdit, ...
                'MaxZEdit', maxZEdit, ...
                'ZScanToggle', zScanToggle, ...
                'MoveToBestButton', moveToBestButton);
        end
        
        function components = createScanImageControlPanel(parent, row, column, controller)
            % Creates a simplified ScanImage control panel with minimal controls
            
            % Create grid layout for the controls
            grid = uigridlayout(parent, [1, 3]);
            grid.ColumnWidth = {'1x', '1x', '1x'};
            grid.Padding = [10 10 10 10];
            grid.ColumnSpacing = 10;
            
            if ~isempty(row)
                grid.Layout.Row = row;
            end
            if ~isempty(column)
                grid.Layout.Column = column;
            end
            
            % Focus button with callback
            focusButton = gui.components.UIComponentFactory.createStyledButton(grid, 'Focus', [], 1, ...
                @(~,~) controller.startSIFocus(), ...
                'BackgroundColor', [0.7 0.85 1.0], ...
                'FontSize', 12);
            
            % Grab button with callback
            grabButton = gui.components.UIComponentFactory.createStyledButton(grid, 'Grab', [], 2, ...
                @(~,~) controller.grabSIFrame(), ...
                'BackgroundColor', [0.7 0.85 1.0], ...
                'FontSize', 12);
            
            % Abort button with callback
            abortButton = gui.components.UIComponentFactory.createStyledButton(grid, 'Abort', [], 3, ...
                @(~,~) controller.abortAllOperations(), ...
                'BackgroundColor', [1.0 0.7 0.7], ...
                'FontSize', 12);
            
            % Return components
            components = struct(...
                'FocusButton', focusButton, ...
                'GrabButton', grabButton, ...
                'AbortButton', abortButton);
        end
        
        function [panel, ax, toggleButton, plotPanel] = createCollapsiblePlotPanel(parent, row, column)
            % Placeholder for the removed plot panel
            panel = [];
            ax = [];
            toggleButton = [];
            plotPanel = [];
        end
        
        %% Helper Methods
        function grid = setupParameterGrid(panel)
            % Sets up a grid layout for parameters
            grid = uigridlayout(panel, [4, 2]);
            grid.RowHeight = {'fit', 'fit', 'fit', '1x'};
            grid.ColumnWidth = {'1x', '1x'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 8;
            grid.ColumnSpacing = 10;
        end
        
        function [slider, value] = createStepSizeControls(grid, parent, controller)
            % Creates step size slider and value display
            label = gui.components.UIComponentFactory.createStyledLabel(grid, ...
                'Step Size:', 1, 1, ...
                'Tooltip', 'Z movement step size');
            
            slider = uislider(grid, ...
                'Limits', [1 100], ...
                'Value', 10, ...
                'MajorTicks', [1 25 50 75 100], ...
                'MajorTickLabels', {'1', '25', '50', '75', '100'});
            slider.Layout.Row = 1;
            slider.Layout.Column = 2;
            
            value = gui.components.UIComponentFactory.createStyledLabel(grid, ...
                '10.0', 2, 2, ...
                'FontSize', gui.components.UIComponentFactory.FONTS.SmallSize, ...
                'HorizontalAlignment', 'center');
        end
        
        function edit = createPauseTimeControl(grid, controller)
            % Creates pause time edit field
            label = gui.components.UIComponentFactory.createStyledLabel(grid, ...
                'Pause Time (s):', 3, 1, ...
                'Tooltip', 'Time to pause between Z steps');
            
            edit = gui.components.UIComponentFactory.createStyledEditField(grid, ...
                3, 2, ...
                'Value', 0.2, ...
                'Format', '%.2f', ...
                'Tooltip', 'Time to pause between Z steps');
        end
        
        function [minEdit, maxEdit] = createZRangeControls(grid, controller)
            % Creates Z range edit fields
            minLabel = gui.components.UIComponentFactory.createStyledLabel(grid, ...
                'Min Z:', 4, 1, ...
                'Tooltip', 'Minimum Z position');
            
            minEdit = gui.components.UIComponentFactory.createStyledEditField(grid, ...
                4, 2, ...
                'Value', 0, ...
                'Format', '%.1f', ...
                'Tooltip', 'Minimum Z position');
            
            maxLabel = gui.components.UIComponentFactory.createStyledLabel(grid, ...
                'Max Z:', 5, 1, ...
                'Tooltip', 'Maximum Z position');
            
            maxEdit = gui.components.UIComponentFactory.createStyledEditField(grid, ...
                5, 2, ...
                'Value', 100, ...
                'Format', '%.1f', ...
                'Tooltip', 'Maximum Z position');
        end
        
        function createSeparator(grid, parent)
            % Creates a visual separator
            separator = uilabel(grid, ...
                'Text', '────────────', ...
                'HorizontalAlignment', 'center', ...
                'FontColor', gui.components.UIComponentFactory.COLORS.TextLight);
            separator.Layout.Row = 2;
            separator.Layout.Column = [1 2];
        end
        
        function htmlContent = buildInstructionHTML()
            % Builds HTML content for instruction panel
            htmlContent = sprintf([
                '<html><body style="font-family: Arial; font-size: 11px;">' ...
                '<b>FocalSweep Z-Control</b><br><br>' ...
                '<b>Manual Focus:</b><br>' ...
                '- Use Z Up/Down buttons to move stage<br>' ...
                '- Step size controls movement distance<br><br>' ...
                '<b>Auto Focus:</b><br>' ...
                '- Set Z range using min/max fields<br>' ...
                '- Adjust step size and pause time<br>' ...
                '- Use Z-scan to automatically find focus<br><br>' ...
                '<b>ScanImage Controls:</b><br>' ...
                '- Focus: Toggle ScanImage focus mode<br>' ...
                '- Grab: Capture single frame<br>' ...
                '- Abort: Stop all operations<br><br>' ...
                '<b>Plot Panel:</b><br>' ...
                '- Shows Z position history<br>' ...
                '- Toggle visibility with arrow button' ...
                '</body></html>']);
        end
        
        function [panel, container] = createModeTabGroup(parent, row, column)
            % Creates a simple panel instead of a tab group
            panel = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', [0.95 0.95 0.98]);
            
            if ~isempty(row)
                panel.Layout.Row = row;
            end
            if ~isempty(column)
                panel.Layout.Column = column;
            end
            
            % Container is the same as panel in this simplified version
            container = panel;
        end
    end
end