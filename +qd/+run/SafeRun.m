classdef SafeRun < qd.run.StandardRun
    properties
        running = false;
        stopnow = false;
    end
    properties(Access=private)
        columns
    end
    methods
        function pause_run(obj)
            disp('Run will pause.');
            obj.running = false;
        end

        function continue_run(obj)
            disp('Run continued.');
            obj.running = true;
        end

        function stop_run(obj)
            disp('Run stopped.');
            obj.stopnow = true;
        end

        function obj = sweep(obj, name_or_channel, from, to, points, varargin)
            p = inputParser();
            p.addOptional('settle', 0);
            p.addOptional('tolerance', []);
            p.addOptional('values', []);
            p.addOptional('alternate', false);
            p.parse(varargin{:});
            sweep = struct();
            sweep.from = from;
            sweep.to = to;
            sweep.points = points;
            sweep.settle = p.Results.settle;
            sweep.tolerance = p.Results.tolerance;
            sweep.alternate = p.Results.alternate;
            if(isempty(p.Results.values))
                sweep.values = linspace(from, to, points);
            else
                sweep.values = p.Results.values;
            end
            sweep.chan = obj.resolve_channel(name_or_channel);
            if(strcmp(name_or_channel,'time/time') && (sweep.from == 0))
                sweep.chan.instrument.reset;
            end
            obj.sweeps{end + 1} = sweep;
        end
    end
    
    methods(Access=protected)
        function perform_run(obj, out_dir)
            % This table will hold the data collected.
            table = qd.data.TableWriter(out_dir, 'data');
            obj.columns = {};
            for sweep = obj.sweeps
                table.add_channel_column(sweep{1}.chan);
                obj.columns{end+1} = sweep{1}.chan.name;
            end
            for inp = obj.inputs
                table.add_channel_column(inp{1});
                obj.columns{end+1} = inp{1}.name;
            end
            table.init();
            obj.running = true;
            obj.stopnow = false;
            % Start meas control window.
            hMeasControl = meas_control(obj);
            % Create plots
            obj.create_plots();
            % Now perform all the measurements.
            obj.handle_sweeps(obj.sweeps, [], table);
            close(hMeasControl);
        end

        function handle_sweeps(obj, sweeps, earlier_values, table)
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
                %values = [earlier_values];
                values = [];
                futures = {};
                for sweep = obj.sweeps
                    futures{end + 1} = sweep{1}.chan.get_async();
                end
                for inp = obj.inputs
                    futures{end + 1} = inp{1}.get_async();
                end
                for future = futures
                    values(end + 1) = future{1}.exec();
                end
                % Add data point
                table.add_point(values); % Write data point to file
                obj.update_plots(values);
                drawnow();
                if obj.running
                    return
                else
                    disp('Click continue.');
                    while (not(obj.running) && not(obj.stopnow))
                        pause(1);
                    end
                    return
                end
            end

            % Sweep one channel. Within the loop, recusively call this
            % function with one less channel to sweep.
            sweep = sweeps{1};
            next_sweeps = sweeps(2:end);
            if(obj.is_time_chan(sweep.chan) && (~sweep.points))
                % This is supposed to run until sweep.to time has passed,
                % and then measure as many points as possible during the given time.
                % sometimes you don't know how long it takes to set a channel
                settle = 0;
                settle = max(settle, sweep.settle);
                % Go to starting point and begin timer
                sweep.chan.set(sweep.from);
                while true
                    value = sweep.chan.get();
                    if value > sweep.to
                        break
                    end
                    if obj.stopnow
                        break
                    end
                    obj.handle_sweeps(next_sweeps, [earlier_values value], table);
                end
            else
                for value = sweep.values
                    sweep.chan.set(value);
                    if ~isempty(sweep.tolerance)
                        curval = sweep.chan.get();
                        fprintf('Setting %s=%f to %f\r',sweep.chan.name,curval,value);
                        while true
                            curval = sweep.chan.get();
                            if abs(value-curval)<sweep.tolerance
                                break;
                            else
                                pause(sweep.settle);
                            end
                        end
                    else
                        pause(sweep.settle);
                    end
                    %settle = max(settle, sweep.settle);
                    obj.handle_sweeps(next_sweeps, [earlier_values value], table);
                    if ~isempty(next_sweeps)
                        % Nicely seperate everything for gnuplot.
                        table.add_divider();
                    end
                    % If the measurement has to be stopped, break here
                    if obj.stopnow
                        break
                    end
                end
            end
        end
    end
end
