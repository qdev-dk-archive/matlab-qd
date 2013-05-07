classdef OxfordSCPI < handle
    properties
        link_func
    end
    methods
        function obj = OxfordSCPI(link_func)
        % con = OxfordSCPI(link_func)
        %
        % link_func should be a function handle to a function taking a single 
        % string argument (the request) and returning a string (the reply).
            obj.link_func = link_func;
        end
        
        function value = read(obj, prop, varargin)
            p = inputParser();
            p.addOptional('read_format', '%s', @ischar);
            p.parse(varargin{:});
            read_format = p.Results.read_format;

            rep = obj.link_func(['READ:' prop]);
            parts = qd.util.strsplit(rep, ':');
            
            % check the reply
            qd.util.assert(strcmp(parts{1}, 'STAT'));
            expected = qd.util.strjoin(parts(2:end-1), ':');
            qd.util.assert(strcmp(expected, prop));
            
            value = qd.util.match(parts{end}, read_format);
        end
        
        function set(obj, prop, value, varargin)
            p = inputParser();
            p.addOptional('set_format', '%s', @ischar);
            p.parse(varargin{:});
            set_format = p.Results.set_format;
            req = ['SET:' prop ':' sprintf(set_format, value)];
            rep = obj.link_func(req);
            qd.util.assert(strcmp(rep, ['STAT:' req ':VALID']));
        end
    end
end