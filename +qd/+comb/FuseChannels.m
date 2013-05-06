classdef FuseChannels < qd.classes.Channel
    properties(Access=private)
        base_channels
    end
    methods
        function obj = FuseChannels(base_channels, name)
            obj.base_channels = base_channels;
            obj.name = name;
        end

        function val = get()
            vals = arrayfun(@(x) x.get(), obj.base_channels);
            val = mean(vals);
        end

        function set(val)
            for chan = obj.base_channels
                chan.set(val);
            end
        end
    end
end