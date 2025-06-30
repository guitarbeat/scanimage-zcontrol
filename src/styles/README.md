# FoilView Modern Styling System

A comprehensive, design-system approach to UI styling for the FoilView application, built with modern design principles, accessibility in mind, and consistent visual hierarchy.

## 🎨 Design Philosophy

The FoilView styling system follows modern design principles inspired by leading design systems like GitHub's, Material Design, and Tailwind CSS:

- **Semantic Design**: Colors and styles have meaning beyond aesthetics
- **Accessibility First**: WCAG AA compliant color contrasts
- **Consistent Scale**: 8pt typography base with 4pt spacing grid
- **Component Variants**: Multiple styling options for different contexts
- **State Management**: Proper handling of hover, active, disabled states

## 🚀 Quick Start

### Modern Button Styling
```matlab
% Primary action button
foilview_styling.styleButton(button, 'primary', 'lg');

% Success button with custom state
foilview_styling.styleButton(button, 'success', 'base', 'loading');

% Secondary button
foilview_styling.styleButton(button, 'secondary', 'sm');

% Danger button
foilview_styling.styleButton(button, 'danger', 'base', 'disabled');
```

### Window Indicators
```matlab
% Modern window status indicators
foilview_styling.styleWindowIndicator(bookmarksButton, ...
    isActive, '📌', '📌●', '📌');
```

### Typography System
```matlab
% Semantic text styling
foilview_styling.styleLabel(label, 'primary', 'lg', 'semibold');
foilview_styling.styleLabel(label, 'success', 'base', 'medium');
foilview_styling.styleLabel(label, 'muted', 'sm', 'normal');
```

### Position Displays
```matlab
% Modern position display with size options
foilview_styling.stylePositionDisplay(label, position, '3xl');
```

## 🎯 Available Variants

### Button Variants
- `'primary'` - Main actions (blue)
- `'secondary'` - Secondary actions (gray)
- `'success'` - Positive actions (green)
- `'warning'` - Caution actions (orange)
- `'danger'` - Destructive actions (red)
- `'ghost'` - Transparent background
- `'outline'` - Bordered style

### Button Sizes
- `'xs'` - Extra small (8pt font)
- `'sm'` - Small (9pt font)
- `'base'` - Default (10pt font)
- `'lg'` - Large (11pt font)
- `'xl'` - Extra large (12pt font)

### Button States
- `'default'` - Normal state
- `'hover'` - Hover state (darker)
- `'active'` - Pressed state (darker)
- `'disabled'` - Disabled state
- `'loading'` - Loading state with spinner

### Text Variants
- `'primary'` - Main text (dark)
- `'secondary'` - Secondary text (medium gray)
- `'muted'` - Subdued text (light gray)
- `'success'` - Success message (green)
- `'warning'` - Warning message (orange)
- `'danger'` - Error message (red)
- `'inverse'` - Light text for dark backgrounds
- `'link'` - Link styling (blue, medium weight)

### Text Sizes
- `'xs'` - Extra small (8pt)
- `'sm'` - Small (9pt)
- `'base'` - Default (10pt)
- `'lg'` - Large (11pt)
- `'xl'` - Extra large (12pt)
- `'2xl'` - 2X large (14pt)
- `'3xl'` - 3X large (16pt)
- `'4xl'` - 4X large (20pt)
- `'5xl'` - 5X large (24pt)

### Text Weights
- `'light'` - Light weight
- `'normal'` - Normal weight
- `'medium'` - Medium weight
- `'semibold'` - Semi-bold weight
- `'bold'` - Bold weight

## 🎨 Color System

### Modern Color Palette
The system uses a comprehensive color palette with semantic meaning:

```matlab
colors = foilview_styling.getColors();

% Primary colors (blue scale)
colors.Primary50   % Lightest blue
colors.Primary500  % Main primary
colors.Primary900  % Darkest blue

% Success colors (green scale)
colors.Success50   % Lightest green
colors.Success500  % Main success
colors.Success900  % Darkest green

% Warning colors (orange scale)
colors.Warning50   % Lightest orange
colors.Warning500  % Main warning
colors.Warning900  % Darkest orange

% Danger colors (red scale)
colors.Danger50    % Lightest red
colors.Danger500   % Main danger
colors.Danger900   % Darkest red

% Neutral colors (gray scale)
colors.Neutral50   % Lightest gray
colors.Neutral500  % Medium gray
colors.Neutral900  % Darkest gray
```

