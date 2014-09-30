classdef Line
    properties
        chans
        from
        to
        points
        job
    end
    methods
        function exec(obj, ctx, future, prefix)
            d = obj.to - obj.from;
            for v = linspace(0, 1, obj.points)
                x = obj.from + v*d;
                for i = 1:length(obj.chans)
                    future = future & obj.chans{i}.set_async(x(i));
                end
                obj.job.exec(ctx, future, [prefix x]);
                future = [];
            end
        end

        function t = time(obj, options)
            t = obj.job.time(options)*obj.points;
        end

        function r = reversed(obj)
            r = qd.q.impl.Line();
            r.chans = obj.chans;
            r.from = obj.to;
            r.to = obj.from;
            r.points = obj.points;
            r.job = obj.job.reversed();
        end

        function cs = columns(obj)
            name_structs = qd.util.map(@(c) struct('name', c.name()), obj.chans);
            cs = [name_structs obj.job.columns()];
        end

        function meta = describe(obj, register)
            meta = struct;
            meta.type = 'Line';
            meta.chans = qd.util.map(@(c) register.put('channels', c), obj.chans);
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
            t = sprintf('line {%s} from [%s] to [%s] in %d steps\n%s', ...
                qd.util.strjoin(qd.util.map(@(c) ['''' c.name ''''], obj.chans), ', '), ...
                qd.util.strjoin(qd.util.map(@(v) sprintf('%g', v), obj.from), ', '). ...
                qd.util.strjoin(qd.util.map(@(v) sprintf('%g', v), obj.to), ', '). ...
                obj.points, ...
                qd.util.indent(obj.job.pprint()));
        end

    end
end
