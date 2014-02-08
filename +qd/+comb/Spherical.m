classdef Spherical < qd.classes.Instrument
    properties(GetAccess=public, SetAccess=private)
        base_channels
        base_offsets
        r
        theta
        phi
    end
    methods
        function obj = Spherical(base_channels)
            if ~iscell(base_channels)
                warning('Using an array for base_channels is deprecated, use a cell array instead');
                base_channels = num2cell(base_channels);
            end
            qd.util.assert(length(base_channels) == 3);
            obj.base_channels = struct();
            obj.base_channels.x = base_channels{1};
            obj.base_channels.y = base_channels{2};
            obj.base_channels.z = base_channels{3};
            obj.base_offsets.theta = 0;
            obj.base_offsets.phi = 0;
            obj.reinitialize();
        end

        function chans = channels(obj)
            chans = {'r', 'theta', 'phi', 'rtp'};
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Instrument(register);
            r.cached_values = struct();
            r.cached_values.r = obj.r;
            r.cached_values.theta = obj.theta;
            r.cached_values.phi = obj.phi;
            r.base_channels = struct();
            for axis = 'xyz'
                r.base_channels.(axis) = register.put('channels', ...
                    obj.base_channels.(axis));
            end
        end
        
        function set_offset(obj, theta, phi)
            obj.base_offsets.theta = theta;
            obj.base_offsets.phi = phi;
            obj.reinitialize();
        end
        
        function setc(obj, chan, val)
            switch chan
            case 'r'
                obj.r = val;
            case 'theta'
                obj.theta = val;
            case 'phi'
                obj.phi = val;
            case 'rtp'
                obj.r = val(1);
                obj.theta = val(2);
                obj.phi = val(3);
            otherwise
                error('No such channel.');
            end
            
            theta = obj.theta + obj.base_offsets.theta;
            phi = obj.phi + obj.base_offsets.phi;
            
            ax = obj.base_channels.x.set_async(obj.r * sin(theta) * cos(phi));
            ay = obj.base_channels.y.set_async(obj.r * sin(theta) * sin(phi));
            az = obj.base_channels.z.set_async(obj.r * cos(theta));
            ax.exec();
            ay.exec();
            az.exec();
        end

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
            obj.theta = acos(z / obj.r) - obj.base_offsets.theta;
            obj.phi = atan2(y, x) - obj.base_offsets.phi;
        end

    end
end