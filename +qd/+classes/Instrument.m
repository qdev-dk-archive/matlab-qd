classdef Instrument < handle
    properties(Access=private)
        defined_name
    end
    methods

        function r = model_name(obj)
            error(['This function should be overwritten in instruments to '...
                'return the name of the instrument type.']);
        end

        function r = name(obj)
            if isempty(obj.defined_name)
                r = obj.model_name;
            else
                r = obj.defined_name;
            end
        end

        function set_name(obj, name)
            obj.defined_name = name;
        end

    end
end