classdef fast < qd.q.Recipe
    properties
        chan
        instrument
        from
        to
        points
    end
    methods
        function obj = fast(instrument, from, to, varargin)
        % recipe = fast(instrument, from, to) 
        %
        % Constructs a recipe that reads a trace from the instrument.
        %
        % Note: you often need to add one to the number of points to get nice
        %   values, e.g. sw(chan, 0, 10, 10) would set chan to the values [0,
        %   1.11, 2.22, ..., 10] for a total of 10 linearly spaced points.
        %   sw(chan, 0, 10, 11) would set chan to [0, 1, 2, ..., 10].
            obj.chan = 'fake/CH';
            obj.instrument = instrument;
            obj.from = from;
            obj.to = to;
            obj.points = 1;
            if ~isempty(varargin)
                error(['qd.q.fast called with one argument too much. The '...
                    'fith argument used to be the settling time, but '...
                    'you can no longer specify a settling time for a '...
                    'sweep. Use the qd.q.settle recipe, the settle '...
                    'function on the Plan class, or set default_settle '...
                    'on the Q object.']);
            end
        end

        function job = apply(obj, ctx, sub_job)
            job = qd.q.impl.Fast();
            job.chan = ctx.resolve_channel('fake/CH');
            job.instrument = obj.instrument;
            job.from = obj.from;
            job.to = obj.to;
            job.points = obj.points;
            job.job = sub_job;
        end
    end
end