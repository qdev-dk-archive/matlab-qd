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

        % Calls force. (mirrors SetFuture.resolve)
        function resolve(obj)
            obj.force();
        end

        function delete(obj)
            if ~isempty(obj.func)
                warning(['A qd.classes.GetFuture was thrown away ' ...
                    'without first calling force() or exec().']);
            end
        end

        % This implement the operator & so that futures can be combined.
        %
        % If a and b are SetFuture objects, then
        % (a & b).exec() is the same as: [a.exec(), b.exec()]
        %
        % Empty is handled specially, such that
        % (a & []).exec() is the same as: a.exec()
        % ([] & a).exec() is the same as: a.exec()
        function f = and(obj, other)
            function val = func()
                if isempty(obj)
                    val = other.exec();
                elseif isempty(other)
                    val = obj.exec();
                else
                    val = [obj.exec(), other.exec()];
                end
            end
            f = qd.classes.SetFuture(@func);
        end
    end
end