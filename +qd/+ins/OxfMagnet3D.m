classdef OxfMagnet3D < qd.classes.Instrument
    properties
        magnet
    end
    methods

        function obj = OxfMagnet3D()
            obj.magnet = daemon.Client(qd.daemons.OxfMagnet3D.bind_address);
        end

        function chans = channels(obj)
            chans = {'x', 'y', 'z'};
        end

        function set_ramp_rate(obj, ramp_rate, varargin)
            qd.util.assert(ramp_rate < 0.25); % Handle this better.
            p = inputParser();
            p.addParamValue('axis', [], @(x)ismember(x, 'xyz'));
            p.parse(varargin{:});
            axis = p.Results.axis;
            for ax = 'xyz'
                if ~isempty(axis) && ax ~= axis
                    continue;
                end
                obj.magnet.remote.set(ax, 'SIG:RFST', ramp_rate, '%.10f');
            end
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Instrument(register);
            r.field = {obj.getc('x'), obj.getc('y'), obj.getc('z')};
        end

        function val = getc(obj, chan)
            val = obj.magnet.remote.read(chan, 'SIG:FLD', '%fT');
        end

        function setc(obj, chan, value)
            obj.magnet.remote.set(chan, 'SIG:FSET', value, '%.10f');
            if value == 0.0
                obj.magnet.remote.set(chan, 'ACTN', 'RTOZ');
            else
                obj.magnet.remote.set(chan, 'ACTN', 'RTOS');
            end
            % We start by waiting 100 ms. Each time we read the state and we are still
            % ramping, we wait 25% longer. delay = 2s is max.
            delay = 0.1;
            while true
                pause(delay);
                actn = obj.magnet.remote.read(chan, 'ACTN');
                if strcmp(actn, 'HOLD')
                    break
                end
                fld = obj.getc(chan);
                if abs(fld - value) <= 1E-4
                    break
                end
                delay = min(delay * 1.25, 2.0);
            end
        end
    end
end