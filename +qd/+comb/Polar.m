classdef Polar < qd.classes.Instrument
    properties(GetAccess=public, SetAccess=private)
        base_channels
        base_offsets
        r
        theta
    end
    methods
        function obj = Polar(base_channels)
            if ~iscell(base_channels)
                warning('Using an array for base_channels is deprecated, use a cell array instead');
                base_channels = num2cell(base_channels);
            end
            qd.util.assert(length(base_channels) == 2);
            obj.base_channels = struct();
            obj.base_channels.x = base_channels{1};
            obj.base_channels.y = base_channels{2};
            obj.base_offsets.theta = 0;
            obj.reinitialize();
        end

        function chans = channels(obj)
            chans = {'r', 'theta'};
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Instrument(register);
            r.cached_values = struct();
            r.cached_values.r = obj.r;
            r.cached_values.theta = obj.theta;
            r.base_channels = struct();
            for axis = 'xy'
                r.base_channels.(axis) = register.put('channels', ...
                    obj.base_channels.(axis));
            end
        end
        
        function set_offset(obj, theta, phi)
            obj.base_offsets.theta = theta;
            obj.reinitialize();
        end
        
        function setc(obj, chan, val)
            switch chan
            case 'r'
                obj.r = val;
            case 'theta'
                obj.theta = val;
            otherwise
                error('No such channel.');
            end
            
            theta = obj.theta + obj.base_offsets.theta;
            
            ax = obj.base_channels.x.set_async(obj.r * cos(theta));
            ay = obj.base_channels.y.set_async(obj.r * sin(theta));
            ax.exec();
            ay.exec();
        end

        function reinitialize(obj)
            x = obj.base_channels.x.get();
            y = obj.base_channels.y.get();
            obj.r = sqrt(x^2 + y^2);
            if obj.r == 0
                obj.theta = 0;
                return
            end
            obj.theta = acos(x / obj.r) - obj.base_offsets.theta;
        end

    end
end