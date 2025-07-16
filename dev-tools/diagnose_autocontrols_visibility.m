function diagnose_autocontrols_visibility()
% Diagnostic script to check AutoControls visibility in foilview app

fprintf('=== AutoControls Visibility Diagnostic ===\n');

% Try to find existing foilview app instance
apps = findall(groot, 'Type', 'figure', 'Name', 'FoilView - Z-Stage Control');

if isempty(apps)
    fprintf('No foilview app found. Please start the app first.\n');
    return;
end

% Get the app handle
fig = apps(1);
fprintf('Found foilview figure: %s\n', fig.Name);
fprintf('Figure Position: [%.3f %.3f %.3f %.3f]\n', fig.Position);

try
    % Find MainPanel
    mainPanel = findobj(fig.Children, 'Type', 'uipanel');
    if ~isempty(mainPanel)
        fprintf('\nMainPanel found: Position = [%.3f %.3f %.3f %.3f]\n', mainPanel(1).Position);

        % Check main grid layout
        mainLayout = findobj(mainPanel(1).Children, 'Type', 'uigridlayout');
        if ~isempty(mainLayout)
            fprintf('Main grid layout found\n');
            fprintf('Current row heights: %s\n', mat2str(mainLayout(1).RowHeight));
            fprintf('Column widths: %s\n', mat2str(mainLayout(1).ColumnWidth));
        else
            fprintf('Main grid layout not found!\n');
        end

        % Look for AutoControls within the panel
        autoControlsPanel = findobj(mainPanel, 'Title', '⚡ Auto Step Control');
        if ~isempty(autoControlsPanel)
            fprintf('\n✓ AutoControls panel found!\n');
            fprintf('  Visible: %s\n', autoControlsPanel(1).Visible);
            fprintf('  Position: [%.3f %.3f %.3f %.3f]\n', autoControlsPanel(1).Position);

            % Check if it has layout row assignment
            if isprop(autoControlsPanel(1), 'Layout') && ~isempty(autoControlsPanel(1).Layout)
                fprintf('  Layout Row: %d\n', autoControlsPanel(1).Layout.Row);
            end

            % Check individual controls
            controls = autoControlsPanel(1).Children;
            fprintf('  Child components: %d\n', length(controls));

            for i = 1:length(controls)
                if isprop(controls(i), 'Type')
                    visibleStr = 'N/A';
                    if isprop(controls(i), 'Visible')
                        visibleStr = controls(i).Visible;
                    end
                    fprintf('    Control %d: Type = %s, Visible = %s\n', i, controls(i).Type, visibleStr);
                end
            end
        else
            fprintf('\n✗ AutoControls panel not found!\n');

            % List all panels to see what's available
            allPanels = findobj(mainPanel, 'Type', 'uipanel');
            fprintf('\nAvailable panels in MainPanel (%d total):\n', length(allPanels));
            for i = 1:length(allPanels)
                titleStr = 'No Title';
                if isprop(allPanels(i), 'Title') && ~isempty(allPanels(i).Title)
                    titleStr = allPanels(i).Title;
                end

                layoutInfo = '';
                if isprop(allPanels(i), 'Layout') && ~isempty(allPanels(i).Layout)
                    layoutInfo = sprintf(' (Row: %d)', allPanels(i).Layout.Row);
                end

                fprintf('  Panel %d: "%s"%s, Visible = %s\n', i, titleStr, layoutInfo, allPanels(i).Visible);
            end
        end

        % Check overall layout health
        fprintf('\n=== Layout Health Check ===\n');
        if ~isempty(mainLayout)
            rowHeights = mainLayout(1).RowHeight;
            fprintf('Row height analysis:\n');
            for i = 1:length(rowHeights)
                fprintf('  Row %d: %s\n', i, char(rowHeights{i}));
            end

            % Check if row 4 (auto controls) has adequate space
            if length(rowHeights) >= 4
                row4Height = rowHeights{4};
                if strcmp(row4Height, '1x')
                    fprintf('⚠️  Row 4 (Auto Controls) has flexible height "1x" - may be squeezed by other elements\n');
                elseif strcmp(row4Height, 'fit')
                    fprintf('✓ Row 4 (Auto Controls) has "fit" height - should size to content\n');
                else
                    fprintf('ℹ️  Row 4 (Auto Controls) has custom height: %s\n', row4Height);
                end
            end
        end

    else
        fprintf('MainPanel not found!\n');
    end

catch ME
    fprintf('Error during diagnosis: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end

fprintf('\n=== End Diagnostic ===\n');
end