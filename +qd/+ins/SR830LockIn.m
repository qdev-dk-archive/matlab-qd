classdef SR830LockIn < qd.classes.ComInstrument
    properties
        time_const_choices = [10e-6,30e-6,100e-6,300e-6,1e-3,3e-3,10e-3,30e-3,100e-3,300e-3,1,3,10,30,100,300,1e3,3e3,10e3,30e3];
        sensitivity_volt = [2e-9,5e-9,10e-9,20e-9,50e-9,100e-9,200e-9,500e-9,1e-6,2e-6,5e-6,10e-6,20e-6,50e-6,100e-6,200e-6,500e-6,1e-3,2e-3,5e-3,10e-3,20e-3,50e-3,100e-3,200e-3,500e-3,1];
        sensitivity_curr = [2e-15,5e-15,10e-15,20e-15,50e-15,100e-15,200e-15,500e-15,1e-12,2e-12,5e-12,10e-12,20e-12,50e-12,100e-12,200e-12,500e-12,1e-9,2e-9,5e-9,10e-9,20e-9,50e-9,100e-9,200e-9,500e-9,1];
    end

    methods

        function obj = SR830LockIn(com)
            obj@qd.classes.ComInstrument(com);
        end

        function r = model(obj)
            r = 'SR830';
        end

        function r = channels(obj)
            r = {'X' 'Y' 'R' 'theta' 'freq' 'display1' 'display2' 'slvl' 'ampl'};
        end

        function val = getc(obj, channel)
            switch channel
                case 'X'
                    val = obj.querym('OUTP?1', '%f');
                case 'Y'
                    val = obj.querym('OUTP?2', '%f');
                case 'R'
                    val = obj.querym('OUTP?3', '%f');
                case 'theta'
                    val = obj.querym('OUTP?4', '%f');
                case 'freq'
                    val = obj.querym('FREQ?', '%f');
                case 'slvl'
                    val = obj.querym('SLVL?', '%f');
                case 'ampl'
                    val = obj.querym('SLVL?', '%f');
                case 'display1'
                    val = obj.querym('OUTR?1', '%f');
                case 'display2'
                    val = obj.querym('OUTR?2', '%f');
                case 'oflt'
                    val = obj.querym('OFLT?', '%f');
                case 'sens'
                    val = obj.querym('SENS?', '%f');

                otherwise
                    error('Not supported.')
            end
        end

        function setc(obj, channel, value)
            switch channel
            case 'freq'
                obj.sendf('FREQ %.10f', value);
            case 'oflt'
                obj.sendf('OFLT %.10f', value);
            case 'sens'
                obj.sendf('SENS %.10f', value);
            case 'slvl'
                % amplitude
                obj.sendf('SLVL %.10f', value);
            case 'ampl'
                % amplitude
                obj.sendf('SLVL %.10f', value);
            otherwise
                error('Not supported');
            end

        end

        function set_time_constant(obj,value)
            [c index] = min(abs(obj.time_const_choices-value));
            if obj.time_const_choices(index) ~= value
                warning(sprintf('Integration time %f not available. Now set to the closest value: %f',value,obj.time_const_choices(index)));
            end
            % obj.sendf('OFLT %.1f', index-1);
            obj.setc('oflt',index-1)
        end

        function val = get_time_constant(obj,value)
            index = obj.getc('oflt');
            val = obj.time_const_choices(index+1);
        end

        function set_sensitivity(obj,value)
            senslist = obj.sensitivity_volt;
            [c index] = min(abs(senslist-value));
            if c ~= value
                warning(sprintf('Sensitivity of %f not available. Now set to the closest value: %f',value,c));
            end
            obj.sendf('SENS %.1f', index-1);
        end

        function val = get_sensitivity(obj,value)
            senslist = obj.sensitivity_volt;
            index = obj.querym('SENS?', '%f');
            val = senslist(index+1);
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.ComInstrument(register);
            r.config = struct();
            for q = {'PHAS', 'FMOD', 'FREQ', 'RSLP', 'HARM', 'SLVL', 'ISRC', 'IGND', ...
                    'ICPL', 'ILIN', 'SENS', 'RMOD', 'OFLT', 'OFSL', 'SYNC'};
                question = [q{1} '?'];
                simplified = q{1};
                r.config.(simplified) = obj.query(question);
            end
            % Save timeconst so it is readable
            r.config.timeconst = obj.time_const_choices(str2num(r.config.OFLT)+1);
            % Save sensitivity so it is readable
            senslist = obj.sensitivity_volt;
            r.config.sensitivity = senslist(str2num(r.config.SENS)+1);
            % Save amplitude with a nice name
            r.config.ampl = r.config.SLVL;
        end
    end
end
