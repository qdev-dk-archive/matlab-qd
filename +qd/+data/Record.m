classdef Record < handle
	properties(Access=private)
		runs
		loc
		creation
	end

	properties(GetAccess=public)
		meta
		read_only
	end

	methods(Static)
		function obj = new(loc, meta)
			% See if meta is json representable
			json.dump(meta);
			obj = qd.data.Record(loc);
			obj.read_only = false;
			obj.meta = meta;
			obj.creation = clock();
			qd.util.assert(~exist(loc, 'file'));
			mkdir(loc);
			obj.loc = qd.util.absdir(loc);
			obj.save_meta();
		end
	end

	methods
		function r = make_run(obj, name)
			qd.util.assert(~obj.read_only);
			r = qd.data.DataOut(obj, name)
			obj.runs{end + 1} = r;
		end

		function r = load_run_data(obj, name)
			run_path = fullfile(obj.loc, [name '.run']);
			meta_path = fullfile(obj.loc, [name '.json']);
			if ~exist(run_path, 'file')
				error('Could not locate run');
			end
			meta = json.read(meta_path);
			data = dlmread(run_path);
			r = {};
			i = 1;
			for c = meta
				c.data = transpose(data(:, i));
				r{end+1} = c;
				i = i + 1;
			end
		end

		function loc = location(obj)
			loc = obj.loc;
		end

		function set_meta(obj, meta)
			qd.util.assert(~obj.read_only);
			meta_bak = [obj.meta_path() '.bak'];
			qd.util.assert(~file.exists(meta_bak))
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