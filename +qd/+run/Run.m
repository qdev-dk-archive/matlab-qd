classdef Run < handle
    properties
        name = ''
        setup
        meta = struct
        comment = ''
        directory
        store
    end
    methods
        function obj = Run()
            if strcmp(qd.util.class_name(obj, 'full'), 'qd.run.Run')
                error([ ...
                    'This is an abstract base class. ' ...
                    'Please use one of the more specialized '...
                    'classes, like qd.run.StandardRun']);
            end
        end

        function obj = set_name(obj, name)
            obj.name = name;
        end

        function obj = set_setup(obj, setup)
            obj.setup = setup;
        end

        function obj = set_meta(obj, meta)
            obj.meta = meta;
        end

        function obj = set_comment(obj, comment)
            obj.comment = comment;
        end

        function obj = set_directory(obj, directory)
            obj.directory = directory;
        end

        function obj = in(obj, store)
            obj.store = store;
        end

        function chan = resolve_channel(obj, name_or_channel)
            chan = name_or_channel;
            if ischar(name_or_channel)
                if isempty(obj.setup)
                    error(['You need to configure a setup for this run before '...
                        'you can add a channel by name.']);
                end
                chan = obj.setup.find_channel(name_or_channel);
            end
        end

        function r = get_type(obj)
            r = qd.util.class_name(obj);
        end

        function r = version(obj)
            r = '0.0.1';
        end

        function meta = get_meta(obj)
            % Setup meta data
            register = qd.classes.Register();
            meta = struct();
            meta.type = obj.get_type();
            meta.version = obj.version();
            meta.timestamp = datestr(clock(),31);
            meta.meta = obj.meta;
            meta.comment = obj.comment;
            meta.name = obj.name;
            if ~isempty(obj.setup)
                meta.setup = obj.setup.describe(register);
            end

            % Allow overriding meta data stored;
            meta = obj.add_to_meta(meta, register);

            meta.register = register.describe();
        end

        function out_dir = run(obj)
            meta = obj.get_meta();
            
            % Get a directory to store the output.
            if ~isempty(obj.directory)
                out_dir = obj.directory;
            else
                out_dir = obj.store.new_dir();
            end

            % Store the metadata.
            json.write(meta, fullfile(out_dir, 'meta.json'), 'indent', 2);

            obj.perform_run(out_dir);
        end
    end

    methods(Access=protected)
        function perform_run(obj)
        end

        function meta = add_to_meta(obj, meta, register)
        end
    end
end