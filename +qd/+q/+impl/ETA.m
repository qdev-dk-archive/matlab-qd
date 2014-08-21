classdef ETA < handle
    properties
        total
        start_tic
        completed = 0
    end
    methods
        % total may be inf if the job will go forever or NaN if it is
        % impossible to tell when it will stop.
        function obj = ETA(total)
            obj.start_tic = tic();
            obj.total = total;
        end

        function strobe(obj)
            obj.completed = obj.completed + 1;
        end

        function s = format(obj)
            running_time = toc(obj.start_tic);
            s = sprintf('%.1f s', ...
                obj.total/obj.completed*running_time);
        end
    end
end