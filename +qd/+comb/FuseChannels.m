classdef FuseChannels < qd.classes.Channel
    properties(Access=private)
        base_channels
    end
    methods
        function obj = FuseChannels(base_channels, name)
            obj.base_channels = base_channels;
            obj.name = name;
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Channel(register);
            r.base_channels = {};
            for chan = obj.base_channels
                r.base_channels{end + 1} = register.put('channels', chan{1});
            end
        end

        function val = get(obj)
            vals = arrayfun(@(x) x.get(), obj.base_channels);
            val = mean(vals);
        end

        function set(obj, val)
            for chan = obj.base_channels
                chan.set(val);
            end
        end
    end
end