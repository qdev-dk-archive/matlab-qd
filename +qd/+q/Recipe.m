classdef Recipe
    methods
        function job = apply(obj, ctx, sub_job)
            error('Method not implemented.');
        end

        function r = or(obj, other)
            r = qd.q.chain(obj, other);
        end
    end
end