classdef Plan
    properties
        q
        recipe
        inputs
        send_sms_set = false
        name
    end
    methods
        function obj = Plan(q, inputs)
            obj.q = q;
            obj.inputs = inputs;
        end

        function obj = send_sms(obj)
            obj.send_sms_set = true;
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
            ctx = obj.make_ctx_for_job_(job);
            job.exec(ctx, 0, []);
            if obj.send_sms_set
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
            ctx.add_point = @(p) add_point(p);
            ctx.periodic_hook = @() obj.periodic_hook_();
            ctx.add_divider = @() table.add_divider();
        end

        function periodic_hook_(obj)
            % TODO
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
        function t = time(varargin)
            options = struct(varargin{:});
            t = obj.make_job_().time(options, 0);
        end
    end
end