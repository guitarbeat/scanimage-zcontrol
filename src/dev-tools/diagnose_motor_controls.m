% diagnose_motor_controls.m
% Diagnostic script to explore ScanImage Motor Controls GUI
% Lists all UI controls, their tags, styles, strings, and callbacks

motorFig = findall(0, 'Type', 'figure', 'Tag', 'MotorControls');
if isempty(motorFig)
    error('Motor Controls window not found. Please ensure ScanImage is running and the Motor Controls window is open.');
end

controls = findall(motorFig);

fprintf('Found %d controls in Motor Controls window:\n', numel(controls));
for i = 1:numel(controls)
    c = controls(i);
    try
        tag = get(c, 'Tag');
    catch
        tag = '';
    end
    try
        style = get(c, 'Style');
    catch
        style = class(c);
    end
    try
        str = get(c, 'String');
    catch
        str = '';
    end
    try
        cb = get(c, 'Callback');
    catch
        cb = '';
    end
    fprintf('Control %2d: %-12s | Tag: %-15s | String: %-20s | Style: %-10s | Callback: %s\n', ...
        i, class(c), tag, mat2str(str), style, func2str_if_func(cb));
end

function s = func2str_if_func(cb)
    if isa(cb, 'function_handle')
        s = func2str(cb);
    elseif ischar(cb)
        s = cb;
    elseif isempty(cb)
        s = '';
    else
        s = '<non-func>';
    end
end 