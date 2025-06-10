function varargout = fsweep()
    % FSWEEP - Quick launcher for the FocalSweep focus finding tool
    %
    % This function provides a simple way to launch the FocalSweep
    % focus finding tool for microscopy applications.
    %
    % Usage:
    %   fsweep           % Launch the FocalSweep tool
    %   fs = fsweep      % Launch and return the FocalSweep object
    %
    % Simulation Mode:
    %   To run in simulation mode without ScanImage:
    %   >> SIM_MODE = true;
    %   >> fsweep
    %
    % See also: FocalSweep
    
    try
        % Ensure FocalSweep.m is in the path
        thisFile = mfilename('fullpath');
        [basePath, ~, ~] = fileparts(thisFile);
        addpath(basePath);
        
        % Launch FocalSweep using the static launch method
        fs = FocalSweep.launch();
        
        % Return the FocalSweep object if requested
        if nargout > 0
            varargout{1} = fs;
        end
    catch ME
        fprintf('Error in fsweep launcher: %s\n', ME.message);
        if nargout > 0
            varargout{1} = [];
        end
    end
end 