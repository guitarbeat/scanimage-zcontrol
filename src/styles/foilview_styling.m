classdef foilview_styling < handle
    % foilview_styling - Modern, accessible styling system for the foilview application
    
    properties (Constant, Access = public)
        %% Modern Color Palette (WCAG AA compliant)
        % Primary colors
        PRIMARY_50 = [0.95 0.97 1.0]
        PRIMARY_100 = [0.87 0.93 0.98]
        PRIMARY_200 = [0.73 0.85 0.95]
        PRIMARY_300 = [0.53 0.73 0.9]
        PRIMARY_400 = [0.33 0.6 0.85]
        PRIMARY_500 = [0.13 0.47 0.8]
        PRIMARY_600 = [0.11 0.4 0.73]
        PRIMARY_700 = [0.09 0.33 0.67]
        PRIMARY_800 = [0.07 0.27 0.6]
        PRIMARY_900 = [0.05 0.2 0.53]
        
        % Success colors
        SUCCESS_50 = [0.95 0.98 0.95]
        SUCCESS_100 = [0.87 0.95 0.87]
        SUCCESS_200 = [0.73 0.9 0.73]
        SUCCESS_300 = [0.53 0.8 0.53]
        SUCCESS_400 = [0.33 0.73 0.33]
        SUCCESS_500 = [0.13 0.67 0.13]
        SUCCESS_600 = [0.11 0.6 0.11]
        SUCCESS_700 = [0.09 0.53 0.09]
        SUCCESS_800 = [0.07 0.47 0.07]
        SUCCESS_900 = [0.05 0.4 0.05]
        
        % Warning colors
        WARNING_50 = [1.0 0.98 0.95]
        WARNING_100 = [0.98 0.95 0.87]
        WARNING_200 = [0.95 0.9 0.73]
        WARNING_300 = [0.9 0.8 0.53]
        WARNING_400 = [0.85 0.73 0.33]
        WARNING_500 = [0.8 0.67 0.13]
        WARNING_600 = [0.73 0.6 0.11]
        WARNING_700 = [0.67 0.53 0.09]
        WARNING_800 = [0.6 0.47 0.07]
        WARNING_900 = [0.53 0.4 0.05]
        
        % Danger colors
        DANGER_50 = [1.0 0.95 0.95]
        DANGER_100 = [0.98 0.87 0.87]
        DANGER_200 = [0.95 0.73 0.73]
        DANGER_300 = [0.9 0.53 0.53]
        DANGER_400 = [0.85 0.33 0.33]
        DANGER_500 = [0.8 0.13 0.13]
        DANGER_600 = [0.73 0.11 0.11]
        DANGER_700 = [0.67 0.09 0.09]
        DANGER_800 = [0.6 0.07 0.07]
        DANGER_900 = [0.53 0.05 0.05]
        
        % Neutral colors
        NEUTRAL_50 = [0.98 0.98 0.98]
        NEUTRAL_100 = [0.95 0.95 0.95]
        NEUTRAL_200 = [0.9 0.9 0.9]
        NEUTRAL_300 = [0.8 0.8 0.8]
        NEUTRAL_400 = [0.6 0.6 0.6]
        NEUTRAL_500 = [0.4 0.4 0.4]
        NEUTRAL_600 = [0.33 0.33 0.33]
        NEUTRAL_700 = [0.27 0.27 0.27]
        NEUTRAL_800 = [0.2 0.2 0.2]
        NEUTRAL_900 = [0.13 0.13 0.13]
        
        %% Typography Scale
        FONT_SIZE_XS = 8
        FONT_SIZE_SM = 9
        FONT_SIZE_BASE = 10
        FONT_SIZE_LG = 11
        FONT_SIZE_XL = 12
        FONT_SIZE_2XL = 14
        FONT_SIZE_3XL = 16
        FONT_SIZE_4XL = 20
        FONT_SIZE_5XL = 24
        
        % Font weights
        FONT_WEIGHT_LIGHT = 'light'
        FONT_WEIGHT_NORMAL = 'normal'
        FONT_WEIGHT_MEDIUM = 'demi'
        FONT_WEIGHT_SEMIBOLD = 'demi'
        FONT_WEIGHT_BOLD = 'bold'
        
        % Font families
        FONT_FAMILY_SANS = 'Arial'
        FONT_FAMILY_MONO = 'Consolas'
        FONT_FAMILY_SERIF = 'Times New Roman'
        
        %% Spacing Scale
        SPACE_0 = 0
        SPACE_1 = 4
        SPACE_2 = 8
        SPACE_3 = 12
        SPACE_4 = 16
        SPACE_5 = 20
        SPACE_6 = 24
        SPACE_8 = 32
        SPACE_10 = 40
        SPACE_12 = 48
        SPACE_16 = 64
        SPACE_20 = 80
        SPACE_24 = 96
        
        %% Border Radius
        BORDER_RADIUS_NONE = 0
        BORDER_RADIUS_SM = 2
        BORDER_RADIUS_BASE = 4
        BORDER_RADIUS_MD = 6
        BORDER_RADIUS_LG = 8
        BORDER_RADIUS_XL = 12
        BORDER_RADIUS_2XL = 16
        BORDER_RADIUS_FULL = 999
        
        %% Plot styling
        MARKER_SIZE_BASE = 4
    end
    
    methods (Static)
        function colors = getColors()
            % Get the complete modern color palette
            colors = struct(...
                'Primary50', foilview_styling.PRIMARY_50, ...
                'Primary100', foilview_styling.PRIMARY_100, ...
                'Primary200', foilview_styling.PRIMARY_200, ...
                'Primary300', foilview_styling.PRIMARY_300, ...
                'Primary400', foilview_styling.PRIMARY_400, ...
                'Primary500', foilview_styling.PRIMARY_500, ...
                'Primary600', foilview_styling.PRIMARY_600, ...
                'Primary700', foilview_styling.PRIMARY_700, ...
                'Primary800', foilview_styling.PRIMARY_800, ...
                'Primary900', foilview_styling.PRIMARY_900, ...
                'Success50', foilview_styling.SUCCESS_50, ...
                'Success100', foilview_styling.SUCCESS_100, ...
                'Success200', foilview_styling.SUCCESS_200, ...
                'Success300', foilview_styling.SUCCESS_300, ...
                'Success400', foilview_styling.SUCCESS_400, ...
                'Success500', foilview_styling.SUCCESS_500, ...
                'Success600', foilview_styling.SUCCESS_600, ...
                'Success700', foilview_styling.SUCCESS_700, ...
                'Success800', foilview_styling.SUCCESS_800, ...
                'Success900', foilview_styling.SUCCESS_900, ...
                'Warning50', foilview_styling.WARNING_50, ...
                'Warning100', foilview_styling.WARNING_100, ...
                'Warning200', foilview_styling.WARNING_200, ...
                'Warning300', foilview_styling.WARNING_300, ...
                'Warning400', foilview_styling.WARNING_400, ...
                'Warning500', foilview_styling.WARNING_500, ...
                'Warning600', foilview_styling.WARNING_600, ...
                'Warning700', foilview_styling.WARNING_700, ...
                'Warning800', foilview_styling.WARNING_800, ...
                'Warning900', foilview_styling.WARNING_900, ...
                'Danger50', foilview_styling.DANGER_50, ...
                'Danger100', foilview_styling.DANGER_100, ...
                'Danger200', foilview_styling.DANGER_200, ...
                'Danger300', foilview_styling.DANGER_300, ...
                'Danger400', foilview_styling.DANGER_400, ...
                'Danger500', foilview_styling.DANGER_500, ...
                'Danger600', foilview_styling.DANGER_600, ...
                'Danger700', foilview_styling.DANGER_700, ...
                'Danger800', foilview_styling.DANGER_800, ...
                'Danger900', foilview_styling.DANGER_900, ...
                'Neutral50', foilview_styling.NEUTRAL_50, ...
                'Neutral100', foilview_styling.NEUTRAL_100, ...
                'Neutral200', foilview_styling.NEUTRAL_200, ...
                'Neutral300', foilview_styling.NEUTRAL_300, ...
                'Neutral400', foilview_styling.NEUTRAL_400, ...
                'Neutral500', foilview_styling.NEUTRAL_500, ...
                'Neutral600', foilview_styling.NEUTRAL_600, ...
                'Neutral700', foilview_styling.NEUTRAL_700, ...
                'Neutral800', foilview_styling.NEUTRAL_800, ...
                'Neutral900', foilview_styling.NEUTRAL_900, ...
                'Background', foilview_styling.NEUTRAL_50, ...
                'Primary', foilview_styling.PRIMARY_500, ...
                'Success', foilview_styling.SUCCESS_500, ...
                'Warning', foilview_styling.WARNING_500, ...
                'Danger', foilview_styling.DANGER_500, ...
                'Light', foilview_styling.NEUTRAL_50, ...
                'TextMuted', foilview_styling.NEUTRAL_500, ...
                'TextPrimary', foilview_styling.NEUTRAL_900, ...
                'TextSecondary', foilview_styling.NEUTRAL_700, ...
                'TextInverse', foilview_styling.NEUTRAL_50, ...
                'Active', foilview_styling.SUCCESS_500, ...
                'Inactive', foilview_styling.NEUTRAL_400, ...
                'Disabled', foilview_styling.NEUTRAL_300, ...
                'Border', foilview_styling.NEUTRAL_200, ...
                'BorderFocus', foilview_styling.PRIMARY_500, ...
                'BorderError', foilview_styling.DANGER_500);
        end
        
        function fonts = getFonts()
            % Get the complete typography system
            fonts = struct(...
                'SizeXS', foilview_styling.FONT_SIZE_XS, ...
                'SizeSM', foilview_styling.FONT_SIZE_SM, ...
                'SizeBase', foilview_styling.FONT_SIZE_BASE, ...
                'SizeLG', foilview_styling.FONT_SIZE_LG, ...
                'SizeXL', foilview_styling.FONT_SIZE_XL, ...
                'Size2XL', foilview_styling.FONT_SIZE_2XL, ...
                'Size3XL', foilview_styling.FONT_SIZE_3XL, ...
                'Size4XL', foilview_styling.FONT_SIZE_4XL, ...
                'Size5XL', foilview_styling.FONT_SIZE_5XL, ...
                'WeightLight', foilview_styling.FONT_WEIGHT_LIGHT, ...
                'WeightNormal', foilview_styling.FONT_WEIGHT_NORMAL, ...
                'WeightMedium', foilview_styling.FONT_WEIGHT_MEDIUM, ...
                'WeightSemibold', foilview_styling.FONT_WEIGHT_SEMIBOLD, ...
                'WeightBold', foilview_styling.FONT_WEIGHT_BOLD, ...
                'FamilySans', foilview_styling.FONT_FAMILY_SANS, ...
                'FamilyMono', foilview_styling.FONT_FAMILY_MONO, ...
                'FamilySerif', foilview_styling.FONT_FAMILY_SERIF);
        end
        
        function styleButton(button, variant, size, state)
            % Apply modern button styling with variants, sizes, and states
            
            if ~foilview_styling.validateComponent(button)
                return;
            end
            
            colors = foilview_styling.getColors();
            fonts = foilview_styling.getFonts();
            
            % Set defaults
            if nargin < 2 || isempty(variant), variant = 'primary'; end
            if nargin < 3 || isempty(size), size = 'base'; end
            if nargin < 4 || isempty(state), state = 'default'; end
            
            % Apply variant styling
            switch lower(variant)
                case 'primary'
                    button.BackgroundColor = colors.Primary500;
                    button.FontColor = colors.TextInverse;
                case 'secondary'
                    button.BackgroundColor = colors.Neutral100;
                    button.FontColor = colors.TextPrimary;
                case 'success'
                    button.BackgroundColor = colors.Success500;
                    button.FontColor = colors.TextInverse;
                case 'warning'
                    button.BackgroundColor = colors.Warning500;
                    button.FontColor = colors.TextInverse;
                case 'danger'
                    button.BackgroundColor = colors.Danger500;
                    button.FontColor = colors.TextInverse;
                case 'ghost'
                    button.BackgroundColor = [0 0 0 0];
                    button.FontColor = colors.TextPrimary;
                case 'outline'
                    button.BackgroundColor = colors.TextInverse;
                    button.FontColor = colors.TextPrimary;
                    button.BorderColor = colors.Border;
                    button.BorderWidth = 1;
                otherwise
                    button.BackgroundColor = colors.Primary500;
                    button.FontColor = colors.TextInverse;
            end
            
            % Apply size styling
            switch lower(size)
                case 'xs'
                    button.FontSize = fonts.SizeXS;
                case 'sm'
                    button.FontSize = fonts.SizeSM;
                case 'base'
                    button.FontSize = fonts.SizeBase;
                case 'lg'
                    button.FontSize = fonts.SizeLG;
                case 'xl'
                    button.FontSize = fonts.SizeXL;
                otherwise
                    button.FontSize = fonts.SizeBase;
            end
        end
        
        function styleLabel(label, variant)
            % Apply label styling
            if ~foilview_styling.validateComponent(label)
                return;
            end
            
            colors = foilview_styling.getColors();
            
            switch lower(variant)
                case 'primary'
                    label.FontColor = colors.Primary500;
                case 'success'
                    label.FontColor = colors.Success500;
                case 'warning'
                    label.FontColor = colors.Warning500;
                case 'danger'
                    label.FontColor = colors.Danger500;
                case 'muted'
                    label.FontColor = colors.TextMuted;
                otherwise
                    label.FontColor = colors.TextPrimary;
            end
        end
        
        function styleWindowIndicator(button, isActive, defaultText, activeText, inactiveText)
            % Style window indicator button
            if ~foilview_styling.validateComponent(button)
                return;
            end
            
            colors = foilview_styling.getColors();
            
            if isActive
                button.BackgroundColor = colors.Success500;
                button.FontColor = colors.TextInverse;
                if nargin >= 4 && ~isempty(activeText)
                    button.Text = activeText;
                end
            else
                button.BackgroundColor = colors.Primary500;
                button.FontColor = colors.TextInverse;
                if nargin >= 5 && ~isempty(inactiveText)
                    button.Text = inactiveText;
                elseif nargin >= 3 && ~isempty(defaultText)
                    button.Text = defaultText;
                end
            end
        end
        
        function styleDirectionButton(button, direction, isRunning)
            % Style direction button
            if ~foilview_styling.validateComponent(button)
                return;
            end
            
            colors = foilview_styling.getColors();
            
            if direction > 0  % Up
                button.BackgroundColor = colors.Success500;
                button.FontColor = colors.TextInverse;
                button.Text = '▲ UP';
            else  % Down
                button.BackgroundColor = colors.Warning500;
                button.FontColor = colors.TextInverse;
                button.Text = '▼ DOWN';
            end
        end
        
        function isValid = validateComponent(component)
            % Validate that a component is a valid UI component
            isValid = ~isempty(component) && isvalid(component) && ...
                     (isa(component, 'matlab.ui.control.UIControl') || ...
                      isa(component, 'matlab.ui.container.Container') || ...
                      isa(component, 'matlab.ui.Figure') || ...
                      isprop(component, 'FontSize') || ...
                      isprop(component, 'BackgroundColor'));
        end
    end
end 