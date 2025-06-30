# FoilView Styling System

This directory contains the centralized styling system for the FoilView application, designed to ensure consistency and maintainability across all UI components.

## Overview

The `foilview_styling.m` class provides a unified interface for all styling operations, replacing scattered styling code throughout the application with a centralized, semantic approach.

## Quick Start

### Basic Button Styling
```matlab
% Style buttons using semantic names
foilview_styling.styleButton(button, 'Success', 'SAVE');
foilview_styling.styleButton(button, 'Danger', 'DELETE');
foilview_styling.styleButton(button, 'Primary', 'START');
```

### Window Indicator Buttons
```matlab
% Style window status indicators with active/inactive states
foilview_styling.styleWindowIndicatorButton(bookmarksButton, ...
    isActive, '📌', '📌●', '📌');
```

### Labels and Text
```matlab
% Style labels with semantic meaning
foilview_styling.styleLabel(label, 'primary');   % Primary text
foilview_styling.styleLabel(label, 'muted');     % Muted text
foilview_styling.styleLabel(label, 'success');   % Success state
foilview_styling.styleLabel(label, 'warning');   % Warning state
foilview_styling.styleLabel(label, 'danger');    % Error state
```

### Position Displays
```matlab
% Style the main position display
foilview_styling.stylePositionDisplay(label, position);
```

## Available Styles

### Button Styles
- `'Primary'` - Main action buttons (blue)
- `'Secondary'` - Secondary actions (gray)
- `'Success'` - Positive actions (green)
- `'Warning'` - Caution actions (orange)
- `'Danger'` - Destructive actions (red)
- `'Info'` - Informational actions (light blue)
- `'Light'` - Subtle actions (light gray)
- `'Active'` - Active state (green)
- `'Inactive'` - Inactive state (gray)

### Text Styles
- `'primary'` - Main text (dark)
- `'secondary'` - Secondary text (medium gray)
- `'muted'` - Subdued text (light gray)
- `'success'` - Success message (green)
- `'warning'` - Warning message (orange)
- `'danger'` - Error message (red)
- `'inverse'` - Light text for dark backgrounds

## Color System

Access the complete color palette:
```matlab
colors = foilview_styling.getColors();
myPanel.BackgroundColor = colors.Background;
myLabel.FontColor = colors.TextPrimary;
```

### Available Colors
- **Primary Colors**: `Background`, `Primary`, `Secondary`, `Accent`
- **Semantic Colors**: `Success`, `Warning`, `Danger`, `Info`
- **UI Colors**: `Light`, `LightGray`, `MediumGray`, `DarkGray`
- **Text Colors**: `TextPrimary`, `TextSecondary`, `TextMuted`, `TextInverse`
- **State Colors**: `Active`, `Inactive`, `Disabled`
- **Plot Colors**: `PlotColors` (array of accessible colors)

## Typography System

Access font definitions:
```matlab
fonts = foilview_styling.getFonts();
myLabel.FontSize = fonts.SizeL;
myLabel.FontWeight = fonts.WeightBold;
```

### Font Sizes
- `SizeXS` (8pt) - Extra small labels
- `SizeS` (9pt) - Secondary text
- `SizeM` (10pt) - Default UI text
- `SizeL` (11pt) - Buttons and headers
- `SizeXL` (12pt) - Important text
- `SizeXXL` (14pt) - Display text
- `SizeDisplay` (28pt) - Main position display

## Layout System

Get spacing and layout constants:
```matlab
layout = foilview_styling.getLayout();
grid.Padding = [layout.SpaceM layout.SpaceM layout.SpaceM layout.SpaceM];
```

### Spacing (8pt Grid System)
- `SpaceXS` (2px) - Tight spacing
- `SpaceS` (4px) - Small spacing
- `SpaceM` (8px) - Default spacing
- `SpaceL` (12px) - Large spacing
- `SpaceXL` (16px) - Extra large spacing
- `SpaceXXL` (24px) - Section spacing

## Utility Methods

### Font Styling
```matlab
% Apply font styles to any component
foilview_styling.applyFontStyle(component, 'SizeL', 'WeightBold');
```

### Responsive Design
```matlab
% Adjust font size by scale factor
foilview_styling.adjustFontSize(component, 1.2);
```

### Formatting
```matlab
% Format position values consistently
positionText = foilview_styling.formatPosition(25.75);  % "25.8 μm"

% Format metric values consistently
metricText = foilview_styling.formatMetric(0.12345);    % "0.123"
```

## Migration Guide

### Old vs New Approach

**Before (scattered styling):**
```matlab
button.BackgroundColor = [0.2 0.7 0.3];
button.FontColor = [1 1 1];
button.FontSize = 10;
button.FontWeight = 'bold';
button.Text = 'SAVE';
```

**After (centralized styling):**
```matlab
foilview_styling.styleButton(button, 'Success', 'SAVE');
```

### Updating Existing Code

1. Replace direct color assignments with `foilview_styling.styleButton()`
2. Replace manual label styling with `foilview_styling.styleLabel()`
3. Use `foilview_styling.getColors()` instead of hardcoded color values
4. Use `foilview_styling.getFonts()` for font size constants

## Best Practices

1. **Use Semantic Names**: Use `'Success'` instead of specific colors
2. **Consistent Spacing**: Use the layout spacing constants
3. **Responsive Design**: Use relative font sizes when possible
4. **Accessibility**: The color palette is designed for good contrast
5. **Maintainability**: Update styles through the central system, not individual components

## Extending the System

### Adding New Button Styles
Add new styles to the `BUTTON_STYLES` constant in `foilview_styling.m`:
```matlab
'MyCustomStyle', struct('bg', 'CustomColor', 'fg', 'TextInverse', 'bold', true)
```

### Adding New Colors
Add new colors to the `COLORS` constant:
```matlab
'CustomColor', [0.5 0.3 0.8], ...  % Purple custom color
```

### Theme Support
The system is designed to support multiple themes (dark mode, high contrast) in the future:
```matlab
foilview_styling.applyTheme(components, 'dark');  % Future feature
```

## Legacy Support

The following legacy constants have been **removed** and replaced with the centralized `foilview_styling` system:

- ~~`foilview_ui.COLORS`~~ - **REMOVED** - Use `foilview_styling.getColors()` or direct constants
- ~~`foilview_utils.UI_STYLE`~~ - **REMOVED** - Use `foilview_styling` constants directly

All code has been migrated to use the new centralized styling system. If you encounter any remaining legacy references, please update them to use `foilview_styling`. 