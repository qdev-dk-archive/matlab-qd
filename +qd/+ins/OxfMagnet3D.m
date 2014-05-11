classdef OxfMagnet3D < qd.classes.Instrument
    properties
        magnet
        rate_limit = 0.25;
        ramp_rate = 0.1;
        sweep_rate = 0.1;
        current_future;
        sensitivity = 1e-4;
        axes_limits = [1,1,6];
    end

    properties(Access=private)
        show_waitbar_handle = true;
        rate_has_changed = false;
        axes_cache = [];
    end

    methods
        function obj = OxfMagnet3D()
            obj.magnet = daemon.Client(qd.daemons.OxfMagnet3D.bind_address);
            obj.current_future = [];
        end

        function axes = axes(obj)
            % Not all magnets have 3 dimensions. The daemon knows.
            if isempty(obj.axes_cache)
                obj.axes_cache = obj.magnet.remote.get_axes();
            end
            axes = obj.axes_cache;
        end

        function chans = channels(obj)
            chans = num2cell(obj.axes());
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Instrument(register);
            r.field = struct;
            for ax = obj.axes()
                r.field.(ax) = obj.getc(ax);
            end
            r.sensitivity = obj.sensitivity;
            r.rate_limit  = obj.rate_limit;
            r.ramp_rate   = obj.ramp_rate;
            r.sweep_rate  = obj.sweep_rate;
            r.axes_limits = obj.axes_limits;
        end

        function val = getc(obj, ax)
            qd.util.assert(all(ismember(ax, obj.axes())));
            val = [];
            % Get all axes
            for i = 1:length(ax)
                val(i) = obj.magnet.remote.read(ax(i), 'SIG:FLD', '%fT');
            end
        end

        function unclamp_all(obj)
            for ax = obj.axes()
                obj.magnet.remote.set(ax, 'ACTN', 'HOLD');
            end
        end

        function zero_all(obj,varargin)
            future = obj.setc_async(obj.axes(),0,varargin{:});
            future.exec();
        end

        function switch_heater(obj, ax, turn_on)
            qd.util.assert(all(ismember(ax, obj.axes())));
            sw = 'OFF';
            if turn_on
                sw = 'ON';
            end
            for i = ax
                obj.magnet.remote.set(i, 'SIG:SWHT', sw);
            end
        end

        function switch_all_heaters(obj, turn_on)
            obj.switch_heater(obj.axes(), turn_on)
        end
        function state = show_waitbar(obj,varargin)
            obj.show_waitbar_handle = varargin{1};
            state = obj.show_waitbar_handle;
        end
        function set_sensitivity(obj, value)
            obj.sensitivity = value;
        end
        function setc(obj, ax, value, varargin)
            % The setc is necessary to allow use of varargin, could this be added to the channel class?
            % If I try it breaks instruments not accepting varargin.
            future = obj.setc_async( ax, value, varargin{:} );
            future.exec();
        end
        function future = setc_async(obj, ax, value, varargin)
        % The setc_async command takes takes all axes combinations; 'xy', 'xz', 'zx' etc...
        % Optionally set the rates for axes, examples:
        % setc_async('xz',[0.7,1.8],'rate',[0.1,0.15])
        % setc_async('xzy',0.5,'rate',[0.1])
            p = inputParser();
            p.addOptional('rate', obj.ramp_rate);
            p.parse(varargin{:});
            sweep_rate = p.Results.rate;
            %
            % Verifications
            qd.util.assert(all(ismember(ax, obj.axes())));
            qd.util.assert(length(ax) == length(value) || length(ax) == 1);
            qd.util.assert(length(sweep_rate) == length(ax) || length(sweep_rate) == 1);

            if length(sweep_rate) == 1 && length(ax) ~= 1
                sweep_rate(1:length(ax)) = sweep_rate;
            end
            if length(value) == 1 && length(ax) ~= 1
                value(1:length(ax)) = value;
            end

            % set setpoints first (magnet does not run away yet)
            for i = 1:length(ax)
                % Only set setpoint if necessary (communication time saver)
                if value(i) ~= 0.0
                    % Set setpoint
                    obj.magnet.remote.set(ax(i), 'SIG:FSET', value(i), '%.10f');
                    % Set rate
                end
                if obj.ramp_rate ~= sweep_rate(i) || obj.rate_has_changed == true
                    % This is to recognize a change in sweep rate after a hard break
                    obj.send_ramp_rate(ax(i),sweep_rate(i));
                    obj.rate_has_changed = true;
                end
            end
            % ramp channels. Now the channels sweep, the execution timestamp is as close as possible for the axes
            for i = 1:length(ax)
                if value(i) ~= 0.0
                    obj.magnet.remote.set(ax(i), 'ACTN', 'RTOS');
                else
                    obj.magnet.remote.set(ax(i), 'ACTN', 'RTOZ');
                end
            end

            function abort()
                % Abort future function
                for i = 1:length(ax)
                    % Stop ramping axes
                    obj.magnet.remote.set(ax(i), 'ACTN', 'HOLD');
                end
                for i = 1:length(ax)
                    % Set rates back, if changed
                    if sweep_rate(i) ~= obj.ramp_rate
                        obj.send_ramp_rate(ax(i),obj.ramp_rate);
                    end
                end
                obj.rate_has_changed = false;
                qd.util.multiWaitbar( 'CloseAll' );
                % Get current field (this is probably not the real field as it might still change slightly)
                axes = obj.axes();
                fld = obj.getc(axes);
                fprintf('Sweep cancelled at\n');
                for i = 1:length(axes)
                    fprintf('            B%s ~ %f T\n',axes(i), fld(i));
                end
                fprintf('\n');
                obj.current_future = [];
            end


            function exec()
                % Execute future function
                delay = 0.1;
                fld = obj.getc(ax);
                deltaB = abs(value-fld);
                actn = num2cell(ax);
                if obj.show_waitbar_handle == false
                    % Do not show waitbar
                    %
                    % We start by waiting 100 ms. Each time we read the state and we are still
                    % ramping, we wait 25% longer. delay = 2s is max. When we get close to the
                    % aimed value we reduce sweep time again
                    while any(deltaB) > obj.sensitivity
                        pause(delay);
                        for i = 1:length(ax)
                            if strcmp(actn(i),'HOLD')
                                continue
                            end
                            actn{i} = obj.magnet.remote.read(ax(i), 'ACTN');
                        end
                        if all(strcmp(actn, 'HOLD'))
                            % sweep finished
                            break
                        end

                        % this smart thing only gets the field from non hold axes :)
                        mask = ~strcmp(actn, 'HOLD');
                        fld(:,mask) = obj.getc(ax(:,mask));

                        deltaB = abs(value-fld);
                        % Reduce waiting time when close to finish.
                        tleft = 60*deltaB./sweep_rate;
                        if any(tleft<=delay)
                            delay = max(tleft);
                        else
                            delay = min(delay * 1.25, 2.0);
                        end
                    end
                else
                    % Show waitbar
                    %
                    % We start by waiting 100 ms. Each time we read the state and we are still
                    % ramping, we wait 25% longer. delay = 2s is max.
                    qd.util.multiWaitbar( 'CloseAll' );
                    breakme = false;
                    for i = 1:length(ax)
                        [~,figh] = qd.util.multiWaitbar(ax(i),0, 'Color', [1.0 0.4 0.0] );
                    end
                    const_deltaB = deltaB; % this value remains constant
                    while any(deltaB) > obj.sensitivity
                        pause(delay);

                        % this smart thing only gets the field from non hold axes :)
                        mask = ~strcmp(actn, 'HOLD');
                        fld(:,mask) = obj.getc(ax(:,mask));

                        deltaB = abs(value-fld);
                        for i = 1:length(ax)
                            if strcmp(actn(i), 'HOLD')
                                continue
                            end
                            if strcmp(figh.Visible,'off')
                                % Progress window has been closed (is not Visible)
                                abort();
                                % Also break outer loop
                                breakme = true;
                                break
                            end
                            actn{i} = obj.magnet.remote.read(ax(i), 'ACTN');
                            % calculate time to finish sweep
                            tleft(i) = 60*deltaB(i)/(sweep_rate(i));
                            if strcmp(actn(i), 'HOLD')
                                qd.util.multiWaitbar(ax(i),1.0,'Color', [0.2 0.9 0.3] ); % Make finished axes green
                            else
                                qd.util.multiWaitbar(ax(i),abs(deltaB(i)-const_deltaB(i))/const_deltaB(i));
                            end
                        end

                        if all(strcmp(actn, 'HOLD')) || breakme
                            % sweep finished or canceled
                            break
                        end
                        if all(tleft<=delay)
                            delay = max(tleft);
                        else
                            delay = min(delay * 1.25, 2.0);
                        end
                    end
                    qd.util.multiWaitbar( 'CloseAll' );
                end
                % Set rates back
                for i = 1:length(ax)
                    if sweep_rate(i) ~= obj.ramp_rate
                        obj.send_ramp_rate(ax(i),obj.ramp_rate);
                    end
                end
                obj.rate_has_changed = false;
                obj.current_future = [];
            end
            future = qd.classes.SetFuture(@exec,@abort);
            obj.current_future = future;
        end

        function future = sweep_async(obj, ax, value, varargin)
            % The aim of this function is to sweep along a vector from current position to setpoint linearly
            p = inputParser();
            p.addOptional('rate', obj.sweep_rate);
            p.parse(varargin{:});
            sweep_rate = p.Results.rate;
            % Verifications
            qd.util.assert(all(ismember(ax, obj.axes())));
            qd.util.assert(length(ax) == length(value));
            qd.util.assert(length(sweep_rate) == 1);

            % Check for limits
            [~,pos] = ismember(num2cell(ax),num2cell(obj.axes()));
            setpoint(:,pos) = value;
            if any(abs(setpoint) > obj.axes_limits)
                error('setpoint is out of limits');
            end

            % Get start values!
            field_start = obj.getc(ax);

            % Make the sweep linear by calculating the rate for each individual axis
            % Calculate distances for the individual axes
            field_distance = value - field_start;
            % Calculate distance from Start to End points
            distance = sqrt(sum(field_distance.^2));
            if distance ~= 0.0
                sweeptime = distance/sweep_rate;
                % Calculate individual rates
                rate = abs(field_distance./sweeptime);
                % Make sure that there is a minimum ramp rate available to be able to sweep a minor distance.
                % 0.0001 is the minimum at triton 4, is this generic?
                rate = rate + (rate<0.0001)*0.0001;
            else
                % It is necessary to set the ramp rate, as it might be really low and the field never
                % goes to the zero.
                rate = value*0+sweep_rate;
            end
            future = obj.setc_async(ax,value,'rate',rate,varargin{:});
        end
        function force_current_future(obj)
            if ~isempty(obj.current_future)
                obj.current_future.exec();
                obj.current_future = [];
            end
        end

        function abort_current_future(obj)
            if ~isempty(obj.current_future)
                obj.current_future.abort();
                obj.current_future = [];
            end
        end

        function set_axes_limits(obj, lim)
            obj.axes_limits = lim;
        end

