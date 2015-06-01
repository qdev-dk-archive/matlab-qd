classdef CallBefore
    properties
        func
        job
    end
    methods
        function exec(obj, ctx, future, prefix)

            % Should we forward the context and the future to the func? It
            % might make sense.
            obj.func();
            obj.job.exec(ctx, future, prefix);
        end

        function t = time(obj, options)
            t = obj.job.time(options);
        end

        function r = reversed(obj)
            r = qd.q.impl.CallBefore();
            r.func = obj.func;
            r.job = obj.job.reversed();
        end

        function cs = columns(obj)
            cs = obj.job.columns();
        end

        function meta = describe(obj, register)
            meta = struct;
            meta.type = 'CallBefore';
            meta.func = func2str(obj.func);
            meta.job = obj.job.describe(register);
        end

        function p = total_points(obj)
            p = obj.job.total_points();
        end

        function t = pprint(obj)
            t = sprintf('call %s\n%s', ...
                func2str(obj.func), ...
                obj.job.pprint());
        end

    end
end
