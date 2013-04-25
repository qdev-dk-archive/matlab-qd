classdef FileLikeInstrument < qd.classes.Instrument
    properties(Access=protected)
        com
    end
    methods

        function obj = FileLikeInstrument(varargin)
            qd.util.assert(length(varargin) <= 1);
            if ~isempty(varargin)
                obj.com = varargin{1};
                fopen(obj.com);
            end
        end

        function rep = query(obj, req)
            rep = query(obj.com, req);
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