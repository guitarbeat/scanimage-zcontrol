function setupFoilview()
    
    scriptDir = fileparts(mfilename('fullpath'));
    subdirs = {'app', 'controllers', 'views', 'views/components', 'utils', 'managers'};
    
    for i = 1:length(subdirs)
        subdir = fullfile(scriptDir, subdirs{i});
        if exist(subdir, 'dir')
            addpath(subdir);
            fprintf('Added to path: %s\n', subdir);
        else
            warning('Directory not found: %s', subdir);
        end
    end
    
    requiredClasses = {'foilview', 'FoilviewController', ...
                       'UiComponents', 'FoilviewUtils'};
    
    fprintf('\nVerifying class availability:\n');
    allFound = true;
    for i = 1:length(requiredClasses)
        className = requiredClasses{i};
        if exist(className, 'class') == 8 || exist(className, 'file') == 2
            fprintf('✓ %s - Found\n', className);
        else
            fprintf('✗ %s - NOT FOUND\n', className);
            allFound = false;
        end
    end
    
    if allFound
        fprintf('\n✓ Setup complete! All foilview components are available.\n');
        fprintf('You can now run: app = foilview();\n');
    else
        fprintf('\n✗ Setup incomplete. Some components are missing.\n');
    end
end 
