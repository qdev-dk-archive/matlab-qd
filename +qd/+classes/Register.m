classdef Register < handle
    properties
        content = struct()
    end
    methods

        function name = put(obj, namespace, value)
            ns = obj.get_ns(namespace);
            name = value.name;
            if ~ns.isKey(name)
                ns(name) = value;
            else
                prev = ns(name);
                if prev ~= value
                    i = 2;
                    while true
                        name = [value.name num2str(i)];
                        if ~ns.isKey(name)
                            warning( ...
                                ['A previous item has already been registered ' ...
                                'with that name. Inventing a new one.']);
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

        function meta = describe(obj)
            meta = struct;
            previously_described = containers.Map();
            while true
                all_described = true;
                for field = transpose(fieldnames(obj.content))
                    ns = obj.content.(field{1});
                    for name = ns.keys()
                        pkey = [field{1} '/' name{1}];
                        if previously_described.isKey(pkey)
                            continue
                        end
                        all_described = false;
                        previously_described(pkey) = true;
                        if ~isfield(meta, field{1})
                            meta.(field{1}) = {};
                        end
                        descr = ns(name{1}).describe(obj);
                        if ~strcmp(descr.name, name{1})
                            descr.registered_name = name{1};
                        end
                        meta.(field{1}){end + 1} = descr;
                    end
                end
                if all_described
                    break;
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