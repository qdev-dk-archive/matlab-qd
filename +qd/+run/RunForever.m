classdef RunForever < qd.run.StandardRun
% Repeatedly perform the same StandardRun into one table.

    properties
        delay = 0 % Seconds to wait between each run.
    end

    methods(Access=protected)
        function perform_run(obj, out_dir)
            table = qd.data.TableWriter(out_dir, 'data');
            table.add_column('iteration');
            for sweep = obj.sweeps
                table.add_channel_column(sweep{1}.chan);
            end
            for inp = obj.inputs
                table.add_channel_column(inp{1});
            end
            table.init();
            
            i = 0;
            while true
                obj.handle_sweeps(obj.sweeps, [i], obj.delay * 1000, table);
                table.add_divider();
                i = i + 1;
            end
        end
    end
end