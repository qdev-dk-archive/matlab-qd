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
                    try
                        val = obj.querym('X', '%f');
                    catch Exception;
                        warning(Exception.message);
                        val = 0;
                    end
                case 'Y'
                    try
                        val = obj.querym('Y', '%f');
                    catch Exception;
                        warning(Exception.message);
                        val = 0;
                    end
                case 'R'
                    try
                        val = obj.querym('MAG', '%f');
                    catch Exception;
                        warning(Exception.message);
                        val = 0;
                    end
                case 'theta'
                    try
                        val = obj.querym('PHA', '%f');
                    catch Exception;
                        warning(Exception.message);
                        val = 0;
                    end
                case 'freq'
                    try
                        val = obj.querym('FRQ', '%f');
                    catch Exception;
                        warning(Exception.message);
                        val = 0;
                    end
                otherwise
                    error('Not supported.')
            end
        end
    end
end