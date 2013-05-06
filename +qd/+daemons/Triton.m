classdef Triton < handle
    properties(Constant)
        % The address the triton proxy server will listen on.
        bind_address = 'tcp://127.0.0.1:9736/'
    end
    
    properties
        address = ''
        password = ''
        channels
        server
    end
    
    properties(Access=private)
        triton
        scpi
    end
    
    methods

        function obj = Triton()
            obj.server = daemon.Daemon(obj.bind_address);
            obj.server.expose(obj, 'talk');
            obj.server.expose(obj, 'list_channels');
            obj.server.daemon_name = 'triton-daemon';
            obj.channels = containers.Map();
        end
            
        function connect(obj)
            if ~isempty(obj.triton)
                % already connected.
                return
            end
            obj.triton = tcpip(obj.address, 33576);
            set(obj.triton, 'InputBufferSize', 10000);
            fopen(obj.triton);
            obj.scpi = qd.protocols.OxfordSCPI(@obj.talk);
            obj.scpi.set('SYS:USER:NORM', obj.password);
            for chan = {'COOL', 'STIL', 'MC', 'PT1', 'PT2', 'SORB'}
                if obj.channels.isKey(chan{1})
                    % This has been overwritten by the user.
                    continue
                end
                uid = obj.scpi.read(['SYS:DR:CHAN:' chan{1}]);
                if strcmp(uid, 'INVALID') || strcmp(uid, 'NONE')
                    continue
                end
                obj.channels(chan{1}) = uid;
            end
        end

        function r = list_channels(obj)
            r = struct();
            r.keys = obj.channels.keys();
            r.values = obj.channels.values();
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
end
