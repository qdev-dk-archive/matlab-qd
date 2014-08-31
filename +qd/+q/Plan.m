classdef Plan < matlab.mixin.CustomDisplay
    properties
        q
        recipe
        inputs
        sms_flag = false
        verbose_flag = false
        name
    end
    methods
        function obj = Plan(q, inputs)
            obj.q = q;
            obj.inputs = inputs;
        end

        function obj = send_sms(obj)
            obj.sms_flag = true;
        end

        function obj = verbose(obj)
            obj.verbose_flag = true;
        end

        function obj = as(obj, name)
            obj.name = name;
        end

        function obj = with(obj, name_or_channel)
            obj.inputs = obj.inputs.with(obj.q.resolve_channel(name_or_channel));
        end

        function obj = without(obj, name)
            obj.inputs = obj.inputs.without(name);
        end

        function obj = only_with(obj, varargin)
            % We make a map of the old inputs.
            m = containers.Map();
            for inp = obj.inputs.inputs
                m(inp{1}.name) = inp{1};
            end
            % Clear the inputs.
            obj.inputs = qd.q.impl.Inputs();
            for arg = varargin
                arg = arg{1};
                if ischar(arg) & isKey(m, arg)
                    obj = obj.with(m(arg));
                else
                    obj = obj.with(arg);
                end
            end
        end

        function obj = do(obj, recipe)
            if isempty(obj.recipe)
                obj.recipe = recipe;
            else
                obj.recipe = qd.q.chain(obj.recipe, recipe);
            end
        end

        function obj = sw(obj, varargin)
            obj = obj.do(qd.q.sw(varargin{:}));
        end

        function go(obj, varargin)
            % TODO: be nice and tell what is wrong instead of assert(false).

            % We overload the go function slightly so the user can give
            % a name or a recipe and a name.
            switch length(varargin)
                case 0
                    % fall through
                case 1
                    obj.as(varargin{1}).go();
                    return
                case 2
                    obj.do(varargin{1}).go(varargin{2});
                    return
                otherwise
                    qd.util.assert(false);
            end
            % If the execution reaches this point, varargin is empty.
            qd.util.assert(~isempty(obj.name));
            job = obj.make_job_();
            if obj.verbose_flag
                disp(job);
            end
            ctx = obj.make_ctx_for_job_(job);
            future = qd.classes.SetFuture.do_nothing_future();
            settle = 0;
            prefix = [];
            job.exec(ctx, future, settle, prefix);
            if obj.sms_flag
                qd.util.send_sms( ...
                    obj.q.cellphone, ...
                    sprintf('Job complete: "%s".', obj.name));
            end
        end

        function job = make_job_(obj)
            qd.util.assert(~isempty(obj.recipe));
            ctx = struct('resolve_channel', @(x) obj.q.resolve_channel(x));
            job = obj.recipe.apply(ctx, obj.inputs);
        end

        function ctx = make_ctx_for_job_(obj, job)
            out_dir = obj.q.store.new_dir();
            meta = obj.describe();
            json.write(meta, fullfile(out_dir, 'meta.json'), 'indent', 2);
            table = qd.data.TableWriter(out_dir, 'data');
            for column = job.columns()
                table.add_column(column{1}.name);
            end
            table.init();
            points = job.total_points();
            eta = qd.q.impl.ETA(points);
            function add_point(p)
                table.add_point(p);
                eta.strobe();
            end
            cmd_sock = zmq.socket('rep');
            cmd_sock.connect('tcp://127.0.0.1:37544')
            ctx.add_point = @(p) add_point(p);
            ctx.periodic_hook = @() obj.cmd_hook_(cmd_sock, eta);
            ctx.add_divider = @() table.add_divider();
        end

        function cmd_hook_(obj, cmd_sock, eta)
            [msg, received] = cmd_sock.recv('dontwait');
            if ~received
                return
            end
            switch msg
                case 'abort'
                    cmd_sock.send('ack');
                    error('qd:q:abort', 'Aborted by user.');
                case 'eta'
                    cmd_sock.send({'ack', eta.format()});
                otherwise
                    cmd_sock.send('nack');
            end
        end

        function meta = describe(obj)
            meta = struct;
            register = qd.classes.Register();
            meta.setup = obj.q.setup.describe(register);
            meta.meta = obj.q.meta;
            job = obj.make_job_();
            meta.job = job.describe(register);
            meta.columns = job.columns();
            meta.name = obj.name;
            meta.timestamp = datestr(clock(),31);
            meta.type = 'Q';
            meta.version = '0.0.1';
            meta.register = register.describe();
        end

        % Measure how long this plan will take to execute.
        % 
        % The following named arguments are supported:
        %   * 'read_inputs' (default: false) 
        %      If set to true, try reading inputs to figure out how
        %      long it takes.
        function t = time(obj, varargin)
            options = struct(varargin{:});
            t = obj.make_job_().time(options, 0);
        end
    end
    methods (Access = protected)
        function displayScalarObject(obj)
            if isempty(obj.name)
                disp('# as (unnamed), do');
            else
                fprintf('# as ''%s'', do\n', obj.name);
            end
            if isempty(obj.recipe)
                j = obj.inputs;
            else
                j = obj.make_job_();
            end
            disp(qd.util.indent(j.pprint()));
        end
    end
end