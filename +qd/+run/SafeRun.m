classdef SafeRun < qd.run.StandardRun
    properties
        running = false;
        stopnow = false;
        plots = {} %Cell array containing plots
        data = [] %Data matrix for plotting
        zdata = [] %Data matrix for 2d surface plot
    end
    properties(Access=private)
        columns
    end
    methods
        function pause_run(obj)
            disp('Run will pause.');
            obj.running = false;
        end

        function continue_run(obj)
            disp('Run continued.');
            obj.running = true;
        end

        function stop_run(obj)
            disp('Run stopped.');
            obj.stopnow = true;
        end

        % varargin defines the plottype, points, line, color ..., e.g. 'r.-'
        function add_plot(obj, xname, yname, title, fignum, varargin)
            p = containers.Map;
            p('xname') = xname;
            p('yname') = yname;
            p('varargin') = varargin;
            p('fignum') = fignum;
            p('title') = title;
            obj.plots{end+1} = p;
        end

        % varargin defines be the colormap type: hot, jet ...
        function add_2dplot(obj, xname, yname, zname, title, fignum, varargin)
            p = containers.Map;
            p('xname') = xname;
            p('yname') = yname;
            p('zname') = zname;
            p('varargin') = varargin;
            p('fignum') = fignum;
            p('title') = title;
            obj.plots{end+1} = p;
        end

        function create_plots(obj)
            for pnum = 1:length(obj.plots)
                fignum = obj.plots{pnum}('fignum');
                if fignum>0
                    figure(fignum);
                else
                    fignum = figure();
                    obj.plots{pnum}('fignum') = fignum;
                end
                clf();
                varargin = obj.plots{pnum}('varargin');
                Keyset = {'zname'};
                surfaceplot = isKey(obj.plots{pnum},Keyset);
                if ~surfaceplot
                    h = plot(0,0,varargin{:});
                    obj.plots{pnum}('handle') = h;
                    xname = obj.plots{pnum}('xname');
                    yname = obj.plots{pnum}('yname');
                    title1 = obj.plots{pnum}('title');
                    xlabel(xname);
                    ylabel(yname);
                    title(title1);
                else
                    x_limits = [obj.sweeps{1,1}.from obj.sweeps{1,1}.to];
                    y_limits = [obj.sweeps{1,2}.from obj.sweeps{1,2}.to];
                    x_extents = [min(x_limits) max(x_limits)];
                    y_extents = [min(y_limits) max(y_limits)];
                    x_points = obj.sweeps{1,1}.points;
                    y_points = obj.sweeps{1,2}.points;
                    xp = linspace(x_extents(1), x_extents(2), x_points);
                    yp = linspace(y_extents(1), y_extents(2), y_points);
                    [X, Y] = meshgrid(xp, yp);
                    obj.plots{pnum}('gridX') = X;
                    obj.plots{pnum}('gridY') = Y;
                    obj.plots{pnum}('counter_outloop') = 0;
                    obj.plots{pnum}('counter_inloop') = 1;
                    xdata = obj.sweeps{1,1}.values;
                    ydata = obj.sweeps{1,2}.values;
                    obj.zdata = nan(length(ydata),length(xdata));
                    h = imagesc(x_extents, y_extents, obj.zdata);
                    colormap(varargin{:});
                    obj.plots{pnum}('handle') = h;
                    cb = colorbar;
                    set(gca,'YDir','normal');
                    xname = obj.plots{pnum}('xname');
                    yname = obj.plots{pnum}('yname');
                    zname = obj.plots{pnum}('zname');
                    title1 = obj.plots{pnum}('title');
                    xlabel(xname);
                    ylabel(yname);
                    ylabel(cb, zname);
                    title(title1);
                end
            end
        end

        function update_plots(obj, values)
            obj.data = [obj.data; values];
            for p = obj.plots
                p = p{1};
                h = p('handle');
                keyset = {'zname'};
                surfaceplot = isKey(p,keyset);
                if ~surfaceplot
                    xname = p('xname');
                    yname = p('yname');
                    xindex = not(cellfun('isempty', strfind(obj.columns, xname)));
                    yindex = not(cellfun('isempty', strfind(obj.columns, yname)));
                    x = obj.data(:,xindex);
                    y = obj.data(:,yindex);
                    hold on;
                    set(h, 'XData', x', 'YData', y');
                else
                    inner_loop_points = obj.sweeps{1,2}.points;
                    outer_loop_points = obj.sweeps{1,1}.points;
                    zname = p('zname');
                    zindex = not(cellfun('isempty', strfind(obj.columns, zname)));
                    z = obj.data(:,zindex);
                    if ~mod(length(z),inner_loop_points)
                        if length(z) ~= inner_loop_points*outer_loop_points
                             dif = inner_loop_points.*outer_loop_points - length(z);
                             z = [z;nan(dif,1)];
                        end
                        obj.zdata = reshape(z,inner_loop_points,outer_loop_points);
                        set(h, 'Cdata', obj.zdata);
                    end
                end
            end
        end

        function obj = sweep(obj, name_or_channel, from, to, points, varargin)
            p = inputParser();
            p.addOptional('settle', 0);
            p.addOptional('tolerance', []);
            p.addOptional('values', []);
            p.addOptional('alternate', false);
            p.parse(varargin{:});
            sweep = struct();
            sweep.from = from;
            sweep.to = to;
            sweep.points = points;
            sweep.settle = p.Results.settle;
            sweep.tolerance = p.Results.tolerance;
            sweep.alternate = p.Results.alternate;
            if(isempty(p.Results.values))
                sweep.values = linspace(from, to, points);
            else
                sweep.values = p.Results.values;
            end
            sweep.chan = obj.resolve_channel(name_or_channel);
            if(strcmp(name_or_channel,'time/time') && (sweep.from == 0))
                sweep.chan.instrument.reset;
            end
            obj.sweeps{end + 1} = sweep;
        end
    end

    methods(Access=protected)
        function perform_run(obj, out_dir)
            % This table will hold the data collected.
            table = qd.data.TableWriter(out_dir, 'data');
            obj.columns = {};
            for sweep = obj.sweeps
                table.add_channel_column(sweep{1}.chan);
                obj.columns{end+1} = sweep{1}.chan.name;
            end
            for inp = obj.inputs
                table.add_channel_column(inp{1});
                obj.columns{end+1} = inp{1}.name;
            end
            table.init();
            obj.running = true;
            obj.stopnow = false;
            % Start meas control window.
            hMeasControl = meas_control(obj);
            % Create plots
            obj.create_plots();
            % Now perform all the measurements.
            obj.handle_sweeps(obj.sweeps, [], table);
            close(hMeasControl);
        end

        function handle_sweeps(obj, sweeps, earlier_values, table)
        % obj.handle_sweeps(sweeps, earlier_values, settle, table)
        %
        % Sweeps the channels in sweeps, takes measurements and puts them in
        % table.
        %
        % sweeps is a cell array of structs with the fields: from, to, points,
        % chan, and settle. Rows will be added to table which look like:
        % [earlier_values sweeps inputs] where earlier_values is an array of
        % doubles, sweeps, is the current value of each swept parameter, and
        % inputs are the measured inputs (the channels in obj.inputs). Settle
        % is the amount of time to wait before measuring a sample (in ms).

            % If there are no more sweeps left, let the system settle, then
            % measure one point.
            if isempty(sweeps)
                %values = [earlier_values];
                values = [];
                futures = {};
                for sweep = obj.sweeps
                    futures{end + 1} = sweep{1}.chan.get_async();
                end
                for inp = obj.inputs
                    futures{end + 1} = inp{1}.get_async();
                end
                % for sweep = obj.sweeps
                %     values(end + 1) = earlier_values(end);
                % end
                for future = futures
                    values(end + 1) = future{1}.exec();
                end
                % Add data point
                table.add_point(values); % Write data point to file
                obj.update_plots(values);
                drawnow();
                if obj.running
                    return
                else
                    disp('Click continue.');
                    while (not(obj.running) && not(obj.stopnow))
                        pause(1);
                    end
                    return
                end
            end

            % Sweep one channel. Within the loop, recusively call this
            % function with one less channel to sweep.
            sweep = sweeps{1};
            next_sweeps = sweeps(2:end);
            for value = sweep.values
                sweep.chan.set(value);
                if ~isempty(sweep.tolerance)
                    curval = sweep.chan.get();
                    fprintf('Setting %s=%f to %f\r',sweep.chan.name,curval,value);
                    while true
                        curval = sweep.chan.get();
                        if abs(value-curval)<sweep.tolerance
                            break;
                        else
                            pause(sweep.settle);
                        end
                    end
                else
                    pause(sweep.settle);
                end
                %settle = max(settle, sweep.settle);
                obj.handle_sweeps(next_sweeps, [earlier_values value], table);
                if ~isempty(next_sweeps)
                    % Nicely seperate everything for gnuplot.
                    table.add_divider();
                end
                % If the measurement has to be stopped, break here
                if obj.stopnow
                    break
                end
            end
        end
    end
end
