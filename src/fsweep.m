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
    %   'verbosity' - Level of output messages (0=quiet, 1=normal, 2=debug)
    %                 Default: 1
    %   'forceNew'  - Force creation of a new instance (true/false)
    %                 Default: false
    %   'close'     - Close any existing instances (no value needed)
    %   'version'   - Display version information (no value needed)
    %
    % RETURNS:
    %   fs - Handle to the FocalSweep object (optional)
    %
    % EXAMPLES:
    %   fsweep                       % Launch with default settings
    %   fsweep('verbosity', 2)       % Launch with debug messages
    %   fs = fsweep('forceNew', true) % Force new instance and get handle
    %   fsweep('close')              % Close any existing instances
    %   fsweep('version')            % Display version information
    %
    % REQUIREMENTS:
    %   - ScanImage must be running with 'hSI' in base workspace
    %   - Access to Motor Controls in ScanImage
    %
    % See also:
    %   core.FocalSweep, core.FocalSweepFactory
    
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
                fprintf('FocalSweep Z-Control version %s (%s)\n', FSWEEP_VERSION, FSWEEP_DATE);
                fprintf('Copyright (C) 2023-2025\n');
                
                % Return version if output requested
                if nargout > 0
                    varargout{1} = FSWEEP_VERSION;
                end
                return;
            end
        end
        
        % Use direct instance creation if no factory exists
        if ~exist('core.FocalSweepFactory', 'class')
            fprintf('FocalSweepFactory not found. Creating instance directly.\n');
            
            % Parse parameters
            p = inputParser;
            p.addParameter('verbosity', 1, @isnumeric);
            p.addParameter('forceNew', false, @islogical);
            p.parse(varargin{:});
            
            % Create a new instance directly
            fs = core.FocalSweep('verbosity', p.Results.verbosity);
        else
            % Use the factory to create or get an instance
            fs = core.FocalSweepFactory.launch(varargin{:});
        end
        
        % Return the FocalSweep handle if requested
        if nargout > 0
            varargout{1} = fs;
        end
    catch ME
        % Handle any errors
        fprintf('Error with FocalSweep: %s\n', ME.message);
        disp(getReport(ME));
        
        % Return empty if output requested
        if nargout > 0
            varargout{1} = [];
        end
        
        % Rethrow to let calling code handle it
        rethrow(ME);
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
            fprintf('FocalSweep: %d instance(s) closed.\n', closedCount);
        else
            fprintf('FocalSweep: No active instances found.\n');
        end
    catch ME
        fprintf('Error closing FocalSweep: %s\n', ME.message);
    end
end 