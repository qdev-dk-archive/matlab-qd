classdef SRLockIn < qd.classes.FileLikeInstrument
    methods

        function obj = SRLockIn(com)
            obj@qd.classes.FileLikeInstrument(com);
        end

        function r = model(obj)
            r = 'SR830';
        end

        function r = channels(obj)
            r = {'X' 'Y' 'R' 'theta' 'freq'};
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
                otherwise
                    error('Not supported.')
            end
        end

        function setc(obj, channel, value)
            switch channel
            case 'freq'
                obj.sendf('FREQ %.6f', value);
            otherwise
                error('Not supported');
            end
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.FileLikeInstrument(register);
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