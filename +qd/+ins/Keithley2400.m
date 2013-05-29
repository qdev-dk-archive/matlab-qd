classdef Keithley2400 < qd.classes.ComInstrument
    % Currently this class only supports sourcing a voltage and reading currents.
    % TODO set range.
    
    properties
        ramp_rate = []; % Ramp rate in V/s. Default is [] which disables ramping.
        ramp_step_size = 10E-3; % Step size to make when ramping. Default is 10 mV
    end

    properties(Access=private)
        output_format_set = false;
    end
    
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
            obj.set_output_format();
        end

        function set_output_format(obj)
            obj.send(':FORM:ELEM VOLT,CURR');
            obj.output_format_set = true;
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
                    if ~isempty(obj.ramp_rate)
                        obj.set_volt_with_ramp(value)
                    else
                        obj.sendf('SOUR:VOLT %.16E', value)
                    end
                otherwise
                    error('not supported.')
            end
        end

        function val = getc(obj, channel)
            % This is not fool-proof, since it does not
            % detect if changes are made.
            if ~obj.output_format_set
                obj.set_output_format();
            end
            switch channel
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

    methods(Access=private)
        function set_volt_with_ramp(obj, val)
            current_value = obj.getc('volt');
            step = obj.ramp_step_size * sign(val - current_value);
            obj.send('SENS:FUNC:OFF:ALL');
            obj.send('SOUR:VOLT:MODE SWE');
            obj.sendf('TRIG:DEL %.16E', obj.ramp_step_size/obj.ramp_rate);
            while true
                first_value = current_value + step;
                number_of_points =  ceil(abs(val - first_value) / obj.ramp_step_size);
                number_of_points = min(2500, number_of_points); % this limit is set by the instrument
                if number_of_points <= 1
                    break
                end
                end_value = current_value + step*number_of_points;
                if val > current_value
                    end_value = min(end_value, val);
                else
                    end_value = max(end_value, val);
                end
                % The keithley calculates all point in the sweep in advance
                % whenever parameters are changed, therefore setting the sweep
                % to two points while setting start and stop greatly speeds up
                % the process.
                obj.send('SOUR:SWE:POIN 2');
                obj.sendf('SOUR:VOLT:START %.16E', first_value);
                obj.sendf('SOUR:VOLT:STOP %.16E', end_value);
                obj.sendf('SOUR:SWE:POIN %d', number_of_points);
                obj.sendf('TRIG:COUN %d', number_of_points);
                obj.send('INIT');
                current_value = end_value;
            end
            obj.send('*OPC?');
            while true
                status = fscanf(obj.com, '%d');
                if ~isempty(status) && status == 1
                    break;
                end
            end
            obj.send('SOUR:VOLT:MODE FIX')
            obj.send('TRIG:COUN 1')
            obj.sendf('TRIG:DEL %.16E', round(abs(current_value - val)/obj.ramp_rate*10000)/10000);
            obj.sendf('SOUR:VOLT %.16E', val);
            obj.send('TRIG:DEL 0');
            obj.send('SENS:FUNC:ON "CURR"');
        end
    end
end