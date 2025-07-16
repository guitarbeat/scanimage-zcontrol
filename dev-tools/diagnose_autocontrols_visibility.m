function diagnose_autocontrols_visibility()
% Diagnostic script to check AutoControls visibility in foilview app

fprintf('=== AutoControls Visibility Diagnostic ===\n');

% Try to find existing foilview app instance
apps = findall(groot, 'Type', 'figure', 'Name', 'FoilView - Z-Stage Control');

if isempty(apps)
    fprintf('No foilview app found. Please start the app first.\n');
    return;
end

% Get the app handle (assuming it's stored in UserData or similar)
fig = apps(1);
fprintf('Found foilview figure: %s\n', fig.Name);

% Try to find the app object
try
    % Look for app object in figure's UserData or Children
    appObj = [];
    if isfield(fig.UserData, 'app')
        appObj = fig.UserData.app;
    elseif ~isempty(fig.Children)
        % Try to find MainPanel
        mainPanel = findobj(fig.Children, 'Type', 'uipanel');
        if ~isempty(mainPanel)
            fprintf('Found MainPanel: Position = [%.3f %.3f %.3f %.3f]\n', mainPanel(1).Position);

            % Look for AutoControls within the panel
            autoControlsPanel = findobj(mainPanel, 'Title', '⚡ Auto Step Control');
            if ~isempty(autoControlsPanel)
                fprintf('Found AutoControls panel: Visible = %s\n', autoControlsPanel(1).Visible);
                fprintf('AutoControls Position: [%.3f %.3f %.3f %.3f]\n', autoControlsPanel(1).Position);

                % Check individual controls
                controls = autoControlsPanel(1).Children;
                fprintf('AutoControls has %d child components\n', length(controls));

                for i = 1:length(controls)
                    if isprop(controls(i), 'Type')
                        fprintf('  Control %d: Type = %s, Visible = %s\n', i, controls(i).Type, controls(i).Visible);
                    end
                end
            else
                fprintf('AutoControls panel not found!\n');

                % List all panels to see what's available
                allPanels = findobj(mainPanel, 'Type', 'uipanel');
                fprintf('Available panels:\n');
                for i = 1:length(allPanels)
                    if isprop(allPanels(i), 'Title')
                        fprintf('  Panel %d: Title = "%s", Visible = %s\n', i, allPanels(i).Title, allPanels(i).Visible);
                    end
                end
            end
        else
            fprintf('MainPanel not found!\n');
        end
    end

catch ME
    fprintf('Error during diagnosis: %s\n', ME.message);
end

fprintf('=== End Diagnostic ===\n');
end