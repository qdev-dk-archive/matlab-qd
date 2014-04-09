classdef SR5210LockIn < qd.classes.ComInstrument
    properties
        sensitivity_dict
        sensitivity
    end
    methods

        function obj = SR5210LockIn(com)
            obj@qd.classes.ComInstrument(com);
            obj.sensitivity_dict = [100e-9, ...
                300e-9, ...
                1e-6, ...
                3e-6, ...
                10e-6, ...
                30e-6, ...
                100e-6, ...
                300e-6, ...
                1e-3, ...
                3e-3, ...
                10e-3, ...
                30e-3, ...
                100e-3, ...
                300e-3, ...
                1, ...
                3];
            obj.getc('sensitivity');
        end

        function r = model(obj)
            r = 'SR5210';
        end

        function r = channels(obj)
            r = {'X' 'Y' 'R', 'theta', 'freq', 'sensitivity'};
        end
        
        function setc(obj, channel, value)
            switch channel
                case 'OA'
                    obj.sendf('OA %i', value);
            end
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
                        val = val*1e-4*obj.sensitivity;
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
                case 'sensitivity'
                    try
                        val = obj.querym('SEN', '%f');
                        val = obj.sensitivity_dict(val+1);
                        obj.sensitivity = val;
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