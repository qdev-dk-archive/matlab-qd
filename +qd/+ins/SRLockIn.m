classdef SRLockIn < qd.classes.FileLikeInstrument
    methods
        function obj = SRLockIn(vendor, board, address)
            obj.com = gpib(vendor, board, address);
            fopen(obj.com); % will be closed on delete by FileLikeInstrument.
        end

        function r = model(obj)
            r = 'SR830';
        end

        function r = channels(obj)
            r = {'X' 'Y' 'R' 'theta' 'freq'};
        end

        function val = getc(obj, channel)
            switch channel
                case 'X'
                    val = obj.querym('OUTP?1', '%f');
                case 'Y'
                    val = obj.querym('OUTP?2', '%f');
                case 'R'
                    val = obj.querym('OUTP?3', '%f');
                case 'theta'
                    val = obj.querym('OUTP?4', '%f');
                case 'freq'
                    val = obj.querym('FREQ?', '%f');
                otherwise
                    error('Not supported.')
            end
        end

        function setc(obj, channel, value)
            switch channel
            case 'freq'
                obj.sendf('FREQ %.6f', value);
            otherwise
                error('Not supported');
            end
        end
    end
end