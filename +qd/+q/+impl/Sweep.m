classdef Sweep
    properties
        chan
        from
        to
        points
        job
    end
    methods
        function exec(obj, ctx, future, prefix)
            for value = linspace(obj.from, obj.to, obj.points)
                future = future & obj.chan.set_async(value);
                obj.job.exec(ctx, future, [prefix value]);
                future = [];
            end
        end

        function t = time(obj, options)
            t = obj.job.time(options)*obj.points;
        end

        function r = reversed(obj)
            r = qd.q.impl.Sweep();
            r.chan = obj.chan;
            r.from = obj.to;
            r.to = obj.from;
            r.points = obj.points;
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