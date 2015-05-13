classdef Triton < qd.classes.Instrument
    properties(Access=private)
        temp_chans
        control_channel
    end
    properties
        triton % an qd.protocol.OxfordSCPI instance connected to the the triton.
        triton_daemon % A daemon.Client connected to the triton daemon
        heater_range_auto = false;
        heater_range_temp = [0.03,0.1,0.3,1,12,40];
        heater_range_curr = [0.316,1,3.16,10,31.6,100];
    end

    methods
        function obj = Triton()
            obj.triton_daemon = daemon.Client(qd.daemons.Triton.bind_address);
            obj.triton = qd.protocols.OxfordSCPI(obj.triton_daemon.remote.talk);
            keysVals = obj.triton_daemon.remote.list_channels();
            obj.temp_chans = containers.Map(keysVals.keys, keysVals.values);
            obj.get_control_channel();
        end

        function r = describe(obj, register)
            obj.get_control_channel();
            r = obj.describe@qd.classes.Instrument(register);
            r.temperatures = struct();
            for chan = obj.temp_chans.keys();
                r.temperatures.(chan{1}) = obj.getc(chan{1});
            end
            r.temperatures.cooling_water = obj.getc('cooling_water');
            r.control = struct();
            r.control.channel = obj.get_control_channel();
            r.control.tset = obj.getc('TSET');
            r.control.rate = obj.getc('RATE');
            r.control.range = obj.getc('RANGE');
            r.control.mode = obj.get_pid_mode();
            r.control.ramp = obj.get_ramp_enabled();
        end

        function chans = channels(obj)
            chans = obj.temp_chans.keys();
            chans{end + 1} = 'cooling_water';
            chans{end + 1} = 'TSET';
            chans{end + 1} = 'RATE';
            chans{end + 1} = 'RANGE';
        end

        function autorange(obj,value)
            obj.heater_range_auto = value;
        end

        function uid = get_control_channel(obj, force_get)
            % uid = triton.get_control_channel([force_get])
            %
            % Get the uid of the control channel. If force_get is false (the
            % default), then a cached value may be returned.
            if nargin < 2
                force_get = false;
            end
            if ~force_get && ~isempty(obj.control_channel)
                uid = obj.control_channel;
                return
            end
            uid = '';
            for i = obj.temp_chans.values
                tempval = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:TSET', i{1}));
                if ~strcmp(tempval,'NOT_FOUND')
                    uid = i{1};
                    obj.control_channel = uid;
                end
            end
        end

        function set_control_channel(obj, channel)
            if isstr(value)
                % Expects 'T5'
                obj.control_channel = value;
            elseif isfloat(value)
                % Expects just a number
                obj.control_channel = sprintf('T%d',value);
            end
            obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:HTR', obj.control_channel), 'H1', '%s');
        end

        function value = get_pid_mode(obj)
            s = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:MODE', obj.get_control_channel()), '%s');
            value = from_on_off(s);
        end

        function set_pid_mode(obj, value)
            s = to_on_off(value);
            obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:MODE', obj.get_control_channel()), s, '%s');
        end

        function value = get_ramp_enabled(obj)
            s = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:RAMP:ENAB', obj.get_control_channel()), '%s');
            value = from_on_off(s);
        end

        function set_ramp_enabled(obj, value)
            s = to_on_off(value);
            obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:RAMP:ENAB', obj.get_control_channel()), s, '%s');
        end

        function val = getc(obj, chan)
            if obj.temp_chans.isKey(chan)
                uid = obj.temp_chans(chan);
                val = obj.triton.read(sprintf('DEV:%s:TEMP:SIG:TEMP', uid), '%fK');
            else
                switch chan
                    case 'cooling_water'
                        val = obj.triton.read('DEV:C1:PTC:SIG:WIT', '%fC');
                    case 'TSET'
                        val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:TSET', obj.get_control_channel()),'%fK');
                    case 'RATE'
                        val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:RAMP:RATE', obj.get_control_channel()), '%f');
                    case 'RANGE'
                        val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:RANGE', obj.get_control_channel()), '%f');
                    otherwise
                        error('No such channel (%s).', chan);
                end
            end
        end

        function setc(obj, chan, value)
            switch chan
                case 'TSET'
                    if obj.heater_range_auto
                        index = min(find(obj.heater_range_temp>=value));
                        current_range = obj.heater_range_curr(index);
                        obj.setc('RANGE',current_range);
                    end
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:TSET', obj.get_control_channel()), value, '%f');
                case 'RATE'
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:RAMP:RATE', obj.get_control_channel()), value, '%f');
                case 'RANGE'
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:RANGE', obj.get_control_channel()), value, '%f');
                otherwise
                    error('No such channel (%s).', chan);
            end
        end
    end
end

function s = to_on_off(v)
    if v
        s = 'ON';
    else
        s = 'OFF';
    end
end

function v = from_on_off(s)
    if strcmp(s, 'ON')
        v = true;
    else
        qd.util.assert(strcmp(s, 'OFF'));
        v = false;
    end
end

