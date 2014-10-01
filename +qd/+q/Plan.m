classdef Plan < matlab.mixin.CustomDisplay
    % Builds and executes jobs.
    %
    % See the file concepts.md for details on how to use this class. In
    % general, it should not be constructed directly, but by the qd.q.Q class.
    %
    % Note: this class is NOT a handle subclass. Every object is immutable,
    %   all functions return new and independent Plan instances.
    %
    % See also qd.q.Q
    properties
        q
        recipe
        inputs
        job_override
        sms_flag = false
        email_flag = false
        verbose_flag = false
        % If input_settle_val is non-zero and go() or time() is called, then
        % qd.q.settle(obj.input_settle_val) is added to the recipe before
        % reading the inputs.
        input_settle_val = 0
        name
    end
    methods
        function obj = Plan(q, inputs)
            obj.q = q;
            obj.inputs = inputs;
        end

        function obj = sms(obj)
        % Send an sms when the job is complete. 
        %
        % The recipient is given by the cellphone property of the associated
        % qd.q.Q object.
            obj.sms_flag = true;
        end

        function obj = email(obj)
        % Send an email when the job is complete. 
        %
        % The recipient is given by the email_recipient property of the
        % associated qd.q.Q object.
            obj.email_flag = true;
        end

        function obj = verbose(obj)
        % Print what is being done when the job is executing.
            obj.verbose_flag = true;
        end

        function obj = as(obj, name, varargin)
        % Change the name job will get.
        %
        % If more than one arguments are given, sprintf is called with all the
        % arguments to generate a name. For instance
        %
        %   obj.as('Gate sweep at %g mT', 12.56)
        %
        % is equivalent to
        %
        %   obj.as(sprintf('Gate sweep at %g mT', 12.56))
            if isempty(varargin)
                obj.name = name;
            else
                obj.name = sprintf(name, varargin{:});
            end
        end

        function obj = with(obj, name_or_channel, varargin)
        % obj.with(input1, [input2, ...])
        %
        % Add one or more inputs to the current set. Arguments can be names or
        % channel objects. Names are looked up in the setup of the associated
        % qd.q.Q object.
        %
        % See also qd.q.Plan.without and qd.q.Plan.with_only.
            obj.inputs = obj.inputs.with(obj.q.resolve_channel(name_or_channel));
            if ~isempty(varargin)
                obj = obj.with(varargin{:});
            end
        end

        function obj = without(obj, name, varargin)
        % obj.without(input1, [input2, ...])
        %
        % Remove one or more inputs to the current set. Arguments should be
        % names only.
        %
        % See also qd.q.Plan.with and qd.q.Plan.with_only.
            obj.inputs = obj.inputs.without(name);
            if ~isempty(varargin)
                obj = obj.without(varargin{:});
            end
        end

        function obj = with_only(obj, varargin)
        % obj.with_only(input1, [input2, ...])
        %
        % Completely override the current set of inputs. Arguments can be
        % channel objects or names of inputs. If names are given, they are
        % first looked up in the current set, then in the setup of the
        % associated qd.q.Q object.
        %  
        % See also qd.q.Plan.with and qd.q.Plan.without.

            % We make a map of the old inputs.
            m = containers.Map();
            for inp = obj.inputs.inputs
                m(inp{1}.name) = inp{1};
            end
            % Clear the inputs.
            obj.inputs = qd.q.impl.Inputs();
            for arg = varargin
                arg = arg{1};
                if ischar(arg) && isKey(m, arg)
                    obj = obj.with(m(arg));
                else
                    obj = obj.with(arg);
                end
            end
        end

        function obj = do(obj, recipe)
        % obj.do(r) appends to the current recipe.
        %
        % If the current recipe was s before, it will be (s|r) after.
            if isempty(obj.recipe)
                obj.recipe = recipe;
            else
                obj.recipe = qd.q.chain(obj.recipe, recipe);
            end
        end

        function obj = sw(obj, varargin)
        % obj.sw(...) calls obj.do(qd.q.sw(...)) to add a sweep to the recipe.
        %
        % See also qd.q.sw.
            obj = obj.do(qd.q.sw(varargin{:}));
        end

        function obj = swd(obj, varargin)
        % obj.swd(...) calls obj.do(qd.q.swd(...)) to add a sweep to the recipe.
        %
        % In contrast to obj.sw(...) this lets you specify the point density
        % rather than the number of points.
        %
        % See also qd.q.swd.
            obj = obj.do(qd.q.swd(varargin{:}));
        end

        function obj = input_settle(obj, seconds)
        % obj.input_settle(seconds) sets the settling time.
        %
        % The settling time is the time to wait after setting outputs before
        % reading inputs. Use obj.do(qd.q.settle(seconds)) to add settling
        % time at a specific point in the recipe instead.
            obj.input_settle_val = seconds;
        end

        function obj = job(obj, job)
        % obj.job(job) changes the job that recipes are applied to.
        %
        % obj.go(..) applies the current recipe to a trivial job that reads
        % one input point, after calling this method, obj.go(..) will apply
        % the current recipe to the supplied job instead.
            obj.job_override = job;
        end

        function go(obj, varargin)
        % obj.go([name, ...]) executes the plan.
        %
        % This function does the following:
        %
        % 1. If arguments are given to this function, they are first forwarded
        %    to qd.q.Plan.as to set the name of the job.
        % 2. A job is then contructed by applying the current recipe to a job
        %    which reads the current inputs once.
        % 3. An output location is created using the associated store.
        % 4. The describe method is called and the output is written to the
        %    file meta.json.
        % 5. The job is executed.
        % 6. An sms or email is optionally sent to the operator.
        %
        % See also qd.q.abort and qd.q.eta.

            % We overload the go function slightly so the user can give
            % a name with the go function.
            if ~isempty(varargin)
                obj.as(varargin{:}).go();
                return;
            end
            % If the execution reaches this point, varargin is empty.
            qd.util.assert(~isempty(obj.name));
            job = obj.make_job_();
            ctx = obj.make_ctx_for_job_(job);
            start_time = tic();
            if obj.verbose_flag
                disp(obj);
            end
            future = qd.classes.SetFuture.do_nothing_future();
            prefix = [];
            job.exec(ctx, future, prefix);
            time_string = sprintf('job took %s', qd.util.format_seconds(toc(start_time)));
            if obj.verbose_flag
                disp(time_string);
            end
            if obj.sms_flag
                obj.q.send_sms_(sprintf('Job complete: "%s" (%s).', obj.name, time_string));
            end
            if obj.email_flag
                obj.q.send_email_(...
                    sprintf('Job complete: "%s".', obj.name), ...
                    sprintf('%s\n%s\n', obj.pprint(), time_string) ...
                )
            end
        end

        function job = make_job_(obj)
            qd.util.assert(~isempty(obj.recipe));
            ctx = struct('resolve_channel', @(x) obj.q.resolve_channel(x));
            recipe = obj.recipe;
            if obj.input_settle_val ~= 0
                recipe = recipe | qd.q.settle(obj.input_settle_val);
            end
            if ~isempty(obj.job_override)
                job = recipe.apply(ctx, obj.job_override);
            else
                job = recipe.apply(ctx, obj.inputs);
            end
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
        % obj.describe() creates a struct describing the plan.
        %
        % This is what goes into the meta.json file. The description includes
        % a description of the job that qd.Plan.go() would currently execute.
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

        function t = time(obj, varargin)
        % obj.time() measures how long this plan will take to execute.
        % 
        % The following named arguments are supported:
        %   * 'read_inputs' (default: true) 
        %      If set to true, try reading inputs to figure out how
        %      long that takes.
        %   * 'set_outputs' (default: false) 
        %      If set to true, try setting outputs to figure out how
        %      long that takes.
            options = struct(varargin{:});
            if ~isfield(options, 'read_inputs')
                options.read_inputs = true;
            end
            t = obj.make_job_().time(options);
        end

        function s = pprint(obj)
            if isempty(obj.name)
                header = '# do';
            else
                header = sprintf('# as ''%s'', do', obj.name);
            end
            if isempty(obj.recipe)
                j = obj.inputs;
            else
                j = obj.make_job_();
            end
            s = sprintf('%s\n%s', header, qd.util.indent(j.pprint()));
        end
    end
    methods (Access = protected)
        function displayScalarObject(obj)
            disp(obj.pprint());
        end
    end
end