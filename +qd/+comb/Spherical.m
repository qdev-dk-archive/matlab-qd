classdef Spherical < qd.classes.Instrument
    properties(GetAccess=public, SetAccess=private)
        base_channels
        r
        theta
        phi
    end
    methods
        function obj = Spherical(base_channels)
            qd.util.assert(length(base_channels) == 3);
            obj.base_channels = struct();
            obj.base_channels.x = base_channels(1);
            obj.base_channels.y = base_channels(2);
            obj.base_channels.z = base_channels(3);
            obj.reinitialize();
        end

        function chans = channels(obj)
            chans = {'r', 'theta', 'phi'};
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Instrument(register);
            r.cached_values = obj.cached_values;
            r.base_channels = struct();
            for axis = 'xyz'
                r.base_channels.(axis) = register.put('channels', ...
                    obj.base_channels.(axis));
            end
        end

        function setc(obj, chan, val)
            switch chan
            case 'r'
                obj.r = val;
            case 'theta'
                obj.theta = val;
            case 'phi'
                obj.phi = val;
            otherwise
                error('No such channel.');
            end
            obj.base_channels.x.set(obj.r * sin(obj.theta) * cos(obj.phi));
            obj.base_channels.y.set(obj.r * sin(obj.theta) * sin(obj.phi));
            obj.base_channels.z.set(obj.r * cos(obj.theta));
        end
    end
    methods(Access = private)

        function reinitialize(obj)
            x = obj.base_channels.x.get();
            y = obj.base_channels.y.get();
            z = obj.base_channels.z.get();
            obj.r = sqrt(x^2 + y^2 + z^2);
            if obj.r == 0
                obj.theta = 0;
                obj.phi = 0;
                return
            end
            obj.theta = acos(z / r);
            obj.phi = atan2(y, x);
        end

    end
end