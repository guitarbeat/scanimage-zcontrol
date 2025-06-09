function varargout = zbright()
    % ZBRIGHT - Quick launcher for the BrightZ focus finding tool
    %
    % This function provides a simple way to launch the BrightZ
    % focus finding tool for microscopy applications.
    %
    % Usage:
    %   zbright           % Launch the BrightZ tool
    %   zb = zbright      % Launch and return the BrightZ object
    %
    % Simulation Mode:
    %   To run in simulation mode without ScanImage:
    %   >> SIM_MODE = true;
    %   >> zbright
    %
    % See also: BrightZ
    
    try
        % Ensure BrightZ.m is in the path
        thisFile = mfilename('fullpath');
        [basePath, ~, ~] = fileparts(thisFile);
        addpath(basePath);
        
        % Launch BrightZ using the static launch method
        zb = BrightZ.launch();
        
        % Return the BrightZ object if requested
        if nargout > 0
            varargout{1} = zb;
        end
    catch ME
        fprintf('Error in zbright launcher: %s\n', ME.message);
        if nargout > 0
            varargout{1} = [];
        end
    end
end 