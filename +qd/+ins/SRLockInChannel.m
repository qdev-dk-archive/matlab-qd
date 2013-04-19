classdef SRLockInChannel < handle
	properties(Access=private)
		parent
		num
	end
	methods
		function obj = SRLockInChannel(parent, num)
			obj.parent = parent;
			obj.num = num;
		end

		function val = get(obj)
			val = sscanf(obj.parent.query(sprintf('OUTP?%d', obj.num)), '%f');
		end
	end
end