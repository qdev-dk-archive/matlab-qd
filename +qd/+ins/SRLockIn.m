classdef SRLockIn < qd.classes.FileLikeInstrument
    methods
        function obj = SRLockIn(vendor, board, address)
            obj.com = gpib(vendor, board, address);
            fopen(obj.com); % will be closed on delete by FileLikeInstrument.
        end

        function r = model(obj)
            r = 'SR530';
        end

        function r = channels(obj)
            r = {'X' 'Y' 'R' 'theta'};
        end

        function val = getc(obj, channel)
            qd.util.assert(obj.has_channel(channel));

            num = find(strcmp(obj.channels(), name));
            val = obj.querym('OUTP?%d', obj.num, '%f');
        end
    end
end