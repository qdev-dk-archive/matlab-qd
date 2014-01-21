classdef OxfMagnet3D < qd.classes.Instrument
    properties
        magnet
    end
    properties(Access=private)
        axes_cache = []
    end
    methods

        function obj = OxfMagnet3D()
            obj.magnet = daemon.Client(qd.daemons.OxfMagnet3D.bind_address);
        end

        function axes = axes(obj)
            % Not all magnets have 3 dimensions. The daemon knows.
            if isempty(obj.axes_cache)
                obj.axes_cache = obj.magnet.remote.get_axes();
            end
            axes = obj.axes_cache;
        end

        function chans = channels(obj)
            chans = num2cell(obj.axes());
        end

        % In T/min. Optionally takes the axis to set the ramp rate for.
        function set_ramp_rate(obj, ramp_rate, varargin)
            qd.util.assert(ramp_rate < 0.25); % TODO: Handle this better.
            p = inputParser();
            p.addOptional('axis', [], @(x)ismember(x, obj.axes()));
            p.parse(varargin{:});
            axis = p.Results.axis;
            for ax = obj.axes()
                if ~isempty(axis) && ax ~= axis
                    continue;
                end
                obj.magnet.remote.set(ax, 'SIG:RFST', ramp_rate, '%.10f');
            end
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Instrument(register);
            r.field = struct;
            for axis = obj.axes()
                r.field.(ax) = obj.getc(ax)
            end
        end

        function val = getc(obj, chan)
            val = obj.magnet.remote.read(chan, 'SIG:FLD', '%fT');
        end

        function unclamp_all(obj)
            for ax = obj.axes()
                obj.magnet.remote.set(ax, 'ACTN', 'HOLD');
            end
        end

        function switch_heater(obj, axis, turn_on)
            qd.assert(ismember(axis, obj.axes()))
            sw = 'OFF';
            if turn_on
                sw = 'ON';
            end
            obj.magnet.remote.set(ax, 'SIG:SWHT', sw);
        end

        function switch_all_heaters(obj, turn_on)
            for ax = obj.axes()
                obj.switch_heater(ax, turn_on)
            end
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