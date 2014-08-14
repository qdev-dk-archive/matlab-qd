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
        function exec(obj, ctx, settle, prefix)
            for value = linspace(obj.from, obj.to, obj.points)
                obj.chan.set(value);
                obj.job.exec(ctx, max(settle, obj.settle), [prefix value]);
                settle = 0
            end
        end

        function t = time(obj, ctx, options, settling_time)
            extra_settle_on_first_point = max(0, settling_time - obj.settle);
            time_per_point = (obj.job.time(ctx, options, obj.settle));
            t = self.points * time_per_point + extra_settle_on_first_point;
        end

        function r = reversed(obj)
            r = qd.q.Sweep();
            r.chan = obj.chan;
            r.from = obj.to;
            r.to = obj.from;
            r.points = obj.points;
            r.settle = obj.settle;
            r.job = obj.job.reversed();
        end

        function cs = columns(obj)
            cs = {struct('name', obj.chan.name()) obj.job.columns()};
        end

    end
end