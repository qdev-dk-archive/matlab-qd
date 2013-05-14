classdef StandardRun < qd.run.Run
    properties
        sweeps = {}
        inputs = {}
        initial_settle = 0;
    end
    methods

        function obj = sweep(obj, name_or_channel, from, to, points, varargin)
            p = inputParser();
            p.addOptional('settle', 0);
            p.parse(varargin{:});
            sweep = struct();
            sweep.from = from;
            sweep.to = to;
            sweep.points = points;
            sweep.settle = p.Results.settle;
            sweep.chan = obj.resolve_channel(name_or_channel);
            obj.sweeps{end + 1} = sweep;
        end

        function obj = clear_sweeps(obj)
            obj.sweeps = {};
        end
        
        function obj = input(obj, name_or_channel)
            obj.inputs{end + 1} = obj.resolve_channel(name_or_channel);
        end

        function move_to_start(obj)
            for sweep = obj.sweeps
                sweep{1}.chan.set(sweep{1}.from);
            end
        end

        function zero_all_sweept_channels(obj)
            for sweep = obj.sweeps
                sweep{1}.chan.set(0);
            end
        end

    end

    methods(Access=protected)

        function meta = add_to_meta(obj, meta, register)
            meta.inputs = {};
            for inp = obj.inputs
                meta.inputs{end + 1} = register.put('channels', inp{1});
            end
            meta.sweeps = {};
            for sweep = obj.sweeps
                sweep = sweep{1};
                s = struct();
                s.from = sweep.from;
                s.to = sweep.to;
                s.points = sweep.points;
                s.settle = sweep.settle;
                s.chan = register.put('channels', sweep.chan);
                meta.sweeps{end+1} = s;
            end
        end

        function perform_run(obj, out_dir)
            % This table will hold the data collected.
            table = qd.data.TableWriter(out_dir, 'data');
            for sweep = obj.sweeps
                table.add_channel_column(sweep{1}.chan);
            end
            for inp = obj.inputs
                table.add_channel_column(inp{1});
            end
            table.init();

            % Now perform all the measurements.
            obj.handle_sweeps(obj.sweeps, [], obj.initial_settle, table);
        end

        function handle_sweeps(obj, sweeps, earlier_values, settle, table)
        % obj.handle_sweeps(sweeps, earlier_values, settle, table)
        % 
        % Sweeps the channels in sweeps, takes measurements and puts them in
        % table.
        %
        % sweeps is a cell array of structs with the fields: from, to, points,
        % chan, and settle. Rows will be added to table which look like:
        % [earlier_values sweeps inputs] where earlier_values is an array of
        % doubles, sweeps, is the current value of each swept parameter, and
        % inputs are the measured inputs (the channels in obj.inputs). Settle
        % is the amount of time to wait before measuring a sample (in ms).

            % If there are no more sweeps left, let the system settle, then
            % measure one point.
            if isempty(sweeps)
                if(settle > 0)
                    pause(settle/1000);
                end
                values = [earlier_values];
                for inp = obj.inputs
                    values(end+1) = inp{1}.get();
                end
                table.add_point(values);
                drawnow();
                return
            end

            % Sweep one channel. Within the loop, recusively call this
            % function with one less channel to sweep.
            sweep = sweeps{1};
            next_sweeps = sweeps(2:end);
            for value = linspace(sweep.from, sweep.to, sweep.points)
                sweep.chan.set(value);
                settle = max(settle, sweep.settle);
                obj.handle_sweeps(next_sweeps, [earlier_values value], settle, table);
                % In the first iteration of the loop, we need to wait for the
                % previously changed value to settle. We also need to wait for
                % this value to settle, whichever is greater. In the next
                % iteration of the loop, we only need to wait for this value,
                % therefore settle is set to 0 here.
                settle = 0;
                if ~isempty(next_sweeps)
                    % Nicely seperate everything for gnuplot.
                    table.add_divider();
                end
            end
        end
    end
end