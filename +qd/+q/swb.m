classdef swb < qd.q.Recipe
    properties
        chan
        from
        to
        points
    end
    methods
        function obj = swb(chan, from, to, points, varargin)
        % recipe = sw(chan, from, to, points)
        %
        % Constructs a recipe that sweeps an output channel. chan can be a
        % channel object or the name of a channel. If chan is a name, it will
        % be looked up at the time the recipe is applied.
        %
        % Note: you often need to add one to the number of points to get nice
        %   values, e.g. sw(chan, 0, 10, 10) would set chan to the values [0,
        %   1.11, 2.22, ..., 10] for a total of 10 linearly spaced points.
        %   sw(chan, 0, 10, 11) would set chan to [0, 1, 2, ..., 10].
            obj.chan = chan;
            obj.from = from;
            obj.to = to;
            obj.points = points;
            if ~isempty(varargin)
                error(['qd.q.sw called with one argument too much. The '...
                    'fith argument used to be the settling time, but '...
                    'you can no longer specify a settling time for a '...
                    'sweep. Use the qd.q.settle recipe, the input_settle '...
                    'function on the Plan class, or set default_settle '...
                    'on the Q object.']);
            end
        end

        function job = apply(obj, ctx, sub_job)
            job = qd.q.impl.SweepBoomerang();
            job.chan = ctx.resolve_channel(obj.chan);
            job.from = obj.from;
            job.to = obj.to;
            job.points = obj.points;
            job.job = sub_job;
        end
    end
end
