classdef settle < qd.q.Recipe
    properties
        settling_time
    end
    methods
        function obj = settle(settle)
            obj.settling_time = settle;
        end

        function job = apply(obj, ctx, sub_job)
            job = qd.q.impl.Settle();
            job.settle = obj.settling_time;
            job.job = sub_job;
        end
    end
end