function diagnose_motor_controls(varargin)
% DIAGNOSE_MOTOR_CONTROLS - Comprehensive diagnostic tool for ScanImage Motor Controls GUI
%
% Usage:
%   diagnose_motor_controls()           - Display all controls
%   diagnose_motor_controls('filter', 'pushbutton') - Filter by style
%   diagnose_motor_controls('save', true) - Save output to file
%   diagnose_motor_controls('verbose', true) - Show additional properties
%
% Options:
%   'filter'  - Control style to filter (e.g., 'pushbutton', 'edit', 'text')
%   'save'    - Save output to timestamped file (default: false)
%   'verbose' - Show additional properties (default: false)

    % Parse inputs
    p = inputParser;
    addParameter(p, 'filter', '', @ischar);
    addParameter(p, 'save', false, @islogical);
    addParameter(p, 'verbose', false, @islogical);
    parse(p, varargin{:});
    opts = p.Results;
    
    % Find Motor Controls window
    motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
    if isempty(motorFig)
        warning('Motor Controls window not found. Searching for windows with "Motor" in name...');
        allFigs = findall(0, 'Type', 'figure');
        motorFig = [];
        for i = 1:length(allFigs)
            if contains(get(allFigs(i), 'Name'), 'Motor', 'IgnoreCase', true)
                motorFig = allFigs(i);
                break;
            end
        end
        if isempty(motorFig)
            error('No Motor Controls window found. Please ensure ScanImage is running and the Motor Controls window is open.');
        end
    end
    
    % Get all controls
    controls = findall(motorFig);
    
    % Initialize output
    if opts.save
        timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        filename = sprintf('motor_controls_diagnostic_%s.txt', timestamp);
        fid = fopen(filename, 'w');
        outputFunc = @(varargin) fprintf(fid, varargin{:});
    else
        outputFunc = @fprintf;
    end
    
    % Header
    outputFunc('===============================================\n');
    outputFunc('ScanImage Motor Controls Diagnostic Report\n');
    outputFunc('Generated: %s\n', char(datetime('now')));
    outputFunc('===============================================\n\n');
    
    % Window information
    outputFunc('WINDOW INFORMATION:\n');
    outputFunc('-------------------\n');
    outputFunc('Name: %s\n', get(motorFig, 'Name'));
    outputFunc('Tag: %s\n', get(motorFig, 'Tag'));
    outputFunc('Position: [%.0f, %.0f, %.0f, %.0f]\n', get(motorFig, 'Position'));
    outputFunc('Visible: %s\n\n', get(motorFig, 'Visible'));
    
    % Collect control information
    controlInfo = [];
    % Preallocate for better performance
    maxControls = numel(controls);
    controlInfo = cell(maxControls, 1);
    validCount = 0;
    
    for i = 1:maxControls
        info = extractControlInfo(controls(i), opts.verbose);
        if ~isempty(opts.filter) && ~strcmpi(info.style, opts.filter)
            continue;
        end
        validCount = validCount + 1;
        controlInfo{validCount} = info;
    end
    
    % Trim to actual size
    controlInfo = controlInfo(1:validCount);
    if ~isempty(controlInfo)
        controlInfo = [controlInfo{:}];
    end
    
    % Summary statistics
    outputFunc('SUMMARY STATISTICS:\n');
    outputFunc('-------------------\n');
    outputFunc('Total controls found: %d\n', numel(controls));
    if ~isempty(opts.filter)
        outputFunc('Controls matching filter "%s": %d\n', opts.filter, numel(controlInfo));
    end
    
    % Count by type
    if ~isempty(controlInfo)
        styles = {controlInfo.style};
        uniqueStyles = unique(styles);
        outputFunc('\nControl types:\n');
        for i = 1:length(uniqueStyles)
            count = sum(strcmp(styles, uniqueStyles{i}));
            outputFunc('  %-15s: %d\n', uniqueStyles{i}, count);
        end
    end
    outputFunc('\n');
    
    % Detailed control listing
    outputFunc('DETAILED CONTROL LISTING:\n');
    outputFunc('-------------------------\n\n');
    
    if isempty(controlInfo)
        outputFunc('No controls found matching criteria.\n');
    else
        % Group by style
        styles = unique({controlInfo.style});
        for s = 1:length(styles)
            currentStyle = styles{s};
            styleControls = controlInfo(strcmp({controlInfo.style}, currentStyle));
            
            outputFunc('=== %s Controls (%d) ===\n', upper(currentStyle), length(styleControls));
            
            for i = 1:length(styleControls)
                ctrl = styleControls(i);
                outputFunc('\n[%d] %s\n', ctrl.index, ctrl.class);
                outputFunc('    Tag:      %s\n', ctrl.tag);
                outputFunc('    String:   %s\n', ctrl.string);
                outputFunc('    Visible:  %s | Enabled: %s\n', ctrl.visible, ctrl.enable);
                
                if opts.verbose
                    outputFunc('    Position: [%.0f, %.0f, %.0f, %.0f]\n', ctrl.position);
                    outputFunc('    Parent:   %s\n', ctrl.parent);
                    if ~isempty(ctrl.tooltipString)
                        outputFunc('    Tooltip:  %s\n', ctrl.tooltipString);
                    end
                end
                
                if ~isempty(ctrl.callback)
                    outputFunc('    Callback: %s\n', ctrl.callback);
                end
                
                % Special properties for specific control types
                if strcmp(currentStyle, 'edit') && ~isempty(ctrl.userdata)
                    outputFunc('    UserData: %s\n', ctrl.userdata);
                end
            end
            outputFunc('\n');
        end
    end
    
    % Interactive controls analysis
    outputFunc('\nINTERACTIVE CONTROLS ANALYSIS:\n');
    outputFunc('------------------------------\n');
    interactiveControls = controlInfo(~cellfun(@isempty, {controlInfo.callback}));
    outputFunc('Controls with callbacks: %d\n', length(interactiveControls));
    
    if ~isempty(interactiveControls)
        outputFunc('\nCallback summary:\n');
        callbacks = {interactiveControls.callback};
        uniqueCallbacks = unique(callbacks);
        for i = 1:length(uniqueCallbacks)
            count = sum(strcmp(callbacks, uniqueCallbacks{i}));
            outputFunc('  %-40s: %d occurrences\n', uniqueCallbacks{i}, count);
        end
    end
    
    % Close file if saving
    if opts.save
        fclose(fid);
        fprintf('Diagnostic report saved to: %s\n', filename);
    end
