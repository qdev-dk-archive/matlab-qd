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
                settle = max(settle, obj.settle)
                obj.job.exec(ctx, future, settle, [prefix value]);
                future = [];
                settle = 0;
            end
        end

        function t = time(obj, options, settling_time)
            extra_settle_on_first_point = max(0, settling_time - obj.settle);
            time_per_point = (obj.job.time(options, obj.settle));
            t = obj.points * time_per_point + extra_settle_on_first_point;
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

    end
end