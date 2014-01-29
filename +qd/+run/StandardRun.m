classdef StandardRun < qd.run.RunWithInputs
    properties
        sweeps = {}
        initial_settle = 0;
    end
    methods

        function obj = sweep(obj, name_or_channel, from, to, points, varargin)
            p = inputParser();
            p.addOptional('settle', 0);
            p.addOptional('retrace', false);
            p.parse(varargin{:});
            sweep = struct();
            sweep.from = from;
            sweep.to = to;
            sweep.points = points;
            sweep.settle = p.Results.settle;
            sweep.retrace = p.Results.retrace;
            sweep.chan = obj.resolve_channel(name_or_channel);
            obj.sweeps{end + 1} = sweep;
        end

        function obj = clear_sweeps(obj)
            obj.sweeps = {};
        end

        function move_to_start(obj)
            futures = {};
            for sweep = obj.sweeps
                futures{end + 1} = sweep{1}.chan.set_async(sweep{1}.from);
            end
            for i = futures
                i{1}.exec();
            end
        end

        function move_to_end(obj)
            futures = {};
            for sweep = obj.sweeps
                futures{end + 1} = sweep{1}.chan.set_async(sweep{1}.to);
            end
            for i = futures
                i{1}.exec();
            end
        end

        function move_to_zero(obj)
            futures = {};
            for sweep = obj.sweeps
                futures{end + 1} = sweep{1}.chan.set_async(0);
            end
            for i = futures
                i{1}.exec();
            end
        end

    end

    methods(Access=protected)

        function meta = add_to_meta(obj, meta, register)
            meta.sweeps = {};
            for sweep = obj.sweeps
                sweep = sweep{1};
                s = struct();
                s.from = sweep.from;
                s.to = sweep.to;
                s.points = sweep.points;
                s.settle = sweep.settle;
                s.retrace = sweep.retrace;
                s.chan = register.put('channels', sweep.chan);
                meta.sweeps{end+1} = s;
            end
            add_to_meta@qd.run.RunWithInputs(obj, meta, register);
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
            obj.handle_sweeps(obj.sweeps, [], obj.initial_settle, table, false);
        end

        function row_hook(obj, sweep_values, inputs)
        % row_hook(sweep_values, inputs)
        %
        % This method is called by handle_sweeps after a row is added to the
        % table. sweep_values and inputs are arays of doubles. inputs contains
        % one value for each input channel (in the same order as obj.inputs).
        % sweep_values is [ealier_values sweeps] where earlier_values is as
        % specified to the call to handle_sweeps (usually []) and sweeps is
        % the current value of each swept parameter. The default implementaion
        % of this function does nothing.
        %
        % This function can be used to print out status information or abort
        % the run (by throwing an exception).
        end

        function handle_sweeps(obj, sweeps, earlier_values, settle, table, retrace)
        % obj.handle_sweeps(sweeps, earlier_values, settle, table, retrace)
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
                    pause(settle);
                end
                inputs = obj.read_inputs();
                values = [earlier_values inputs];
                table.add_point(values);
                obj.row_hook(earlier_values, inputs);
                drawnow();
                return
            end

            % Sweep one channel. Within the loop, recusively call this
            % function with one less channel to sweep.
            sweep = sweeps{1};
            next_sweeps = sweeps(2:end);
            if(obj.is_time_chan(sweep.chan) && (~sweep.points))
                % This is supposed to run until sweep.to time has passed,
                % and then measure as many points as possible during the given time.
                % sometimes you don't know how long it takes to set a channel
                settle = max(settle, sweep.settle);
                % Go to starting point and begin timer
                sweep.chan.set(sweep.from);
                while true
                    value = sweep.chan.get();
                    if value > sweep.to
                        break
                    end
                    obj.handle_sweeps(next_sweeps, [earlier_values value], settle, table, retrace);
                    retrace = ~retrace;
                end
                settle = 0;
            else
                % % This is supposed to run a given number of times
                % if(obj.is_time_chan(sweep.chan) && (sweep.from == 0) && (sweep.to == Inf))
                %     % In this case a measurement is supposed to run sweep.points number of times
                %     % ignore retrace
                %     to = sweep.points
                %     from = sweep.from;
                if sweep.retrace && retrace
                    % Measure backwards
                    from = sweep.to;
                    to = sweep.from;
                else
                    % Measure as usual
                    from = sweep.from;
                    to = sweep.to;
                end
                for value = linspace(from, to, sweep.points)
                    sweep.chan.set(value);
                    settle = max(settle, sweep.settle);
                    obj.handle_sweeps(next_sweeps, [earlier_values value], settle, table, retrace);
                    retrace = ~retrace;
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
end
