classdef SetFuture < handle
    properties(Access=protected)
        func
    end
    methods
        function obj = SetFuture(func)
            obj.func = func;
        end

        function exec(obj)
            if isempty(obj.func)
                error('exec already called once.');
            end
            obj.func();
            obj.func = [];
        end

        function delete(obj)
            if ~isempty(obj.func)
                warning('A qd.classes.SetFuture was thrown away without first calling exec().');
            end
        end
    end
end