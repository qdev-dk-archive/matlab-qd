classdef Store < handle
	properties(GetAccess=public)
		loc
	end
	methods
		function obj = Store(loc)
			qd.util.assert(exist(loc, 'file'));
			obj.loc = qd.util.absdir(loc);
		end

		function r = record(obj, meta)
			i = 0;
			while true
				l = fullfile(obj.loc, [datestr(clock(), 29) '#' sprintf('%03d', i)]);
				% TODO, do not fill in holes.
				if ~exist(l, 'file')
					break
				end
				i = i + 1;
			end
			r = qd.data.Record.new(l, meta);
		end
	end
end