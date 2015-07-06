classdef DecaDAC2 < qd.classes.ComInstrument
% Drivers for our DecaDACs. Please have a look at
% https://wiki.nbi.ku.dk/qdevwiki/DACs before using these drivers. Unless you
% know better, call obj.set_all_to_4channel_mode in your setup script.
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

        % When setting a channel, the instrument does not ramp if the distance
        % from the current value to the value to set is less than the
        % skip_ramp_tolerance. Set as 
        skip_ramp_tolerance = struct

        % Running futures. Format: futures.CH0.abort().
        futures = struct

        % The currently selected channel
        selected = -1
        % When was it selected. If it is more than 10 s ago, we assume the dac
        % forgot the selected channel (for instance if the DAC was power
        % cycled or something).
        when_selected

        % We want the user to set the mode of each slot explicitly. mode_set
        % is an array containing a 0 or 1 for each slot in dac. 1 means the
        % mode has been set using set_mode_of_slot.
        mode_set
        mode_warning_emitted = false;
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
                obj.skip_ramp_tolerance.(ch{1}) = 0;
                obj.ranges.(ch{1}) = [-10, 10];
            end
            obj.mode_set = zeros(1, ceil(obj.number_of_channels/4));
        end

        function r = model(obj)
            r = 'DecaDAC';
        end

        function val = getc(obj, ch)
            n = obj.parse_ch(ch);
            if ~obj.mode_set(floor(n/4) + 1)
                obj.emit_mode_warning(ch);
            end
            obj.select(n);
            raw = obj.querym('d;', 'd%d!');
            val = obj.raw_to_float(ch, raw);
        end

        function future = setc_async(obj, ch, val)
            n = obj.parse_ch(ch);
            if ~obj.mode_set(floor(n/4) + 1)
                obj.emit_mode_warning(ch);
            end
            obj.validate(ch, val);
            if isfield(obj.futures, ch)
                obj.futures.(ch).resolve();
            end
            rate = obj.ramp_rates.(ch);
            if ~isempty(obj.ramp_rates.(ch))
                future = obj.set_ramp(ch, n, val);
            else
                future = obj.set_no_ramp(ch, n, val);
            end
        end

        function r = channels(obj)
            r = qd.util.map(@(n)['CH' num2str(n)], 0:(obj.number_of_channels - 1));
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

        function set_mode_of_slot(obj, slot_nr, m)
        % Sets the mode of a slot. Each slot has 4 channels. I.e. slot_nr 0
        % has channels CH0 to CH3. slot_nr 1 has channels CH4 to CH7 etc.
        %
        % m is one of:
        %   * '4channel': all channels work independently. This is mode M2.
        %   * 'fine_adjust': CH2 is fine adjust for CH0, CH3 is fine adjust
        %     for CH1, CH6 is fine adjust for CH4 etc.
        %
        % See https://wiki.nbi.ku.dk/qdevwiki/File:DecaDAC_ASCIIProtocol_121231.pdf
            qd.util.assert(slot_nr >= 0 && slot_nr < obj.number_of_channels/4);
            obj.mode_set(slot_nr + 1) = 1;
            switch m
                case '4channel'
                    obj.queryf('B%d;M2;', slot_nr);
                case 'fine_adjust'
                    obj.queryf('B%d;M1;', slot_nr);
                otherwise
                    error('No such mode "%s".', m);
            end
        end

        function set_all_to_4channel_mode(obj, m)
            for i = 0:(obj.number_of_channels/4 - 1)
                obj.set_mode_of_slot(i, '4channel');
            end
        end
    end
    properties(Constant)
        number_of_channels = 20
        max_raw_value = 2^16 - 1
    end
    methods(Access=private)

        function emit_mode_warning(obj, ch)
            if ~obj.mode_warning_emitted
                warning(['DecaDAC2: The mode has not been set for the slot ' ...
                    'containing %s. You should call set_mode_of_slot or ' ...
                    'set_all_to_4channel_mode to be explicit.'], ch);
                obj.mode_warning_emitted = 1;
            end
        end

        function val = raw_to_float(obj, ch, raw)
            val = raw/obj.max_raw_value*obj.span(ch) + obj.low(ch);
        end

        function raw = float_to_raw(obj, ch, val)
            raw = round(obj.max_raw_value*(val - obj.low(ch))/obj.span(ch));
        end

        function future = set_no_ramp(obj, ch, n, val)
        % n is parse_ch(ch).
            obj.select(n);
            obj.queryf('D%d;', obj.float_to_raw(ch, val));
            future = qd.classes.SetFuture.do_nothing_future;
        end

        function future = set_ramp(obj, ch, n, valf)
        % n is parse_ch(ch).

            obj.select(n);
            nowr = obj.querym('d;', 'd%d!');   % Current value (raw)
            nowf = obj.raw_to_float(ch, nowr); % Current value (float)

            % Check if we can skip the ramp entirely.
            tolerance = obj.skip_ramp_tolerance.(ch);
            if abs(nowf - valf) <= tolerance
                future = obj.set_no_ramp(ch, n, valf);
                return
            end

            valr = obj.float_to_raw(ch, valf);
            % the ramp stops when it reaches the limit. We set it appropriately.
            if nowr < valr
                obj.queryf('U%d;', valr);
            elseif nowr > valr
                obj.queryf('L%d;', valr);
            else
                % We are already at the goal. No need to do anything.
                future = qd.classes.SetFuture.do_nothing_future;
                return
            end

            rate = obj.ramp_rates.(ch);
            % We set the ramp clock period to 1000 us. Changing the clock
            % is not supported for all DACs it seems, for those that do
            % not support it, I hope the default is always 1000.
            ramp_clock = 1000;
            % Calculate the required slope (see the DecaDAC docs)
            slope = ceil((rate / obj.span(ch) * ramp_clock * 1E-6) * (2^32));
            slope = slope * sign(valr - nowr);
            % Initiate the ramp.
            obj.queryf('T%d;G0;S%d;', ramp_clock, slope);

            % Below we construct an appropriate SetFuture.
            function abort()
                % someone might have selected a different channel
                obj.select(n);
                obj.queryf('S0;L0;U%d;', 2^16-1);
                if obj.querym('d;', 'd%d!') ~= valr
                    warning('%s: A ramp was aborted before it was finished.', obj.name);
                end
                obj.futures = rmfield(obj.futures, ch);
            end
            function exec()
                % someone might have selected a different channel
                obj.select(n);
                while obj.querym('d;', 'd%d!') ~= valr
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
            qd.util.assert(n < obj.number_of_channels);
            qd.util.assert(n >= 0);
        end

        function select(obj, n)
            if obj.selected == n && toc(obj.when_selected) < 10
                return
            end
            % Select channel number n on the DecaDAC.
            obj.queryf('B%d;C%d;', floor(n/4), mod(n, 4));
            obj.selected = n;
            obj.when_selected = tic;
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