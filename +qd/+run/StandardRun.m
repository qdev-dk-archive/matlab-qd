classdef StandardRun < handle
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
        function obj = StandardRun()
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
                    sweep.settle = varargin{1};
                otherwise
                    error('Got too many arguments.');
            end
            chan = name_or_channel;
            if ischar(name_or_channel)
                if isempty(obj.setup)
                    error(['You need to configure a setup for this run before '...
                        'you can add a channel by name.']);
                end
                chan = obj.setup.find_channel(name_or_channel);
            end
            for other = obj.sweeps
                other = other{1};
                if strcmp(other.chan.name, chan.name)
                    error('A channel of this name is already being swept.');
                end
            end
            sweep.chan = chan;
            obj.sweeps{end + 1} = sweep;
        end

        function obj = clear_sweeps(obj)
            obj.sweeps = {};
        end
        
        function obj = input(obj, name_or_channel)
            chan = name_or_channel;
            if ischar(name_or_channel) && ~isempty(obj.setup)
                chan = obj.setup.find_channel(name_or_channel);
            end
            obj.inputs{end + 1} = chan;
        end

        function out_dir = run(obj)
            % Setup meta data
            meta = struct();
            meta.type = 'standard run';
            meta.version = '0.0.1';
            meta.timestamp = datestr(clock(),31);
            meta.meta = obj.meta;
            meta.comment = obj.comment;
            meta.name = obj.name;
            if ~isempty(obj.setup)
                meta.setup = obj.setup.describe();
            end
            meta.inputs = {};
            for inp = obj.inputs
                inp = inp{1};
                if qd.util.cellmember(inp.instrument, obj.setup.instruments)
                    meta.inputs{end + 1} = inp.describe_without_instrument();
                else
                    meta.inputs{end + 1} = inp.describe();
                end
            end
            meta.sweeps = {};
            for sweep = obj.sweeps
                sweep = sweep{1};
                s = struct();
                s.chan = sweep.chan.name;
                s.from = sweep.from;
                s.to = sweep.to;
                s.points = sweep.points;
                s.settle = sweep.settle;
                meta.sweeps{end+1} = s;
                if qd.util.cellmember(sweep.chan, obj.setup.instruments)
                    s.chan = sweep.chan.describe_without_instrument();
                else
                    s.chan = sweep.chan.describe();
                end
            end

            % Get a directory to store the output.
            if ~isempty(obj.directory)
                out_dir = obj.directory;
            else
                out_dir = obj.store.new_dir();
            end

            % Store the metadata.
            json.write(meta, fullfile(out_dir, 'meta.json'));

            % This table will hold the data collected.
            table = qd.data.TableWriter(out_dir, 'data');
            for sweep = obj.sweeps
                sweep = sweep{1};
                 % TODO. No proper handling of units yet.
                table.add_column(sweep.chan.name, '');
            end
            for inp = obj.inputs
                inp = inp{1};
                 % TODO. No proper handling of units yet.
                table.add_column(inp.name, '');
            end
            table.init();

            % Now perform all the measurements.
            obj.handle_sweeps(obj.sweeps, [], 0, obj.inputs, table);
        end
    end

    methods(Access=private)
        function handle_sweeps(obj, sweeps, earlier_values, settle, inputs, table)
            % If there are no more sweeps left, let the system settle, then
            % measure one point.
            if isempty(sweeps)
                if(settle > 0)
                    pause(settle/1000);
                end
                values = [earlier_values];
                for inp = inputs
                    inp = inp{1};
                    values(end+1) = inp.get();
                end
                table.add_point(values);
                return
            end

            % Sweep one channel. Within the loop, recusively call this
            % function with one less channel to sweep.
            sweep = sweeps{1};
            next_sweeps = sweeps(2:end);
            for value = linspace(sweep.from, sweep.to, sweep.points)
                sweep.chan.set(value);
                settle = max(settle, sweep.settle);
                obj.handle_sweeps(next_sweeps, [earlier_values value], settle, inputs, table);
                if ~isempty(next_sweeps)
                    % Nicely seperate everything for gnuplot.
                    table.add_divider();
                end
            end
        end
    end
end