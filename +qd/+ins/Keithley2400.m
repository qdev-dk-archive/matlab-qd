classdef Keithley2400 < qd.classes.ComInstrument
    % Currently this class only supports current mode.
    % TODO set range.
    methods

        function obj = Keithley2400(com)
            obj = obj@qd.classes.ComInstrument(com);
        end

        function r = model(obj)
            r = 'Keithley 2400 SourceMeter';
        end

        function r = channels(obj)
            r = {'curr', 'volt', 'resist'};
        end

        function reset(obj)
            obj.send('*rst');
            obj.init();
        end

        function init(obj)
            obj.send(':FORM:ELEM VOLT,CURR');
        end

        function set_curr_compliance(obj, level)
            obj.sendf(':CURR:PROT %.16E', level);
        end

        function turn_on_output(obj)
            obj.send(':OUTP:STAT 1')
        end

        function turn_off_output(obj)
            obj.send(':OUTP:STAT 0');
        end

        function setc(obj, channel, value)
            switch channel
                case 'volt'
                    obj.sendf('SOUR:VOLT %.16E', value)
                otherwise
                    error('not supported.')
            end
        end

        function val = getc(obj, channel)
            switch channel
            % How to interpret what is read depends on the configured output
            % format. Here we assume init has been called.
                case 'curr'
                    res = obj.querym(':READ?', '%g, %g');
                    val = res(2);
                case 'volt'
                    res = obj.querym(':READ?', '%g, %g');
                    val = res(1);
                case 'resist'
                    res = obj.querym(':READ?', '%g, %g');
                    val = res(1) / res(2);
                otherwise
                    error('not supported.')
            end
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.ComInstrument(register);
            r.config = struct();
            for q = { ...
                'FORM:ELEM', 'OUTP:STAT', 'OUTP:SMOD', 'ROUT:TERM', 'FUNC:CONC', ...
                'FUNC:ON', 'CURR:RANG:UPP', 'CURR:RANG:AUTO', 'CURR:NPLC', 'CURR:PROT', ...
                'VOLT:RANG:UPP', 'VOLT:RANG:AUTO', 'VOLT:NPLC', 'VOLT:PROT', 'RES:RANG:UPP', ...
                'RES:RANG:AUTO', 'RES:NPLC', 'AVER:STAT', 'AVER:COUN', 'AVER:TCON', ...
                'SOUR:DEL', 'SOUR:FUNC', 'SOUR:CURR:LEV', 'SOUR:CURR:RANG', ...
                'SOUR:VOLT:LEV', 'SOUR:VOLT:RANG', 'SOUR:VOLT:PROT'}
                question = [':' q{1} '?'];
                simplified = lower(strrep(q{1}, ':', '_'));
                r.config.(simplified) = obj.query(question);
            end
        end
        
    end
end