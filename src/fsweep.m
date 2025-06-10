function varargout = fsweep(varargin)
    % FSWEEP - Quick launcher for the FocalSweep focus finding tool
    %
    % This function provides a simple way to launch the FocalSweep
    % focus finding tool for microscopy applications.
    %
    % Usage:
    %   fsweep           % Launch the FocalSweep tool
    %   fs = fsweep      % Launch and return the FocalSweep object
    %   fsweep('quiet')  % Launch with minimal output and no warnings
    %   fsweep('force')  % Force creation of a new instance
    %
    % Simulation Mode:
    %   To run in simulation mode without ScanImage:
    %   >> SIM_MODE = true;
    %   >> fsweep
    %
    % See also: FocalSweep, fsweep_close
    
    try
        % Parse options
        quiet = false;
        forceNew = false;
        
        % Process input arguments
        for i = 1:nargin
            if ischar(varargin{i})
                switch lower(varargin{i})
                    case 'quiet'
                        quiet = true;
                    case 'force'
                        forceNew = true;
                end
            end
        end
        
        % Turn off warnings if quiet mode
        if quiet
            warnState = warning('off', 'all');
        end
        
        % Ensure FocalSweep.m is in the path
        thisFile = mfilename('fullpath');
        [basePath, ~, ~] = fileparts(thisFile);
        addpath(basePath);
        
        % Launch FocalSweep using the static launch method
        if quiet
            % Only print essential messages
            fprintf('Launching FocalSweep...\n');
            fs = FocalSweep.launch('verbosity', 0, 'forceNew', forceNew);
        else
            fs = FocalSweep.launch('verbosity', 0, 'forceNew', forceNew);
        end
        
        % Return the FocalSweep object if requested
        if nargout > 0
            varargout{1} = fs;
        end
        
        % Restore warnings if quiet mode
        if quiet
            warning(warnState);
        end
    catch ME
        % Check if the error is related to a previous instance
        if contains(ME.message, 'superclass constructor') || ...
           contains(ME.message, 'property access')
            fprintf('Error detected that may be due to a previous instance.\n');
            fprintf('Attempting to clean up and restart...\n');
            
            % Try to close any open instances
            try
                % Create the cleanup function if it doesn't exist
                if ~exist('fsweep_close', 'file')
                    fsweep_close_path = fullfile(basePath, 'fsweep_close.m');
                    if ~exist(fsweep_close_path, 'file')
                        fprintf('Creating cleanup utility...\n');
                        fid = fopen(fsweep_close_path, 'w');
                        if fid > 0
                            fprintf(fid, 'function fsweep_close()\n');
                            fprintf(fid, '    %% Force close FocalSweep instances\n');
                            fprintf(fid, '    figs = findall(0, ''Type'', ''figure'');\n');
                            fprintf(fid, '    for i = 1:length(figs)\n');
                            fprintf(fid, '        if contains(get(figs(i), ''Name''), ''FocalSweep'')\n');
                            fprintf(fid, '            close(figs(i));\n');
                            fprintf(fid, '        end\n');
                            fprintf(fid, '    end\n');
                            fprintf(fid, '    clear FocalSweep.launch\n');
                            fprintf(fid, 'end\n');
                            fclose(fid);
                        end
                    end
                end
                
                % Run the cleanup
                fsweep_close();
                
                % Try to clear classes
                fprintf('Resetting class definitions...\n');
                clear classes;
                
                % Retry once with force flag
                fprintf('Retrying launch...\n');
                if nargout > 0
                    varargout{1} = fsweep('force');
                else
                    fsweep('force');
                end
                return;
            catch ME2
                fprintf('Recovery attempt failed: %s\n', ME2.message);
            end
        end
        
        % If we get here, the error wasn't handled or recovery failed
        fprintf('Error in fsweep launcher: %s\n', ME.message);
        if nargout > 0
            varargout{1} = [];
        end
    end
end 