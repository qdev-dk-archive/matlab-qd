classdef Forever
    properties
        job
    end
    methods
        function exec(obj, ctx, future, prefix)
            i = 0;
            while true
                obj.job.exec(ctx, future, [prefix i]);
                i = i + 1;
                future = [];
            end
        end

        function t = time(obj, options)
            t = inf;
        end

        function r = reversed(obj)
            r = qd.q.impl.Forever();
            r.job = obj.job.reversed();
        end

        function cs = columns(obj)
            cs = [{struct('name', 'repeat')} obj.job.columns()];
        end

        function meta = describe(obj, register)
            meta = struct;
            meta.type = 'Forever';
            meta.job = obj.job.describe(register);
        end

        function p = total_points(obj)
            p = inf;
        end

        function t = pprint(obj)
            t = sprintf('forever\n%s', ...
                qd.util.indent(obj.job.pprint()));
        end

    end
end
