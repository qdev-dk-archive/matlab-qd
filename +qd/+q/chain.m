classdef chain
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
            obj.a.apply(ctx, obj.b.apply(sub_job));
        end
    end
end