classdef DecaDACChannel < qd.classes.Channel
    properties(Access=private)
        num
        range_low
        range_high
        ramp_rate % volts per second
        limit_low
        limit_high
    end
    methods
        function obj = DecaDACChannel(num)
            persistent warning_issued;
            obj.num = num;
            obj.range_low = -10.0;
            obj.range_high = 10.0;
            obj.ramp_rate = 0.1;
            if isempty(warning_issued)
                warning(['DecaDAC drivers: ' ...
                    'No handling of DecaDAC range yet, setting -10V to 10V. ' ...
                    'These drivers only support mode 2 so far (16 bit resolution). ' ...
                    'No handling of limits either, chan.set(val) will remove limits ' ...
                    'if ramping is enabled.'])
                warning_issued = true;
            end
        end

        function set_limits(obj, low, high)
            qd.util.assert((isnumeric(low) && isscalar(low)) || isempty(low))
            qd.util.assert((isnumeric(high) && isscalar(high)) || isempty(high))
            obj.limit_low = low;
            obj.limit_high = high;
        end

        function range = get_limits(obj)
            range = [obj.limit_low, obj.limit_high];
        end
        
        function set(obj, val)
            % Shorthand for obj.instrument
            ins = obj.instrument;
            % Validate the input for common errors.
            qd.util.assert(isnumeric(val));
            if (val > obj.range_high) || (val < obj.range_low)
                error('%f is out of range.', val);
            end
            % FQHE 2DEG can not handle positive gates voltages.
            if ~isempty(obj.limit_low) && ((val < obj.limit_low) || (val > obj.limit_high))
                error('Value must be within %f and %f', obj.limit_low, obj.limit_high);
            end
            
            % Here we calculate how far into the full range val is.
            frac = (val - obj.range_low)/obj.range_span();
            % DecaDACs expect a number between 0 and 2^16-1 representing the output range.
            goal = round((2^16 - 1)*frac);

            % Set this as the active channel on the decadac.
            obj.select();
            % For now, force mode 2 (4-chan)
            ins.query('M2;');
            if isempty(obj.ramp_rate)
                % Do not ramp, just set the output.
                ins.queryf('D%d;', goal);
            else % The else part is a ramping set.
                % Get the current value.
                current = ins.querym('d;', 'd%d!');
                % set the limit for the ramp
                if current < goal
                    ins.queryf('U%d;', goal);
                elseif current > goal
                    ins.queryf('L%d;', goal);
                else
                    % No need to change anything.
                    return;
                end
                % We set the ramp clock period to 1000 us. Changing the clock
                % is not supported for all DACs it seems, for those that do
                % not support it, I hope the default is always 1000.
                ramp_clock = 1000;
                % Calculate the required slope (see the DecaDAC docs)
                slope = ceil((obj.ramp_rate / obj.range_span() * ramp_clock * 1E-6) * (2^32));
                slope = slope * sign(goal - current);
                % Initiate the ramp.
                ins.queryf('T%d;G0;S%d;', ramp_clock, slope);
                % Now we wait until the goal has been reached
                while true
                    val = ins.querym('d;', 'd%d!');
                    if val == goal
                        break;
                    end
                    pause(ramp_clock * 1E-6 * 3); % wait a few ramp_clock periods
                    % TODO, if this is taking too long. Abort the ramp with an error.
                end
                % Set back everything
                ins.queryf('S0;L0;U%d;', 2^16-1);
            end
        end
        
        function set_setpoint(obj, val)
            % Same as set but without wait time (added by Guen on 12/10/2013)
            % Shorthand for obj.instrument
            ins = obj.instrument;
            % Validate the input for common errors.
            qd.util.assert(isnumeric(val));
            if (val > obj.range_high) || (val < obj.range_low)
                error('%f is out of range.', val);
            end
            % FQHE 2DEG can not handle positive gates voltages.
            if ~isempty(obj.limit_low) && ((val < obj.limit_low) || (val > obj.limit_high))
                error('Value must be within %f and %f', obj.limit_low, obj.limit_high);
            end
            
            % Here we calculate how far into the full range val is.
            frac = (val - obj.range_low)/obj.range_span();
            % DecaDACs expect a number between 0 and 2^16-1 representing the output range.
            goal = round((2^16 - 1)*frac);

            % Set this as the active channel on the decadac.
            obj.select();
            % For now, force mode 2 (4-chan)
            ins.query('M2;');
            if isempty(obj.ramp_rate)
                % Do not ramp, just set the output.
                ins.queryf('D%d;', goal);
            else % The else part is a ramping set.
                % Get the current value.
                current = ins.querym('d;', 'd%d!');
                % set the limit for the ramp
                if current < goal
                    ins.queryf('U%d;', goal);
                elseif current > goal
                    ins.queryf('L%d;', goal);
                else
                    % No need to change anything.
                    return;
                end
                % We set the ramp clock period to 1000 us. Changing the clock
                % is not supported for all DACs it seems, for those that do
                % not support it, I hope the default is always 1000.
                ramp_clock = 1000;
                % Calculate the required slope (see the DecaDAC docs)
                slope = ceil((obj.ramp_rate / obj.range_span() * ramp_clock * 1E-6) * (2^32));
                slope = slope * sign(goal - current);
                % Initiate the ramp.
                ins.queryf('T%d;G0;S%d;', ramp_clock, slope);
            end
        end

        function val = get(obj)
            obj.select();
            raw = obj.instrument.querym('d;', 'd%d!');
            val = raw / 2^16 * obj.range_span() + obj.range_low;
        end

        function set_ramp_rate(obj, rate)
        % chan.set_ramp_rate(rate)
        %
        % Set the ramping rate of this channel instance. Set this to [] to
        % disable ramping.
        % Rate is in volts per second.
            qd.util.assert((isnumeric(rate) && isscalar(rate)) || isempty(rate))
            obj.ramp_rate = abs(rate);
        end
        
        function rate = get_ramp_rate(obj)
            rate = obj.ramp_rate;
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Channel(register);
            r.ramp_rate = obj.ramp_rate;
            r.current_value = obj.get();
        end
    end
    methods(Access=private)
        function select(obj)
            % Select this channel on the DAC.
            obj.instrument.queryf('B%d;C%d;', floor(obj.num/4), mod(obj.num, 4));
        end

        function span = range_span(obj)
            span = obj.range_high - obj.range_low;
        end
    end
end