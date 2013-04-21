classdef SRLockIn < qd.classes.Instrument
    properties(Access=private)
        com
    end
    methods
        function obj = SRLockIn(vendor, board, address)
            obj.com = gpib(vendor, board, address);
            fopen(obj.com);
        end

        function rep = query(obj, req)
            rep = query(obj.com, req);
        end

        function delete(obj)
            fclose(obj.com);
        end

        function r = channels(obj)
            r = {'X' 'Y' 'R' 'theta'};
        end

        function chan = channel(obj, name)
            num = find(strcmp(obj.channels, name));
            if isempty(num)
                error(sprintf('Channel not found (%s)', name));
            end
            chan = qd.ins.SRLockInChannel(obj, num);
        end
    end
end