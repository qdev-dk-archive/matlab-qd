classdef Repeat
    properties
        repeats
        job
    end
    methods
        function exec(obj, ctx, future, settle, prefix)
            for i = 1:obj.repeats
                obj.job.exec(ctx, future, settle, [prefix i]);
                future = [];
                settle = 0;
            end
        end

        function t = time(obj, options, settling_time)
            if obj.repeats == 0
                t = 0
                return
            end
            time_for_first = obj.job.time(options, settling_time);
            time_for_remaining = obj.job.time(options, 0);
            t = time_for_first + time_for_remaining*(obj.repeats - 1);
        end

        function r = reversed(obj)
            r = qd.q.impl.Repeat();
            r.points = obj.repeats;
            r.job = obj.job.reversed();
        end

        function cs = columns(obj)
            cs = [{struct('name', 'repeat')} obj.job.columns()];
        end

        function meta = describe(obj, register)
            meta = struct;
            meta.type = 'Repeat';
            meta.repeats = obj.repeats;
            meta.job = obj.job.describe(register);
        end

        function p = total_points(obj)
            p = obj.repeats * obj.job.total_points();
        end

        function t = pprint(obj)
            t = sprintf('repeat %d\n%s', ...
                obj.repeats, ...
                qd.util.indent(obj.job.pprint()));
        end

    end
end