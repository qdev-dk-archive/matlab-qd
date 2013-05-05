classdef TritonServer < handle
    properties(Constant)
        % The address the triton proxy server will listen on.
        bind_address = 'tcp://127.0.0.1:9736/'
    end
    
    properties
        address = ''
        password = ''
    end
    
    properties(Access=private)
        triton
    end
    
    methods
        function connect(obj)
            if ~isempty(obj.triton)
                % already connected.
                return
            end
            obj.triton = tcpip(obj.address, 33576);
            set(obj.triton, 'InputBufferSize', 10000);
            fopen(obj.triton);
            obj.get_access();
        end

        function server = make_server(obj)
            server = daemon.Daemon(obj.bind_address);
            server.expose(obj, 'talk');
        end
        
        function delete(obj)
            if ~isempty(obj.triton)
                fclose(obj.triton);
            end
        end
    end
    
    methods(Access=private)
        
        function rep = talk(obj, req)
        % triton.talk(req)
        %
        %   Send a request to the triton, returns the reply.
        %   Do not include trailing newline in request.
            rep = query(obj.triton, req, '%s\n', '%s\n');
        end

        function get_access(obj)
            rep = obj.talk(['SET:SYS:USER:NORM:' obj.password]);
            qd.util.assert(strcmp(rep, ...
                ['STAT:SET:SYS:USER:NORM:' obj.password ':VALID'])));
        end
    end
end
