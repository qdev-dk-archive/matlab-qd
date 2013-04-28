classdef TableView < handle
    properties(Access=private)
        loc
    end
    methods

        function obj = TableView(loc, table_names, varargin)
            switch length(varargin)
            case 0
                fig = figure();
            case 1
                fig = varargin{1};
            end
            obj.loc = loc;
        end

    end
end