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
    %
    % Simulation Mode:
    %   To run in simulation mode without ScanImage:
    %   >> SIM_MODE = true;
    %   >> fsweep
    %
    % See also: FocalSweep
    
    try
        % Parse options
        quiet = false;
        if nargin > 0 && strcmpi(varargin{1}, 'quiet')
            quiet = true;
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
            fs = FocalSweep.launch('verbosity', 0);
        else
            fs = FocalSweep.launch('verbosity', 1);
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
        fprintf('Error in fsweep launcher: %s\n', ME.message);
        if nargout > 0
            varargout{1} = [];
        end
    end
end 