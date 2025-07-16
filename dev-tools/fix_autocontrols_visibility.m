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
            fprintf('Resetting MainPanel position to full window...\n');
            mainPanel(1).Position = [0, 0, 1, 1];
            
            % Find AutoControls panel
            autoControlsPanel = findobj(mainPanel, 'Title', '⚡ Auto Step Control');
            if ~isempty(autoControlsPanel)
                fprintf('Making AutoControls panel visible...\n');
                autoControlsPanel(1).Visible = 'on';
                
                % Make all child controls visible
                controls = findobj(autoControlsPanel(1), '-property', 'Visible');
                for i = 1:length(controls)
                    if ~strcmp(controls(i).Type, 'uipanel') % Don't change panel visibility
                        controls(i).Visible = 'on';
                    end
                end
                
                fprintf('AutoControls should now be visible.\n');
            else
                fprintf('AutoControls panel not found!\n');
            end
            
            % Force a refresh
            drawnow;
            
        else
            fprintf('MainPanel not found!\n');
        end
        
    catch ME
        fprintf('Error during fix: %s\n', ME.message);
    end
    
    fprintf('=== Fix Complete ===\n');
end