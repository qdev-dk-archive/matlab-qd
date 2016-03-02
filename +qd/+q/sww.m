classdef sww < qd.q.Recipe
    properties
        chan
        from
        to
        points
        wait_before_start
    end
    methods
        function obj = sww(chan, from, to, points, wait_before_start)
        % recipe = sww(chan, from, to, points, wait_before_start)
        %
        % This recipe does the same as sw except it inserts a waiting time
        % between ramping the channel to its initial value and starting the
        % sweep.
        % See sw.m for more information.
        %
            obj.chan = chan;
            obj.from = from;
            obj.to = to;
            obj.points = points;
            obj.wait_before_start = wait_before_start;
        end

        function job = apply(obj, ctx, sub_job)
            job = qd.q.impl.SweepWait();
            job.chan = ctx.resolve_channel(obj.chan);
            job.from = obj.from;
            job.to = obj.to;
            job.points = obj.points;
            job.job = sub_job;
            job.wait_before_start = obj.wait_before_start;
        end
    end
end
