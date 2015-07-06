classdef Timed
    properties
        job
        running_time
    end
    methods
        function exec(obj, ctx, future, prefix)
            i = 0;
            t = tic();
            while true
                obj.job.exec(ctx, future, [prefix i]);
                i = i + 1;
                future = [];
                if toc(t) > obj.running_time
                    break
                end
            end
        end

        function t = time(obj, options)
            t = obj.running_time;
        end

        function r = reversed(obj)
            r = qd.q.impl.Timed();
            r.job = obj.job.reversed();
            r.running_time = obj.running_time
        end

        function cs = columns(obj)
            cs = [{struct('name', 'repeat')} obj.job.columns()];
        end

        function meta = describe(obj, register)
            meta = struct;
            meta.type = 'Timed';
            meta.job = obj.job.describe(register);
            meta.running_time = obj.running_time;
        end

        function p = total_points(obj)
            p = nan;
        end

        function t = pprint(obj)
            t = sprintf('for %s\n%s', qd.util.format_seconds(obj.running_time), ...
                qd.util.indent(obj.job.pprint()));
        end

    end
end
