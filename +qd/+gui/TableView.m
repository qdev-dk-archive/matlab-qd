classdef TableView < handle
    properties
        tables
        fig
        columns = [1 2 0]
        resolution = 3
        aspect = 'x:y'
        zoom = 1
        limits = '*:*'
    end
    properties(Constant)
        resolution_settings = [32 64 128 256 512 1024]
        zoom_settings = [0 5 10 15]
    end
    methods

        function obj = TableView(tables, varargin)
            p = inputParser();
            p.addOptional('fig', []);
            p.parse(varargin{:});
            obj.fig = p.Results.fig;
            if isempty(obj.fig)
                obj.fig = figure();
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
            lists(end + 1) = uicontrol( ...
                'Style', 'edit', ...
                'String', obj.limits, ...
                'Callback', @(h, varargin) obj.set_limits(get(h, 'String')));
            lists(end + 1) = uicontrol( ...
                'Style', 'edit', ...
                'String', obj.aspect, ...
                'Callback', @(h, varargin) obj.set_aspect_ratio(get(h, 'String')));
            resolutions = qd.util.map(@(n)[num2str(n) 'x' num2str(n)], obj.resolution_settings);
            lists(end + 1) = uicontrol( ...
                'Style', 'popupmenu', ...
                'String', resolutions, ...
                'Value', obj.resolution, ...
                'Callback', @(h, varargin) obj.set_resolution(get(h, 'Value')));
            zoom = qd.util.map(@(n)['Enlarge ' num2str(n) '%'], obj.zoom_settings);
            lists(end + 1) = uicontrol( ...
                'Style', 'popupmenu', ...
                'String', zoom, ...
                'Value', obj.zoom, ...
                'Callback', @(h, varargin) obj.set_zoom(get(h, 'Value')));
            obj.do_plot();
            align(lists, 'Fixed', 0, 'Bottom');
        end

        function set_resolution(obj, res)
            obj.resolution = res;
            obj.update();
        end

        function set_aspect_ratio(obj, asp)
            obj.aspect = asp;
            obj.update();
        end

        function set_limits(obj, limits)
            obj.limits = limits;
            obj.update();
        end

        function set_zoom(obj, zoom)
            obj.zoom = zoom;
            obj.update();
        end

        function aspect = get_aspect_ratio(obj)
            parts = qd.util.strsplit(obj.aspect, ':');
            if length(parts) ~= 2
                aspect = 'auto';
                return
            end
            aspect = [1 1 1];
            for i = 1:2
                n = str2double(parts{i});
                if isnan(n)
                    aspect = 'auto';
                    return
                end
                aspect(i) = n;
            end
        end

        function limits = get_limits(obj, data)
            limits = [min(data), max(data)];
            parts = qd.util.strsplit(obj.limits, ':');
            if length(parts) ~= 2
                return
            end
            for i = 1:2
                l = str2double(parts{i});
                if isnan(l)
                    continue
                end
                limits(i) = l;
            end
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
                res = obj.resolution_settings(obj.resolution);
                mia = min(a);
                maa = max(a);
                mib = min(b);
                mab = max(b);
                xp = linspace(mia, maa, res);
                yp = linspace(mib, mab, res);
                [X, Y] = meshgrid(xp, yp);
                Z = griddata(a, b, c, X, Y, 'nearest');
                colormap(hot);
                colorbar();
                try
                    plt = imagesc([mia maa], [mib mab], Z);
                catch err
                    warning(err.message)
                end
                axis('tight');
                daspect(obj.get_aspect_ratio());
                ax = gca();
                set(ax, 'CLim', obj.get_limits(c));
            end
            ax = gca();
            zoom = obj.zoom_settings(obj.zoom)/100.0;
            pos = [0-zoom, 0-zoom, 1+2*zoom, 1+2*zoom];
            set(ax, 'OuterPosition', pos);
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