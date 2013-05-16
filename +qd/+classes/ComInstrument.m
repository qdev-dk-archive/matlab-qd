classdef ComInstrument < qd.classes.Instrument
% A base instrument for instruments piggy-backing of a matlab instrument (the
% ones supporting fwrite/fread and friends).
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
        % Send command and read the response.
            rep = query(obj.com, req, '%s\n', '%s\n');
        end

        function rep = queryf(obj, req, varargin)
        % Send command and read the response. With a format string for the
        % command.
            rep = obj.query(sprintf(req, varargin{:}));
        end

        function rep = querym(obj, req, varargin)
        % Send command with a format string and read the response. Then check
        % if the repsonse matches a format string and parse it. For example:
        %
        % field = ins.querym('get_field: %s', axis, '%fT')
        %
        % would send the command 'get_field: x' if axis is 'x', and parse a
        % return value like '3.1T'.
        %
        % This function raises an error if the response does not match the
        % format string supplied at the end.
            rep = qd.util.match(obj.queryf(req, varargin{1:end-1}), varargin{end});
        end

        function send(obj, req)
        % Send command expecting no response.
            fwrite(obj.com, req);
        end

        function sendf(obj, req, varargin)
        % Send command expecting no response. With a format string.
            fprintf(obj.com, req, varargin{:});
        end

        function delete(obj)
            if ~isempty(obj.com)
                fclose(obj.com);
            end
        end
    end
end