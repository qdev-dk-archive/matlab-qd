classdef GetFuture < handle
    properties(Access=protected)
        func
    end
    methods
        function obj = GetFuture(func)
            obj.func = func;
        end

        function val = exec(obj)
            if isempty(obj.func)
                error('exec already called once.');
            end
            val = obj.func();
            obj.func = [];
        end

        function delete(obj)
            if ~isempty(obj.func)
                warning('A qd.classes.GetFuture was thrown away without first calling exec().');
            end
        end
    end
end