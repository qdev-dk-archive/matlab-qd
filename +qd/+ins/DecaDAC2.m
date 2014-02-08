classdef DecaDAC2 < qd.classes.ComInstrument
    properties
        % Software of all channels. Format: limits.CH0 = [-10, 10]. Default is
        % [-10, 10].
        limits = struct

        % Ranges of all channels (set with a physical switch). Format:
        % ranges.CH0 = [-10, 10]. Default is [-10, 10]
        ranges = struct

        % Ramp rates of all channels. Format: ramp_rates.CH0 = 0.5. In V/s.
        % Default is 0.1. Set to [] to disable ramping.
        ramp_rates = struct

        % Running futures. Format: futures.CH0.abort().
        futures = struct
    end
    methods
        function obj = DecaDAC2(port)
            obj.com = serial(port, ...
                'BaudRate', 9600, ...
                'Parity',   'none', ...
                'DataBits', 8, ...
                'StopBits', 1);
            fopen(obj.com);

            for ch = obj.channels
                obj.limits.(ch{1}) = [-10, 10];
                obj.ramp_rates.(ch{1}) = 0.1;
                obj.ranges.(ch{1}) = [-10, 10];
            end
        end

        function r = model(obj)
            r = 'DecaDAC';
        end

        function val = getc(obj, ch)
            n = obj.parse_ch(ch);
            obj.select(n);
            raw = obj.querym('d;', 'd%d!');
            val = raw / (2^16 - 1) * obj.span(ch) + obj.low(ch);
        end

        function future = setc_async(obj, ch, val)
            n = obj.parse_ch(ch);
            obj.validate(ch, val);
            if isfield(obj.futures, ch)
                obj.futures.(ch).resolve();
            end
            % Here we calculate how far into the full range val is.
            frac = (val - obj.low(ch))/obj.span(ch);
            % DecaDACs expect a number between 0 and 2^16-1 representing the output range.
            goal = round((2^16 - 1)*frac);
            obj.select(n);
            obj.query('M2;');
            rate = obj.ramp_rates.(ch);
            if isempty(rate)
                obj.queryf('D%d;', goal);
                future = qd.classes.SetFuture.do_nothing_future();
            else
                future = obj.ramp(ch, n, goal);
            end
        end

        function r = channels(obj)
            r = qd.util.map(@(n)['CH' num2str(n)], 0:19);
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.ComInstrument(register);
            r.current_values = struct();
            for q = obj.channels()
                r.current_values.(q{1}) = obj.getc(q{1});
            end
            r.limits = obj.limits;
            r.ranges = obj.ranges;
            r.ramp_rates = obj.ramp_rates;
        end
    end
    methods(Access=private)

        function future = ramp(obj, ch, n, goal)
        % n is parse_ch(ch). Before calling this, make sure to call obj.select(n).
        % goal is an integer (see setc_async above and decadac docs).
            value_now = obj.querym('d;', 'd%d!');
            rate = obj.ramp_rates.(ch);
            % the ramp stops when it reaches the limit. We set it appropriately.
            if value_now < goal
                obj.queryf('U%d;', goal);
            elseif value_now > goal
                obj.queryf('L%d;', goal);
            else
                % No need to do anything.
                future = qd.classes.SetFuture.do_nothing_future();
                return
            end
            % We set the ramp clock period to 1000 us. Changing the clock
            % is not supported for all DACs it seems, for those that do
            % not support it, I hope the default is always 1000.
            ramp_clock = 1000;
            % Calculate the required slope (see the DecaDAC docs)
            slope = ceil((rate / obj.span(ch) * ramp_clock * 1E-6) * (2^32));
            slope = slope * sign(goal - value_now);
            % Initiate the ramp.
            obj.queryf('T%d;G0;S%d;', ramp_clock, slope);
            % Now we construct a future.
            function b = is_done()
                % must be selected first!
                val = obj.querym('d;', 'd%d!');
                b = val == goal;
            end
            function abort()
                % someone might have selected a different channel
                obj.select(n);
                obj.queryf('S0;L0;U%d;', 2^16-1);
                if ~is_done()
                    warning('%s: A ramp was aborted before it was finished.', obj.name);
                end
                obj.futures = rmfield(obj.futures, ch);
            end
            function exec()
                % someone might have selected a different channel
                obj.select(n);
                while ~is_done()
                    pause(ramp_clock * 1E-6 * 3); % wait a few ramp_clock periods
                end
                obj.queryf('S0;L0;U%d;', 2^16-1);
                obj.futures = rmfield(obj.futures, ch);
            end
            future = qd.classes.SetFuture(@exec, @abort);
            obj.futures.(ch) = future;
        end

        function n = parse_ch(obj, ch)
            try
                n = qd.util.match(ch, 'CH%d');
            catch
                error('No such channel (%s).', ch);
            end
            qd.util.assert(n < 20);
            qd.util.assert(n >= 0);
        end

        function select(obj, n)
            % Select channel number n on the decadac.
            obj.queryf('B%d;C%d;', floor(n/4), mod(n, 4));
        end

        function v = low(obj, ch)
            r = obj.ranges.(ch);
            v = r(1);
        end

        function v = high(obj, ch)
            r = obj.ranges.(ch);
            v = r(2);
        end

        function v = span(obj, ch)
            r = obj.ranges.(ch);
            v = r(2) - r(1);
        end

        function validate(obj, ch, val)
            r = obj.ranges.(ch);
            l = obj.limits.(ch);
            qd.util.assert( ...
                val >= r(1) && val <= r(2) && ...
                val >= l(1) && val <= l(2) ...
            );
        end
    end
end