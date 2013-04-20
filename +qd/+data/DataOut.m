classdef DataOut < handle
	properties(Access=private)
		parent
		name
		columns
		initialized
		file
	end
	
	methods(Access=[?qd.data.Record])
		function obj = DataOut(parent, name)
			qd.util.assert(~parent.read_only);
			obj.parent = parent;
			obj.name = name;
			obj.columns = [];
			obj.initialized = false;
			data_file_path = fullfile(obj.parent.location(), [obj.name '.run']);
			qd.util.assert(~exist(data_file_path));
			obj.file = fopen(data_file_path, 'w');
		end
	end

	methods

		function add_column(obj, name, unit)
			column = struct('name', name, 'unit', unit);
			if isempty(obj.columns)
				obj.columns = column
			else
				obj.columns(end + 1) = column;
			end
		end

		function init(obj)
			qd.util.assert(~obj.initialized);
			obj.initialized = true;
			meta_path = fullfile(obj.parent.location(), [obj.name '.json']);
			qd.util.assert(~exist(meta_path));
			json.write(obj.columns, meta_path);
		end

		function add_point(obj, data)
			if ~obj.initialized
				obj.init()
			end
			qd.util.assert(numel(data) == numel(obj.columns));
			fprintf(obj.file, '%.16G\t', data);
			fprintf(obj.file, '\n');
		end

		function delete(obj)
			fclose(obj.file);
		end

	end
end