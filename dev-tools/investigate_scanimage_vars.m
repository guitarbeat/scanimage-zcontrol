% Investigate hSI and hSICtl for ScanImage data access

fprintf('--- Investigating hSI ---\n');
try
    hSI = evalin('base', 'hSI');
    exploreObject(hSI, 'hSI', 0, 2); % limit to depth 2 for readability
catch
    fprintf('hSI not found in base workspace.\n');
end

fprintf('\n--- Investigating hSICtl ---\n');
try
    hSICtl = evalin('base', 'hSICtl');
    exploreObject(hSICtl, 'hSICtl', 0, 2);
catch
    fprintf('hSICtl not found in base workspace.\n');
end

function exploreObject(obj, name, depth, maxDepth)
    if depth > maxDepth
        return;
    end
    indent = repmat('  ', 1, depth);
    if isobject(obj) || isstruct(obj)
        props = fieldnames(obj);
        for i = 1:length(props)
            prop = props{i};
            try
                val = obj.(prop);
                sz = size(val);
                if isobject(val) || isstruct(val)
                    fprintf('%s%s.%s: [%s] %s\n', indent, name, prop, class(val), mat2str(sz));
                    exploreObject(val, [name '.' prop], depth+1, maxDepth);
                elseif isnumeric(val) || islogical(val)
                    fprintf('%s%s.%s: [%s] %s\n', indent, name, prop, class(val), mat2str(sz));
                elseif ischar(val) || isstring(val)
                    fprintf('%s%s.%s: %s\n', indent, name, prop, char(val));
                elseif iscell(val)
                    fprintf('%s%s.%s: cell [%s]\n', indent, name, prop, mat2str(sz));
                else
                    fprintf('%s%s.%s: [%s]\n', indent, name, prop, class(val));
                end
            catch
                fprintf('%s%s.%s: <error accessing>\n', indent, name, prop);
            end
        end
    else
        fprintf('%s%s: [%s] %s\n', indent, name, class(obj), mat2str(size(obj)));
    end
end