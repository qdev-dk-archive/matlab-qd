classdef Triton < handle
    properties(Constant)
        % The address the triton proxy server will listen on.
        bind_address = 'tcp://127.0.0.1:9736/'
    end
    
    properties
        address = ''
        password = ''
        server
    end
    
    properties(Access=private)
        triton
    end
    
    methods

        function obj = Triton()
            obj.server = daemon.Daemon(obj.bind_address);
            obj.server.expose(obj, 'talk');
            obj.server.daemon_name = 'triton-daemon';
        end
            
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

        function run(obj)
            obj.connect();
            obj.server.serve_forever();
        end

        function delete(obj)
            if ~isempty(obj.triton)
                fclose(obj.triton);
            end
        end
        
        function rep = talk(obj, req)
        % triton.talk(req)
        %
        %   Send a request to the triton, returns the reply.
        %   Do not include trailing newline in request.
            rep = query(obj.triton, req, '%s\n', '%s\n');
        end
        
    end
    
    methods(Access=private)

        function get_access(obj)
            oxf = qd.protocols.OxfordSCPI(@obj.talk);
            oxf.set('SYS:USER:NORM', obj.password);
        end
    end
end
