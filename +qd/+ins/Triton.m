classdef Triton < qd.classes.Instrument
    properties
        triton % an qd.protocol.OxfordSCPI instance connected to the the triton.
        ramp_rate
    end

    properties(Access=private)
        temp_chans
    end

    methods

        function obj = Triton()
            triton_daemon = daemon.Client(qd.daemons.Triton.bind_address);
            obj.triton = qd.protocols.OxfordSCPI(triton_daemon.remote.talk);
            keysVals = triton_daemon.remote.list_channels();
            obj.temp_chans = containers.Map(keysVals.keys, keysVals.values);
            obj.ramp_rate = 0.001;
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
            chans{end + 1} = 'cooling_water';
            chans{end + 1} = 'TSET';
            chans{end + 1} = 'RAMP';
            chans{end + 1} = 'RATE';
        end

        function val = getc(obj, chan)
            if strcmp(chan, 'cooling_water')
                val = obj.triton.read('DEV:C1:PTC:SIG:WIT', '%fC');
            elseif obj.temp_chans.isKey(chan)
                uid = obj.temp_chans(chan);
                val = obj.triton.read(sprintf('DEV:%s:TEMP:SIG:TEMP', uid), '%fK');
<<<<<<< HEAD
<<<<<<< HEAD
            elseif strcmp(chan, 'TSET')
                uid = obj.temp_chans('MC');
                val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:TSET', uid), '%fK');
            elseif strcmp(chan, 'RAMP')
                uid = obj.temp_chans('MC');
                val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:RAMP:ENAB', uid), '%s');
            elseif strcmp(chan, 'RATE')
                uid = obj.temp_chans('MC');
                val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:RAMP:RATE', uid), '%f');
=======
=======
>>>>>>> 4c86360c86e334a71cfc40a7efe4c89fed478651
             elseif strcmp(chan, 'TSET')
                for i = obj.temp_chans.values
                    tempval = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:TSET', i{1}));
                    if ~strcmp(tempval,'NOT_FOUND')
                        val = qd.util.match(tempval,'%fK');
                    end
                end
<<<<<<< HEAD
>>>>>>> 4c86360c86e334a71cfc40a7efe4c89fed478651
=======
>>>>>>> 4c86360c86e334a71cfc40a7efe4c89fed478651
            else
                error('No such channel (%s).', chan);
            end
        end

        function setc(obj, chan, value)
            switch chan
                case 'TSET'
                    uid = obj.temp_chans('MC');
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:TSET', uid), value, '%f');
                case 'RAMP'
                    uid = obj.temp_chans('MC');
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:RAMP:ENAB', uid), value, '%s');
                case 'RATE'
                    obj.ramp_rate = value;
                    uid = obj.temp_chans('MC');
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:RAMP:RATE', uid), value, '%f');
                otherwise
                    error('No such channel (%s).', chan);
            end
        end

        function pid_mode(obj, value)
            uid = obj.temp_chans('MC');
            obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:MODE', uid), value, '%s');
        end
    end
end
