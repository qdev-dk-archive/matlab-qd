classdef FolderBrowser < handle
	properties(Access=private)
		location
	end
	methods
		function obj = FolderBrowser(loc)
			obj.location = loc;
		end
	end
end