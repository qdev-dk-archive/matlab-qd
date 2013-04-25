classdef RunForever < qd.run.StandardRun
% Repeatedly perform the same StandardRun into one table.

    properties
        delay = 0 % Seconds to wait between each run.
    end

    methods(Access=protected)
        function perform_run(obj, out_dir)
            table = qd.data.TableWriter(out_dir, 'data');
            for sweep = obj.sweeps
                table.add_channel_column(sweep{1}.chan);
            end
            for inp = obj.inputs
                table.add_channel_column(inp{1});
            end
            table.init();

            while true
	            obj.handle_sweeps(obj.sweeps, [], obj.delay * 1000, table);
	            table.add_divider();
	        end
        end
    end
end