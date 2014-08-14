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
            obj.recipe = qd.q.chain(recipe, obj.recipe);
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
            qt.util.assert(~isempty(obj.name));
            out_dir = obj.q.store.new_dir();
            meta = obj.describe();
            json.write(meta, fullfile(out_dir, 'meta.json'), 'indent', 2);
            table = qd.data.TableWriter(out_dir, 'data');
            job = obj.make_job()
            for column = job.columns()
                table.add_column(column{1}.name)
            end
            table.init();
            job.exec(table, 0, []);
        end

        function job = make_job(obj)
            qt.util.assert(~isempty(obj.recipe));
            job = obj.recipe.apply(obj.inputs.make_job());
        end

        function meta = describe(obj)
            meta = struct;
            register = qd.classes.Register();
            meta.setup = obj.q.setup.describe(register);
            meta.meta = obj.q.meta;
            job = obj.make_job();
            meta.job = job.describe(register);
            meta.columns = job.columns();
            meta.name = obj.name;
            meta.timestamp = datestr(clock(),31);
            meta.type = 'Q';
            meta.version = '0.0.1';
            meta.register = register.describe();
        end
    end
end