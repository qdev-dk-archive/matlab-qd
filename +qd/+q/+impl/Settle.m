classdef Settle
    properties
        settle
        job
    end
    methods
        function exec(obj, ctx, future, prefix)
            future.exec();
            pause(obj.settle);
            obj.job.exec(ctx, [], prefix);
        end

        function t = time(obj, options)
            t = obj.settle + obj.job.time(options);
        end

        function r = reversed(obj)
            r = qd.q.impl.Settle();
            r.settle = obj.settle;
            r.job = obj.job.reversed();
        end

        function cs = columns(obj)
            cs = obj.job.columns();
        end

        function meta = describe(obj, register)
            meta = struct;
            meta.type = 'Settle';
            meta.settle = obj.settle;
            meta.job = obj.job.describe(register);
        end

        function p = total_points(obj)
            p = obj.job.total_points();
        end

        function t = pprint(obj)
            t = sprintf('settle %g\n%s', ...
                obj.settle, ...
                obj.job.pprint());
        end

    end
end