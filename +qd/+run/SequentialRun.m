classdef SequentialRun < qd.run.RunWithInputs
    properties
        sweeps = {}
        inputs = {}
        initial_settle = 0;
    end
    methods

        function obj = sweep(obj, name_or_channel, from, to, points, varargin)
            p = inputParser();
            p.addOptional('settle', 0);
            p.addOptional('initial_settle', 0);
            p.parse(varargin{:});
            sweep = struct();
            sweep.type = 'sweep';
            sweep.from = from;
            sweep.to = to;
            sweep.points = points;
            sweep.settle = p.Results.settle;
            sweep.initial_settle = p.Results.initial_settle;
            sweep.chan = obj.resolve_channel(name_or_channel);
            if(obj.is_time_chan(sweep.chan) && (sweep.from == 0))
                sweep.chan.instrument.reset;
            end
            obj.sweeps{end + 1} = sweep;
        end

        function obj = func(obj, func_handle, args)
            p = inputParser();
            p.addOptional('runs', 1);
            p.addOptional('settle', 0);
            p.addOptional('initial_settle', 0);
            p.parse(varargin{:});
            func = struct();
            func.type = 'func';
            func.args = args;
            func.func = func_handle;
            func.runs = p.Results.runs;
            func.settle = p.Results.settle;
            func.initial_settle = p.Results.initial_settle;

            obj.sweeps{end + 1} = func;
        end

        function obj = clear_sweeps(obj)
            obj.sweeps = {};
        end

        function obj = input(obj, name_or_channel)
            chan = obj.resolve_channel(name_or_channel);
            obj.inputs{end + 1} = chan;
            if obj.is_time_chan(chan)
                chan.instrument.reset;
            end
        end

        function move_to_start(obj)
            futures = {};
            for sweep = obj.sweeps
                if strcmp(sweep{1}.type,'sweep')
                    futures{end + 1} = sweep{1}.chan.set_async(sweep{1}.from);
                end
            end
            for i = futures
                i{1}.exec();
            end
        end

        function move_to_end(obj)
            futures = {};
            for sweep = obj.sweeps
                if strcmp(sweep{1}.type,'sweep')
                    futures{end + 1} = sweep{1}.chan.set_async(sweep{1}.to);
                end
            end
            for i = futures
                i{1}.exec();
            end
        end

        function move_to_zero(obj)
            futures = {};
            for sweep = obj.sweeps
                if strcmp(sweep{1}.type,'sweep')
                    futures{end + 1} = sweep{1}.chan.set_async(0);
                end
            end
            for i = futures
                i{1}.exec();
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
                if strcmp(sweep{1}.type,'sweep')
                    sweep = sweep{1};
                    s = struct();
                    s.from = sweep.from;
                    s.to = sweep.to;
                    s.points = sweep.points;
                    s.settle = sweep.settle;
                    s.initial_settle = sweep.initial_settle;
                    s.chan = register.put('channels', sweep.chan);
                    meta.sweeps{end+1} = s;
                elseif (strcmp(sweep{1}.type,'func'))
                    sweep = sweep{1};
                    f = struct();
                    f.func = func2str(sweep.func_handle);
                    f.runs = sweep.runs;
                    f.settle = sweep.settle;
                    f.initial_settle = sweep.initial_settle;
                    meta.funcs{end+1} = f;
                end
            end
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

        function perform_run(obj, out_dir)
            % This table will hold the data collected.
            table = qd.data.TableWriter(out_dir, 'data');
            % Measure all the input channels
            for inp = obj.inputs
                table.add_channel_column(inp{1});
            end
            table.init();

            % Now perform all the measurements.
            for sweep = obj.sweeps
                sweep = sweep{1};
                % for the first iteration add the initial settle this is set to zero for all further iterations
                settle = sweep.initial_settle;

                % check if sweep is a function, if so execute it
                if strcmp(sweep.type,'func')
                    % evaluate function
                    for i = 1:sweep.runs
                        sweep.func(sweep.args{:});
                        % get the settle time, on first iteration also include the initial settle
                        settle = max(settle, sweep.settle);
                        if(sweep.settle > 0)
                            pause(sweep.settle);
                        end
                        % This makes it possible to break a run
                        drawnow();
                        settle = 0;
                    end
                elseif strcmp(sweep.type,'sweep')
                    % if channel is from a Time instrument and sweep.from is 0 reset the timer
                    if(strcmp(sweep.chan.instrument.default_name,'Time') && (sweep.from == 0))
                        sweep.chan.instrument.reset();
                    end
                    % Create the sweep
                    for value = linspace(sweep.from, sweep.to, sweep.points)
                        % Set the value
                        sweep.chan.set(value);
                        % get the settle time, on first iteration also include the initial settle
                        settle = max(settle, sweep.settle);
                        if(settle > 0)
                            pause(settle);
                        end
                        % Read the inputs asynchronously
                        futures = {};
                        inputs = obj.read_inputs();
                        % Save the data
                        table.add_point(inputs);
                        obj.row_hook([], inputs);
                        % This makes it possible to break a run
                        drawnow();
                        settle = 0;
                    end
                    % Nicely seperate everything for gnuplot.
                    table.add_divider();
                end
            end
        end
        function r = is_time_chan(obj, chan)
            r = strcmp(chan.channel_id,'time');
        end
    end
end
