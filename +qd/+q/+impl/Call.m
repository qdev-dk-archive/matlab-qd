classdef Call
    properties
        func
        job
    end
    methods
        function exec(obj, ctx, future, prefix)

            % We replace the add_point function in ctx with one that records added points.
            added_points = [];
            old_add_point = ctx.add_point;
            function add_point(p)
                old_add_point(p);
                added_points = [added_points; p];
            end
            ctx.add_point = @(p) add_point(p);
            obj.job.exec(ctx, future, prefix);
            obj.func(added_points);
        end

        function t = time(obj, options)
            t = obj.job.time(options);
        end

        function r = reversed(obj)
            r = qd.q.impl.Call();
            r.func = obj.func;
            r.job = obj.job.reversed();
        end

        function cs = columns(obj)
            cs = obj.job.columns();
        end

        function meta = describe(obj, register)
            meta = struct;
            meta.type = 'Call';
            meta.func = func2str(obj.func);
            meta.job = obj.job.describe(register);
        end

        function p = total_points(obj)
            p = obj.job.total_points();
        end

        function t = pprint(obj)
            t = sprintf('%s\ncall %s', ...
                obj.job.pprint(), ...
                func2str(obj.func));
        end

    end
end
