function check_autocontrols_clipping()
    % Check specifically what parts of auto controls are clipped
    
    fprintf('=== AutoControls Clipping Analysis ===\n');
    
    apps = findall(groot, 'Type', 'figure', 'Name', 'FoilView - Z-Stage Control');
    if isempty(apps)
        fprintf('No foilview app found. Please start the app first.\n');
        return;
    end
    
    fig = apps(1);
    mainPanel = findobj(fig.Children, 'Type', 'uipanel');
    
    if ~isempty(mainPanel)
        autoPanel = findobj(mainPanel, 'Title', '⚡ Auto Step Control');
        if ~isempty(autoPanel)
            fprintf('AutoControls Panel Analysis:\n');
            fprintf('Panel Position: [%.3f %.3f %.3f %.3f]\n', autoPanel(1).Position);
            fprintf('Panel Height: %.1f%% of parent\n', autoPanel(1).Position(4) * 100);
            
            % Find the internal grid
            grid = findobj(autoPanel(1).Children, 'Type', 'uigridlayout');
            if ~isempty(grid)
                fprintf('\nInternal Grid Layout:\n');
                fprintf('Grid Rows: %d\n', size(grid(1).RowHeight, 2));
                fprintf('Row Heights: %s\n', mat2str(grid(1).RowHeight));
                
                % Check specific controls
                fprintf('\nControl Visibility Check:\n');
                
                % Look for START button
                startBtn = findobj(autoPanel(1), 'Type', 'uibutton', 'Text', 'START ▲');
                if ~isempty(startBtn)
                    fprintf('✓ START button found and visible: %s\n', startBtn(1).Visible);
                else
                    startBtn = findobj(autoPanel(1), 'Type', 'uibutton');
                    if ~isempty(startBtn)
                        fprintf('? Button found with text: "%s"\n', startBtn(1).Text);
                    else
                        fprintf('✗ START button not found\n');
                    end
                end
                
                % Look for numeric fields
                numFields = findobj(autoPanel(1), 'Type', 'uieditfield');
                fprintf('Numeric fields found: %d\n', length(numFields));
                for i = 1:length(numFields)
                    if isprop(numFields(i), 'Tooltip')
                        fprintf('  Field %d: %s (Visible: %s)\n', i, numFields(i).Tooltip, numFields(i).Visible);
                    end
                end
                
                % Look for direction switch
                dirSwitch = findobj(autoPanel(1), 'Type', 'uiswitch');
                if ~isempty(dirSwitch)
                    fprintf('✓ Direction switch found (Visible: %s)\n', dirSwitch(1).Visible);
                else
                    fprintf('✗ Direction switch not found\n');
                end
                
                % Look for status display
                statusLabels = findobj(autoPanel(1), 'Type', 'uilabel');
                fprintf('Status labels found: %d\n', length(statusLabels));
                statusFound = false;
                for i = 1:length(statusLabels)
                    if isprop(statusLabels(i), 'Text') && contains(statusLabels(i).Text, 'Ready')
                        fprintf('✓ Status display found: "%s" (Visible: %s)\n', statusLabels(i).Text, statusLabels(i).Visible);
                        statusFound = true;
                    end
                end
                if ~statusFound
                    fprintf('✗ Status display not found or not containing "Ready"\n');
                    fprintf('Available labels:\n');
                    for i = 1:length(statusLabels)
                        if isprop(statusLabels(i), 'Text')
                            fprintf('  Label %d: "%s"\n', i, statusLabels(i).Text);
                        end
                    end
                end
                
            else
                fprintf('Internal grid layout not found\n');
            end
        else
            fprintf('AutoControls panel not found\n');
        end
    end
    
    fprintf('\n=== Analysis Complete ===\n');
end