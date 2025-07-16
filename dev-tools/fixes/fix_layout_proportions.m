function fix_layout_proportions()
    % Script to fix the main layout proportions to ensure auto controls are visible
    
    fprintf('=== Fixing Layout Proportions ===\n');
    
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
            % Find the main grid layout
            mainLayout = findobj(mainPanel(1).Children, 'Type', 'uigridlayout');
            if ~isempty(mainLayout)
                fprintf('Current row heights: %s\n', mat2str(mainLayout(1).RowHeight));
                
                % Set better proportions:
                % Row 1: Metrics (fit)
                % Row 2: Position display (1.2x - reduced from 2x)  
                % Row 3: Manual controls (fit)
                % Row 4: Auto controls (1.5x - increased from 1x)
                % Row 5: Expand button (fit)
                % Row 6: Status bar (fit)
                newRowHeights = {'fit', '1.2x', 'fit', '1.5x', 'fit', 'fit'};
                mainLayout(1).RowHeight = newRowHeights;
                
                fprintf('Updated row heights to: %s\n', mat2str(newRowHeights));
                
                % Also ensure the figure has adequate height
                currentPos = fig.Position;
                if currentPos(4) < 600  % Height less than 600 pixels
                    fig.Position(4) = 650;  % Set minimum height
                    fprintf('Increased figure height to %d pixels\n', fig.Position(4));
                end
                
                % Force layout update
                drawnow;
                
                fprintf('✓ Layout proportions updated successfully\n');
            else
                fprintf('Main grid layout not found!\n');
            end
        else
            fprintf('MainPanel not found!\n');
        end
        
    catch ME
        fprintf('Error during layout fix: %s\n', ME.message);
        fprintf('Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
    end
    
    fprintf('=== Layout Fix Complete ===\n');
end