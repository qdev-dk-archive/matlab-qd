% TODO: Make this work for 2D magnet as well, i.e. phi always 0.0 ?
% I think it works for 2D magnets as well, when magnet axes are 'xz'
% then phi is naturally 0 and you can use setc('rt',[radius,theta])...

classdef OxfMagnet3DSphere < qd.ins.OxfMagnet3D
    properties(GetAccess=public, SetAccess=private)
        cached_field = [];
        phi
        r
        sphere_offsets
        theta
    end
    methods
        function obj = OxfMagnet3DSphere()
            obj.sphere_offsets.theta = 0;
            obj.sphere_offsets.phi = 0;
            obj.reinitialize();
        end

        function chans = channels(obj)
            base_chans = obj.channels@qd.ins.OxfMagnet3D();
            morechans = {};
            if length(obj.axes()) == 3
                morechans = {'phi','rtp'};
            end
            chans = horzcat(base_chans , {'r', 'theta'} , morechans , {'rt'});
        end

        function r = describe(obj, register)
            r = obj.describe@qd.ins.OxfMagnet3D(register);
            r.field.r = obj.r;
            r.field.theta = obj.theta;
            r.field.phi = obj.phi;
            r.sphere_offsets = obj.sphere_offsets;
        end

        function reinitialize(obj)
            obj.cached_field = obj.getc(obj.axes());
            [obj.r,obj.theta,obj.phi] = obj.get_spherical(obj.cached_field);
        end

        function set_offset(obj, theta, phi)
            obj.sphere_offsets.theta = theta;
            obj.sphere_offsets.phi = phi;
            obj.reinitialize();
        end

        function setc(obj, chan, val, varargin)
            future = obj.setc_async( chan, val, varargin{:} );
            future.exec();
        end

        function future = setc_async(obj, chan, val, varargin)
            % This is different to sweep_async as max sweeprate is used for all channels
            % and no initialize is performed (saves time as it doesn't require to know the current field)

            % validate input and get setpoint
            [axes, setpoint] = obj.validate_setpoint( chan, val );

            % ramp to setpoint
            future = obj.setc_async@qd.ins.OxfMagnet3D(axes, setpoint, varargin{:} );
        end

        function future = sweep_async(obj, chan, val, varargin)
            % Sweeps linearly
            % validate input and get setpoint
            [axes, setpoint] = obj.validate_setpoint( chan, val );
            % sweep linearly to setpoint
            future = obj.sweep_async@qd.ins.OxfMagnet3D( axes, setpoint, varargin{:} );
        end

        function val = getc(obj, ax)
            if all(ismember( ax, obj.axes() ))
                val = obj.getc@qd.ins.OxfMagnet3D(ax);
                return
            end

            obj.reinitialize()
            switch ax
                case 'r'
                    val = obj.r;
                case 'theta'
                    val = obj.theta;
                case 'phi'
                    val = obj.phi;
                case 'rtp'
                    val = [obj.r,obj.theta,obj.phi];
                case 'rt'
                    val = [obj.r,obj.theta];
                otherwise
                    warning('No such channel.');
            end
        end

        function out = spheretocart(obj, r, theta, phi )
            x = (r * sin(theta) * cos(phi));
            y = (r * sin(theta) * sin(phi));
            z = (r * cos(theta));
            out = [x,y,z];
        end

        function [r,theta,phi] = carttosphere(obj, field )
            r = sqrt(sum(field.^2));
            if r == 0
                theta = 0;
                phi = 0;
            else
                if length(obj.axes()) == 2
                    % for 2D magnet
                    field = [field(1),0,field(2)]
                end
                theta = acos(field(3) / r);
                phi = atan2(field(2), field(1));
            end
        end

        function [r,theta,phi] = get_spherical(obj,field)
            [r,theta,phi] = obj.carttosphere(field);
            % remove offsets
            theta = theta - obj.sphere_offsets.theta;
            phi = phi - obj.sphere_offsets.phi;
        end

        function out = get_cartesian(obj,r,theta,phi)
            % add offsets
            theta = theta + obj.sphere_offsets.theta;
            phi = phi + obj.sphere_offsets.phi;
            out = obj.spheretocart( r, theta, phi );
        end

        function out = maxr(obj, theta, phi, varargin )
            % Returns max radius floored to 'sig_digits' significant digits for a
            % given theta and phi within x,y,z axes limits
            try
                sig_digits = varargin{1};
            catch
                sig_digits = 8;
            end

            vect = abs(obj.get_cartesian(1,theta,phi));
            vect = vect/max(vect ./ obj.axes_limits);
            out = sqrt(sum(vect.^2));

            % floor to sig_digits significant digits
            out = floor((10^sig_digits)*out)/(10^sig_digits);
        end
    end

    methods(Access=private)
        function r = valid_r(obj, r, theta, phi)
            maxr = obj.maxr(theta, phi);
            if r>maxr
                warning(sprintf('Radius too large, seting to maximum! r = %f',maxr));
                r = maxr;
            end
        end

        function [axes, setpoint] = validate_setpoint(obj, chan, val)
            % xyz fallback
            if all(ismember( chan, obj.axes() ))
                % This function uses the cached_field to calculate the cached theta,phi values.
                % This is not really optimal,but when is this needed anyways?
                setpoint = obj.cached_field;
                [~,pos] = ismember(num2cell(chan),num2cell(obj.axes()));
                setpoint(:,pos) = val;

                % Check for limits
                if any(abs(setpoint) > obj.axes_limits)
                    error('setpoint is out of limits');
                end
                % get the right values in cache
                obj.cached_field = setpoint;
                [obj.r, obj.theta, obj.phi] = obj.get_spherical(setpoint);
                % When we got here, all is good, thus retrurn chan and val
                axes = chan;
                setpoint = val;
            else
                switch chan
                    case 'r'
                        obj.r = val;
                    case 'theta'
                        obj.theta = val;
                    case 'phi'
                        obj.phi = val;
                    case 'rtp'
                        % This assumes val=[r,theta,phi]
                        obj.r     = val(1);
                        obj.theta = val(2);
                        obj.phi   = val(3);
                    case 'rt'
                        % This assumes val=[r,theta]
                        obj.r     = val(1);
                        obj.theta = val(2);
                    otherwise
                        error('No such channel.');
                end
                % Verifying the setpoint is within the limits
                obj.r = obj.valid_r(obj.r, obj.theta, obj.phi);
                % add offsets and calculate setpoint
                setpoint = obj.get_cartesian(obj.r, obj.theta, obj.phi);
                % reduce vector to available axes
                [~,pos] = ismember(num2cell(obj.axes()),{'x','y','z'});
                setpoint = setpoint(:,pos);
                axes = obj.axes();
                obj.cached_field = setpoint;
            end
        end
    end
end
