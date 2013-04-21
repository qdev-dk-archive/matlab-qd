classdef Nameable < handle
    properties(Dependent)
        name
    end
    
    properties(Access=private)
        defined_name
    end

    methods
        function r = default_name(obj)
            error('No default name exists for this object (override this function in subclasses).');
        end

        function r = get.name(obj)
            if isempty(obj.defined_name)
                r = obj.default_name();
            else
                r = obj.defined_name;
            end
        end

        function set.name(obj, name)
            obj.defined_name = name;
        end
    end
end