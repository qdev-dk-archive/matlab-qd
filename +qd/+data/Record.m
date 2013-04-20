classdef Record < handle
	properties(Access=private)
		runs
		loc
		creation
	end

	properties(GetAcces=public)
		meta
	end

	methods(Static)
		function obj = new(loc, meta)
			% See if meta is json representable
			json.dumps(meta);
			obj = qd.data.Record(loc);
			obj.meta = meta;
			obj.creation = clock();
			assert(~exist(loc, 'file'));
			mkdir(loc);
			% to get the absolute path corresponding to loc. We cd into it and
			% call pwd.
			save_dir = pwd();
			cd(loc);
			obj.loc = pwd();
			cd(save_dir);
			obj.save_meta();
		end
	end

	methods
		function r = make_run(obj, name)
			r = qd.data.Run(obj, name)
			obj.runs{end + 1} = r;
		end

		function loc = location(obj)
			loc = obj.loc;
		end

		function set_meta(obj, meta)
			meta_bak = [obj.meta_path() '.bak'];
			assert(~file.exists(meta_bak))
			movefile(obj.meta_path(), meta_bak);
			obj.meta = meta;
			obj.save_meta();
			delete(meta_bak);
		end
	end

	methods(Access=private)
		function obj = Record(loc)
			obj.loc = loc;
			obj.meta = struct();
			obj.runs = {};
		end

		function save_meta(obj)
			metadata = struct();
			metadata.format = 'qd-record';
			metadata.version = '0.0';
			metadata.creation = datestr(obj.creation, 31);
			metadata.meta = obj.meta;
			json.write(metadata, obj.meta_path());
		end

		function p = meta_path(obj)
			p = fullfile(obj.loc, 'meta.json');
		end
	end
end