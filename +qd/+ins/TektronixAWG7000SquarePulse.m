classdef TektronixAWG7000SquarePulse < qd.classes.Instrument
    properties
        awg
        freq = 1E8;
        Ton = 1E-9;
        level = 1E-3;
        is_on = false;
        offset = 0;
    end
    methods
        function obj = TektronixAWG7000SquarePulse(awg)
            obj.awg = awg;
        end

        function c = channels(obj)
           c = {'freq', 'Ton', 'level', 'offset'};
        end

        function setc(obj, chan, val)
            switch chan
                case 'freq'
                    obj.freq = val;
                case 'Ton'
                    obj.Ton = val;
                case 'level'
                    obj.level = val;
                case 'offset'
                    obj.offset = val;
                otherwise
                    error('No such channel');
            end
            obj.update();
            % update has the side-effect of turning of channel 1. If we are
            % supposed to be on, then we call turn_on.
            if obj.is_on
                obj.turn_on();
            end
        end

        function update(obj)
            sampl_freq = obj.awg.querym('sour:freq?', '%f');
            % number of points in the generated waveform.
            n = round(sampl_freq/obj.freq);
            qd.util.assert(n > 0);
            % duty cycle
            d = obj.Ton * obj.freq;
            % number of points that are on.
            m = round(d * n);
            waveform = (1:n < m + 1) * obj.level + obj.offset;
            wname = 'qd_sq_puls';
            obj.awg.upload_waveform_real(wname, waveform);
            obj.awg.sendf('sour1:wav "%s"', wname);
        end

        function turn_on(obj)
            obj.awg.send('awgc:run');
            obj.awg.send('outp1:stat 1');
            obj.is_on = true;
        end

        function turn_off(obj)
            obj.awg.send('outp1:stat 0');
            obj.is_on = false;
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Instrument(register);
            r.awg = register.put('instruments', obj.awg);
            r.freq = obj.freq;
            r.Ton = obj.Ton;
            r.level = obj.level;
        end
    end
end