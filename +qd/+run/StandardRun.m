classdef StandardRun < qd.run.Run
    properties
        sweeps
        inputs
    end
    methods
        function obj = StandardRun()
            obj.sweeps = {};
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
            sweep.chan = obj.resolve_channel(name_or_channel);
            obj.sweeps{end + 1} = sweep;
        end

        function obj = clear_sweeps(obj)
            obj.sweeps = {};
        end
        
        function obj = input(obj, name_or_channel)
            obj.inputs{end + 1} = obj.resolve_channel(name_or_channel);
        end

    end

    methods(Access=protected)

        function add_to_meta(obj, meta)
            meta.inputs = {};
            for inp = obj.inputs
                inp = inp{1};
                meta.inputs{end + 1} = obj.describe_channel(inp);
            end
            meta.sweeps = {};
            for sweep = obj.sweeps
                sweep = sweep{1};
                s = struct();
                s.from = sweep.from;
                s.to = sweep.to;
                s.points = sweep.points;
                s.settle = sweep.settle;
                s.chan = obj.describe_channel(sweep.chan);
                meta.sweeps{end+1} = s;
            end
        end

        function perform_run(obj, out_dir)
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