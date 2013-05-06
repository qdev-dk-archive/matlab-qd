classdef Triton < qdev.classes.Intrument
    properties(Access=private)
        triton
        temp_chans
    end

    methods
        
        function obj = Triton()
            obj.triton = daemon.Client(qd.daemons.Triton.bind_address);
            obj.triton.heartbeat();
            obj.temp_chans = containers.Map();
            obj.temp_chans('PT2') = 1;
        end
        
        function value = read(obj, prop, varargin)
            p = inputParser();
            p.addOptional('read_format', '%s');
            p.parse(varargin{:});
            read_format = p.Result.read_format;

            rep = obj.triton.remote.talk(['READ:' prop]);
            parts = qd.util.strsplit(rep, ':');
            
            % check the reply
            qd.util.assert(strcmp(parts{1}, 'STAT'));
            expected = strcat(parts{2:end-1}, ':');
            qd.util.assert(strcmp(expected, prop));
            
            value = qd.util.match(parts{end}, read_format);
        end
        
        function set(obj, prop, value)
            qd.util.assert(ischar(value));
            req = ['SET:' prop ':' value];
            rep = obj.triton.remote.talk(req);
            qd.util.assert(strcmp(rep, ['STAT:' req ':VALID']));
        end

        function chans = channels(obj)
            chans = obj.temp_chans.keys();
            chans{end + 1} = 'cooling_water';
        end

        function val = getc(obj, chan)
            if strcmp(chan, 'cooling_water')
                val = obj.read('DEV:C1:PTC:SIG:WIT', '%fC');
            elseif obj.temp_chans.isKey(chan)
                n = obj.temp_chans(chan);
                val = obj.read(sprintf('DEV:T%d:TEMP:SIG:TEMP', n), '%fK');
            else
                error('No such channel (%s).', chan);
            end
        end

    end
end