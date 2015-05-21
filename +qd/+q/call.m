classdef call < qd.q.Recipe
    properties
        func
    end
    methods
        function obj = call(func)
        % recipe = call(func)
        %
        % Calls the supplied function handle after each execution of the
        % sub-job. func receives as an argument a matrix with one row for each
        % point added by the sub-job.
            obj.func = func;
        end

        function job = apply(obj, ctx, sub_job)
            job = qd.q.impl.Call();
            job.func = obj.func;
            job.job = sub_job;
        end
    end
end
