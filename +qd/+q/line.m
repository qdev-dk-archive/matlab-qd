classdef line < qd.q.Recipe
    properties
        chans
        from
        to
        points
    end
    methods
        function obj = line(chans, from, to, points)
        % recipe = line(chan, from, to, points)
        %
        % Constructs a recipe that sweeps several channels along a line. chans
        % can be a cell array of channel objects or names of channels. If an
        % entry is a name, it will be looked up at the time the recipe is
        % applied.
        %
        % from and to are row vectors.
            qd.util.assert(length(from) == length(to));
            qd.util.assert(length(from) == length(chans));
            obj.chans = chans;
            obj.from = from;
            obj.to = to;
            obj.points = points;
        end

        function job = apply(obj, ctx, sub_job)
            job = qd.q.impl.Line();
            job.chans = qd.util.map(@(c) ctx.resolve_channel(c), obj.chans);
            job.from = obj.from;
            job.to = obj.to;
            job.points = obj.points;
            job.job = sub_job;
        end
    end
end
