classdef AgilentAWG < qd.classes.ComInstrument
    properties
        current_future;
    end
    methods

        function  obj = AgilentAWG(com)
            obj@qd.classes.ComInstrument(com);
        end

        function r = model(obj)
            r = 'Agilent';
            idn = obj.query('*IDN?');
            for m = {'33210A', '33250A'}
                if strfind(idn, m{1}) ~= -1
                    r = ['Agilent' m{1}];
                end
            end
        end

        function r = channels(obj)
            r = {'freq','ampl','offs','dev','volt','func'};
        end
           
        function r = fuctions(obj)
            r = {'SIN', 'SQU', 'RAMP', 'PULS', 'NOIS', 'DC', 'USER'};
        end
        
        function setc(obj, channel, value)
            switch channel
                case 'freq'
                    obj.sendf('FREQ %.16E', value);
                case 'ampl'
                    obj.sendf('VOLT:UNIT VPP'); % setting units to peak-peak voltage
                    obj.sendf('VOLT %.16E', value);
                case 'offs'
                    obj.sendf('VOLT:OFFS %.16E', value);
                case 'dev'
                    obj.sendf('FM:DEV %.16E', value);
                case 'volt'
                    obj.sendf('VOLT:UNIT VPP'); % setting units to peak-peak voltage
                    obj.sendf('VOLT %.16E', value);
                case 'func'
                    avaliable = {'SIN', 'SQU', 'RAMP', 'PULS', 'NOIS', 'DC', 'USER'};
                    if any(ismember(avaliable,value))
                        obj.sendf('FUNC %s', value)
                    else
                        error('not supported.')
                    end
                otherwise
                    error('not supported.')
            end
        end

        function turn_on_output(obj)
            obj.send('OUTP 1')
        end

        function turn_off_output(obj)
            obj.send('OUTP 0')
        end

        function val = getc(obj, channel)
            switch channel
                case 'freq'
                    val = obj.querym('FREQ?', '%f');
                case 'ampl'
                    val = obj.querym('VOLT?', '%f');
                case 'offs'
                    val = obj.querym('VOLT:OFFS?', '%f');
                case 'dev'
                    val = obj.querym('FM:DEV?', '%f');
                case 'volt'
                    val = obj.querym('VOLT?', '%f');
                case 'func'
                    val = obj.querym('FUNC?', '%s');
                otherwise
                    error('not supported.')
            end
        end

        function playsound(obj, varargin)
            % THIS CHANGES CURRENT SETTINGS!!!
            num = 0; % Default value
            if ~isempty(varargin)
                num = varargin{1};
            end
            switch num
                case 0
                    obj.send('OUTP ON');
                    obj.send(sprintf('APPL:SIN %f, 2.0, 0',1));

                    for i = 1:2
                        for j = 10:5:50
                            obj.send(sprintf('FREQ %f',j*10));
                            pause(0.02)
                        end
                    end

                    obj.send(sprintf('FREQ %f',1));
                    obj.send('VOLT 1')
                otherwise
                    warning('Sound not available.')
            end
        end




        function apply(obj, mode, freq, amp, offset)
            str = sprintf('APPL:%s %f, %f, %f', mode, freq, amp, offset);
            obj.sendf(str);
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.ComInstrument(register);
            r.config = struct();
            for q = {'DEV','FREQ', 'VOLT'}
                if strcmp(q{1},'DEV')
                    question = ['FM:DEV', '?'];
                else
                    question = [q{1} '?'];
                end
                simplified = q{1};
                r.config.(simplified) = obj.query(question);
            end
        end
    end
end
