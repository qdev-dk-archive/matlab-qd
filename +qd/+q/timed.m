classdef timed < qd.q.Recipe
    properties
        running_time
    end
    methods
        function obj = timed(running_time)
        % r = timed(t)
        %
        % A recipe which keeps repeating the subordinate job for t seconds.
            obj.running_time = running_time;
        end

        function job = apply(obj, ctx, sub_job)
            job = qd.q.impl.Timed();
            job.running_time = obj.running_time;
            job.job = sub_job;
        end
    end
end
