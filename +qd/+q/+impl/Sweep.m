classdef Sweep
    properties
        chan
        from
        to
        points
        settle
        job
    end
    methods
        function exec(obj, ctx, future, settle, prefix)
            for value = linspace(obj.from, obj.to, obj.points)
                future = future & obj.chan.set_async(value);
                settle = max(settle, obj.settle);
                obj.job.exec(ctx, future, settle, [prefix value]);
                future = [];
                settle = 0;
            end
        end

        function t = time(obj, options, settling_time)
            if obj.points == 0
                t = 0;
                return;
            end
            time_for_first = obj.job.time(options, ...
                max(settling_time, obj.settle));
            time_for_remaining = obj.job.time(options, obj.settle);
            t = time_for_first + time_for_remaining*(obj.points - 1);
        end

        function r = reversed(obj)
            r = qd.q.impl.Sweep();
            r.chan = obj.chan;
            r.from = obj.to;
            r.to = obj.from;
            r.points = obj.points;
            r.settle = obj.settle;
            r.job = obj.job.reversed();
        end

        function cs = columns(obj)
            cs = [{struct('name', obj.chan.name())} obj.job.columns()];
        end

        function meta = describe(obj, register)
            meta = struct;
            meta.type = 'Sweep';
            meta.chan = register.put('channels', obj.chan);
            meta.from = obj.from;
            meta.to = obj.to;
            meta.points = obj.points;
            meta.repeats = obj.points;
            meta.settle = obj.settle;
            meta.job = obj.job.describe(register);
        end

        function p = total_points(obj)
            p = obj.points * obj.job.total_points();
        end

        function t = pprint(obj)
            t = sprintf('sweep ''%s'' from %g to %g in %d steps\n%s', ...
                obj.chan.name, obj.from, obj.to, obj.points, ...
                qd.util.indent(obj.job.pprint()));
        end

    end
end