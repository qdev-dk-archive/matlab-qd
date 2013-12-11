classdef Triton < qd.classes.Instrument
    properties
        triton % an qd.protocol.OxfordSCPI instance connected to the the triton.
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
        end

        function val = getc(obj, chan)
            if strcmp(chan, 'cooling_water')
                val = obj.triton.read('DEV:C1:PTC:SIG:WIT', '%fC');
            elseif obj.temp_chans.isKey(chan)
                uid = obj.temp_chans(chan);
                val = obj.triton.read(sprintf('DEV:%s:TEMP:SIG:TEMP', uid), '%fK');
            elseif strcmp(chan, 'TSET')
                uid = obj.temp_chans('MC');
                val = obj.triton.read(sprintf('DEV:%s:TEMP:LOOP:TSET', uid), '%fK');
            else
                error('No such channel (%s).', chan);
            end
        end
        
        function setc(obj, chan, value)
            switch chan
                case 'TSET'
                    uid = obj.temp_chans('MC');
                    obj.triton.set(sprintf('DEV:%s:TEMP:LOOP:TSET', uid), value, '%f');
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