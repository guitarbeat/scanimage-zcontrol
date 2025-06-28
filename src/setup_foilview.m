function setup_foilview()
    % setup_foilview - Initialize MATLAB path for foilview application
    %
    % This function adds all necessary subdirectories to the MATLAB path
    % so that the foilview application can locate all its components.
    %
    % Usage:
    %   setup_foilview()  % Run this before using foilview
    %
    % Directory Structure:
    %   src/
    %   ├── app/         - Main application entry point
    %   ├── core/        - Core controllers and business logic
    %   ├── ui/          - User interface components and plotting
    %   └── utils/       - Utilities and helper functions
    
    % Get the directory where this script is located
    scriptDir = fileparts(mfilename('fullpath'));
    
    % Define subdirectories to add to path
    subdirs = {'app', 'core', 'ui', 'utils'};
    
    % Add each subdirectory to the MATLAB path
    for i = 1:length(subdirs)
        subdir = fullfile(scriptDir, subdirs{i});
        if exist(subdir, 'dir')
            addpath(subdir);
            fprintf('Added to path: %s\n', subdir);
        else
            warning('Directory not found: %s', subdir);
        end
    end
    
    % Verify that all required classes can be found
    requiredClasses = {'foilview', 'foilview_controller', 'foilview_logic', ...
                       'foilview_ui', 'foilview_updater', 'foilview_plot', 'foilview_utils'};
    
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