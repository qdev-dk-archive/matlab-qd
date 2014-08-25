classdef repeat < qd.q.Recipe
    properties
        repeats
    end
    methods
        function obj = repeat(n)
            obj.repeats = n;
        end

        function job = apply(obj, ctx, sub_job)
            job = qd.q.impl.Repeats();
            job.repeats = obj.repeats;
            job.job = sub_job;
        end
    end
end