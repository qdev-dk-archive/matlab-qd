classdef Model5210 < qd.classes.ComInstrument
    properties
        sensitivity
    end
    properties(SetAccess=private)
        sens_lookup_table
    end
    methods

        function obj = Model5210(com)
            obj@qd.classes.ComInstrument(com);
            obj.update_sensitivity();
            % [100nV 300nV 1uV 3uV ... 3V]
            obj.sens_lookup_table = [...
                100E-9 300E-9 ...
                  1E-6   3E-6 ...
                 10E-6  30E-6 ...
                100E-6 300E-6 ... 
                  1E-3   3E-3 ...
                 10E-3  30E-3 ...
                100E-3 300E-3 ...
                  1      3    ...
            ];
        end

        function r = model(obj)
            r = '5210';
        end

        function r = channels(obj)
            r = {'X' 'Y' 'R' 'theta' 'fast_x'};
        end

        function auto_phase(obj)
            obj.send('AQN');
        end

        function val = getc(obj, channel)
            switch channel
                case 'X'
                    val = obj.decode_sens(obj.querym('X', '%d'));
                case 'Y'
                    val = obj.decode_sens(obj.querym('Y', '%d'));
                case 'R'
                    val = obj.decode_sens(obj.querym('MAG', '%d'));
                case 'theta'
                    val = obj.querym('PHA', '%d') / 1000.0;
                case 'fast_x'
                    val = obj.decode_sens(obj.querym('*', '%d'));
                otherwise
                    error('Not supported.')
            end
        end

        function update_sensitivity(obj)
            obj.sensitivity = obj.querym('SENS', '%d');
        end

        function val = decode_sens(obj, p)
            if isempty(obj.sensitivity)
                obj.update_sensitivity();
            end
            val = obj.sens_lookup_table(obj.sensitivity + 1) * p / 10000.0;
        end


        function r = describe(obj, register)
            r = obj.describe@qd.classes.ComInstrument(register);
            r.config = struct();
            for q = {'SEN', 'F2F', 'XDB', 'TC', 'X', 'Y'}
                r.config.(q{1}) = obj.query(q{1});
            end
        end
    end
end