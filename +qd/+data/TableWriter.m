classdef TableWriter < handle
    properties(Access=private)
        meta_path
        data_path
        columns = {}
        initialized = false
        file
    end
    
    methods
    
        function obj = TableWriter(directory, name)
            obj.meta_path = fullfile(directory, [name '.json']);
            obj.data_path = fullfile(directory, [name '.dat']);
            qd.util.assert(~exist(obj.meta_path));
            qd.util.assert(~exist(obj.data_path));
        end

        function add_column(obj, name)
            obj.columns{end + 1} = struct('name', name); 
        end

        function add_channel_column(obj, chan)
            obj.columns{end + 1} = struct('name', chan.name);
        end

        function init(obj)
            qd.util.assert(~obj.initialized);
            json.write(obj.columns, obj.meta_path);
            obj.file = fopen(obj.data_path, 'wt');
            obj.initialized = true;
        end

        function add_point(obj, data_point)
            if ~obj.initialized
                obj.init();
            end
            qd.util.assert(length(data_point) == length(obj.columns));
            fprintf(obj.file, '%.16G\t', data_point);
            fprintf(obj.file, '\n');
        end

        function add_divider(obj)
            fprintf(obj.file, '\n');
        end

        function delete(obj)
            if obj.initialized
                fclose(obj.file);
            end
        end

        function file = get_file(obj)
            file = obj.data_path;
        end

    end
end