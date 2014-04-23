classdef QDAC < qd.classes.ComInstrument
    properties(Access=private)
        range_low
        range_high
        ramp_rate
    end
    
    methods
        function obj = QDAC(port)
            obj.com = serial(port, ...
                'BaudRate', 115200, ...
                'DataTerminalReady', 'off', ...
                'Terminator', {'CR/LF', 'CR/LF'}, ...
                'RequestToSend', 'off');
            obj.range_low = -10;
            obj.range_high = 10;
            obj.ramp_rate = [];
            fopen(obj.com); % will be closed on delete by ComInstrument.
        end
        
        function r = model(obj)
            r = 'QDAC';
        end
        
        function r = channels(obj)
            r = qd.util.map(@(n)['CH' num2str(n)], 1:4);
        end
        
        function setc(obj, channel, val)
            if isempty(obj.ramp_rate)
                % Just set the output to val.
                channel_string = strsplit(channel,'CH');
                channel_num = channel_string{2};
                obj.queryf(sprintf('#SET%s %d', channel_num, obj.get_bin(val)));
                obj.query('#DO');
            else
                % Ramp.
                disp('Ramp not supported at the moment');
            end
        end
        
        function bin = get_bin(obj, val)
            Bin_range = 2^19-1;
            % Resolusion is 2^20, but the first 2^19 bins is range(0,10)
            % and the last 2^19 is range(-10,0)
            VoltToBin = [linspace(0,obj.range_span/2,Bin_range) linspace(-obj.range_span/2,0,Bin_range)];
                       
            [~,bin] = min(abs(val-VoltToBin));
        end
        
        function set_ramp_rate(obj, rate)
        % Set the ramping rate of this channel instance. Set this to [] to
        % disable ramping.
        % Rate is in volts per second.
            qd.util.assert((isnumeric(rate) && isscalar(rate)) || isempty(rate))
            obj.ramp_rate = abs(rate);
        end
        
        function rate = get_ramp_rate(obj)
            rate = obj.ramp_rate;
        end
        
        function set_range(obj, low_limit, high_limit)
            obj.range_low = low_limit;
            obj.range_high = high_limit;
        end
        
        function range = get_range(obj)
            range = [obj.range_low, obj.range_high];
        end
    end
    methods(Access=private)        
        function span = range_span(obj)
            span = obj.range_high - obj.range_low;
        end
    end
end