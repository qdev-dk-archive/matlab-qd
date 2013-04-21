classdef DecaDAC < handle
    properties(Access=private)
        com
    end
    methods

        function obj = DecaDAC(port)
            obj.com = serial(port, ...
                'BaudRate', 9600, ...
                'Parity',   'none', ...
                'DataBits', 8, ...
                'StopBits', 1);
            fopen(obj.com);
        end

        function delete(obj)
            fclose(obj.com);
        end

        function r = channels(obj)
            r = qd.util.map(@(n)['CH' num2str(n)], 0:19)
        end

        function chan = channel(obj, name)
            n = qd.util.match(name, 'CH%d');
            if isempty(n)
                error('No such channel.');
            end
            chan = qd.ins.DecaDACChannel(obj, n);
        end

        function rep = query(obj, req)
            rep = query(obj.com, req);
        end
    end
end