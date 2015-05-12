classdef forever < qd.q.Recipe
    methods
        function job = apply(obj, ctx, sub_job)
            job = qd.q.impl.Forever();
            job.job = sub_job;
        end
    end
end
