classdef settle < qd.q.Recipe
    properties
        settle
    end
    methods
        function obj = settle(settle)
            obj.settle = settle;
        end

        function job = apply(obj, ctx, sub_job)
            job = qd.q.impl.Settle();
            job.settle = obj.settle;
            job.job = sub_job;
        end
    end
end