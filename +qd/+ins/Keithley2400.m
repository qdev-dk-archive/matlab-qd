classdef Keithley2400 < qd.classes.FileLikeInstrument
    methods
        function obj = Keithley2400(vendor, board, address)
            obj.com = gpib(vendor, board, address);
            fopen(obj.com); % will be closed on delete by FileLikeInstrument.
        end

        function r = model(obj)
            r = 'Keithley 2400 SourceMeter';
        end
    end
end