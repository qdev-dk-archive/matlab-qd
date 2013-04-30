classdef Register < handle
    properties(Access=private)
        content = struct()
    end
    methods
        function name = put(obj, namespace, value)
            ns = obj.get_ns(namespace);
            if ~ns.isKey(value.name)
                ns(value.name) = value;
                name = value.name;
            else
                prev = ns(value.name);
                if prev ~= value
                    warning( ...
                        ['A previous item has already been registered ' ...
                        'with that name. Inventing a new one.']);
                    i = 2;
                    while true
                        name = [value.name num2str(i)];
                        if ~ns.isKey(name)
                            ns(name) = value;
                            break;
                        elseif ns(name) == value
                            break;
                        end
                        i = i + 1;
                    end
                end
            end
        end
    end

    methods(Access=private)
        function ns = get_ns(obj, namespace)
            if ~isfield(obj.content, namespace)
                ns = containers.Map();
                obj.content.(namespace) = ns;
            else
                ns = obj.content.(namespace);
            end
        end
    end
end