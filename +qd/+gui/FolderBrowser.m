classdef FolderBrowser < handle
    properties(Access=private)
        location
        content
        listbox
        listbox_fig
        fig
        update_timer
        track_timer
        has_been_closed = false
        cache
        editor
    end
    properties
        tbl
        loc
        meta
        tables
        table_view
        pseudo_columns = {}
        % This is a containers.Map mapping strings to strings.
        % The key is the name of a column, the value is the desired label
        % on the axis of that column.
        column_label_override
        % Set this to false if you do not want headers on plots.
        show_headers = true
        show_folder_names = true
        size_of_data = 0
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
            obj.track_timer = timer();
            obj.track_timer.Period = 0.5;
            obj.track_timer.ExecutionMode = 'fixedSpacing';
            obj.track_timer.TimerFcn = @(varargin)obj.track_fcn();
            start(obj.track_timer);
            function on_close(varargin)
                stop(obj.update_timer);
                stop(obj.track_timer);
                delete(obj.update_timer);
                delete(obj.track_timer);
                obj.has_been_closed = true;
            end
            set(obj.listbox_fig, 'DeleteFcn', @on_close);
        end

        function set_editor(obj, editor)
        % See qd.gui.TableView.set_editor.
            obj.editor = editor;
        end

        % set_title(title) renames the docked figure showing the list of runs.
        function set_title(obj, title)
            set(obj.listbox_fig, 'Name', title);
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

        function track_fcn(obj)
            should_track = false;
            try
                if obj.table_view.track
                    should_track = true;
                end
            end
            if ~should_track
                return
            end
            s = obj.discover_size_of_data(obj.loc);
            if s ~= obj.size_of_data
                obj.load_and_plot(obj.loc);
            end
        end

        function clear_cache(obj)
            obj.cache = containers.Map();
        end

        function clear_figure(obj)
            try
                close(obj.fig);
            catch
            end
            obj.fig = [];
            obj.table_view = [];
        end

        function select(obj, val)
            obj.loc = obj.content{val}.loc;
            obj.load_and_plot(obj.loc);
        end

        function load_and_plot(obj, loc)
            obj.loc = loc;
            obj.meta = json.read(fullfile(obj.loc, 'meta.json'));
            obj.tables = containers.Map;
            for table_name = obj.list_table_names(obj.loc)
                tbl = qd.data.load_table(obj.loc, table_name{1});
                for pseudo_column = obj.pseudo_columns
                    try
                        func = pseudo_column{1};
                        new_columns = func(qd.data.view_table(tbl), obj.meta);
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
                obj.tables(table_name{1}) = tbl;
            end
            obj.size_of_data = obj.discover_size_of_data(obj.loc);
            obj.plot_loc(obj.tables, obj.loc, obj.meta);
            obj.view_loc(obj.tables);
        end

        function s = discover_size_of_data(obj, loc)
            s = 0;
            for table_name = obj.list_table_names(loc)
                tbl = qd.data.load_table(loc, table_name{1});
                try
                    s = s + length(tbl{1}.data);
                end
            end
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

        % Adds a column to the currently plotted data.
        %
        % Call as inject_column(name, data), where data is a string and data
        % is a list of doubles. This list should be as long as the other
        % columns in the data. Optionally takes a third argument which is the
        % name of the table to add the column to (some runs generate multiple
        % tables).
        function inject_column(obj, name, data, varargin)
            p = inputParser();
            p.addOptional('table', []);
            p.parse(varargin{:});
            for key = obj.tables.keys()
                if ~isempty(p.Results.table) && ~strcmp(p.Results.table, key)
                    continue;
                end
                table = obj.tables(key{1});
                table{end+1} = struct('name', name, 'data', data);
                obj.tables(key{1}) = table;
            end
            obj.plot_loc(obj.tables, obj.loc, obj.meta);
            obj.view_loc(obj.tables);
        end

        % Updates the plot to view the supplied arguments.
        % 
        % Params:
        %   tables: a Map mapping table names to tables.
        %   loc:    the path to the folder containing the data.
        %   meta:   parsed metadata
        %
        % In this context a table is a cell array of structs. Each struct has
        % a name field and a data field. The data field is an array of
        % doubles.
        function plot_loc(obj, tables, loc, meta)
            if isempty(obj.fig)
                obj.fig = figure();
            end
            old_view = obj.table_view;
            obj.table_view = qd.gui.TableView(tables.values(), obj.fig);
            try
                obj.table_view.sweeps = meta.sweeps;
            end
            if obj.show_headers && isfield(meta, 'name')
                obj.table_view.header = meta.name;
            end
            if obj.show_folder_names
                [pathstr,name,ext] = fileparts(loc);
                obj.table_view.header = [obj.table_view.header ' - ' name];
            end
            if ~isempty(old_view)
                obj.table_view.mirror_settings(old_view);
            end
            obj.table_view.loc = loc;
            obj.table_view.set_editor(obj.editor)
            obj.table_view.update();
        end

        % Updates the obj.tbl property to reflect the supplied argument.
        % 
        % Params:
        %   tables: a Map mapping table names to tables.
        %
        % In this context a table is a cell array of structs. Each struct has
        % a name field and a data field. The data field is an array of
        % doubles.
        function view_loc(obj, tables)
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