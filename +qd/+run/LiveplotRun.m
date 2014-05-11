classdef LiveplotRun < qd.run.StandardRun
    properties
        plots = {} %Cell array containing plots
        custom_plots = {} % Custom plots
        data = [] %Data matrix for plotting
        zdata = [] %Data matrix for 2d surface plot
    end
    properties(Access=private)
        columns
        table
    end
    methods
        function obj = LiveplotRun(config)
            % Create store object
            obj.store = qd.data.Store(config('datadir'), [config('name'), '_', config('measurement_type')]);
            % Measurement details
            obj.comment = config('comment');
            obj.name = config('name');
            obj.type = config('measurement_type');
            obj.setup = config('setup');
        end

        function init(obj)
            out_dir = obj.store.new_dir();
            obj.table = qd.data.TableWriter(out_dir, 'data');
            obj.columns = {};
            for inp = obj.inputs
                obj.table.add_channel_column(inp{1});
                obj.columns{end+1} = inp{1}.name;
            end
            obj.table.init();
            % Create plots
            obj.create_plots();
        end

        function add_data_point(obj)
            values = [];
            for inp = obj.inputs
                values(end + 1)  = inp{1}.get_async().exec();
            end
            % Add data point
            obj.table.add_point(values); % Write data point to file
            obj.update_plots(values);
        end

        % varargin defines the plottype, points, line, color ..., e.g. 'r.-'
        function add_plot(obj, xname, yname, varargin)
            p = containers.Map;
            p('xname') = xname;
            p('yname') = yname;
            p('varargin') = varargin;
            p('fignum') = 0;
            p('title') = '';
            p('type') = '1d';
            obj.plots{end+1} = p;
        end

        function add_custom_plot(obj, xname, yname, varargin)
            p = containers.Map;
            p('xname') = xname;
            p('yname') = yname;
            p('varargin') = varargin;
            p('fignum') = 0;
            p('title') = '';
            obj.custom_plots{end+1} = p;
        end

        function create_plots(obj)
            plots = cat(2,obj.plots, obj.custom_plots);
            for pnum = 1:length(plots)
                fignum = plots{pnum}('fignum');
                if fignum>0
                    hFig = figure(fignum);
                else
                    hFig = figure();
                    plots{pnum}('fignum') = hFig;
                end
                clf();
                varargin = plots{pnum}('varargin');
                mytitle = plots{pnum}('title');
                if isempty(mytitle)
                    plots{pnum}('title') = [obj.store.datestamp, '/', obj.store.timestamp, ' ', strrep(obj.store.name,'_','\_')];
                end
                h = plot(0,0,varargin{:});
                plots{pnum}('handle') = h;
                xlabel(plots{pnum}('xname'));
                ylabel(plots{pnum}('yname'));
                title(plots{pnum}('title'));
            end
        end

        function update_plots(obj, values)
            obj.data = [obj.data; values];
            for p = obj.plots
                p = p{1};
                h = p('handle');
                xname = p('xname');
                yname = p('yname');
                xindex = not(cellfun('isempty', strfind(obj.columns, xname)));
                yindex = not(cellfun('isempty', strfind(obj.columns, yname)));
                x = obj.data(:,xindex);
                y = obj.data(:,yindex);
                set(h, 'XData', x', 'YData', y');
            end
        end

        function save_plots(obj)
            for plot = obj.plots
                figure(plot{1}('fignum'));
                name = [strrep(plot{1}('xname'),'/','_'), '_vs_', strrep(plot{1}('yname'),'/','_')];
                saveas(gcf, [obj.store.directory, '/', name, '.png'], 'png');
            end
        end
    end
end
