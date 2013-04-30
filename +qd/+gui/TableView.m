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
        end

        function update(obj)
            figure(obj.fig);
            clf();
            hold('all');
            lists = [];
            if isempty(obj.tables)
                return
            end
            num_columns = length(obj.tables{1});
            for i = 1:3
                if i < 3
                    obj.columns(i) = max(1, min(obj.columns(i), num_columns));
                else
                    obj.columns(i) = max(0, min(obj.columns(i), num_columns));
                end
            end
            for i = 1:3
                names = {};
                for column = obj.tables{1}
                    names{end + 1} = column{1}.name;
                end
                if i < 3
                    selection = obj.columns(i);
                else
                    names{end + 1} = '---';
                    selection = obj.columns(i);
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
            obj.do_plot();
            align(lists, 'Fixed', 0, 'Bottom');
        end

        function do_plot(obj)
            if obj.columns(3) == 0
                for table = obj.tables
                    plot(table{1}{obj.columns(1)}.data, ...
                        table{1}{obj.columns(2)}.data);
                end
            else
                table = obj.tables{1};
                a = table{obj.columns(1)}.data;
                b = table{obj.columns(2)}.data;
                c = table{obj.columns(3)}.data;
                xp = linspace(min(a), max(a), 500);
                yp = linspace(min(b), max(b), 500);
                [X, Y] = meshgrid(xp, yp);
                Z = griddata(a, b, c, X, Y, 'nearest');
                colormap(hot);
                colorbar();
                try
                    plt = pcolor(X, Y, Z);
                    set(plt, 'EdgeColor', 'none');
                catch err
                    warning(err.message)
                end
            end
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