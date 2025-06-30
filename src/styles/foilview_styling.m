classdef foilview_styling < handle
    % foilview_styling - Centralized styling system for the foilview application
    %
    % This class provides a unified interface for all styling operations including:
    %   - Color definitions and themes
    %   - Font sizes and weights
    %   - Component styling methods
    %   - Semantic styling (success, warning, danger, etc.)
    %   - Responsive design utilities
    %   - Theme consistency across the application
    %
    % Usage:
    %   foilview_styling.styleButton(button, 'success');
    %   colors = foilview_styling.getColors();
    %   foilview_styling.styleWindowActiveIndicator(button, true);
    
    properties (Constant, Access = public)
        % Basic color definitions
        BACKGROUND_COLOR = [0.95 0.95 0.95]
        PRIMARY_COLOR = [0.2 0.6 0.9]
        SUCCESS_COLOR = [0.2 0.7 0.3]
        WARNING_COLOR = [0.9 0.6 0.2]
        DANGER_COLOR = [0.9 0.3 0.3]
        LIGHT_COLOR = [0.98 0.98 0.98]
        TEXT_MUTED_COLOR = [0.5 0.5 0.5]
        TEXT_PRIMARY_COLOR = [0.1 0.1 0.1]
        TEXT_INVERSE_COLOR = [1 1 1]
        
        % Font sizes
        FONT_SIZE_SMALL = 9
        FONT_SIZE_MEDIUM = 10
        FONT_SIZE_LARGE = 11
    end
    
    methods (Static)
        %% Core Styling Methods
        function colors = getColors()
            % Get the complete color palette
            colors = struct(...
                'Background', foilview_styling.BACKGROUND_COLOR, ...
                'Primary', foilview_styling.PRIMARY_COLOR, ...
                'Success', foilview_styling.SUCCESS_COLOR, ...
                'Warning', foilview_styling.WARNING_COLOR, ...
                'Danger', foilview_styling.DANGER_COLOR, ...
                'Light', foilview_styling.LIGHT_COLOR, ...
                'TextMuted', foilview_styling.TEXT_MUTED_COLOR, ...
                'TextPrimary', foilview_styling.TEXT_PRIMARY_COLOR, ...
                'TextInverse', foilview_styling.TEXT_INVERSE_COLOR, ...
                'Active', foilview_styling.SUCCESS_COLOR);
        end
        
        function fonts = getFonts()
            % Get the complete typography system
            fonts = struct(...
                'SizeS', foilview_styling.FONT_SIZE_SMALL, ...
                'SizeM', foilview_styling.FONT_SIZE_MEDIUM, ...
                'SizeL', foilview_styling.FONT_SIZE_LARGE, ...
                'WeightNormal', 'normal', ...
                'WeightBold', 'bold');
        end
        
        %% Button Styling Methods
        function styleButton(button, style, customText)
            % Apply semantic styling to a button
            % Usage: foilview_styling.styleButton(button, 'Success', 'SAVE')
            
            if ~foilview_styling.validateComponent(button)
                return;
            end
            
            colors = foilview_styling.getColors();
            fonts = foilview_styling.getFonts();
            
            % Apply style based on semantic name
            switch style
                case 'Primary'
                    button.BackgroundColor = colors.Primary;
                    button.FontColor = colors.TextInverse;
                case 'Success'
                    button.BackgroundColor = colors.Success;
                    button.FontColor = colors.TextInverse;
                case 'Warning'
                    button.BackgroundColor = colors.Warning;
                    button.FontColor = colors.TextInverse;
                case 'Danger'
                    button.BackgroundColor = colors.Danger;
                    button.FontColor = colors.TextInverse;
                case 'Light'
                    button.BackgroundColor = colors.Light;
                    button.FontColor = colors.TextPrimary;
                case 'Active'
                    button.BackgroundColor = colors.Active;
                    button.FontColor = colors.TextInverse;
                otherwise
                    button.BackgroundColor = colors.Primary;
                    button.FontColor = colors.TextInverse;
            end
            
            button.FontSize = fonts.SizeM;
            button.FontWeight = fonts.WeightBold;
            
            if nargin >= 3 && ~isempty(customText)
                button.Text = customText;
            end
        end
        
        function styleWindowIndicatorButton(button, isActive, iconText, activeText, inactiveText)
            % Style window indicator buttons (bookmarks, stage view)
            % Usage: foilview_styling.styleWindowIndicatorButton(button, true, '📌', '📌●', '📌')
            
            if ~foilview_styling.validateComponent(button)
                return;
            end
            
            if isActive
                button.Text = activeText;
                button.BackgroundColor = foilview_styling.SUCCESS_COLOR;
                button.FontColor = foilview_styling.TEXT_INVERSE_COLOR;
            else
                button.Text = inactiveText;
                button.BackgroundColor = foilview_styling.LIGHT_COLOR;
                button.FontColor = foilview_styling.TEXT_PRIMARY_COLOR;
            end
            
            button.FontSize = foilview_styling.FONT_SIZE_LARGE;
            button.FontWeight = 'bold';
        end
        
        function styleDirectionButton(button, direction, isRunning)
            % Style direction buttons with appropriate colors and arrows
            % direction: 1 for up, -1 for down
            
            if ~foilview_styling.validateComponent(button)
                return;
            end
            
            colors = foilview_styling.getColors();
            
            if direction > 0
                button.Text = '▲';
                baseColor = colors.Success;
            else
                button.Text = '▼';
                baseColor = colors.Warning;
            end
            
            if isRunning
                button.BackgroundColor = colors.Danger;
            else
                button.BackgroundColor = baseColor;
            end
            
            button.FontColor = colors.TextInverse;
            foilview_styling.applyFontStyle(button, 'SizeM', 'WeightBold');
        end
        
        %% Text and Label Styling
        function styleLabel(label, style, fontSize)
            % Style labels with semantic meaning
            % Styles: 'primary', 'secondary', 'muted', 'success', 'warning', 'danger'
            
            if ~foilview_styling.validateComponent(label)
                return;
            end
            
            colors = foilview_styling.getColors();
            fonts = foilview_styling.getFonts();
            
            switch lower(style)
                case 'primary'
                    label.FontColor = colors.TextPrimary;
                case 'secondary'
                    label.FontColor = colors.TextSecondary;
                case 'muted'
                    label.FontColor = colors.TextMuted;
                case 'success'
                    label.FontColor = colors.Success;
                case 'warning'
                    label.FontColor = colors.Warning;
                case 'danger'
                    label.FontColor = colors.Danger;
                case 'inverse'
                    label.FontColor = colors.TextInverse;
                otherwise
                    label.FontColor = colors.TextPrimary;
            end
            
            if nargin >= 3 && ~isempty(fontSize)
                if ischar(fontSize) && isfield(fonts, ['Size' fontSize])
                    label.FontSize = fonts.(['Size' fontSize]);
                elseif isnumeric(fontSize)
                    label.FontSize = fontSize;
                end
            end
        end
        
        function stylePositionDisplay(label, position)
            % Style the main position display with responsive font sizing
            
            if ~foilview_styling.validateComponent(label)
                return;
            end
            
            colors = foilview_styling.getColors();
            fonts = foilview_styling.getFonts();
            
            label.FontSize = fonts.SizeDisplay;
            label.FontWeight = fonts.WeightBold;
            label.FontName = fonts.Monospace;
            label.FontColor = colors.TextPrimary;
            label.BackgroundColor = colors.Light;
            label.HorizontalAlignment = 'center';
            
            % Format the position value
            if nargin >= 2
                label.Text = foilview_styling.formatPosition(position);
            end
        end
        
        %% Panel and Container Styling
        function stylePanel(panel, title, titleSize)
            % Style panels with consistent appearance
            
            if ~foilview_styling.validateComponent(panel)
                return;
            end
            
            colors = foilview_styling.getColors();
            fonts = foilview_styling.getFonts();
            
            panel.BackgroundColor = colors.Background;
            
            if nargin >= 2 && ~isempty(title)
                panel.Title = title;
                panel.FontWeight = fonts.WeightBold;
                if nargin >= 3
                    panel.FontSize = titleSize;
                else
                    panel.FontSize = fonts.SizeS;
                end
            end
        end
        
        function styleStatusBar(statusBar)
            % Style status bar components
            
            if ~foilview_styling.validateComponent(statusBar)
                return;
            end
            
            colors = foilview_styling.getColors();
            statusBar.BackgroundColor = colors.LightGray;
        end
        
        %% Input Field Styling
        function styleInputField(field, style)
            % Style input fields (edit fields, dropdowns)
            
            if ~foilview_styling.validateComponent(field)
                return;
            end
            
            colors = foilview_styling.getColors();
            fonts = foilview_styling.getFonts();
            
            field.FontSize = fonts.SizeM;
            field.BackgroundColor = colors.Light;
            
            switch lower(style)
                case 'error'
                    field.FontColor = colors.Danger;
                case 'success'
                    field.FontColor = colors.Success;
                case 'warning'
                    field.FontColor = colors.Warning;
                otherwise
                    field.FontColor = colors.TextPrimary;
            end
        end
        
        %% Utility Methods
        function applyFontStyle(component, size, weight)
            % Apply font styling to any component
            
            if ~foilview_styling.validateComponent(component)
                return;
            end
            
            fonts = foilview_styling.getFonts();
            
            if nargin >= 2 && ~isempty(size)
                if ischar(size) && isfield(fonts, size)
                    component.FontSize = fonts.(size);
                elseif isnumeric(size)
                    component.FontSize = size;
                end
            end
            
            if nargin >= 3 && ~isempty(weight)
                if ischar(weight) && isfield(fonts, weight)
                    component.FontWeight = fonts.(weight);
                end
            end
        end
        
        function str = formatPosition(position, precision)
            % Format position values consistently
            
            if nargin < 2
                if abs(position) < 0.1
                    precision = 2;
                else
                    precision = 1;
                end
            end
            
            formatStr = sprintf('%%.%df μm', precision);
            str = sprintf(formatStr, position);
        end
        
        function str = formatMetric(value)
            % Format metric values consistently
            
            if isnan(value)
                str = 'N/A';
            elseif value == 0
                str = '0.00';
            elseif abs(value) < 0.01
                str = sprintf('%.4f', value);
            elseif abs(value) < 1
                str = sprintf('%.3f', value);
            else
                str = sprintf('%.2f', value);
            end
        end
        
        function adjustFontSize(component, scaleFactor)
            % Adjust font size by a scale factor for responsive design
            
            if ~foilview_styling.validateComponent(component) || ~isnumeric(scaleFactor)
                return;
            end
            
            try
                currentSize = component.FontSize;
                newSize = max(8, round(currentSize * scaleFactor));  % Minimum 8pt
                component.FontSize = newSize;
            catch
                % Ignore errors for components that don't support font sizing
            end
        end
        
        function applyTheme(components, themeName)
            % Apply a complete theme to a set of components
            % Future extension point for multiple themes
            
            if ~isstruct(components)
                return;
            end
            
            % Currently only default theme, but extensible
            switch lower(themeName)
                case 'default'
                    foilview_styling.applyDefaultTheme(components);
                case 'dark'
                    % Future: dark theme implementation
                    warning('Dark theme not yet implemented');
                case 'high-contrast'
                    % Future: high contrast theme
                    warning('High contrast theme not yet implemented');
                otherwise
                    foilview_styling.applyDefaultTheme(components);
            end
        end
        
        %% Validation and Helpers
        function isValid = validateComponent(component)
            % Validate that a component is a valid UI component
            isValid = ~isempty(component) && isvalid(component) && ...
                     (isa(component, 'matlab.ui.control.UIControl') || ...
                      isa(component, 'matlab.ui.container.Container') || ...
                      isa(component, 'matlab.ui.Figure') || ...
                      isprop(component, 'FontSize') || ...
                      isprop(component, 'BackgroundColor'));
        end
        
        function status = getEnabledStatus(enabled)
            % Convert boolean to MATLAB Enable property value
            if enabled
                status = 'on';
            else
                status = 'off';
            end
        end
    end
    
    methods (Static, Access = private)
        function applyDefaultTheme(components)
            % Apply the default theme to all components
            % This is where we'd implement comprehensive theming
            
            colors = foilview_styling.getColors();
            
            % Apply background colors to containers
            fieldNames = fieldnames(components);
            for i = 1:length(fieldNames)
                component = components.(fieldNames{i});
                if isstruct(component)
                    foilview_styling.applyDefaultTheme(component);
                elseif foilview_styling.validateComponent(component)
                    try
                        if isprop(component, 'BackgroundColor')
                            component.BackgroundColor = colors.Background;
                        end
                    catch
                        % Ignore errors for read-only properties
                    end
                end
            end
        end
    end
end 