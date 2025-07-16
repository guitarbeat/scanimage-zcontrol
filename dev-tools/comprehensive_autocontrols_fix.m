function comprehensive_autocontrols_fix()
    % Comprehensive fix for AutoControls visibility issues
    % This script addresses multiple potential causes of the visibility problem
    
    fprintf('=== Comprehensive AutoControls Fix ===\n');
    
    % Find existing foilview app instance
    apps = findall(groot, 'Type', 'figure', 'Name', 'FoilView - Z-Stage Control');
    
    if isempty(apps)
        fprintf('❌ No foilview app found. Please start the app first.\n');
        return;
    end
    
    fig = apps(1);
    fprintf('✓ Found foilview figure: %s\n', fig.Name);
    
    try
        % Step 1: Ensure figure has adequate size
        fprintf('\n--- Step 1: Figure Size Check ---\n');
        currentPos = fig.Position;
        fprintf('Current figure size: %dx%d pixels\n', currentPos(3), currentPos(4));
        
        minWidth = 800;
        minHeight = 700;
        needsResize = false;
        
        if currentPos(3) < minWidth
            currentPos(3) = minWidth;
            needsResize = true;
        end
        if currentPos(4) < minHeight
            currentPos(4) = minHeight;
            needsResize = true;
        end
        
        if needsResize
            fig.Position = currentPos;
            fprintf('✓ Resized figure to: %dx%d pixels\n', currentPos(3), currentPos(4));
        else
            fprintf('✓ Figure size is adequate\n');
        end
        
        % Step 2: Find and fix MainPanel
        fprintf('\n--- Step 2: MainPanel Setup ---\n');
        mainPanel = findobj(fig.Children, 'Type', 'uipanel');
        if ~isempty(mainPanel)
            mainPanel(1).Position = [0, 0, 1, 1];
            fprintf('✓ MainPanel position reset to full window\n');
            
            % Step 3: Fix main layout proportions
            fprintf('\n--- Step 3: Layout Proportions ---\n');
            mainLayout = findobj(mainPanel(1).Children, 'Type', 'uigridlayout');
            if ~isempty(mainLayout)
                oldHeights = mainLayout(1).RowHeight;
                fprintf('Old row heights: %s\n', mat2str(oldHeights));
                
                % Optimized proportions for better auto controls visibility
                newRowHeights = {'fit', '1x', 'fit', '1.2x', 'fit', 'fit'};
                mainLayout(1).RowHeight = newRowHeights;
                
                fprintf('✓ New row heights: %s\n', mat2str(newRowHeights));
                fprintf('  Row 4 (Auto Controls) now has 1.2x height allocation\n');
            else
                fprintf('❌ Main grid layout not found!\n');
            end
            
            % Step 4: Find and fix AutoControls panel
            fprintf('\n--- Step 4: AutoControls Panel ---\n');
            autoControlsPanel = findobj(mainPanel, 'Title', '⚡ Auto Step Control');
            if ~isempty(autoControlsPanel)
                fprintf('✓ AutoControls panel found\n');
                
                % Ensure visibility
                autoControlsPanel(1).Visible = 'on';
                
                % Ensure proper sizing
                if isprop(autoControlsPanel(1), 'AutoResizeChildren')
                    autoControlsPanel(1).AutoResizeChildren = 'on';
                end
                
                % Check and fix child controls
                controls = findobj(autoControlsPanel(1), '-property', 'Visible');
                visibleCount = 0;
                for i = 1:length(controls)
                    if ~strcmp(controls(i).Type, 'uipanel')
                        controls(i).Visible = 'on';
                        visibleCount = visibleCount + 1;
                    end
                end
                
                fprintf('✓ Made %d child controls visible\n', visibleCount);
                
                % Check layout assignment
                if isprop(autoControlsPanel(1), 'Layout') && ~isempty(autoControlsPanel(1).Layout)
                    fprintf('✓ Panel assigned to layout row: %d\n', autoControlsPanel(1).Layout.Row);
                else
                    fprintf('⚠️  Panel layout assignment not found\n');
                end
                
            else
                fprintf('❌ AutoControls panel not found!\n');
                
                % List available panels for debugging
                allPanels = findobj(mainPanel, 'Type', 'uipanel');
                fprintf('Available panels (%d total):\n', length(allPanels));
                for i = 1:length(allPanels)
                    titleStr = 'No Title';
                    if isprop(allPanels(i), 'Title') && ~isempty(allPanels(i).Title)
                        titleStr = allPanels(i).Title;
                    end
                    fprintf('  - "%s"\n', titleStr);
                end
            end
            
        else
            fprintf('❌ MainPanel not found!\n');
        end
        
        % Step 5: Force UI refresh
        fprintf('\n--- Step 5: UI Refresh ---\n');
        drawnow;
        pause(0.1);  % Small pause to ensure layout settles
        drawnow;
        fprintf('✓ UI refresh completed\n');
        
        % Step 6: Final verification
        fprintf('\n--- Step 6: Verification ---\n');
        autoControlsPanel = findobj(mainPanel, 'Title', '⚡ Auto Step Control');
        if ~isempty(autoControlsPanel) && strcmp(autoControlsPanel(1).Visible, 'on')
            fprintf('✅ AutoControls panel is now visible!\n');
            
            % Check if it has reasonable size
            pos = autoControlsPanel(1).Position;
            if pos(4) > 0.05  % Height > 5% of parent
                fprintf('✅ AutoControls panel has adequate height: %.1f%%\n', pos(4) * 100);
            else
                fprintf('⚠️  AutoControls panel height may be too small: %.1f%%\n', pos(4) * 100);
            end
        else
            fprintf('❌ AutoControls panel is still not visible\n');
        end
        
    catch ME
        fprintf('❌ Error during comprehensive fix: %s\n', ME.message);
        fprintf('Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
    end
    
    fprintf('\n=== Comprehensive Fix Complete ===\n');
    fprintf('If AutoControls are still not visible, try:\n');
    fprintf('1. Restart the foilview app\n');
    fprintf('2. Check if the app was built with the latest UiBuilder code\n');
    fprintf('3. Run diagnose_autocontrols_visibility() for detailed analysis\n');
end