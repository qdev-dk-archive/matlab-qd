classdef SR5210LockIn < qd.classes.ComInstrument
    methods

        function obj = SR5210LockIn(com)
            obj@qd.classes.ComInstrument(com);
        end

        function r = model(obj)
            r = 'SR5210';
        end

        function r = channels(obj)
            r = {'X' 'Y' 'R', 'theta', 'freq'};
        end

        function val = getc(obj, channel)
            switch channel
                case 'X'
                    val = obj.querym('X', '%f');
                case 'Y'
                    val = obj.querym('Y', '%f');
                case 'R'
                    val = obj.querym('MAG', '%f');
                case 'theta'
                    val = obj.querym('PHA', '%f');
                case 'freq'
                    val = obj.querym('FRQ', '%f');
                otherwise
                    error('Not supported.')
            end
        end
    end
end