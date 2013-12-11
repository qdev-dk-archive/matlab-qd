classdef SRLockIn < qd.classes.ComInstrument
    methods

        function obj = SRLockIn(com)
            obj@qd.classes.ComInstrument(com);
        end

        function r = model(obj)
            r = 'SR830';
        end

        function r = channels(obj)
            r = {'X' 'Y' 'R' 'theta' 'freq' 'display1' 'display2' 'slvl' 'oflt'};
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
                case 'display1'
                    val = obj.querym('OUTR?1', '%f');
                case 'display2'
                    val = obj.querym('OUTR?2', '%f');
                case 'oflt'
                    val = obj.querym('OFLT?', '%d');
                otherwise
                    error('Not supported.')
            end
        end

        function setc(obj, channel, value)
            switch channel
            case 'freq'
                obj.sendf('FREQ %.10f', value);
            case 'slvl'
                obj.sendf('SLVL %.10f', value);
            case 'oflt'
                obj.sendf('OFLT %.1f', value);
            otherwise
                error('Not supported');
            end
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.ComInstrument(register);
            r.config = struct();
            for q = {'PHAS', 'FMOD', 'FREQ', 'RSLP', 'HARM', 'SLVL', 'ISRC', 'IGND', ...
                    'ICPL', 'ILIN', 'SENS', 'RMOD', 'OFLT', 'OFSL', 'SYNC'}
                question = [q{1} '?'];
                simplified = q{1};
                r.config.(simplified) = obj.query(question);
            end
        end
    end
end