classdef Inputs
    properties
        inputs = {}
    end
    methods
        % Create a new Inputs object with the channel object chan appended.
        function r = with(obj, chan)
            r = qd.q.Inputs();
            r.inputs = {r.inputs, chan};
        end

        % Create a new Inputs object where all channels named chan_name are omitted.
        function r = without(obj, chan_name)
            r = qd.q.Inputs();
            for inp = obj.inputs
                inp = inp{1};
                if not strcmp(inp.name, chan_name)
                    r.inputs{end + 1} = inp;
                end
            end
        end

        function cs = columns(obj)
            cs = {};
            for i = 1:length(obj.inputs)
                cs{i} = struct('name', obj.inputs{i}.name);
            end
        end

        % Reads all configured inputs into the array values (in parallel where
        % available).
        function values = read(obj)
            values = [];
            futures = {};
            for i = 1:length(obj.inputs)
                futures{i} = obj.inputs{1}.get_async();
            end
            for i = 1:length(futures)
                values(i) = futures{i}.exec();
            end
        end

        function meta = describe(obj, register)
            meta = {};
            for i in 1:length(obj.inputs)
                meta{i} = obj.inputs{i}.describe(register);
            end
        end
    end
end