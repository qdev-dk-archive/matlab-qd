classdef RunWithInputs < qd.run.Run
    properties
        % Cell array containing one qd.classes.Channel (or a subclass) per
        % input (in the order specified).
        inputs = {}
    end
    methods

        function obj = input(obj, name_or_channel)
            chan = obj.resolve_channel(name_or_channel);
            obj.inputs{end + 1} = chan;
            if(strcmp(name_or_channel,'time/time'))
                chan.instrument.reset;
            end
        end

        % Reads all configured inputs into the array values (in parallel where
        % available).
        function values = read_inputs(obj)
            values = [];
            futures = {};
            for inp = obj.inputs
                futures{end + 1} = inp{1}.get_async();
            end
            for future = futures
                values(end + 1) = future{1}.exec();
            end
        end
    end

    methods(Access=protected)

        function meta = add_to_meta(obj, meta, register)
            meta.inputs = {};
            for inp = obj.inputs
                meta.inputs{end + 1} = register.put('channels', inp{1});
            end
            add_to_meta@qd.run.Run(obj, meta, register);
        end

    end
end
