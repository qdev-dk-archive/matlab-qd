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
            if any(nplc == [0.02,0.2,1,10,100])
                obj.send(['VOLT:NPLCycles ', num2str(nplc)]);
            else
                error('not supported. NPLC = [0.02,0.2,1,10,100]');
            end
        end
        
        function r = get_NPLC(obj)
            r = obj.query('VOLT:NPLCycles?');
        end
        
        function set_display_text(obj,line1,line2)
            model = obj.model();
            if strcmp(model,'Agilent34410A') || strcmp(model,'Agilent34411A');
                obj.send(sprintf('DISP:WIND1:TEXT "%s"',line1));
                obj.send(sprintf('DISP:WIND2:TEXT "%s"',line2));
            else strcmp(model,'Agilent34401A');
                obj.send(sprintf('DISP:TEXT "%s"',line1));
            end
        end
        
        function clear_display_text(obj)
            model = obj.model();
            if strcmp(model,'Agilent34410A') || strcmp(model,'Agilent34411A');
                obj.send('DISP:WIND1:TEXT:CLE')
                obj.send('DISP:WIND1:STAT 1')
                obj.send('DISP:WIND2:TEXT:CLE')
                obj.send('DISP:WIND2:STAT 1')
            else strcmp(model,'Agilent34401A');
                obj.send('DISP:WIND:TEXT:CLE')
                obj.send('DISP:WIND:STAT 1')
            end
        end
        
    end
end