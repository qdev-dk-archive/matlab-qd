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

        function hold_magnet(obj)
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

        function set_and_wait(obj, chan, value)
            %
            % Sets the value of the field and displays a progress bar.
            % If progress bar is closed, sweep is terminated and field stops sweeping.
            switch chan
                case 'fld'
                    obj.setc(chan, value);
                    sweep_rate = obj.get_field_sweep_rate();
                    curval = obj.getc(chan);
                    deltaB = abs(value-curval);
                    h = waitbar(0,'Initializing waitbar...');
                    set(h,'Name','Setting B-field');
                    while abs(value-curval)>0.0001
                        pause(0.1);
                        curval = obj.getc(chan);
                        if ishandle(h)
                            waitbar(abs(abs(value-curval)-deltaB)/deltaB,h,sprintf('B = %f T...',curval))
                        else
                            % Progress window has been closed
                            disp(sprintf('Sweep cancelled at B = %f T', curval));
                            obj.setc(chan, curval);
                            break
                        end
                    end
                    if ishandle(h)
                        close(h);
                    end
                otherwise
                    error('No such channel.')
            end
        end
    end
end