classdef Store < handle
    properties(GetAccess=public)
        loc
        name
        directory
        timestamp
        datestamp
        datainfo
        latestDataID = 0;
    end
    methods
        function obj = Store(loc, name)
            qd.util.assert(exist(loc, 'file'));
            obj.loc = qd.util.absdir(loc);
            if nargin == 2
                obj.name = name;
            end
            obj.directory = obj.loc;
            
            % Get data from current directory
            obj.dataInCurrentDirectory()
        end

        function cd(obj, d)
            d = fullfile(obj.loc, d);
            if ~exist(d, 'file')
                mkdir(d);
            end
            obj.loc = qd.util.absdir(d);
            
            obj.dataInCurrentDirectory()
        end
        
        function dataInCurrentDirectory(obj)
            % Fill in information on existing data objects:
            files = dir(obj.loc);
            
            % Save directory
            for i = 1:length(files)
                % Check if it is in fact a data folder
                if ~isempty(regexp(files(i).name,'\w*#\w*','ONCE'))
                    num = strsplit(files(i).name,'#');
                    obj.datainfo.(['x' num{2}]) = fullfile(obj.loc,files(i).name);
                    
                    % Store the latest data ID
                    num = str2double(num{2});
                    if num > obj.latestDataID
                        obj.latestDataID = num;
                    end
                    
                end
            end
        end

        function data = getData(obj,varargin)
            % Set default data ID
            dataNum = obj.latestDataID;
            
            % Check if varargin has been set
            if ~isempty(varargin)
                dataNum = varargin{1};
            end
            
            % Load data from directory.
            data = qd.data.load_table(obj.datainfo.(['x' sprintf('%03d',dataNum)]), 'data');
        end
        
        function directory = new_dir(obj)
            if isempty(obj.name)
                % Time and counter-style data directories
                
                dataID = obj.latestDataID + 1;
                directory = fullfile(obj.loc, [datestr(clock(), 29) '#' sprintf('%03d', dataID)]);
                
                                
                % Save directory of new data
                obj.datainfo.(['x' sprintf('%03d', dataID)]) = directory;
                
                % Make directory
                if exist(directory,'dir')
                    return;
                end
                mkdir(directory);
                obj.latestDataID = obj.latestDataID + 1;

            else
                % Date and time-style data directories
                datestamp = strcat(datestr(now,10),strrep(datestr(now, 6), '/',''));
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
