classdef Probe < qd.run.Run
    properties
        sweep
        inputs = {}
    end
    methods

        function obj = set_sweep(obj, name_or_channel, from, to, points, settle)
            obj.sweep = struct();
            obj.sweep.from = from;
            obj.sweep.to = to;
            obj.sweep.points = points;
            obj.sweep.settle = settle;
            obj.sweep.chan = obj.resolve_channel(name_or_channel);
        end
        
        function obj = input(obj, name_or_channel)
            obj.inputs{end + 1} = obj.resolve_channel(name_or_channel);
        end
        
        function move_to_start(obj)
            obj.sweep.chan.set(obj.sweep.from);
        end
        
        function move_to_end(obj)
            obj.sweep.chan.set(obj.sweep.to);
        end
        
        function move_to_zero(obj)
            obj.sweep.chan.set(0);
        end

    end

    methods(Access=protected)

        function meta = add_to_meta(obj, meta, register)
            meta.inputs = {};
            for inp = obj.inputs
                meta.inputs{end + 1} = register.put('channels', inp{1});
            end
            meta.sweep = struct();
            meta.sweep.from = obj.sweep.from;
            meta.sweep.to = obj.sweep.to;
            meta.sweep.points = obj.sweep.points;
            meta.sweep.settle = obj.sweep.settle;
            meta.sweep.chan = register.put('channels', obj.sweep.chan);
        end

        function perform_run(obj, out_dir)
            tables = struct();
            for d = {'forward', 'backward'}
                table = qd.data.TableWriter(out_dir, d{1});
                table.add_channel_column(obj.sweep.chan);
                for inp = obj.inputs
                    table.add_channel_column(inp{1});
                end
                table.init();
                tables.(d{1}) = table;
            end
            obj.handle_sweep(obj.sweep.from, obj.sweep.to, tables.forward);
            obj.handle_sweep(obj.sweep.to, obj.sweep.from, tables.backward);
        end
    end

    methods(Access=private)
        function handle_sweep(obj, from, to, table)
            for value = linspace(from, to, obj.sweep.points)
                obj.sweep.chan.set(value);
                if(obj.sweep.settle > 0)
                    pause(obj.sweep.settle/1000);
                end
                values = [value];
                for inp = obj.inputs
                    values(end+1) = inp{1}.get();
                end
                table.add_point(values);
                drawnow();
            end
        end
    end
end