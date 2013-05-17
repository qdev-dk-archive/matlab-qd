classdef AgilentDMM < qd.classes.ComInstrument
    properties
        read_queued = false;
    end
    methods

        function  obj = AgilentDMM(com)
            obj@qd.classes.ComInstrument(com);
        end
        
        function r = model(obj)
            r = 'Agilent';
            idn = obj.query('*IDN?');
            for m = {'34401A', '34410A'}
                if strfind(idn, m{1}) ~= -1
                    r = ['Agilent' m{1}];
                end
            end
        end

        function r = channels(obj)
            r = {'in'};
        end

        function future = getc_async(obj, channel)
            if ~strcmp(channel, 'in')
                error('No such channel.')
            end
            if obj.read_queued
                error('read_queued is true. An async get has been requested but not executed.');
            end
            obj.send('INIT')
            obj.read_queued = true;
            function val = exec()
                val = obj.querym('FETCH?', '%f');
                obj.read_queued = false;
            end
            future = qd.classes.GetFuture(@exec);
        end
    end
end