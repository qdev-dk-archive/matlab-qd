classdef Triton < qd.classes.Instrument
    properties(Access=private)
        temp_chans
    end
    properties
        triton % an qd.protocol.OxfordSCPI instance connected to the the triton.
        ramp_rate
        control_channel
    end
	methods
        function obj = Triton()
            triton_daemon = daemon.Client(qd.daemons.Triton.bind_address);
            obj.triton = qd.protocols.OxfordSCPI(triton_daemon.remote.talk);
            keysVals = triton_daemon.remote.list_channels();
            obj.temp_chans = containers.Map(keysVals.keys, keysVals.values);
            obj.ramp_rate = 0.001;
            obj.control_channel = obj.get_control_channel();
        end
        
        function r = describe(obj, register)
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
            chans{end + 1} = 'TSET_STEP';
            chans{end + 1} = 'RAMP';
            chans{end + 1} = 'RATE';
            chans{end + 1} = 'RANGE';
        end
        
        function val = getc(obj, chan)
            if strcmp(chan, 'cooling_water')
                val = obj.triton.read('DEV:C1:PTC:SIG:WIT', '%fC');
            elseif obj.temp_chans.isKey(chan)
                uid = obj.temp_chans(chan);
                val = obj.triton.read(sprintf('DEV:%s:TEMP:SIG:TEMP', uid), '%fK');
            elseif strcmp(chan, 'TSET')
                tempval = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:TSET', obj.control_channel));
                val = qd.util.match(tempval,'%fK');
            elseif strcmp(chan, 'TSET_STEP')
                uid = obj.control_channel;
                val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:TSET', uid), '%fK');
            elseif strcmp(chan, 'RAMP')
                uid = obj.control_channel;
                val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:RAMP:ENAB', uid), '%s');
            elseif strcmp(chan, 'RATE')
                uid = obj.control_channel;
                val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:RAMP:RATE', uid), '%f');
            elseif strcmp(chan, 'MC_cernox')
                uid = 'T5';
                val = obj.triton.read(sprintf('DEV:%s:TEMP:SIG:TEMP', uid), '%f');
            elseif strcmp(chan, 'RANGE')
                uid = obj.control_channel;
                val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:RANGE', uid), '%f');
            elseif strcmp(chan, 'MODE')
                uid = obj.control_channel;
                val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:MODE', uid), '%s');
            else
                error('No such channel (%s).', chan);
            end
        end
        
		function setc(obj, chan, value)
            switch chan
                case 'TSET'
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:TSET', obj.control_channel), value, '%f');
                case 'RAMP'
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:RAMP:ENAB', obj.control_channel), value, '%s');
                case 'RATE'
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:RAMP:RATE', obj.control_channel), value, '%f');
                case 'RANGE'
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:RANGE', obj.control_channel), value, '%f');
                case 'MODE'
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:MODE', obj.control_channel), value, '%s');
                otherwise
                    error('No such channel (%s).', chan);
            end
        end
        
        function uid = get_control_channel(obj)
            uid = '';
            for i = obj.temp_chans.values
                tempval = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:TSET', i{1}));
                if ~strcmp(tempval,'NOT_FOUND')
                    uid = i{1};
                end
            end
        end
    end
end   