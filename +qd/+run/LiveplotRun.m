classdef LiveplotRun < qd.run.SafeRun
    properties
        plots = {} %Cell array containing plots
        columns = {}
        variables = {}
        variables_colnames = {} % save original equation for metadata & post-analysis
        data = [] %Data matrix for plotting
        zdata = [] %Data matrix for 2d surface plot
        width = 4     % Width in inches
        height = 4    % Height in inches
        alw = 0.75    % AxesLineWidth
        fsz = 11      % Fontsize
        lw = 1      % LineWidth
        msz = 8       % MarkerSize
        sz = get(0,'ScreenSize'); % Get Screen size
        table = []
        number = '+4561774499'
        send_text = false % If true, a text will be send on completion of sweep
        send_mail = false % If true, a mail will be send on completion of sweep
        mail = 'oxtriton2@gmail.com';    % Sending email
        password = 'qdevtriton2';          % Sending email password
        smtp_server = 'smtp.gmail.com';     % Sending email SMTP server
        recive_mail = 'CJS.Olsen@nbi.dk'    % Reciving email
    end
    methods

        function setup_mail(obj)
            props = java.lang.System.getProperties;
            props.setProperty('mail.smtp.port','465');
            pp=props.setProperty('mail.smtp.auth','true'); %#ok
            pp=props.setProperty('mail.smtp.socketFactory.class','javax.net.ssl.SSLSocketFactory'); %#ok
            pp=props.setProperty('mail.smtp.socketFactory.port','465'); %#ok
            % Apply prefs and props
            setpref('Internet','E_mail',obj.mail);
            setpref('Internet','SMTP_Server',obj.smtp_server);
            setpref('Internet','SMTP_Username',obj.mail);
            setpref('Internet','SMTP_Password',obj.password);
        end
        
        function sweep_done(obj)
            if obj.send_text && obj.send_mail
                qd.util.send_sms(obj.number, sprintf('Sweep done at %s',datestr(clock,'yyyy-mm-dd HH:MM:SS')))
                sendmail(obj.recive_mail,sprintf('Sweep done at %s',datestr(clock,'yyyy-mm-dd HH:MM:SS')),'Same as above;)')
            elseif obj.send_mail
                sendmail(obj.recive_mail,sprintf('Sweep done at %s',datestr(clock,'yyyy-mm-dd HH:MM:SS')),'Same as above;)')
            elseif obj.send_text
                qd.util.send_sms(obj.number, sprintf('Sweep done at %s',datestr(clock,'yyyy-mm-dd HH:MM:SS')))
            end
        end
        
        % varargin defines the plottype, points, line, color ..., e.g. 'r.-'
        function add_plot(obj, xname, yname, title, fignum, varargin)
            p = struct();
            p.('xname') = xname;
            p.('yname') = yname;
            p.('varargin') = varargin;
            p.('fignum') = fignum;
            p.('title') = title;
            p.('type') = '1d';
            obj.plots{end+1} = p;
            obj.meta.plots = obj.plots;
            obj.meta.columns = obj.columns;
            obj.meta.variables = obj.variables_colnames;
        end

        % varargin defines be the colormap type: hot, jet ...
        function add_2dplot(obj, xname, yname, zname, title, fignum, varargin)
            p = struct();
            p.('xname') = xname;
            p.('yname') = yname;
            p.('zname') = zname;
            p.('varargin') = varargin;
            p.('fignum') = fignum;
            p.('title') = title;
            p.('type') = 'surface';
            obj.plots{end+1} = p;
        end

        % varargin defines the plot type: points or line ...
        function add_waterfall_plot(obj, xname, yname, title, fignum, varargin)
            p = containers.Map;
            p('xname') = xname;
            p('yname') = yname;
            p('varargin') = varargin;
            p('fignum') = fignum;
            p('title') = title;
            p('type') = 'waterfall';
            p('counter') = 0;
            obj.plots{end+1} = p;
        end

        function create_plots(obj)
            fig_per_row = 0;
            for pnum = 1:length(obj.plots)
                fignum = obj.plots{pnum}.('fignum');
                if fignum>0
                    hFig = figure(fignum);
                else
                    hFig = figure();
                    obj.plots{pnum}.('fignum') = hFig;
                end
                clf();

                % change figure size and distrubute on screen
                if pnum*obj.width*72 <= obj.sz(3) && obj.height*72 <= obj.sz(4)
                    set(gcf, 'OuterPosition', [0+(pnum-1)*obj.width*72 obj.sz(4)-(obj.height*72) obj.width*72, obj.height*72]); %<- Set size and position
                    fig_per_row = fig_per_row + 1;
                elseif pnum*obj.width*72 > obj.sz(3) && ceil(pnum/(fig_per_row))*obj.height*72 <= obj.sz(4)
                    set(gcf, 'OuterPosition', [0+(pnum-((fig_per_row*(ceil(pnum/fig_per_row)-1))+1))*obj.width*72 obj.sz(4)-(ceil(pnum/(fig_per_row))*obj.height*72) obj.width*72, obj.height*72]); %<- Set size and position
                else
                    % Put the rest on top of the first
                    set(gcf, 'OuterPosition', [0 obj.sz(4)-(obj.height*72) obj.width*72 obj.height*72]); %<- Set size and position
                end
                set(gca, 'FontSize', obj.fsz, 'LineWidth', obj.alw); %<- Set properties
                
                varargin = obj.plots{pnum}.('varargin');
                varargin{end+1} = 'LineWidth';
                varargin{end+1} = obj.lw;
                varargin{end+1} = 'MarkerSize';
                varargin{end+1} = obj.msz;
                surfaceplot = strcmp(obj.plots{pnum}.type, 'surface');
                %mytitle = obj.plots{pnum}.('title');
                mytitle = {[obj.store.datestamp, '/', obj.store.timestamp], obj.plots{pnum}.('title'),''};
                if isempty(mytitle)
                    obj.plots{pnum}.('title') = [obj.store.datestamp, '/', obj.store.timestamp, ' ', strrep(obj.store.name,'_','\_')];
                end
                if ~surfaceplot
                    h = plot(0,0,varargin{:});
                    obj.plots{pnum}.('handle') = h;
                    xlabel(obj.plots{pnum}.('xname'));
                    ylabel(obj.plots{pnum}.('yname'));
                    title(mytitle);
                else
                    type = obj.plots{pnum}('type');
                    if strcmp(type,'1d') || strcmp(type,'waterfall')
                        h = plot(NaN,NaN,varargin{:});
                        obj.plots{pnum}('handle') = h;
                        xname = obj.plots{pnum}('xname');
                        yname = obj.plots{pnum}('yname');
                        title1 = obj.plots{pnum}('title');
                        xlabel(xname);
                        ylabel(yname);
                        title(title1);
                    elseif strcmp(type,'surface')
                        x_limits = [obj.sweeps{1,1}.from obj.sweeps{1,1}.to];
                        y_limits = [obj.sweeps{1,2}.from obj.sweeps{1,2}.to];
                        x_extents = [min(x_limits) max(x_limits)];
                        y_extents = [min(y_limits) max(y_limits)];
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
                        xlabel(xname);
                        ylabel(yname);
                        ylabel(cb, zname);
                        title(mytitle);
                        title(title1);
                    else
                        error('Supported plottypes is: 1d, surface and waterfall');
                    end
                end
            end
        end
        
        function add_variable(obj, name, input)
            n = 1;
            if isfloat(input)
                obj.meta.(name) = input;
            else
                obj.variables_colnames{end+1} = input; % save original equation for metadata & post-analysis
                if isempty(obj.columns)
                    obj.init_columns();
                end
                for column = obj.columns
                    input = strrep(input, column, ['values(:,', num2str(n), ')']);
                    n = n + 1;
                end
                varnames = fieldnames(obj.meta);
                for k=1:length(varnames)
                    varname = varnames{k};
                    input = strrep(input, varname, ['obj.meta.(', '''', varname, '''', ')']);
                end
                obj.variables{end+1} = input;
                obj.columns{end+1} = name;
            end
        end

        function update_plots(obj, values)
            for variable = obj.variables
                value = eval(variable{1}{1});
                values = [values, value];
            end
            obj.data = [obj.data; values];
            for p = obj.plots
                p = p{1};
                h = p.('handle');
                type = p.('type');
                if strcmp(type,'1d')
                    xname = p.('xname');
                    yname = p.('yname');
                    [~, xindex] = ismember(xname, obj.columns);
                    [~, yindex] = ismember(yname, obj.columns);
                    if xindex == 0
                        error(['Cannot find ', xname]);
                    elseif yindex == 0
                        error(['Cannot find ', yname]);
                    end
                    x = obj.data(:,xindex);
                    y = obj.data(:,yindex);
                    try
                        set(h, 'XData', x', 'YData', y');
                    catch
                        obj.create_plots();
                        set(h, 'XData', x', 'YData', y');
                    end
                elseif strcmp(type,'surface')
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
                elseif strcmp(type,'waterfall')
                    inner_loop_points = obj.sweeps{1,2}.points;
                    outer_loop_points = obj.sweeps{1,1}.points;
                    counter = p('counter');
                    xname = p('xname');
                    xindex = not(cellfun('isempty', strfind(obj.columns, xname)));
                    x = obj.data(:,xindex);
                    if ~mod(length(x),inner_loop_points)
                        yname = p('yname');
                        yindex = not(cellfun('isempty', strfind(obj.columns, yname)));
                        y = obj.data(inner_loop_points*counter+1:inner_loop_points+inner_loop_points*counter,yindex);
                        x = obj.data(inner_loop_points*counter+1:inner_loop_points+inner_loop_points*counter,xindex);
                        figure(p('fignum'));
                        h = plot(x,y);
                        set(h,'color',hsv2rgb([1-counter/(outer_loop_points-1) 1 1]));
                        p('handle') = h;
                        hold on;
                        p('counter') = counter+1;
                    end
                end
            end
        end

        function save_plots(obj)
            for plot = obj.plots
                figure(plot{1}.('fignum'));
                name = [strrep(plot{1}.('xname'),'/','_'), '_vs_', strrep(plot{1}.('yname'),'/','_')];

                % Here we preserve the size of the image when we save it.
                set(gcf,'InvertHardcopy','on');
                set(gcf,'PaperUnits', 'inches');
                papersize = get(gcf, 'PaperSize');
                left = (papersize(1)- obj.width)/2;
                bottom = (papersize(2)- obj.height)/2;
                myfiguresize = [left, bottom, obj.width, obj.height];
                set(gcf,'PaperPosition', myfiguresize);

                % Save image as png
                saveas(gcf, [obj.store.directory, '/', name, '.png'], 'png');
                savefig(gcf, [obj.store.directory, '/', name, '.fig']);
            end
        end

        function send_plots_to_evernote(obj, title, comment)
            % Get all plot file attachments
            attachments = {};
            for plot = obj.plots
                name = [strrep(plot{1}.('xname'),'/','_'), '_vs_', strrep(plot{1}.('yname'),'/','_')];
                if exist([obj.store.directory, '/', name, '.png'], 'file') == 2
                    attachments{end+1} = [obj.store.directory, '/', name, '.png'];
                end
            end
            % add .fig files
            for plot = obj.plots
                name = [strrep(plot{1}.('xname'),'/','_'), '_vs_', strrep(plot{1}.('yname'),'/','_')];
                attachments{end+1} = [obj.store.directory, '/', name, '.fig'];
            end
            sendmail(obj.meta.evernotemail, [title ' @', obj.meta.notebookname], comment, attachments);
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

        function add_data_point(obj)
            values = [];
            futures = {};
            for sweep = obj.sweeps
                futures{end + 1} = sweep{1}.chan.get_async();
            end
            for inp = obj.inputs
                futures{end + 1} = inp{1}.get_async();
            end
            for future = futures
                values(end + 1) = future{1}.exec();
            end
            % Add data point
            obj.table.add_point(values); % Write data point to file
            obj.update_plots(values);
            pause(10e-3); % Pause to update the GUI
        end
    end
    

    methods(Access=protected)
        function perform_run(obj, out_dir)
            % This table will hold the data collected.
            table = qd.data.TableWriter(out_dir, 'data');
            for sweep = obj.sweeps
                table.add_channel_column(sweep{1}.chan);
            end
            for inp = obj.inputs
                table.add_channel_column(inp{1});
            end
            table.init();
            obj.table = table;
            obj.running = true;
            obj.stopnow = false;
            % Start meas control window.
            hMeasControl = qd.run.meas_control_export(obj);
            % Create plots
            obj.create_plots();
            % Init columns
            if isempty(obj.columns)
                obj.init_columns();
            end
            % Now perform all the measurements.
            obj.handle_sweeps(obj.sweeps, [], table);
            close(hMeasControl);
            if obj.send_text || obj.send_mail
                obj.setup_mail();
                obj.sweep_done();
            end
        end
        
        function init_columns(obj)
            obj.columns = {};
            for sweep = obj.sweeps
                obj.columns{end+1} = sweep{1}.chan.name;
            end
            for inp = obj.inputs
                obj.columns{end+1} = inp{1}.name;
            end
        end
    end
end
