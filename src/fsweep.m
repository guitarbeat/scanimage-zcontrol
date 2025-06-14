% src\fsweep.m
function varargout = fsweep(varargin)
% fsweep - Launch or manage the Focal Sweep Tool for ScanImage.
%
% SYNTAX:
%   fsweep()                     % Launch with default settings
%   fsweep('param', value)       % Launch with custom parameters
%   fsweep('close')              % Close any existing instances
%   fsweep('version')            % Display version information
%   fs = fsweep(...)             % Return the FocalSweepApp instance
%
% REQUIREMENTS:
%   - ScanImage running with 'hSI' in base workspace
%   - Motor Controls accessible in ScanImage

persistent instance;

% Handle special commands
if nargin > 0 && ischar(varargin{1})
    cmd = lower(varargin{1});
    switch cmd
        case 'close'
            if ~isempty(instance) && isvalid(instance)
                instance.closeFigure();
                delete(instance);
                instance = [];
                fprintf('FocalSweep instance closed.\n');
            end
            if nargout, varargout{1} = []; end
            return;

        case 'version'
            fprintf('FocalSweep version %s (%s)\n', ...
                FocalSweepApp.VERSION, FocalSweepApp.BUILD_DATE);
            if nargout, varargout{1} = FocalSweepApp.VERSION; end
            return;
    end
end

% Validate or create instance
isValidInstance = ~isempty(instance) && isvalid(instance) && ...
                  ~isempty(instance.gui) && isvalid(instance.gui.hFig);

% Parse optional inputs
p = inputParser;
p.addParameter('forceNew', false, @islogical);
p.addParameter('verbosity', 0, @isnumeric);
p.parse(varargin{:});

if isValidInstance && ~p.Results.forceNew
    figure(instance.gui.hFig);
    obj = instance;
else
    if isValidInstance && p.Results.forceNew
        delete(instance);
    end
    try
        obj = FocalSweepApp(p.Results);
        instance = obj;
    catch ME
        fprintf('Error launching FocalSweep: %s\n', ME.message);
        fprintf('%s\n', ME.getReport('extended', 'on'));
        if nargout, varargout{1} = []; end
        return;
    end
end

if nargout, varargout{1} = obj; end
end
