classdef OffsetChannel < qd.classes.Channel
% y = OffsetChannel(x, offset, [name])
%
% Constructs a channel y from a channel x, such that
%
%    value of y = value of x - offset
%
% That is, y.set(v) calls x.set(v + offset) 
% and y.get() returns (x.get() - offset).
    properties
        base_channel
        offset
    end
    methods
        function obj = OffsetChannel(base_channel, offset, name)
            obj.base_channel = base_channel;
            obj.offset = offset;
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
            r.offset = obj.offset;
        end

        function future = get_async(obj)
            f = obj.base_channel.get_async();
            offset = obj.offset;
            future = qd.classes.GetFuture(@() f.exec() - offset);
        end

        function future = set_async(obj, val)
            future = obj.base_channel.set_async(val + obj.offset);
        end
    end
end