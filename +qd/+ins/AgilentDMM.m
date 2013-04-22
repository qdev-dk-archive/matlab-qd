classdef AgilentDMM < qd.classes.FileLikeInstrument
    methods
        function obj = AgilentDMM(vendor, board, address)
            obj.com = gpib(vendor, board, address);
            fopen(obj.com); % will be closed on delete by FileLikeInstrument.
        end

        function r = model(obj)
            r = 'AgilentA34410';
        end

        function r = channels(obj)
            r = {'in'};
        end

        function val = getc(obj, channel)
            switch channel
                case 'in'
                    val = obj.querym('READ?', '%f');
                otherwise
                    error('Not supported.')
            end
        end
    end
end