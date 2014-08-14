classdef sw
    properties
        chan
        from
        to
        points
        settle = 0
    end
    methods
        function obj = sw(chan, from, to, points, varargin)
            obj.chan = chan;
            obj.from = from;
            obj.to = to;
            obj.points = points;
            if length(varargin) == 1
                obj.settle = varargin(1);
            end
            qd.util.assert(length(varargin) < 2);
        end

        function job = apply(obj, ctx, sub_job)
            job = qd.q.Sweep();
            job.chan = ctx.resolve_channel(obj.chan);
            job.from = obj.from;
            job.to = obj.to;
            job.points = obj.points;
            job.settle = obj.settle;
            job.job = sub_job;
        end
    end
end