### Semantic Color Aliases
For backward compatibility and semantic meaning:
- `colors.Background` - App background
- `colors.Primary` - Main brand color
- `colors.Success` - Success state
- `colors.Warning` - Warning state
- `colors.Danger` - Error state
- `colors.TextPrimary` - Main text
- `colors.TextSecondary` - Secondary text
- `colors.TextMuted` - Muted text
- `colors.Border` - Default borders
- `colors.BorderFocus` - Focus state borders
- `colors.BorderError` - Error state borders

## 📝 Typography System

### Font Sizes (8pt base scale)
```matlab
fonts = foilview_styling.getFonts();

fonts.SizeXS    % 8pt  - Captions, metadata
fonts.SizeSM    % 9pt  - Secondary text
fonts.SizeBase  % 10pt - Body text
fonts.SizeLG    % 11pt - Buttons, emphasis
fonts.SizeXL    % 12pt - Headers
fonts.Size2XL   % 14pt - Section headers
fonts.Size3XL   % 16pt - Page headers
fonts.Size4XL   % 20pt - Display text
fonts.Size5XL   % 24pt - Hero text
```

### Font Weights
- `fonts.WeightLight` - Light weight
- `fonts.WeightNormal` - Normal weight
- `fonts.WeightMedium` - Medium weight
- `fonts.WeightSemibold` - Semi-bold weight
- `fonts.WeightBold` - Bold weight

### Font Families
- `fonts.FamilySans` - Arial (UI text)
- `fonts.FamilyMono` - Consolas (code, numbers)
- `fonts.FamilySerif` - Times New Roman (formal text)

## 📏 Spacing System

### 4pt Grid System
```matlab
spacing = foilview_styling.getSpacing();

spacing.Space0   % 0px  - No spacing
spacing.Space1   % 4px  - Tight spacing
spacing.Space2   % 8px  - Small spacing
spacing.Space3   % 12px - Medium spacing
spacing.Space4   % 16px - Default spacing
spacing.Space5   % 20px - Large spacing
spacing.Space6   % 24px - Extra large spacing
spacing.Space8   % 32px - Section spacing
spacing.Space10  % 40px - Large section spacing
spacing.Space12  % 48px - Extra large section spacing
spacing.Space16  % 64px - Hero spacing
spacing.Space20  % 80px - Page spacing
spacing.Space24  % 96px - Maximum spacing
```

## 🎯 Component Styling

### Panel Variants
```matlab
% Default panel
foilview_styling.stylePanel(panel, 'default', 'Settings');

% Elevated panel (white background)
foilview_styling.stylePanel(panel, 'elevated', 'Settings', 'lg');

% Outlined panel (thicker border)
foilview_styling.stylePanel(panel, 'outlined', 'Settings');

% Filled panel (gray background)
foilview_styling.stylePanel(panel, 'filled', 'Settings');
```

### Input Field Styling
```matlab
% Default input field
foilview_styling.styleInputField(field, 'default', 'base');

% Filled input field
foilview_styling.styleInputField(field, 'filled', 'lg');

% Input field with error state
foilview_styling.styleInputField(field, 'default', 'base', 'error');

% Input field with focus state
foilview_styling.styleInputField(field, 'default', 'base', 'focus');
```

### Status Bar Variants
```matlab
% Default status bar
foilview_styling.styleStatusBar(statusBar, 'default');

% Subtle status bar
foilview_styling.styleStatusBar(statusBar, 'subtle');

% Prominent status bar
foilview_styling.styleStatusBar(statusBar, 'prominent');
```

## 🛠️ Utility Methods

### Font Styling
```matlab
% Apply comprehensive font styling
foilview_styling.applyFontStyle(component, 'SizeLG', 'WeightMedium', 'FamilySans');
```

### Responsive Design
```matlab
% Adjust font size with bounds checking
foilview_styling.adjustFontSize(component, 1.2, 8, 24);
```

### Formatting
```matlab
% Format position values with intelligent precision
positionText = foilview_styling.formatPosition(25.75);     % "25.8 μm"
positionText = foilview_styling.formatPosition(0.123, 3); % "0.123 μm"
positionText = foilview_styling.formatPosition(100, 0, 'mm'); % "100 mm"

% Format metric values with intelligent precision
metricText = foilview_styling.formatMetric(0.12345);      % "0.123"
metricText = foilview_styling.formatMetric(1234.5678);    % "1234.6"
metricText = foilview_styling.formatMetric(0.000123, 6);  % "0.000123"
```

### Color Utilities
```matlab
% Adjust color brightness
darkerColor = foilview_styling.adjustBrightness(color, -0.1);
lighterColor = foilview_styling.adjustBrightness(color, 0.1);
```

## 🔄 Migration Guide

### From Old to New System

