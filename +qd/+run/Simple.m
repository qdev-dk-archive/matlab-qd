classdef Simple < handle
    properties(Access=private)
        name
        setup
        sweeps
        inputs
        meta
        comment
    end
    methods
        function obj = name(obj, name)
            obj.name = name;
        end

        function obj = setup(obj, setup)
            obj.setup = setup;
        end

        function obj = meta(obj, meta)
            obj.meta = meta;
        end

        function obj = comment(obj, comment)
            obj.comment = comment;
        end

        function obj = sweep(obj, name_or_channel, from, to, points)
        end
    end
end