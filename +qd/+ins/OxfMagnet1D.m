classdef OxfMagnet1D < qd.classes.Instrument
    properties
        magnet
    end
    methods

        function obj = OxfMagnet1D()
            obj.magnet = daemon.Client(qd.daemons.OxfMagnet1D.bind_address);
        end

        function chans = channels(obj)
            chans = {'fld'};
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Instrument(register);
            r.field = obj.getc('fld');
        end

        function val = getc(obj, chan)
            switch chan
                case 'fld'
                    val = obj.magnet.remote.get_field();
                otherwise
                    error('No such channel.')
            end
        end

        function set_field_sweep_rate(obj, value)
            if abs(value) > .3; %.3 T/MIN
                error('Magnet ramp rate too high!')
            end
            obj.magnet.remote.set_field_sweep_rate(value);
        end

        function switch_heater(obj, value)
            obj.magnet.remote.switch_heater(value);
        end

        function hold(obj)
            obj.magnet.remote.stop_sweep();
        end

        function val = get_field_sweep_rate(obj)
            val = obj.magnet.remote.get_field_sweep_rate();
        end

        function val = system_report(obj)
            val = obj.magnet.remote.get_status_report();
        end

        function val = get_switch_heater_current(obj)
            val = obj.magnet.remote.get_switch_heater_current();
        end

        function setc(obj, chan, value)
            switch chan
                case 'fld'
                    if abs(value) > 12; %12 T
                        error('Set point too high!')
                    end
                    obj.magnet.remote.set_field(value);
                otherwise
                    error('No such channel.')
            end
        end
    end
end