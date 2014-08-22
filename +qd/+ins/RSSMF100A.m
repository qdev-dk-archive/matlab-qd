classdef RSSMF100A < qd.classes.ComInstrument
    methods
        function obj = RSSMF100A(varargin)
            obj@qd.classes.ComInstrument(varargin{:});
        end

        function cs = channels(obj)
            cs = {'freq', 'pow'};
        end

        function setc(obj, chan, val)
            switch chan
                case 'freq'
                    obj.sendf('FREQ %.11f', val);
                case 'pow'
                    obj.sendf('POW %.11f', val);
                otherwise
                    error('No such channel');
            end
        end

        function val = getc(obj, chan)
            switch chan
                case 'freq'
                    val = obj.querym('FREQ?', '%f');
                case 'pow'
                    val = obj.querym('POW?', '%f');
                otherwise
                    error('No such channel');
            end
        end

        function turn_on(obj)
            obj.send('OUTP 1')
        end

        function turn_off(obj)
            obj.send('OUTP 0')
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.ComInstrument(register);
            r.freq = obj.getc('freq');
            r.pow = obj.getc('pow');
            r.is_on = obj.querym('OUTP?', '%d');
        end
    end
end