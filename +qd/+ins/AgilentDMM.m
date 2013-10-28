classdef AgilentDMM < qd.classes.ComInstrument
    properties
        current_future;
    end
    methods

        function  obj = AgilentDMM(com)
            obj@qd.classes.ComInstrument(com);
        end
        
        function r = model(obj)
            r = 'Agilent';
            idn = obj.query('*IDN?');
            for m = {'34401A', '34410A', '34411A'}
                if strfind(idn, m{1}) ~= -1
                    r = ['Agilent' m{1}];
                end
            end
        end

        function r = channels(obj)
            r = {'in'};
        end

        function force_current_future(obj)
            if ~isempty(obj.current_future)
                obj.current_future.force();
                obj.current_future = [];
            end
        end

        function future = getc_async(obj, channel)
            if ~strcmp(channel, 'in')
                error('No such channel.')
            end
            obj.force_current_future();
            obj.send('INIT');
            function val = exec()
                val = obj.querym('FETCH?', '%f');
            end
            future = qd.classes.GetFuture(@exec);
            obj.current_future = future;
        end
        
        function set_NPLC(obj, nplc)
            obj.send(['VOLT:NPLCycles ', num2str(nplc)]);
        end
    end
end