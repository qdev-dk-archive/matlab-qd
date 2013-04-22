classdef Simple < handle
    properties
        name = ''
        setup
        sweeps
        inputs
        meta = struct
        comment = ''
        directory
        store
    end
    methods
        function obj = Simple()
            obj.sweeps = {};
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

        function obj = set_directory(obj, director)
            obj.directory = directory;
        end

        function obj = in(obj, store)
            obj.store = store;
        end

        function obj = sweep(obj, name_or_channel, from, to, points, varargin)
            sweep = struct();
            sweep.from = from;
            sweep.to = to;
            sweep.points = points;
            switch length(varargin)
                case 0
                    sweep.settle = 0;
                case 1
                    sweep.settle = varargin(1);
                otherwise
                    error('Got too many arguments.');
            end
            chan = name_or_channel;
            if ischar(name_or_channel) && ~isempty(obj.setup)
                chan = obj.setup.find_channel(name_or_channel);
            end
            for other = obj.sweeps
                if strcmp(other.name(), chan.name())
                    error('A channel of this name is already being swept.');
                end
            end
            sweep.chan = chan;
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
            if ~isempty(obj.meta)
                meta.meta = obj.meta;
            end
            if ~isempty(obj.comment)
                meta.comment = obj.comment;
            end
            if ~isempty(obj.name)
                meta.name = obj.name;
            end
            if ~isempty(obj.setup)
                meta.setup = obj.setup.describe();
            end
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