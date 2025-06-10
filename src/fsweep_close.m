function fsweep_close()
    % FSWEEP_CLOSE - Force close any open FocalSweep instances
    %
    % This utility function will close all open FocalSweep windows
    % and attempt to clean up any instances in memory.
    %
    % Usage:
    %   fsweep_close()
    
    % First, try to find and close figures with 'FocalSweep' in their names
    figs = findall(0, 'Type', 'figure');
    closedCount = 0;
    
    for i = 1:length(figs)
        figName = get(figs(i), 'Name');
        if contains(figName, 'FocalSweep')
            try
                fprintf('Closing FocalSweep figure: %s\n', figName);
                close(figs(i));
                closedCount = closedCount + 1;
            catch ME
                fprintf('Error closing figure %s: %s\n', figName, ME.message);
            end
        end
    end
    
    % Force clear any variables in base workspace that are FocalSweep objects
    try
        vars = evalin('base', 'who');
        for i = 1:length(vars)
            try
                if evalin('base', sprintf('isa(%s, ''FocalSweep'')', vars{i}))
                    fprintf('Clearing FocalSweep object: %s\n', vars{i});
                    evalin('base', sprintf('clear %s', vars{i}));
                    closedCount = closedCount + 1;
                end
            catch
                % Skip variables that can't be evaluated
            end
        end
    catch
        % Ignore errors in workspace variable access
    end
    
    % Try to clear any persistent instances in the launch method
    try
        clear FocalSweep.launch
    catch
        % Ignore errors clearing persistent variables
    end
    
    % Report results
    if closedCount > 0
        fprintf('Successfully closed %d FocalSweep instance(s).\n', closedCount);
    else
        fprintf('No active FocalSweep instances found.\n');
    end
    
    % Add a tip for additional cleanup
    fprintf('If issues persist, try running "clear classes" to reset all class definitions.\n');
end 