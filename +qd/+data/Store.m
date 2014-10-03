classdef Store < handle
    properties(GetAccess=public)
        loc
        directory
        timestamp
        datestamp
        datainfo
        latestDataID = 0;
    end
    methods
        function obj = Store(loc)
            
            % Check if file location exists
            qd.util.assert(exist(loc, 'dir'));
            
            % Construct absolute path
            obj.loc = qd.util.absdir(loc);
                       
            % Store the location
            obj.directory = obj.loc;
            
            % Get data from current directory
            obj.dataInCurrentDirectory()
        end
        % This is just the constructor function, and this stores the
        % location of the current data acquisition (loc)

        function cd(obj, d)
            % Create pathname to change to
            d = fullfile(obj.loc, d);
            
            % Check if folder exists
            if ~exist(d, 'dir')
                % Create directory if it does not exist
                mkdir(d);
            end
            
            % Update the location to the new directory
            obj.loc = qd.util.absdir(d);
            
            % Check for data in the folder
            obj.dataInCurrentDirectory()
        end
        % A function to change directory. 
        % Updates loc and calls function dataInCurrentDirectory
     

        function dataInCurrentDirectory(obj)
            % Get files in the current folder:
            files = dir(obj.loc);
            
            % Loop over the files
            for i = 1:length(files)
                
                % Check if it is in fact a data folder
                if ~isempty(regexp(files(i).name,'\w*#\w*','ONCE'))
                    
                    % Find the ID number
                    string = strsplit(files(i).name,'#');
                    ID = str2double(string{2});
                    
                    % Store the directory of the data
                    obj.datainfo.(['x' ID]) = fullfile(obj.loc,files(i).name);
                    
                    % Store the latest data ID
                    if ID > obj.latestDataID
                        obj.latestDataID = ID;
                    end
                    
                end
            end
        end
        % A function that scans loc for folders matching the naming pattern
        % (date#dataID) and stores their path in the datainfo property, and
        % the number of the highest dataID in the latestDataID


        function data = getData(obj,varargin)
            % Set default data ID
            dataID = obj.latestDataID;
            
            % Check if varargin has been set
            if ~isempty(varargin)
                dataID = varargin{1};
            end
            
            % Load data from directory.
            data = qd.data.load_table(obj.datainfo.(['x' sprintf('%03d',dataID)]), 'data');
        end
        % A function that retrieves the data from the latestDataID (default)
        % or from an ID specified by varargin
        
        function directory = new_dir(obj)
            % Time and counter-style data directories
            
            % Assing a new dataID
            dataID = obj.latestDataID + 1;
            
            % Create directory name
            directory = fullfile(obj.loc, [datestr(clock(), 29) '#' sprintf('%03d', dataID)]);
            
            % Save directory of new data
            obj.datainfo.(['x' sprintf('%03d', dataID)]) = directory;
            
            % Make directory
            if exist(directory,'dir')
                return;
            end
            mkdir(directory);
            
            % Update latestDataID
            obj.latestDataID = obj.latestDataID + 1;
        end
        % A function to create a new folder for a data measurement. 
        % Updates the latestDataID and datainfo


    end
end
