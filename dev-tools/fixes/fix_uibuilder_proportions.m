function fix_uibuilder_proportions()
    % Fix the UiBuilder layout proportions to ensure auto controls are visible
    % This modifies the source code proportions for a permanent fix
    
    fprintf('=== Fixing UiBuilder Layout Proportions ===\n');
    
    uiBuilderPath = 'src/views/components/UiBuilder.m';
    
    if ~exist(uiBuilderPath, 'file')
        fprintf('❌ UiBuilder.m not found at: %s\n', uiBuilderPath);
        return;
    end
    
    try
        % Read the current file
        fprintf('Reading UiBuilder.m...\n');
        content = fileread(uiBuilderPath);
        
        % Find the current row height definition
        oldPattern = 'mainLayout.RowHeight = {''fit'', ''2x'', ''fit'', ''1x'', ''fit'', ''fit''};';
        newPattern = 'mainLayout.RowHeight = {''fit'', ''1.2x'', ''fit'', ''1.5x'', ''fit'', ''fit''};';
        
        if contains(content, oldPattern)
            % Replace the row heights
            newContent = strrep(content, oldPattern, newPattern);
            
            % Write back to file
            fid = fopen(uiBuilderPath, 'w');
            if fid == -1
                fprintf('❌ Could not open file for writing\n');
                return;
            end
            
            fprintf(fid, '%s', newContent);
            fclose(fid);
            
            fprintf('✅ Updated UiBuilder.m row heights:\n');
            fprintf('   Old: {''fit'', ''2x'', ''fit'', ''1x'', ''fit'', ''fit''}\n');
            fprintf('   New: {''fit'', ''1.2x'', ''fit'', ''1.5x'', ''fit'', ''fit''}\n');
            fprintf('\n');
            fprintf('Changes made:\n');
            fprintf('• Position display (row 2): 2x → 1.2x (reduced space)\n');
            fprintf('• Auto controls (row 4): 1x → 1.5x (increased space)\n');
            fprintf('\n');
            fprintf('⚠️  You will need to restart the foilview app for changes to take effect.\n');
            
        else
            fprintf('⚠️  Could not find the expected row height pattern in UiBuilder.m\n');
            fprintf('The file may have been modified or the pattern has changed.\n');
            
            % Show what we're looking for
            fprintf('\nLooking for pattern:\n%s\n', oldPattern);
            
            % Try to find similar patterns
            lines = splitlines(content);
            for i = 1:length(lines)
                if contains(lines{i}, 'RowHeight') && contains(lines{i}, 'fit')
                    fprintf('Found similar line %d: %s\n', i, strtrim(lines{i}));
                end
            end
        end
        
    catch ME
        fprintf('❌ Error modifying UiBuilder.m: %s\n', ME.message);
        fprintf('Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
    end
    
    fprintf('\n=== UiBuilder Fix Complete ===\n');
end