**Before (legacy styling):**
```matlab
button.BackgroundColor = [0.2 0.7 0.3];
button.FontColor = [1 1 1];
button.FontSize = 10;
button.FontWeight = 'bold';
button.Text = 'SAVE';
```

**After (modern styling):**
```matlab
foilview_styling.styleButton(button, 'success', 'base');
```

**Before (legacy label styling):**
```matlab
label.FontColor = [0.5 0.5 0.5];
label.FontSize = 9;
label.FontWeight = 'normal';
```

**After (modern label styling):**
```matlab
foilview_styling.styleLabel(label, 'muted', 'sm', 'normal');
```

### Updating Existing Code

1. **Replace direct color assignments** with semantic styling methods
2. **Use variant-based styling** instead of manual property setting
3. **Leverage the spacing system** for consistent layouts
4. **Apply proper typography hierarchy** using the font scale
5. **Use state management** for interactive components

## 🎨 Design Best Practices

### 1. Semantic Design
- Use `'success'` for positive actions, not just green colors
- Use `'danger'` for destructive actions, not just red colors
- Use `'muted'` for secondary information, not just gray colors

### 2. Consistent Spacing
- Use the spacing scale: `spacing.Space2`, `spacing.Space4`, etc.
- Maintain consistent padding and margins
- Follow the 4pt grid system

### 3. Typography Hierarchy
- Use `'base'` for body text
- Use `'lg'` for buttons and emphasis
- Use `'xl'` or `'2xl'` for headers
- Use `'sm'` for secondary information

### 4. Accessibility
- The color palette is WCAG AA compliant
- Use semantic colors for meaning, not just aesthetics
- Maintain proper contrast ratios
- Use appropriate font sizes for readability

### 5. Component States
- Always handle `'disabled'` states
- Consider `'loading'` states for async operations
- Use `'hover'` and `'active'` states for interactivity

## 🔮 Future Enhancements

### Planned Features
- **Dark Mode Support**: Complete dark theme implementation
- **High Contrast Mode**: Accessibility-focused theme
- **Animation System**: Smooth transitions and micro-interactions
- **Custom Themes**: User-configurable color schemes
- **Component Library**: Pre-styled common components

### Extensibility
The system is designed to be easily extensible:
- Add new color variants to the palette
- Create new component variants
- Implement custom spacing scales
- Add new typography options

## 📚 Examples

### Complete Button Example
```matlab
% Create a modern primary button
button = uibutton('Text', 'Save Changes');
foilview_styling.styleButton(button, 'primary', 'lg');

% Create a danger button with loading state
deleteButton = uibutton('Text', 'Delete');
foilview_styling.styleButton(deleteButton, 'danger', 'base', 'loading');
```

### Complete Form Example
```matlab
% Style a form panel
panel = uipanel('Title', 'User Settings');
foilview_styling.stylePanel(panel, 'elevated', 'User Settings', 'lg');

% Style form labels
nameLabel = uilabel('Text', 'Full Name');
foilview_styling.styleLabel(nameLabel, 'primary', 'base', 'medium');

% Style form inputs
nameField = uieditfield('Text');
foilview_styling.styleInputField(nameField, 'default', 'base');

% Style form buttons
saveButton = uibutton('Text', 'Save');
foilview_styling.styleButton(saveButton, 'primary', 'base');

cancelButton = uibutton('Text', 'Cancel');
foilview_styling.styleButton(cancelButton, 'secondary', 'base');
```

### Status Display Example
```matlab
% Style status indicators
statusLabel = uilabel('Text', 'Connected');
foilview_styling.styleLabel(statusLabel, 'success', 'sm', 'medium');

% Style position display
positionLabel = uilabel('Text', '0.00 μm');
foilview_styling.stylePositionDisplay(positionLabel, 25.75, '3xl');
```

## 🆘 Troubleshooting

### Common Issues

**Button not styling correctly:**
- Ensure the component is a valid UI control
- Check that the variant name is spelled correctly
- Verify the component is not disabled

**Colors not applying:**
- Use the `getColors()` method to access the palette
- Check for typos in color property names
- Ensure the component supports the color property

**Font sizes not working:**
- Use the `getFonts()` method to access typography
- Check that the size name matches the available options
- Verify the component supports font sizing

### Debug Mode
Enable debug mode to see detailed styling information:
```matlab
% Check if component is valid
isValid = foilview_styling.validateComponent(component);

% Get all available colors
colors = foilview_styling.getColors();

% Get all available fonts
fonts = foilview_styling.getFonts();
```

## 📄 License

This styling system is part of the FoilView project and follows the same licensing terms.

---

*Built with modern design principles and accessibility in mind. Inspired by GitHub's design system and Material Design guidelines.* 