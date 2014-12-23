classdef AutoHRDecaDACChannel < qd.classes.Channel
	properties
        num
        mode
        board
        chan
        range_low
        range_high
        ramp_rate % volts per second
        limit_low
        limit_high
        wait_for_ramp = true
        slope
        offset
        fine_limits_disabled = false;
    end
    methods
    	function obj = AutoHRDecaDACChannel(num,mode)
            persistent warning_issued;
            obj.num = num;
            obj.board = floor(obj.num/4);
            obj.chan = mod(obj.num, 4);
            obj.mode = mode;
            obj.range_low = -10.0;
            obj.range_high = 10.0;
            obj.ramp_rate = 0.1;
            obj.slope = 1;
            obj.offset = 0;
            obj.ramp_clock = 1000;
            if isempty(warning_issued)
                warning(['DecaDAC drivers: Only use Mode 3 if the Dac supports the mode and it has been calibrated!'])
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

        function val = get(obj)
            obj.select();
            if obj.mode == 3
            	raw = obj.instrument.querym('d;', 'd%.4f!');
            else
            	raw = obj.instrument.querym('d;', 'd%d!');
        	end
        	val = raw / 2^16 * obj.range_span() + obj.range_low;
            val = val*obj.slope+obj.offset;
        end

        function set(obj, val)
			% Shorthand for obj.instrument
            ins = obj.instrument;
            
            % Validate the input for common errors.
            obj.check_val();

            % setting the output
            % if ramp_rate is empty just set the output (be careful!)
            % obj.select (selects board and channel) only needs to be called once for most calls.
            obj.select();
            if isempty(obj.ramp_rate) || obj.mode == 0
            	if obj.mode == 1
            		[bin,c_bin,f_bin] = obj.get_manbins(val);
            		ins.queryf('D%d;B%d;C%d;D%d;', c_bin, obj.board, obj.chan+2, f_bin);
            	elseif obj.mode = 2 || obj.mode == 0
            		[bin,c_bin,f_bin] = obj.get_manbins(val);
            		ins.queryf('D%d;',bin);
            	elseif obj.mode == 3
            	 	autof_bin = get_autofinebin(val);
            		ins.queryf('D%.4f;',autof_bin);
            	end
            % Ramp output	
            else
            	% calculate the required slope
            	if obj.mode == 3
            		current = ins.querym('d;', 'd%.4f!');
            		% get bin
            		autof_bin = get_autofinebin(val);
            		r_slope = ceil((obj.ramp_rate/obj.range_span()*obj.ramp_clock*1e-6)*(2^32));
                	r_slope = r_slope * sign(bin - current);
                	% initiate ramp
                	ins.queryf('L%.4f;U%.4f;T%d;G0;S%d;', autof_bin, autof_bin, obj.ramp_clock, r_slope);
                	if obj.wait_for_ramp
                		while true
                			val = ins.querym('d;', 'd%.4f!');
                        	if val == autof_bin
                            	break;
                        	end
                        	pause(3*obj.ramp_clock*1e-6); % wait a few ramp_clock periods
                		end
                	end
            	else
            		% get coarse value
            		current = ins.querym('d;', 'd%d!');
            		% get bins
                	[bin,c_bin,f_bin] = obj.get_manbins(val);

                	if ~obj.wait_for_ramp && obj.mode == 1
                		% if ramping blind, set fine channel first.
                    	obj.select_fine()
                    	ins.queryf('D%d;', f_bin);
                    	% make sure to ramp to c_bin
                    	bin = c_bin;
                	end
                	% calculate required slope
            		r_slope = ceil((obj.ramp_rate/obj.range_span()*obj.ramp_clock*1e-6)*(2^32));
                	r_slope = r_slope * sign(bin - current);

                	% initiate ramp
                	obj.select();
                	ins.queryf('L%d;U%d;T%d;G0;S%d;', bin, bin, ramp_clock, r_slope);
                	if obj.wait_for_ramp
                    	while true
                        	val = ins.querym('d;', 'd%d!');
                        	if val == bin
                            	break;
                        	end
                        	pause(ramp_clock * 1E-6 * 3); % wait a few ramp_clock periods
                    	end
                    end
                    if obj.wait_for_ramp && obj.mode == 1
                        % If fine Channel is activated, send the exact value now.
                        obj.select_fine();
                        ins.queryf('D%d;', f_bin);
                    end
            	end
            	% set limits back
            	ins.queryf('L%d;U%d;', 0, 2^16-1);
            end
        end

        function check_val(obj, val)
        	qd.util.assert(isnumeric(val));
            val = (val/obj.slope)-obj.offset;
            
            %check that val is in range
            if (val > obj.range_high) || (val < obj.range_low)
                error('%f is out of range. Remember slope and offset.', val);
            end
            %check that val is within limits
            if (val < obj.limit_low) || (val > obj.limit_high)
                error('Value must be within %f and %f . Remember slope and offset.', obj.limit_low, obj.limit_high);
            end

        	% issue warnings and errors if wrong mode is choosen.
        	% 0:off, 1:fine,  2:coarse, 3:auto-fine.
            if obj.mode == 0
                warning('This board is diabled, only internal output is changed');
            elseif obj.mode == 1 || obj.mode == 3
                if obj.chan == 2 || obj.chan == 3
                    error('In fine or auto-fine mode channels 2 and 3 on all boards are used as fine adjustment for channels 0 and 1');
                end
            elseif obj.mode == 2
                % all is fine.
            else
                error('No valid mode')
            end
        end

        function set_ramp_rate(obj, rate)
            % Set the ramping rate of this channel instance. Set this to [] to disable ramping.
            % Rate is in volts per second.
            qd.util.assert((isnumeric(rate) && isscalar(rate)) || isempty(rate))
            if rate==0.0
                obj.ramp_rate = [];
            else
                obj.ramp_rate = abs(rate);
            end
        end
        
        function rate = get_ramp_rate(obj)
            rate = obj.ramp_rate;
        end

        function set_slope(obj, slope)
            qd.util.assert((isnumeric(slope) && isscalar(slope)) || isempty(slope))
            obj.slope = slope;
        end
        
        function set_offset(obj, offset)
            qd.util.assert((isnumeric(offset) && isscalar(offset)) || isempty(offset))
            obj.offset = offset;
        end
        
        function r = get_slope(obj)
            r = obj.slope;
        end
        
        function r = get_offset(obj)
            r = obj.offset;
        end
        
        function r = describe(obj, register)
            r = obj.describe@qd.classes.Channel(register);
            r.current_value = obj.get();
            r.mode = obj.mode;
            r.offset = obj.offset;
            r.ramp_rate = obj.ramp_rate;
            r.slope = obj.slope;
        end
        
        function set_mode(obj, mode)
            obj.mode = mode;
        end
        
        function mode = get_mode(obj)
            mode = obj.mode;
        end

    end
    methods(Access=private)

        function [bin,c_bin,f_bin] = get_manbins(obj, val)
            % Following the comments on WIKI about DAC:
            % The coarse channel is used as little as possible. Thus
            % limited to ~8 bit, when exactly 8 bit are used the fine
            % channel does not span over the remaining steps, so the coarse
            % range (c_BinRange)is increased by 1.
            
            binrange = 2^16 - 1;
            
            nval = val - obj.range_low;
            frac = nval/obj.range_span();
            
            bin = round(frac*binrange);
            c_bin = floor(frac*(2^8))*(2^8) - 1 ;
            
            f_nval = (nval - ( c_bin * obj.range_span() / binrange) );
            f_frac = f_nval/0.1;  % hard-coded range of 100mV
            f_bin = round(f_frac*binrange);
        end

        function autof_bin = get_autofinebin(obj, val)
        	binrange = 2^16-1;
        	nval = val - obj.range_low;
        	frac = nval/obj.range_span();
        	autof_bin = round(frac*binrange,4);
        end
	
	        
        function select(obj)
            % Select this channel on the DAC.
            obj.instrument.queryf('B%d;C%d;', obj.board, obj.chan);
        end
        
        function select_fine(obj)
            % Select the corresponding fine channel on the DAC.
            obj.instrument.queryf('B%d;C%d;', obj.board, obj.chan+2);
        end

        function span = range_span(obj)
            span = obj.range_high - obj.range_low;
        end
    end
end