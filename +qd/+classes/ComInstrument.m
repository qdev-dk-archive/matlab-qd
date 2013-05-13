classdef ComInstrument < qd.classes.Instrument
    properties
        com
    end
    methods

        function obj = ComInstrument(varargin)
            p = inputParser();
            p.addOptional('com', []);
            p.parse(varargin{:});
            obj.com = p.Results.com;
            if ~isempty(obj.com)
                fopen(obj.com);
            end
        end

        function rep = query(obj, req)
            rep = query(obj.com, req, '%s\n', '%s\n');
        end

        function rep = queryf(obj, req, varargin)
            rep = obj.query(sprintf(req, varargin{:}));
        end

        function rep = querym(obj, req, varargin)
            rep = qd.util.match(obj.queryf(req, varargin{1:end-1}), varargin{end});
        end

        function send(obj, req)
            fwrite(obj.com, req);
        end

        function sendf(obj, req, varargin)
            fprintf(obj.com, req, varargin{:});
        end

        function delete(obj)
            if ~isempty(obj.com)
                fclose(obj.com);
            end
        end
    end
end