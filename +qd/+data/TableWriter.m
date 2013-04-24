classdef TableWriter < handle
    properties(Access=private)
        meta_path
        data_path
        columns = {}
        initialized = false
        file
    end
    
    methods
    
        function obj = TableWriter(directory, name);
            obj.meta_path = fullfile(directory, [name '.json']);
            obj.data_path = fullfile(directory, [name '.dat']);
            qd.util.assert(~exist(obj.meta_path));
            qd.util.assert(~exist(obj.data_path));
        end

        function add_column(obj, name, unit)
            obj.columns{end + 1} = struct('name', name, 'unit', unit); 
        end

        function add_channel_column(obj, chan)
            obj.columns{end + 1} = struct('name', chan.name, 'unit', '');
            % TODO proper handling of units.
        end

        function init(obj)
            qd.util.assert(~obj.initialized);
            json.write(obj.columns, obj.meta_path);
            obj.file = fopen(obj.data_path, 'wt');
            obj.initialized = true;
        end

        function add_point(obj, data)
            if ~obj.initialized
                obj.init();
            end
            qd.util.assert(length(data) == length(obj.columns));
            fprintf(obj.file, '%.16G\t', data);
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

    end
end