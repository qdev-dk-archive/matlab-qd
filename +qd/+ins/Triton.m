classdef Triton < qdev.classes.Intrument
    properties(Access=private)
        triton
        temp_chans
    end

    methods
        
        function obj = Triton()
            obj.triton_daemon = daemon.Client(qd.daemons.Triton.bind_address);
            obj.triton = qd.protocols.OxfordSCPI(obj.triton_daemon.remote.talk);
            obj.temp_chans = containers.Map();
            obj.temp_chans('PT2') = 1;
        end

        function chans = channels(obj)
            chans = obj.temp_chans.keys();
            chans{end + 1} = 'cooling_water';
        end

        function val = getc(obj, chan)
            if strcmp(chan, 'cooling_water')
                val = obj.triton.read('DEV:C1:PTC:SIG:WIT', '%fC');
            elseif obj.temp_chans.isKey(chan)
                n = obj.temp_chans(chan);
                val = obj.triton.read(sprintf('DEV:T%d:TEMP:SIG:TEMP', n), '%fK');
            else
                error('No such channel (%s).', chan);
            end
        end

    end
end