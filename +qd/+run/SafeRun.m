classdef SafeRun < qd.run.StandardRun
    properties
        running = false;
        stopnow = false;
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
    end

	methods(Access=protected)
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
        	obj.running = true;
            obj.stopnow = false;
            % Start meas control window.
            hMeasControl = meas_control(obj);
            % Now perform all the measurements.
            obj.handle_sweeps(obj.sweeps, [], obj.initial_settle, table);
            close(hMeasControl);
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
                    pause(settle);
                end
                values = [earlier_values];
                futures = {};
                for inp = obj.inputs
                    futures{end + 1} = inp{1}.get_async();
                end
                for future = futures
                    values(end + 1) = future{1}.exec();
                end
                table.add_point(values);
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
                % If the measurement has to be stopped, break here
                if obj.stopnow
                    break
                end
            end
        end
	end
end
