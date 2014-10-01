classdef fastInstrument < qd.classes.ComInstrument
% this class manages multiple DecaDAC2 objects and
% allows to add, remove them and allows to call one
% certain channel without caring which DecaDAC it
% actually is
    
    methods
        function r = model(obj)
            r = 'I am a fast instrument!';
        end
        
        function val = getc(obj, ch)
            if strcmp(ch,'CH')
                val = 1;
            else
                display 'Invalid channel number'
                val = NaN;
            end
        end
        
        function r = channels(obj)
            r = {'CH'};
        end
        
        function future = setc_async(obj, ch, val)
            if strcmp(ch,'CH')
                val = 1;
                future = qd.classes.SetFuture.do_nothing_future;
            else
                display 'Invalid channel number'
                val = NaN;
            end
        end
    end
end