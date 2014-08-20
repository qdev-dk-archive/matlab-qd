classdef Recipe
    methods
        function job = apply(obj, ctx, sub_job)
            error('Method not implemented.');
        end

        function r = or(obj, other)
            if isempty(other)
                r = obj;
            else
                r = qd.q.chain(obj, other);
            end
        end
    end
end