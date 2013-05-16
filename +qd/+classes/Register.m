classdef Register < handle
% A register is used as part of meta data generation. It solves a simple
% problem. Say you have a qd.Setup containing two channels, both belonging to
% the same instrument. To describe one of these channels completely you need
% to describe both the channel and the instrument it belongs to. What you do
% not want, is to include the description of the instrument twice. To solve
% this, each channel calls 'name = register.put('instruments', ins)' to get a
% unique name for the instrument. When, at some point, register.describe() is
% called, it will include a description of the instrument.
%
% The Register class handles cyclical references between elements (for
% instance, between an instrument and a channel), and other such oddities.
    properties
        content = struct()
    end
    methods

        function name = put(obj, namespace, value)
        % Place 'value' in the namespace named 'namespace'. Returns a name
        % associated with value guaranteed to be unique in that namespace.
        % 'value' should have a name property which is used as a basis for
        % name generation, and a 'describe' method, taking this register as an
        % argument, and generating metadata. 'put' does nothing is 'value' is
        % already in the register.
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
        % Form metadata describing all items in every namespace of this
        % register. If, during the 'describe' call of each element in the
        % register, more element are put in the register, these will also be
        % included in the returned metadata (moral is: you do not have to
        % worry about this happening).
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
                        descr.registered_name = name{1};
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