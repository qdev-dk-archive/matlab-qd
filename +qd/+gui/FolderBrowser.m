classdef FolderBrowser < handle
    properties(Access=private)
        location
        content
        listbox
        listbox_fig
        fig
        update_timer
        table_view
        has_been_closed = false
    end
    properties
        tbl
        loc
        meta
    end
    methods
        function obj = FolderBrowser(loc)
            obj.location = loc;
            obj.listbox_fig = figure( ...
                'MenuBar', 'none', ...
                'Name', loc, ...
                'NumberTitle', 'off', ...
                'WindowStyle', 'docked');
            w = warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            set(get(obj.listbox_fig,'javaframe'), 'GroupName','FolderBrowser');
            warning(w);
            obj.listbox = uicontrol( ...
                'Style', 'listbox', ...
                'Parent', obj.listbox_fig, ...
                'Units', 'normalized', ...
                'Position', [0,0,1,1], ...
                'Callback', @(h, varargin)obj.select(get(h, 'Value')));
            obj.update();
            obj.update_timer = timer();
            obj.update_timer.Period = 3;
            obj.update_timer.ExecutionMode = 'fixedSpacing';
            obj.update_timer.TimerFcn = @(varargin)obj.update();
            start(obj.update_timer);
            function on_close(varargin)
                stop(obj.update_timer);
                delete(obj.update_timer);
                obj.has_been_closed = true;
            end
            set(obj.listbox_fig, 'DeleteFcn', @on_close);
        end

        function close(obj)
            close(obj.listbox_fig);
        end

        function update(obj)
            if obj.has_been_closed
                return
            end
            listing = dir(obj.location);
            obj.content = {};
            names = {};
            for d = transpose(listing)
                c = struct();
                c.loc = fullfile(obj.location, d.name);
                meta_path = fullfile(c.loc, 'meta.json');
                if ~exist(meta_path, 'file')
                    continue;
                end
                try
                    meta = json.read(meta_path);
                catch
                    continue;
                end
                c.name = meta.name;
                obj.content{end + 1} = c;
                names{end + 1} = c.name;
            end
            if get(obj.listbox, 'Value') > length(names)
                set(obj.listbox, 'Value', 1)
            end
            set(obj.listbox, 'String', names);
        end

        function select(obj, val)
            loc = obj.content{val}.loc;
            obj.plot_loc(loc, obj.content{val}.name);
            obj.view_loc(loc);
        end

        function plot_loc(obj, loc, name)
            if isempty(obj.fig)
                obj.fig = figure();
            end
            tables = {};
            for table_name = obj.list_table_names(loc)
                tables{end + 1} = qd.data.load_table(loc, table_name{1});
            end
            old_view = obj.table_view;
            obj.table_view = qd.gui.TableView(tables, obj.fig);
            if ~isempty(old_view)
                obj.table_view.columns = old_view.columns;
            end
            obj.table_view.update();
        end

        function view_loc(obj, loc)
            names = obj.list_table_names(loc);
            obj.loc = loc;
            obj.meta = json.read(fullfile(loc, 'meta.json'));
            if length(names) == 1
                obj.tbl = qd.data.view_table(loc, names{1});
            else
                obj.tbl = qd.data.view_tables(loc);
            end
        end
    end
    methods(Access=private)

        function names = list_table_names(obj, loc)
            names = {};
            for d = transpose(dir(fullfile(loc, '*.dat')))
                [~, table_name, ~] = fileparts(fullfile(loc, d.name));
                names{end + 1} = table_name;
            end
        end

    end
end