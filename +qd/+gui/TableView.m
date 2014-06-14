classdef TableView < handle
    properties
        tables
        sweeps
        fig
        meta
        columns = [1 2 0]
        resolution = 1
        aspect = 'x:y'
        zoom = 4
        limits
        header = ''
        loc
        editor
    end
    properties(Constant)
        resolution_settings = [NaN 32 64 128 256 512 1024]
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

        function set_editor(obj, editor)
        % Set this to the complete path to an executable. When the "edit meta"
        % button is clicked, the executable will be called with the path to
        % the meta-file as its only argument.
            obj.editor = editor;
        end
        
        function update(obj)
            figure(obj.fig);
            clf();
            
            set(obj.fig,'Units','characters',...
                'ResizeFcn',@figResize);
                
            botPanel = uipanel('BorderType','etchedin',...
                'Units','characters',...
                'Position',[0 0 1 1],...
                'Parent',obj.fig, ...
                'ResizeFcn',@botPanelResize);

            centerPanel = uipanel('bordertype','etchedin',...
                'Units','characters',...
                'Position', [0 0 1 1],...
                'Parent',obj.fig,...
                'ResizeFcn',@centerPanelResize);
                 
            function botPanelResize(src,evt)
                bpos = get(botPanel,'Position');
            end
            
            function centerPanelResize(src,evt)
                cpos = get(centerPanel,'Position');
            end
            
            function figResize(src,evt)
                fpos = get(obj.fig,'Position');
                botHeight = 4;
                set(botPanel,'Position',...
                    [0 0 fpos(3) botHeight])
                set(centerPanel,'Position',...
                    [0 botHeight fpos(3) fpos(4)-botHeight]);
            end
                    
            axes('parent',centerPanel,'box','on');
            
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
            resolutions{1} = 'Native';
            lists(end + 1) = uicontrol( ...
                'Style', 'popupmenu', ...
                'String', resolutions, ...
                'Value', obj.resolution, ...
                'TooltipString', 'Resampling resolution', ...
                'Callback', @(h, varargin) obj.set_resolution(get(h, 'Value')));
            zoom = qd.util.map(@(n)['Enlarge ' num2str(n) '%'], obj.zoom_settings);
            zoom{end+1} = 'Tight inset';
            lists(end + 1) = uicontrol( ...
                'Style', 'popupmenu', ...
                'String', zoom, ...
                'Value', obj.zoom, ...
                'Callback', @(h, varargin) obj.set_zoom(get(h, 'Value')));
            lists(end + 1) = uicontrol( ...
                'Style', 'pushbutton', ...
                'String', 'Copy figure', ...
                'Callback', @(h, varargin) obj.copy_to_clipboard());
            if ~isempty(obj.editor)
                lists(end + 1) = uicontrol( ...
                    'Style', 'pushbutton', ...
                    'String', 'Edit meta', ...
                    'Callback', @(h, varargin) obj.edit_metafile());
            end
            try
                obj.do_plot();
            catch err
                obj.show_message_instead_of_plot( ...
                    getReport(err, 'extended', 'hyperlinks', 'off'));
                disp(getReport(err));
            end
            align(lists, 'Fixed', 0, 'Bottom');
            
            figResize();
            botPanelResize();
            centerPanelResize();
        end

        function show_message_instead_of_plot(obj, msg)
            uistack(uicontrol('Style', 'text', 'String', msg, ...
                'Units', 'normalized', 'Position', [0,0,1,1], ...
                'HorizontalAlignment', 'left'), 'bottom');
        end

        function edit_metafile(obj)
            assert(~isempty(obj.editor));
            runtime = java.lang.Runtime.getRuntime();
            fullfile(obj.loc, 'meta.json')
            runtime.exec({obj.editor, fullfile(obj.loc, 'meta.json')});
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
            % Make sure limits are not decreasing
            if limits(1) > limits(2)
                x = limits(2);
                limits(2) = limits(1);
                limits(1) = x;
            end
            if abs(limits(1) - limits(2)) < eps(limits(1)) * 100;
                limits(1) = limits(1) - eps(limits(1)) * 50;
                limits(2) = limits(2) + eps(limits(1)) * 50;
            end
        end

        function label = get_label(obj, axis)
        % Get the desired label for axis where axis is 1, 2, or 3 specifying
        % the x-axis, y-axis or z-axis respectively.
            table = obj.tables{1};
            if isfield(table{obj.columns(axis)}, 'label')
                label = table{obj.columns(axis)}.label;
            else
                label = table{obj.columns(axis)}.name;
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
                    xlabel(obj.get_label(1));
                    ylabel(obj.get_label(2));
                end
            else
                if (obj.resolution == 1)
                    if ~(obj.columns(1) == 1 && obj.columns(2) == 2 ...
                        || obj.columns(1) == 2 && obj.columns(2) == 1)
                        obj.show_message_instead_of_plot( ...
                            ['Plotting in native resolution is not supported for ' ...
                             'your choice of axes. The x-axis must be column ' ...
                             'one and the y-axis must be column two, or vice-versa. ' ...
                             'If you want to plot these axes, set a resampling resolution.']);
                        return;
                    end
                    [data, extents] = obj.get_data_in_native_resolution();
                else
                    [data, extents] = obj.resample_data();
                end
                colormap(hot);
                cb = colorbar();
                plt = imagesc(extents(1,:), extents(2,:), data);
                axis('tight');
                daspect(obj.get_aspect_ratio());
                ax = gca();
                set(ax, 'XLim', obj.get_limits('x', extents(1,1), extents(1,2)));
                set(ax, 'YLim', obj.get_limits('y', extents(2,1), extents(2,2)));
                set(ax, 'CLim', obj.get_limits('z', min(min(data)), max(max(data))));
                
                xstr = obj.get_label(1);
                ystr = obj.get_label(2);
                zstr = obj.get_label(3);
                
                xl = xlabel(xstr);
                yl = ylabel(ystr);
                zl = ylabel(cb, zstr);
                
                if xstr(1)=='$' && xstr(end)=='$'
                    set(xl,'Interpreter','Latex');
                end
                if ystr(1)=='$' && ystr(end)=='$'
                    set(yl,'Interpreter','Latex');
                end
                if zstr(1)=='$' && zstr(end)=='$'
                    set(zl,'Interpreter','Latex');
                end
            end
            if ~isempty(obj.header)
                t = title(obj.header);
                
                if obj.header(1)=='$' && obj.header(end)=='$'
                    set(t,'Interpreter','Latex');
                end
            end
            if obj.zoom > length(obj.zoom_settings)
                set(ax, 'OuterPosition', [0 0 1 1]);
                set(ax, 'LooseInset', [0,0,0,0]);
            else
                zoom = obj.zoom_settings(obj.zoom)/100.0;
                pos = [0-zoom, 0-zoom, 1+2*zoom, 1+2*zoom];
                set(ax, 'OuterPosition', pos);
            end
        end

        function [data, extents] = get_data_in_native_resolution(obj)
            assert(~isempty(obj.sweeps));
            table = obj.tables{1};
            [data, extents] = qd.data.reshape_data( ...
                table{obj.columns(3)}.data, obj.sweeps);
            if obj.columns(1) == 2 && obj.columns(2) == 1
                data = transpose(data);
                extents = extents(end:-1:1,:);
            else
                assert(obj.columns(1) == 1 && obj.columns(2) == 2);
            end
        end

        function [data, extents] = resample_data(obj)
            table = obj.tables{1};
            a = table{obj.columns(1)}.data;
            b = table{obj.columns(2)}.data;
            c = table{obj.columns(3)}.data;
            res = obj.resolution_settings(obj.resolution);
            extents = [];
            extents(1,:) = obj.get_limits('x', min(a), max(a));
            extents(2,:) = obj.get_limits('y', min(b), max(b));
            xp = linspace(0, 1, res);
            yp = linspace(0, 1, res);
            [X, Y] = meshgrid(xp, yp);
            data = griddata(...
                (a - extents(1,1))./(extents(1,2) - extents(1,1)), ...
                (b - extents(2,1))./(extents(2,2) - extents(2,1)), ...
                c, X, Y, 'nearest');
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