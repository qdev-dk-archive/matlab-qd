classdef TableView < handle
    properties
        tables
        fig
        columns = [1 2 0]
    end
    methods

        function obj = TableView(tables, varargin)
            switch length(varargin)
            case 0
                obj.fig = figure();
            case 1
                obj.fig = varargin{1};
            end
            obj.tables = tables;
            obj.update();
        end

        function update(obj)
            figure(obj.fig);
            clf();
            hold('all');
            lists = [];
            for i = 1:3
                names = {};
                for column = obj.tables{1}
                    names{end + 1} = column{1}.name;
                end
                if i < 3
                    selection = max(1, min(obj.columns(i), length(names)));
                else
                    selection = max(0, min(obj.columns(i), length(names)));
                    names{end + 1} = '---';
                    if selection == 0
                        selection = length(names);
                    end
                end
                lists(end + 1) = uicontrol( ...
                    'Style', 'popupmenu', ...
                    'String', names, ...
                    'Value', selection, ...
                    'Callback', @(h, varargin) obj.select(i, get(h, 'Value')));
            end
            if obj.columns(3) == 0
                for table = obj.tables
                    plot(table{1}{obj.columns(1)}.data, ...
                        table{1}{obj.columns(2)}.data);
                end
            end
            align(lists, 'Fixed', 0, 'Bottom');
        end

        function select(obj, dim, column)
            if column ~= length(obj.tables{1}) + 1
                obj.columns(dim) = column;
            else
                obj.columns(dim) = 0;
            end
            obj.update();
        end

    end
end