%         function set_sweep_rate(obj, sweep_rate)
%             obj.sweep_rate = sweep_rate;
%         end

        function val = get_ramp_rate( obj, ax )
            val = [];
            qd.util.assert(all(ismember(ax, obj.axes())));
            for i = ax
                val(end+1) = obj.magnet.remote.read(i,'SIG:RFST','%fT/m');
            end
        end

        function set_ramp_rate( obj, ramp_rate, varargin )
        % In T/min. Optionally takes the axis to set the ramp rate for.
        % This is used to set the global ramp_rate variable (and then let the magnet know)
            if ramp_rate > obj.rate_limit
                warning(sprintf('Tried to set ramp_rate larger than limit: %.3fT/min > %.3fT/min, now set to max: %.3fT/min',ramp_rate,obj.rate_limit,obj.rate_limit));
                obj.ramp_rate = obj.rate_limit;
            else
                obj.ramp_rate = ramp_rate;
            end
            p = inputParser();
            p.addOptional('axis', [], @(x)ismember(x, obj.axes()));
            p.parse(varargin{:});
            axis = p.Results.axis;
            for ax = obj.axes()
                if ~isempty(axis) && ax ~= axis
                    continue;
                end
                obj.send_ramp_rate(ax,ramp_rate)
            end
        end
    end

    methods(Access=private)
        function send_ramp_rate(obj, ax, ramp_rate )
        % This function is used to send the ramp rate to the magnet,
        % but does not store it in the global ramp_rate variable
            qd.util.assert(all(ismember(ax, obj.axes())));
            if ramp_rate > obj.rate_limit
                warning(sprintf('Tried to set ramp_rate larger than limit: %.3fT/min > %.3fT/min, now set to max: %.3fT/min',ramp_rate,obj.rate_limit,obj.rate_limit));
                ramp_rate = obj.rate_limit;
            end
            for i = ax
                obj.magnet.remote.set(i, 'SIG:RFST', ramp_rate, '%.10f');
            end
        end
    end
end
