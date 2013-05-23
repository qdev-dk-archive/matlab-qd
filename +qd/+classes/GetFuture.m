classdef GetFuture < handle
    properties(Access=protected)
        func
        value
    end
    methods
        function obj = GetFuture(func)
            obj.func = func;
        end

        function force(obj)
            if isempty(obj.func)
                return;
            end
            obj.value = obj.func();
            obj.func = [];
        end

        function val = exec(obj)
            obj.force();
            val = obj.value;
        end

        function delete(obj)
            if ~isempty(obj.func)
                warning(['A qd.classes.GetFuture was thrown away ' ...
                    'without first calling force() or exec().']);
            end
        end
    end
end