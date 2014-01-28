classdef Probe < qd.run.StandardRun
    % A Probe run is like a StandardRun, but it after a run, it does the run
    % again with all sweeps reversed. The run makes to tables in the data
    % folder, one called 'forward' and one called 'backward'.
    methods(Access=protected)

        function perform_run(obj, out_dir)
            tables = struct();
            for d = {'forward', 'backward'}
                table = qd.data.TableWriter(out_dir, d{1});
                for sweep = obj.sweeps
                    table.add_channel_column(sweep{1}.chan);
                end
                for inp = obj.inputs
                    table.add_channel_column(inp{1});
                end
                table.init();
                tables.(d{1}) = table;
            end
            
            % Sweep forward
            obj.handle_sweeps(obj.sweeps, [], obj.initial_settle, table.forward);
            % Reverse all sweep direction and sweep the other way.
            reversed_sweeps = {};
            for sweep = obj.sweeps
                reversed_sweep = sweep{1};
                reversed_sweep.from = sweep{1}.to;
                reversed_sweep.to = sweep{1}.from;
                reversed_sweeps{end + 1} = reversed_sweep;
            end
            obj.handle_sweepsreversed_sweeps, [], obj.initial_settle, table.backward);
        end

    end
end
