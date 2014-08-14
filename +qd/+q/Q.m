classdef Q < handle
    properties
        setup
        store
        meta = struct
        inputs = qd.q.Inputs()
        cellphone = ''
    end
    methods
        % Add a default input for jobs spawned from this Q.
        function add_input(obj, name_or_channel)
            chan = obj.resolve_channel(name_or_channel);
            obj.inputs = obj.inputs.with(chan);
        end

        function chan = resolve_channel(obj, name_or_channel)
            chan = name_or_channel;
            if ischar(name_or_channel)
                if isempty(obj.setup)
                    error(['You need to configure a setup for this run before '...
                        'you can add a channel by name.']);
                end
                chan = obj.setup.find_channel(name_or_channel);
            end
        end

        function plan = make_plan(obj)
            plan = qd.q.Plan(obj, obj.inputs);
        end
    end
end