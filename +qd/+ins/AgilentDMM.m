classdef AgilentDMM < qd.classes.ComInstrument
    methods

        function  obj = AgilentDMM(com)
            obj@qd.classes.ComInstrument(com);
        end
        
        function r = model(obj)
            r = 'Agilent';
            idn = obj.query('*IDN?');
            for m = {'34401A', '34410A'}
                if strfind(idn, m{1}) ~= -1
                    r = ['Agilent' m{1}];
                end
            end
        end

        function r = channels(obj)
            r = {'in'};
        end

        function val = getc(obj, channel)
            switch channel
                case 'in'
                    val = obj.querym('READ?', '%f');
                otherwise
                    error('Not supported.')
            end
        end
    end
end