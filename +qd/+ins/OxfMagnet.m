classdef OxfMagnet < qd.classes.Instrument
% Drivers for vector magnets from Oxford Instr.
%
% This class replaces OxfMagnet3D. It does not have as many features, but it
% implements the async interface for ramping, and thus plays more nicely with
% the rest of matlab-qd.
    properties
        daemon
        futures = struct();

        % When is a ramp considered done.
        %
        % The PSU is very sluggish in when it considers a ramp to be done. In
        % general if the current field value is less than 'sensitivity' away
        % from the desired value, this driver will consider the ramp over
        % regardless of what the PSU claims.
        sensitivity = 1e-4;

        % Outer limits of the magnet.
        %
        % Set as
        %
        %   magnet.limits.x = [-1, 1]
        %   magnet.limits.z = [-3, 3]
        % 
        % where the arrays contain upper and lower bounds in Tesla.
        limits = struct();

        % Include extra details in description.
        %
        % If verbose is true, all available signals will be queried in the
        % description. This takes a few seconds at the start of every run.
        verbose = false;
    end

    properties(Access=private)
        % This variable caches the axes present on the magnet as reported by
        % the daemon.
        axes = [];
    end

    methods
        function obj = OxfMagnet()
            obj.daemon = daemon.Client(qd.daemons.OxfMagnet3D.bind_address).remote;
            obj.axes = obj.daemon.get_axes();
        end

        function chans = channels(obj)
            chans = num2cell(obj.axes);
        end

        function val = getc(obj, ax)
            qd.util.assert(ismember(ax, obj.axes));
            val = obj.daemon.read(ax, 'SIG:FLD', '%fT');
        end

        function future = setc_async(obj, ax, value)
            qd.util.assert(ismember(ax, obj.axes));
            obj.check_limits(ax, value);
            obj.abort(ax);
            obj.daemon.set(ax, 'SIG:FSET', value, '%.10f');
            if value == 0
                obj.daemon.set(ax, 'ACTN', 'RTOZ');
            else
                obj.daemon.set(ax, 'ACTN', 'RTOS');
            end
            function done = is_done()
                actn = obj.daemon.read(ax, 'ACTN');
                if strcmp(actn, 'HOLD')
                    done = true;
                else
                    done = abs(value - obj.getc(ax)) < obj.sensitivity;
                end
            end
            function abort()
                if ~is_done()
                    warning('%s/%s: A ramp was aborted before it was finished.', obj.name, ax);
                end
                obj.daemon.set(ax, 'ACTN', 'HOLD');
                obj.futures = rmfield(obj.futures, ax);
            end
            function exec()
                while ~is_done()
                    % Since we are not doing anything else at the moment. We
                    % might as well poll every 10 ms like a mad-man.
                    pause(0.01);
                end
                obj.futures = rmfield(obj.futures, ax);
            end
            future = qd.classes.SetFuture(@exec, @abort);
            obj.futures.(ax) = future;
        end

        % Abort any running futures, optionally takes axis to affect.
        function abort(obj, varargin)
            axes = obj.axes;
            p = inputParser();
            p.addOptional('ax', [], @(x)true);
            p.parse(varargin{:});
            axes = p.Results.ax;
            if ~isempty(axes)
                qd.util.assert(ismember(axes, obj.axes));
            else
                axes = obj.axes;
            end
            for ax = axes
                if isfield(obj.futures, ax)
                    obj.futures.(ax).abort();
                end
            end
        end

        function set_ramp_rate(obj, ax, rate)
            qd.util.assert(ismember(ax, obj.axes));
            obj.daemon.set(ax, 'SIG:RFST', rate, '%.10f');
        end

        function all_axes_to_hold(obj)
            for ax = obj.axes
                obj.abort(ax);
                obj.daemon.set(ax, 'ACTN', 'HOLD');
            end
        end

        function zero_all(obj,varargin)
            for ax = obj.axes
                future{end + 1} = obj.setc_async(ax, 0);
            end
            for i = 1:length(futures)
                futures{i}.exec();
            end
        end

        function switch_heater(obj, ax, turn_on)
            qd.util.assert(ismember(ax, obj.axes));
            obj.abort(ax);
            sw = 'OFF';
            if turn_on
                sw = 'ON';
            end
            obj.daemon.set(ax, 'SIG:SWHT', sw);
        end

        function switch_all_heaters(obj, turn_on)
            for ax = obj.axes
                obj.switch_heater(ax, turn_on);
            end
        end

        % Directly execute a set to the magnet. Bypassing the overheating
        % protection. Use this if the magnet is overheating and you need to
        % carry out emergency stuff. For example
        %
        %   magnet.direct_set('DEV:GRPZ:PSU:SIG:RCST', 13.42, '%.16f');
        %
        % Note, this function just calls obj.daemon.force_set_base.
        function direct_set(obj, prop, value, varargin)
            obj.daemon.force_set_base(prop, value, varargin{:});
        end

        % Directly execute a read to the magnet.
        %
        %   curr = magnet.direct_read('DEV:GRPZ:PSU:SIG:RCST', '%f');
        %
        % Note, this function just calls obj.daemon.read_base.
        function resp = direct_read(obj, prop, varargin)
            resp = obj.daemon.read_base(prop, varargin{:});
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Instrument(register);
            for ax = obj.axes()
                r.field.(ax) = obj.getc(ax);
                if obj.verbose
                    r.signals.(ax) = struct;
                    for sig = {'VOLT', 'CURR', 'RCUR', 'FLD', ...
                        'RFLD', 'PCUR', 'PFLD', 'CSET', ...
                        'FSET', 'RCST', 'RFST', 'SWHT'}
                        r.signals.(ax).(sig{1}) = obj.daemon.read(ax, ['SIG:' sig{1}]);
                    end
                    r.action.(ax) = obj.daemon.read(ax, 'ACTN');
                end
            end
            r.sensitivity = obj.sensitivity;
        end
    end

    methods(Access=private)
        function check_limits(obj, ax, value)
            if isfield(obj.limits, ax)
                limits = obj.limit.(ax);
                qd.util.assert(value > limits(1) && value < limits(2));
            end
        end
    end

end