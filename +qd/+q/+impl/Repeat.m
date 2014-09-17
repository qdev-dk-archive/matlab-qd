classdef Repeat
    properties
        repeats
        job
    end
    methods
        function exec(obj, ctx, future, prefix)
            for i = 1:obj.repeats
                obj.job.exec(ctx, future, [prefix i]);
                future = [];
            end
        end

        function t = time(obj, options)
            t = obj.job.time(options)*obj.repeats;
        end

        function r = reversed(obj)
            r = qd.q.impl.Repeat();
            r.repeats = obj.repeats;
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