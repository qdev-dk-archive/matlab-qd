classdef ScaledChannel < qd.classes.Channel
% y = ScaledChannel(x, scaling, [name])
%
% Constructs a channel y from a channel x, such that
%
%    value of y = scaling * value of x
%
% That is, y.set(v) calls x.set(v * scaling)
% and y.get() returns (x.get() / scaling).
    properties
        base_channel
        scaling
    end
    methods
        function obj = ScaledChannel(base_channel, scaling, name)
            obj.base_channel = base_channel;
            obj.scaling = scaling;
            if nargin == 3
                obj.name = name;
            end
        end

        function r = default_name(obj)
            r = ['off_', obj.base_channel.name];
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Channel(register);
            r.base_channel = register.put('channels', obj.base_channel);
            r.scaling = obj.scaling;
        end

        function future = get_async(obj)
            f = obj.base_channel.get_async();
            scaling = obj.scaling;
            future = qd.classes.GetFuture(@() f.exec() / scaling);
        end

        function future = set_async(obj, val)
            future = obj.base_channel.set_async(val * obj.scaling);
        end
    end
end