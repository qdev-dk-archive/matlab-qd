classdef Store < handle
    properties(GetAccess=public)
        loc
    end
    methods
        function obj = Store(loc)
            qd.util.assert(exist(loc, 'file'));
            obj.loc = qd.util.absdir(loc);
        end

        function cd(obj, d)
            d = fullfile(obj.loc, d);
            qd.util.assert(exist(d, 'file'));
            obj.loc = d;
        end

        function directory = new_dir(obj)
            i = 0;
            while true
                directory = fullfile(obj.loc, [datestr(clock(), 29) '#' sprintf('%03d', i)]);
                % TODO, do not fill in holes.
                if ~exist(directory, 'file')
                    break
                end
                i = i + 1;
            end
            mkdir(directory);
        end
    end
end