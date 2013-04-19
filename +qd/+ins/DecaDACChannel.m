classdef DecaDACChannel < handle
	properties(Access=private)
		parent
		num
		range_low
		range_high
	end
	methods
		function obj = DecaDACChannel(parent, num)
			obj.parent = parent;
			obj.num = num;
			obj.range_low = -10.0;
			obj.range_high = 10.0;
			warning('No handling of DAC range yet, assuming -10V to 10V.');
		end

		function set(obj, val)
			qd.util.assert(isnumeric(val));
			if (val > obj.range_high) || (val < obj.range_low)
				error(sprintf('%f is out of range.', val));
			end
			% Here we calculate how far into the full range val is.
			frac = (val - obj.range_low)/(obj.range_high - obj.range_low);
			% DecaDACs expect a number between 0 and 2^16-1 representing the output range.
			num = round((2^16 - 1)*frac);
			obj.select();
			obj.parent.query(sprintf('D%d;', num));
		end
	end
	methods(Access=private)
		function select(obj)
			% Select this channel on the DAC.
			obj.parent.query(sprintf('B%d;C%d;', floor(obj.num/4), mod(obj.num, 4)));
		end
	end
end