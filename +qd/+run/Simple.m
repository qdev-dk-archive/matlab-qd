classdef Simple < handle
    properties(Access=private)
        name_
        setup_
        sweeps
        inputs
        meta_
        comment_
        directory
        store
    end
    methods
        function obj = Simple()
            obj.sweeps = {};
        end

        function obj = name(obj, name)
            obj.name_ = name;
        end

        function obj = setup(obj, setup)
            obj.setup_ = setup;
        end

        function obj = meta(obj, meta)
            obj.meta_ = meta;
        end

        function obj = comment(obj, comment)
            obj.comment_ = comment;
        end

        function obj = output_directory(obj, director)
            obj.directory = directory;
        end

        function obj = in(obj, store)
            obj.store = store;
        end

        function obj = sweep(obj, name_or_channel, from, to, points)
            chan = name_or_channel;
            if ischar(name_or_channel) && ~isempty(obj.setup)
                chan = obj.setup.find_channel(name_or_channel);
            end
            for other = obj.sweeps
                if strcmp(other.name(), chan.name())
                    error('A channel of this name is already being swept.');
                end
            end
            sweep = struct();
            sweep.chan = chan;
            sweep.from = from;
            sweep.to = to;
            sweep.points = points;
            obj.sweeps{end + 1} = sweep;
        end

        function obj = input(obj, name_or_channel)
            chan = name_or_channel;
            if ischar(name_or_channel) && ~isempty(obj.setup)
                chan = obj.setup.find_channel(name_or_channel);
            end
        end

        function run(obj)
            meta = struct();
            meta.type = 'simple run';
            meta.version = '0.0.1';
            meta.timestamp = datestr(clock(),31);
            if ~isempty(obj.meta_)
                meta.meta = obj.meta_;
            end
            if ~isempty(obj.comment_)
                meta.comment = obj.comment_;
            end
            if ~isempty(obj.name_)
                meta.name = obj.name_;
            end
            % TODO add setup to meta
            % TODO add inputs to meta
            % TODO add sweeps to meta
            % TODO set up columns
            % TODO add columns to meta
            if ~isempty(obj.output_directory)
                out_dir = obj.output_directory;
            else
                out_dir = obj.store.new_dir();
            end
            % TODO store meta
            % TODO open table
            obj.handle_sweeps(sweeps, [], 0, inputs, table)
        end
    end
    methods(Access=private)
        function handle_sweeps(sweeps, earlier_values, settle, inputs, table)
            if isempty(sweeps)
                if(settle > 0)
                    pause(settle/1000);
                end
                values = [earlier_values];
                for inp = inputs
                    values(end+1) = inp.get();
                end
                table.add_point(values);
            end
            % TODO do sweep and recursively call handle sweeps.
        end
    end
end