classdef FuseChannels < qd.classes.Channel
    properties
        base_channels
        future = []
    end
    methods
        function obj = FuseChannels(base_channels, name)
            if ~iscell(base_channels)
                warning('Using an array for base_channels is deprecated, use a cell array instead');
                base_channels = num2cell(base_channels);
            end
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
            vals = arrayfun(@(x) x{1}.get(), obj.base_channels);
            val = mean(vals);
        end

        function future = set_async(obj, val)
            if ~isempty(obj.future)
                obj.future.resolve();
            end
            future = [];
            for chan = obj.base_channels
                future = future & chan{1}.set_async(val);
            end
            obj.future = future;
        end
    end
end