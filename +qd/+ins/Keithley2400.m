classdef Keithley2400 < qd.classes.FileLikeInstrument
    methods

        function r = model(obj)
            r = 'Keithley 2400 SourceMeter';
        end

        function r = channels(obj)
            r = {'current', 'voltage'};
        end
        
    end
end