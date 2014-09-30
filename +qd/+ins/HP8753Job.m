classdef HP8753Job
    properties
        ins
        channel_names
        inputs
    end
    methods

        function obj = HP8753Job(ins)
            obj.ins = ins;
            obj.inputs = qd.q.impl.Inputs();
        end

        function exec(obj, ctx, future, prefix)
            if ~isempty(future)
                future.exec();
            end
            vals = obj.read();
            for v = vals.'
                ctx.add_point([prefix v.']);
            end
            ctx.periodic_hook();
        end

        function vals = read(obj)
            input_vals = obj.inputs.read();
            [mag, phase] = obj.ins.read_waveform();
            vals = [mag.', phase.', repmat(input_vals, lenght(mag), 1)];
        end

        function t = time(obj, options)
            t = 0;
            if isfield(options, 'read_inputs') && options.read_inputs
                m = tic;
                obj.read();
                t = toc(m);
            end
        end

        function r = reversed(obj)
            r = obj;
        end

        function cs = columns(obj)
            input_columns = inputs.columns();
            cs = [obj.get_channel_names() input_columns];
        end

        function names = get_channel_names(obj)
            if ~isempty(obj.channel_names)
                names = obj.channel_names;
            else
                names = {[obj.ins.name '/mag'], [obj.ins.name, '/phase']};
            end
        end

        function meta = describe(obj, register)
            meta = struct;
            meta.type = 'HP8753Job';
            meta.ins = register.put('instruments', obj.ins);
            meta.channel_names = obj.get_channel_names();
            meta.inputs = obj.inputs.describe(register);
        end

        function p = total_points(obj)
            p = obj.ins.getNumberOfPoints();
        end

        function t = pprint(obj)
            if isempty(obj.inputs)
                t = sprintf('waveform %s', obj.ins.name);
            else
                t = sprintf('waveform %s\n%s', obj.inputs.pprint());
            end
        end

    end
end