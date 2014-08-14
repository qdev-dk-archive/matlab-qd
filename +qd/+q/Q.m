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

        function plan = send_sms(obj, varargin)
            plan = obj.make_plan().send_sms(varargin{:});
        end
        function plan = as(obj, varargin)
            plan = obj.make_plan().as(varargin{:});
        end
        function plan = with(obj, varargin)
            plan = obj.make_plan().with(varargin{:});
        end
        function plan = without(obj, varargin)
            plan = obj.make_plan().without(varargin{:});
        end
        function plan = do(obj, varargin)
            plan = obj.make_plan().do(varargin{:});
        end
        function plan = sw(obj, varargin)
            plan = obj.make_plan().sw(varargin{:});
        end
        function go(obj, varargin)
            obj.make_plan().go(varargin{:});
        end
    end
end