classdef MemoizeChannel < qd.classes.Channel
    properties(Access=private)
        base_channel
        memoize_time
        last_time
        last_value
    end
    methods
        function obj = MemoizeChannel(base_channel, memoize_time)
            obj.base_channel = base_channel;
            obj.memoize_time = memoize_time;
        end

        function name = default_name(obj)
            name = obj.base_channel.name;
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Channel(register);
            r.base_channel = register.put('channels', obj.base_channel{1});
            r.memoize_time = obj.memoize_time;
        end

        function val = get(obj)
            if isempty(obj.last_time) || toc(obj.last_time) > memoize_time
                obj.last_value = obj.base_channel.get();
                obj.last_time = tic();
            end
            val = obj.last_value;
        end

        function set(obj, val)
            obj.base_channel.set(val);
        end
    end
end