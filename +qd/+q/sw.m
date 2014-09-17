classdef sw < qd.q.Recipe
    properties
        chan
        from
        to
        points
    end
    methods
        function obj = sw(chan, from, to, points, varargin)
            obj.chan = chan;
            obj.from = from;
            obj.to = to;
            obj.points = points;
            if length(varargin) ~= 0
                error(['qd.q.sw called with one argument too much. The '...
                    'fith argument used to be the settling time, but '...
                    'you can no longer specify a settling time for a '...
                    'sweep. Use the qd.q.settle recipe, the settle '...
                    'function on the Plan class, or set default_settle '...
                    'on the Q object.']);
            end
        end

        function job = apply(obj, ctx, sub_job)
            job = qd.q.impl.Sweep();
            job.chan = ctx.resolve_channel(obj.chan);
            job.from = obj.from;
            job.to = obj.to;
            job.points = obj.points;
            job.job = sub_job;
        end
    end
end