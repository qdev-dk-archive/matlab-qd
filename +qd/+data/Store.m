classdef Store < handle
    properties(GetAccess=public)
        loc
        name
        directory
        timestamp
        datestamp
    end
    methods
        function obj = Store(loc, name)
            qd.util.assert(exist(loc, 'file'));
            obj.loc = qd.util.absdir(loc);
            if nargin == 2
                obj.name = name;
            end
            obj.directory = obj.loc;
        end

        function cd(obj, d)
            d = fullfile(obj.loc, d);
            if ~exist(d, 'file')
                mkdir(d);
            end
            obj.loc = qd.util.absdir(d);
        end

        function directory = new_dir(obj)
            if isempty(obj.name)
                % Time and counter-style data directories
                i = 1;
                while true
                    directory = fullfile(obj.loc, [datestr(clock(), 29) '#' sprintf('%03d', i)]);
                    % TODO, do not fill in holes.
                    if ~exist(directory, 'file')
                        break
                    end
                    i = i + 1;
                end
                mkdir(directory);
            else
                % Date and time-style data directories
                datestamp = strcat(strrep(datestr(now, 6), '/',''),datestr(now,10));
                timestamp = strrep(datestr(now, 13), ':','');
                directory = strcat(obj.loc, '\', datestamp, '\', timestamp, '_', obj.name);

                if ~exist(strcat(obj.loc, '\', datestamp), 'dir')
                  mkdir(strcat(obj.loc, '\', datestamp));
                end
                mkdir(directory);
                obj.directory = directory;
                obj.datestamp = datestamp;
                obj.timestamp = timestamp;
            end
        end
    end
end
