classdef DecaDACChannel < handle
    properties(Access=private)
        parent
        num
        range_low
        range_high
        ramp_rate % volts per second
    end
    methods
        function obj = DecaDACChannel(parent, num)
            obj.parent = parent;
            obj.num = num;
            warning('These drivers only support mode 2 so far (16 bit resolution).');
            warning('No handling of DecaDAC range yet, setting -10V to 10V.');
            obj.range_low = -10.0;
            obj.range_high = 10.0;
            obj.ramp_rate = 1.0;
            warning('No handling of limits either, chan.set(val) will remove limits if ramping is enabled.')
        end

        function set(obj, val)
            % Validate the input for common errors.
            qd.util.assert(isnumeric(val));
            if (val > obj.range_high) || (val < obj.range_low)
                error(sprintf('%f is out of range.', val));
            end
            
            % Here we calculate how far into the full range val is.
            frac = (val - obj.range_low)/obj.range_span();
            % DecaDACs expect a number between 0 and 2^16-1 representing the output range.
            goal = round((2^16 - 1)*frac);

            obj.select();
            if isempty(obj.ramp_rate)
                % Do not ramp, just set the output.
                obj.parent.query(sprintf('D%d;', goal));
            else % The else part is a ramping set.
                current = qd.util.match(obj.parent.query('d;'), 'd%d!');
                % set the limit for the ramp
                if current < goal
                    obj.parent.query(sprintf('U%d;', goal));
                elseif current > goal
                    obj.parent.query(sprintf('L%d;', goal));
                else
                    % No need to change anything.
                    return;
                end
                % We set the ramp clock period to 1000 us.
                % Changing the clock is not supported for all DACs it seems,
                % for those that do not support it, I hope the default is always 1000.
                ramp_clock = 1000;
                % Calculate the required slope (see the DecaDAC docs)
                slope = ceil((obj.ramp_rate / obj.range_span() * ramp_clock * 1E-6) * (2^32));
                slope = slope * sign(goal - current);
                % Initiate the ramp.
                obj.parent.query(sprintf('T%d;G0;S%d;', ramp_clock, slope));
                % Now we wait until the goal has been reached
                while true
                    val = qd.util.match(obj.parent.query('d;'), 'd%d!');
                    if val == goal
                        break;
                    end
                    pause(ramp_clock * 1E-6 * 3); % wait a few ramp_clock periods
                    % TODO, if this is taking too long. Abort the ramp with an error.
                end
                % Set back everything
                obj.parent.query(sprintf('S0;L0;U%d;', 2^16-1));
            end
        end

        function val = get(obj)
            raw = qd.util.match(obj.parent.query('d;'), 'd%d!');
            val = raw / (2^16-1) * obj.range_span() + obj.range_low;
        end

        function set_ramp_rate(obj, rate)
        % chan.set_ramp_rate(rate)
        %
        % Set the ramping rate of this channel instance. Set this to [] to
        % disable ramping.
            qd.util.assert((isnumeric(rate) && isscalar(rate)) || isempty(rate))
            obj.ramp_rate = abs(rate);
        end
    end
    methods(Access=private)
        function select(obj)
            % Select this channel on the DAC.
            obj.parent.query(sprintf('B%d;C%d;', floor(obj.num/4), mod(obj.num, 4)));
        end

        function span = range_span(obj)
            span = obj.range_high - obj.range_low;
        end
    end
end