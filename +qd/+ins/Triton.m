classdef Triton < qd.classes.Instrument
    properties(Access=private)
        temp_chans
    end
    properties
        triton % an qd.protocol.OxfordSCPI instance connected to the the triton.
        control_channel
        heater_range_auto = false;
        heater_range_temp = [0.03,0.1,0.3,1,12,40];
        heater_range_curr = [0.316,1,3.16,10,31.6,100];
    end


    methods
        function obj = Triton()
            triton_daemon = daemon.Client(qd.daemons.Triton.bind_address);
            obj.triton = qd.protocols.OxfordSCPI(triton_daemon.remote.talk);
            keysVals = triton_daemon.remote.list_channels();
            obj.temp_chans = containers.Map(keysVals.keys, keysVals.values);
            obj.get_control_channel();
        end

        function r = describe(obj, register)
            obj.get_control_channel();
            r = obj.describe@qd.classes.Instrument(register);
            r.temperatures = struct();
            for chan = obj.channels();
                r.temperatures.(chan{1}) = obj.getc(chan{1});
            end
        end

        function chans = channels(obj)
            chans = obj.temp_chans.keys();
            chans{end + 1} = 'MC_cernox';
            chans{end + 1} = 'cooling_water';
            chans{end + 1} = 'TSET';
            chans{end + 1} = 'TSET_STEP'; % Why is this channel here?
            chans{end + 1} = 'RAMP';
            chans{end + 1} = 'RATE';
            chans{end + 1} = 'RANGE';
            chans{end + 1} = 'CCHAN';
        end

        function autorange(obj,value)
            obj.heater_range_auto = value;
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
                        val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:TSET', obj.control_channel),'%fK');
                    case 'TSET_STEP'
                        % why is this one here?
                        val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:TSET', obj.control_channel),'%fK');
                    case 'RAMP'
                        val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:RAMP:ENAB', obj.control_channel), '%s');
                    case 'RATE'
                        val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:RAMP:RATE', obj.control_channel), '%f');
                    case 'RANGE'
                        val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:RANGE', obj.control_channel), '%f');
                    case 'MODE'
                        val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:MODE', obj.control_channel), '%s');
                    case 'CCHAN'
                        val = obj.get_control_channel();
                        val = qd.util.match(val, 'T%d');
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
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:TSET', obj.control_channel), value, '%f');
                case 'RAMP'
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:RAMP:ENAB', obj.control_channel), value, '%s');
                case 'RATE'
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:RAMP:RATE', obj.control_channel), value, '%f');
                case 'RANGE'
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:RANGE', obj.control_channel), value, '%f');
                case 'MODE'
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:MODE', obj.control_channel), value, '%s');
                case 'CCHAN'
                    % Set the temperature control_channel
                    if isstr(value)
                        % Expects 'T5'
                        obj.control_channel = value;
                    elseif isfloat(value)
                        % Expects just a number
                        obj.control_channel = sprintf('T%d',value);
                    end
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:HTR', obj.control_channel), 'H1', '%s');
                otherwise
                    error('No such channel (%s).', chan);
            end
        end

        function pid_mode(obj, value)
            obj.get_control_channel();
            obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:MODE', obj.control_channel), value, '%s');
        end


        function uid = get_control_channel(obj)
            uid = '';
            for i = obj.temp_chans.values
                tempval = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:TSET', i{1}));
                if ~strcmp(tempval,'NOT_FOUND')
                    uid = i{1};
                    obj.control_channel = uid;
                end
            end
        end
    end
end
