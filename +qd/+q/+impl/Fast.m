classdef Fast
    properties
        chan
        instrument
        from
        to
        points
        job
    end
    methods
        function exec(obj, ctx, ~, prefix)
            % Add data to data structure
            for value = obj.readTrace();
                ctx.add_point([prefix value])
                ctx.periodic_hook();
            end
        end

        function t = time(obj, options)
            time_to_set = 0;
            if isfield(options, 'set_outputs') && options.set_outputs
                values = linspace(obj.from, obj.to, obj.points);
                obj.chan.set(values(1));
                tic;
                obj.chan.set(values(2));
                time_to_set = toc();
            end
            t = (time_to_set + obj.job.time(options))*obj.points;
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
            meta.type = 'Fast-Sweep';
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
            t = sprintf('fast-sweep ''%s'' from %g to %g in %d steps\n%s', ...
                obj.chan.name, obj.from, obj.to, obj.points, ...
                qd.util.indent(obj.job.pprint()));
        end

        function trace = readTrace(obj)
            % Check for instrument type
            switch lower(obj.instrument)
                case 'alazar'
                    trace = 1:10;
                otherwise
                    warning('fast-sweep cannot recognize input')
            end
            
        end
        
    end
end