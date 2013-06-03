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
        pseudo_columns = {}
        cache
        editor
    end
    properties
        tbl
        loc
        meta
        % This is a containers.Map mapping strings to strings.
        % The key is the name of a column, the value is the desired label
        % on the axis of that column.
        column_label_override
        % Set this to false if you do not want headers on plots.
        show_headers = true
    end
    methods
        function obj = FolderBrowser(loc)
            obj.column_label_override = containers.Map();
            obj.clear_cache();
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

        function set_editor(obj, editor)
        % See qd.gui.TableView.set_editor.
            obj.editor = editor;
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
            for d = transpose(listing(end:-1:1))
                if obj.cache.isKey(d.name)
                    c = obj.cache(d.name);
                else
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
                    obj.cache(d.name) = c;
                end
                obj.content{end + 1} = c;
                names{end + 1} = c.name;
            end
            if get(obj.listbox, 'Value') > length(names)
                set(obj.listbox, 'Value', 1)
            end
            set(obj.listbox, 'String', names);
        end

        function clear_cache(obj)
            obj.cache = containers.Map();
        end

        function select(obj, val)
            loc = obj.content{val}.loc;
            meta = json.read(fullfile(loc, 'meta.json'));
            tables = containers.Map;
            for table_name = obj.list_table_names(loc)
                tbl = qd.data.load_table(loc, table_name{1});
                for pseudo_column = obj.pseudo_columns
                    try
                        func = pseudo_column{1};
                        new_columns = func(qd.data.view_table(tbl), meta);
                        for column = new_columns
                            assert(isfield(column{1}, 'data'));
                            assert(isfield(column{1}, 'name'));
                            tbl{end + 1} = column{1};
                        end
                    catch err
                        warning('Error while computing column pseudo columns. Error was:\n%s', ...
                            getReport(err));
                    end
                end
                for i = 1:length(tbl)
                    if obj.column_label_override.isKey(tbl{i}.name)
                        tbl{i}.label = obj.column_label_override(tbl{i}.name);
                    end
                end
                tables(table_name{1}) = tbl;
            end
            obj.plot_loc(tables, loc, meta);
            obj.view_loc(loc, meta, tables);
        end

        function add_pseudo_column(obj, func, name)
            function r = pseudo(tbls, meta)
                c = struct();
                c.name = name;
                c.data = func(tbls, meta);
                r = {c};
            end
            obj.pseudo_columns{end + 1} = @pseudo;
        end

        function add_pseudo_columns(obj, func)
            obj.pseudo_columns{end + 1} = func;
        end

        function plot_loc(obj, tables, loc, meta)
            if isempty(obj.fig)
                obj.fig = figure();
                set(obj.fig, 'Color', 'white');
            end
            old_view = obj.table_view;
            obj.table_view = qd.gui.TableView(tables.values(), obj.fig);
            try
                obj.table_view.sweeps = meta.sweeps;
            end
            if obj.show_headers && isfield(meta, 'name')
                obj.table_view.header = meta.name;
            end
            if ~isempty(old_view)
                obj.table_view.mirror_settings(old_view);
            end
            obj.table_view.loc = loc;
            obj.table_view.set_editor(obj.editor)
            obj.table_view.update();
        end

        function view_loc(obj, loc, meta, tables)
            obj.loc = loc;
            obj.meta = meta;
            if length(tables) == 1
                tbl = tables.values();
                obj.tbl = qd.data.view_table(tbl{1});
            else
                obj.tbl = struct();
                for key = tables.keys()
                    if ~isvarname(key{1})
                        continue
                    end
                    obj.tbl.(key{1}) = qd.data.view_table(tables(key{1}));
                end
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