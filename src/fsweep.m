function varargout = fsweep(varargin)
    % FSWEEP - Focal Sweep Tool for ScanImage
    %
    % DESCRIPTION:
    %   Launch or close the Focal Sweep tool for ScanImage, which provides Z-focus
    %   finding based on image brightness optimization.
    %
    % SYNTAX:
    %   fsweep                    % Launch with default settings
    %   fsweep('param', value)    % Launch with custom parameters
    %   fsweep('close')           % Close any existing instances
    %   fsweep('version')         % Display version information
    %   fs = fsweep(...)          % Return the FocalSweep instance
    %
    % PARAMETERS:
    %   'forceNew'  - Force creation of a new instance (true/false)
    %                 Default: false
    %   'verbosity' - Verbosity level (0=quiet, 1=normal, 2=debug)
    %                 Default: 0
    %   'close'     - Close any existing instances (no value needed)
    %   'version'   - Display version information (no value needed)
    %
    % RETURNS:
    %   fs - Handle to the FocalSweep object (optional)
    %
    % EXAMPLES:
    %   fsweep                       % Launch with default settings
    %   fs = fsweep('forceNew', true) % Force new instance and get handle
    %   fsweep('close')              % Close any existing instances
    %   fsweep('version')            % Display version information
    %
    % REQUIREMENTS:
    %   - ScanImage must be running with 'hSI' in base workspace
    %   - Access to Motor Controls in ScanImage
    %
    % See also:
    %   core.FocalSweep, core.FocalSweepFactory, core.AppConfig
    
    % Copyright (C) 2023-2025
    % Version 1.1.0
    
    % Version information
    FSWEEP_VERSION = '1.1.0';
    FSWEEP_DATE = 'May 2025';
    
    try
        % Check if the 'close' command is provided
        if nargin > 0 && ischar(varargin{1})
            if strcmpi(varargin{1}, 'close')
                % Close any existing instances
                closeInstances();
                
                % Return empty if output requested
                if nargout > 0
                    varargout{1} = [];
                end
                return;
            elseif strcmpi(varargin{1}, 'version')
                % Display version information
                core.AppConfig.showVersion();
                
                % Return version if output requested
                if nargout > 0
                    varargout{1} = core.AppConfig.VERSION;
                end
                return;
            end
        end
        
        % Parse parameters
        p = inputParser;
        p.addParameter('forceNew', false, @islogical);
        p.addParameter('verbosity', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
        p.parse(varargin{:});
        
        % Use the factory to create or get an instance
        if exist('core.FocalSweepFactory', 'class')
            fs = core.FocalSweepFactory.launch('forceNew', p.Results.forceNew, ...
                                               'verbosity', p.Results.verbosity);
        else
            % Create a new instance directly if factory not available
            fs = core.FocalSweep('verbosity', p.Results.verbosity);
        end
        
        % Return the FocalSweep handle if requested
        if nargout > 0
            varargout{1} = fs;
        end
    catch ME
        % Display error message
        errMsg = sprintf('Error launching FocalSweep: %s', ME.message);
        fprintf('%s\n', errMsg);
        
        % Return empty if output requested
        if nargout > 0
            varargout{1} = [];
        end
    end
end

%% Helper function to close instances
function closeInstances()
    try
        % Find all figures with FocalSweep in the name
        figs = findall(0, 'Type', 'figure');
        closedCount = 0;
        
        for i = 1:length(figs)
            if contains(get(figs(i), 'Name'), 'FocalSweep')
                close(figs(i));
                closedCount = closedCount + 1;
            end
        end
        
        % Reset the persistent instance variables if factory exists
        if exist('core.FocalSweepFactory', 'class')
            try
                clear core.FocalSweepFactory.launch
            catch
                % Ignore errors when clearing factory
            end
        end
        
        if closedCount > 0
            fprintf('Closed %d FocalSweep instance(s).\n', closedCount);
        end
    catch ME
        fprintf('Error closing instances: %s\n', ME.message);
    end
end 