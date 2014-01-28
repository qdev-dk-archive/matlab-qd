classdef BreakdownRun < qd.run.StandardRun
    properties
        % breakdown_condition should be set to a funtion handle taking a
        % single parameter 'inputs', which is a containers.Map mapping the
        % name of each input to the last meassured value. If the function
        % returns true, then move_to_zero is called, and the run terminates.
        breakdown_condition = @(inputs) false;
    end

    methods(Access=protected)

        function row_hook(obj, sweep_values, inputs)
            input_map = container.Map();
            for i = [1..length(inputs)]
                input_map(obj.inputs{i}.name) = inputs(i);
            end
            if obj.breakdown_condition(input_map)
                obj.move_to_zero();
                throw(MException('qd:run:BreakdownRun:breakdown', 'breakdown condition met.'))
            end
        end

    end
end
