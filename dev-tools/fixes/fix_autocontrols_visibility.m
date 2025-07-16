function fix_autocontrols_visibility()
    % Script to fix AutoControls visibility issues in foilview app
    
    fprintf('=== Fixing AutoControls Visibility ===\n');
    
    % Find existing foilview app instance
    apps = findall(groot, 'Type', 'figure', 'Name', 'FoilView - Z-Stage Control');
    
    if isempty(apps)
        fprintf('No foilview app found. Please start the app first.\n');
        return;
    end
    
    fig = apps(1);
    fprintf('Found foilview figure: %s\n', fig.Name);
    
    try
        % Find MainPanel
        mainPanel = findobj(fig.Children, 'Type', 'uipanel');
        if ~isempty(mainPanel)
            fprintf('Adjusting MainPanel layout...\n');
            mainPanel(1).Position = [0, 0, 1, 1];
            
            % Find the main grid layout
            mainLayout = findobj(mainPanel(1).Children, 'Type', 'uigridlayout');
            if ~isempty(mainLayout)
                fprintf('Adjusting main layout row heights for better visibility...\n');
                % Reduce position display height and give more space to auto controls
                mainLayout(1).RowHeight = {'fit', '1.5x', 'fit', '1.2x', 'fit', 'fit'};
                fprintf('Updated row heights: fit, 1.5x, fit, 1.2x, fit, fit\n');
            end
            
            % Find AutoControls panel
            autoControlsPanel = findobj(mainPanel, 'Title', '⚡ Auto Step Control');
            if ~isempty(autoControlsPanel)
                fprintf('Making AutoControls panel visible...\n');
                autoControlsPanel(1).Visible = 'on';
                
                % Ensure the panel has proper sizing
                if isprop(autoControlsPanel(1), 'AutoResizeChildren')
                    autoControlsPanel(1).AutoResizeChildren = 'on';
                end
                
                % Make all child controls visible
                controls = findobj(autoControlsPanel(1), '-property', 'Visible');
                for i = 1:length(controls)
                    if ~strcmp(controls(i).Type, 'uipanel') % Don't change panel visibility
                        controls(i).Visible = 'on';
                    end
                end
                
                fprintf('AutoControls panel and %d child controls made visible.\n', length(controls));
            else
                fprintf('AutoControls panel not found!\n');
                
                % List available panels for debugging
                allPanels = findobj(mainPanel, 'Type', 'uipanel');
                fprintf('Available panels in MainPanel:\n');
                for i = 1:length(allPanels)
                    if isprop(allPanels(i), 'Title') && ~isempty(allPanels(i).Title)
                        fprintf('  - "%s" (Visible: %s)\n', allPanels(i).Title, allPanels(i).Visible);
                    end
                end
            end
            
            % Force a refresh
            drawnow;
            
        else
            fprintf('MainPanel not found!\n');
        end
        
    catch ME
        fprintf('Error during fix: %s\n', ME.message);
        fprintf('Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
    end
    
    fprintf('=== Fix Complete ===\n');
end