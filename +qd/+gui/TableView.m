classdef TableView < handle
    properties
        tables
        fig
        meta
        columns = [1 2 0]
        resolution = 3
        aspect = 'x:y'
        zoom = 4
        limits
    end
    properties(Constant)
        resolution_settings = [32 64 128 256 512 1024]
        zoom_settings = [-15 -10 -5 0 5 10 15]
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
            obj.limits = struct();
            obj.limits.x = '*:*';
            obj.limits.y = '*:*';
            obj.limits.z = '*:*';
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
            for axis = 'xyz'
                lists(end + 1) = uicontrol( ...
                    'Style', 'edit', ...
                    'String', obj.limits.(axis), ...
                    'TooltipString', sprintf('Limits for %s-axis', axis), ...
                    'Callback', @(h, varargin) obj.set_limits(axis, get(h, 'String')));
            end
            lists(end + 1) = uicontrol( ...
                'Style', 'edit', ...
                'String', obj.aspect, ...
                'TooltipString', 'Aspect ratio', ...
                'Callback', @(h, varargin) obj.set_aspect_ratio(get(h, 'String')));
            resolutions = qd.util.map(@(n)[num2str(n) 'x' num2str(n)], obj.resolution_settings);
            lists(end + 1) = uicontrol( ...
                'Style', 'popupmenu', ...
                'String', resolutions, ...
                'Value', obj.resolution, ...
                'TooltipString', 'Resampling resolution', ...
                'Callback', @(h, varargin) obj.set_resolution(get(h, 'Value')));
            zoom = qd.util.map(@(n)['Enlarge ' num2str(n) '%'], obj.zoom_settings);
            lists(end + 1) = uicontrol( ...
                'Style', 'popupmenu', ...
                'String', zoom, ...
                'Value', obj.zoom, ...
                'Callback', @(h, varargin) obj.set_zoom(get(h, 'Value')));
            lists(end + 1) = uicontrol( ...
                'Style', 'pushbutton', ...
                'String', 'Copy figure', ...
                'Callback', @(h, varargin) obj.copy_to_clipboard());
            obj.do_plot();
            align(lists, 'Fixed', 0, 'Bottom');
        end

        function mirror_settings(obj, other)
            % Select the same columns as before (by name)
            for i = 1:3
                try
                    name = other.tables{1}{other.columns(i)}.name;
                catch
                    continue
                end
                for j = 1:length(obj.tables{1})
                    if strcmp(obj.tables{1}{j}.name, name)
                        obj.columns(i) = j;
                    end
                end
            end
            obj.resolution = other.resolution;
            obj.aspect = other.aspect;
            obj.zoom = other.zoom;
            obj.limits = other.limits;
        end

        function set_resolution(obj, res)
            obj.resolution = res;
            obj.update();
        end


        function copy_to_clipboard(obj)
            % unfortunately the copy includes a large white background
            print -dmeta -noui
        end

        function set_aspect_ratio(obj, asp)
            obj.aspect = asp;
            obj.update();
        end

        function set_limits(obj, axis, limits)
            obj.limits.(axis) = limits;
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

        function limits = get_limits(obj, axis, min_data, max_data)
            limits = [min_data, max_data];
            parts = qd.util.strsplit(obj.limits.(axis), ':');
            if length(parts) == 2
                for i = 1:2
                    l = str2double(parts{i});
                    if isnan(l)
                        continue
                    end
                    limits(i) = l;
                end
            end
            if limits(1) > limits(2)
                x = limits(2);
                limits(2) = limits(1);
                limits(1) = x;
            elseif limits(1) == limits(2)
                limits(1) = limits(1) * 0.999 - 1e-12;
                limits(2) = limits(2) * 1.001 + 1e-12;
            end
        end

        function do_plot(obj)
            if obj.columns(3) == 0
                for table = obj.tables
                    xdata = table{1}{obj.columns(1)}.data;
                    ydata = table{1}{obj.columns(2)}.data;
                    plot(xdata, ydata);
                    ax = gca();
                    set(ax, 'XLim', obj.get_limits('x', min(xdata), max(xdata)));
                    set(ax, 'YLim', obj.get_limits('y', min(ydata), max(ydata)));
                    xlabel(table{1}{obj.columns(1)}.name)
                    ylabel(table{1}{obj.columns(2)}.name)
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
                cb = colorbar();
                try
                    plt = imagesc([mia maa], [mib mab], Z);
                catch err
                    warning(err.message)
                end
                axis('tight');
                daspect(obj.get_aspect_ratio());
                ax = gca();
                set(ax, 'XLim', obj.get_limits('x', mia, maa));
                set(ax, 'YLim', obj.get_limits('y', mib, mab));
                set(ax, 'CLim', obj.get_limits('z', min(c), max(c)));
                xlabel(table{obj.columns(1)}.name)
                ylabel(table{obj.columns(2)}.name)
                ylabel(cb, table{obj.columns(3)}.name)
%                 title(obj.meta.name)
%                 I would like to get the meta data from FolderBrowser, but
%                 I cannot pass it via the TableView function.
            end
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