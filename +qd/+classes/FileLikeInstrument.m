classdef FileLikeInstrument < qd.classes.Instrument
    properties(Access=protected)
        com
    end
    methods

        function rep = query(obj, req)
            rep = query(obj.com, req);
        end

        function rep = queryf(obj, req, varargin)
            rep = obj.query(sprintf(req, varargin{}));
        end

        function rep = querym(obj, req, varargin)
            rep = qd.util.match(obj.queryf(req, varargin{:end-1}), varargin{end});
        end

        function delete(obj)
            if ~isempty(obj.com)
                fclose(obj.com);
            end
        end
    end
end