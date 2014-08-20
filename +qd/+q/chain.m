classdef chain < qd.q.Recipe
    properties
        a
        b
    end
    methods
        function obj = chain(a, b)
            obj.a = a;
            obj.b = b;
        end

        function job = apply(obj, ctx, sub_job)
            if isempty(obj.b)
                job = obj.a.apply(ctx, sub_job);
            else
                job = obj.a.apply(ctx, obj.b.apply(ctx, sub_job));
            end
        end
    end
end