end

function info = extractControlInfo(control, verbose)
% Extract relevant information from a control
    info = struct();
    info.index = [];
    info.class = class(control);
    
    % Safe property extraction
    info.tag = safeGet(control, 'Tag', '');
    info.style = safeGet(control, 'Style', info.class);
    info.string = formatString(safeGet(control, 'String', ''));
    info.visible = safeGet(control, 'Visible', 'N/A');
    info.enable = safeGet(control, 'Enable', 'N/A');
    info.callback = formatCallback(safeGet(control, 'Callback', ''));
    
    if verbose
        info.position = safeGet(control, 'Position', [0 0 0 0]);
        info.parent = formatParent(safeGet(control, 'Parent', []));
        info.tooltipString = safeGet(control, 'TooltipString', '');
        info.userdata = formatUserData(safeGet(control, 'UserData', []));
    else
        info.position = [];
        info.parent = '';
        info.tooltipString = '';
        info.userdata = '';
    end
end

function value = safeGet(obj, prop, default)
% Safely get property value with default
    try
        if isprop(obj, prop) || isfield(get(obj), prop)
            value = get(obj, prop);
        else
            value = default;
        end
    catch
        value = default;
    end
end

function str = formatString(input)
% Format string property for display
    if ischar(input)
        str = input;
    elseif iscell(input)
        str = strjoin(input, ' | ');
    elseif isnumeric(input)
        str = num2str(input);
    else
        str = '<complex>';
    end
    % Truncate long strings
    if length(str) > 50
        str = [str(1:47) '...'];
    end
    % Remove newlines
    str = strrep(str, newline, ' ');
end

function str = formatCallback(cb)
% Format callback for display
    if isa(cb, 'function_handle')
        str = func2str(cb);
    elseif ischar(cb)
        str = cb;
    elseif iscell(cb) && ~isempty(cb)
        if isa(cb{1}, 'function_handle')
            str = [func2str(cb{1}) ' (+args)'];
        else
            str = '<cell callback>';
        end
    elseif isempty(cb)
        str = '';
    else
        str = sprintf('<%s>', class(cb));
    end
end

function str = formatParent(parent)
% Format parent object for display
    if isempty(parent)
        str = 'none';
    elseif ishghandle(parent)
        parentTag = safeGet(parent, 'Tag', '');
        parentType = safeGet(parent, 'Type', class(parent));
        if ~isempty(parentTag)
            str = sprintf('%s [%s]', parentType, parentTag);
        else
            str = parentType;
        end
    else
        str = class(parent);
    end
end

function str = formatUserData(data)
% Format UserData for display
    if isempty(data)
        str = '';
    elseif ischar(data)
        str = data;
    elseif isnumeric(data) && numel(data) < 10
        str = mat2str(data);
    elseif isstruct(data)
        fields = fieldnames(data);
        str = sprintf('struct with %d fields', length(fields));
    else
        str = sprintf('<%s>', class(data));
    end
end