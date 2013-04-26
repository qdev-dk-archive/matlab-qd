classdef FolderBrowser < handle
	properties(Access=private)
		loc
		content
		listbox
		listbox_fig
		fig
		update_timer
	end
	methods
		function obj = FolderBrowser(loc)
			obj.loc = loc;
			obj.listbox_fig = figure( ...
				'MenuBar', 'none', ...
				'Name', loc, ...
				'NumberTitle', 'off', ...
				'WindowStyle', 'docked');
			set(get(obj.listbox_fig,'javaframe'), 'GroupName','FolderBrowser');
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
			% TODO set a a delete function on the figure to close the folder
			% browser.
		end

		function update(obj)
			listing = dir(obj.loc);
			obj.content = {};
			names = {};
			for d = transpose(listing)
				meta_path = fullfile(obj.loc, d.name, 'meta.json');
				if ~exist(meta_path, 'file')
					continue
				end
				meta = json.read(meta_path);
				c = struct();
				c.name = meta.name;
				c.loc = fullfile(obj.loc, d.name);
				obj.content{end + 1} = c;
				names{end + 1} = c.name;
			end
			set(obj.listbox, 'String', names);
		end

		function select(obj, val)
			loc = obj.content{val}.loc;
			if isempty(obj.fig)
				obj.fig = figure();
			else
				figure(obj.fig);
			end
			clf();
			hold('all');
			title(obj.content{val}.name);
			for d = transpose(dir(fullfile(loc, '*.dat')))
				[~, table_name, ~] = fileparts(fullfile(loc, d.name));
				table = qd.data.load_table(loc, table_name);
				plot(table{1}.data, table{2}.data);
			end
		end

		function delete(obj)
			stop(obj.update_timer);
		end
	end
end