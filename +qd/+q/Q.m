% This is the main entry-point for the q module. The main tutorial and
% concepts.md describes how to use it.
%
classdef Q < handle
    properties
        setup
        store
        meta = struct % This will be included in the generated meta.json file.
        inputs = qd.q.impl.Inputs()
        % Default settling time after setting ouputs before reading inputs. In
        % seconds.
        default_settle = 0
        % Phone number of the operator. Used for notification texts.
        %
        % This should be a string with the area code, e.g. '+45 2664 2790'.
        % See also qd.q.Plan.sms
        cellphone = ''
    end
    methods

        function obj = Q(store, setup)
        % Q(store, setup) where store is a qd.data.Store and setup is a qd.Setup.
            if nargin >= 1
                obj.store = store;
            end
            if nargin >= 2
                obj.setup = setup;
            end
        end

        function add_input(obj, name_or_channel)
        % Add a default input for jobs spawned from this Q.
            chan = obj.resolve_channel(name_or_channel);
            obj.inputs = obj.inputs.with(chan);
        end

        function channels = list_inputs(obj)
        % Returns a cell array of default inputs.
        %
        % The returned cell array contains only channel objects.
            channels = obj.inputs.inputs;
        end

        function set_inputs(obj, names_or_channels)
        % Override the current list of default inputs.
        %
        % q.set_inputs(names_or_channels) clears the current set of default
        % inputs, then calls add_input for each element in names_or_channels.
        % names_or_channels should be a cell-array of strings or channel
        % objects.
            obj.inputs.inputs = {};
            for i = 1:length(names_or_channels)
                obj.add_input(names_or_channels{i});
            end
        end

        function chan = resolve_channel(obj, name_or_channel)
        % Lookup a channel by name in the associated setup.
        %
        % Channel objects are directly returned. Strings are forwarded to
        % find_channel in obj.setup to locate a channel with that name.
            chan = name_or_channel;
            if ischar(name_or_channel)
                if isempty(obj.setup)
                    error(['You need to configure a setup for this run before '...
                        'you can add a channel by name.']);
                end
                chan = obj.setup.find_channel(name_or_channel);
            end
        end

        function plan = make_plan(obj)
        % Construct a bare qd.q.Plan from this Q object.
        %
        % Typically a user should not call this function directly, but call
        % functions like 'do' or 'sw' instead.
            plan = qd.q.Plan(obj, obj.inputs);
            plan = plan.input_settle(obj.default_settle);
        end

        function plan = sms(obj, varargin)
        % See also qd.q.Plan.sms
            plan = obj.make_plan().sms(varargin{:});
        end
        function plan = verbose(obj, varargin)
        % See also qd.q.Plan.verbose
            plan = obj.make_plan().verbose(varargin{:});
        end
        function plan = as(obj, varargin)
        % See also qd.q.Plan.as
            plan = obj.make_plan().as(varargin{:});
        end
        function plan = with(obj, varargin)
        % See also qd.q.Plan.with
            plan = obj.make_plan().with(varargin{:});
        end
        function plan = without(obj, varargin)
        % See also qd.q.Plan.without
            plan = obj.make_plan().without(varargin{:});
        end
        function plan = with_only(obj, varargin)
        % See also qd.q.Plan.with_only
            plan = obj.make_plan().with_only(varargin{:});
        end
        function plan = do(obj, varargin)
        % See also qd.q.Plan.do
            plan = obj.make_plan().do(varargin{:});
        end
        function plan = sw(obj, varargin)
        % See also qd.q.Plan.sw
            plan = obj.make_plan().sw(varargin{:});
        end
        function plan = input_settle(obj, varargin)
        % See also qd.q.Plan.input_settle
            plan = obj.make_plan().input_settle(varargin{:});
        end
        function go(obj, varargin)
        % See also qd.q.Plan.go
            obj.make_plan().go(varargin{:});
        end
    end
end