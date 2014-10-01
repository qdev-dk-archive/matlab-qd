classdef EquipmentBrowser < handle
    properties
        q % handle to q object necessary for reading the list of active channels
        
        variableList % list of variables that can be set manually
        variableTable % table of variables
        
        inputList % list of measurable inputs
        inputTable % table of abovementioned inputs
        
        sweepPanel % panel running the 1d and 2d sweeps
        Xpopup % pupup menu for choosing (slowly) sweeped parameter
        Xpopuplabel
        Xminedit % field for introducing lower limit of a sweep
        Xminlabel
        Xmaxedit % field for introducing upper limit of a sweep
        Xmaxlabel
        Xstepedit % field for introducing number of steps along X axis
        Xsteplabel
        Xsetfinishedit % field for introducing value which should be set after the measurement
        Xsetfinishbox
        Xsetfinishlabel
        
        Ypopup % pupup menu for choosing (fastly) sweeped parameter
        Ypopuplabel
        Yminedit % field for introducing lower limit of a sweep
        Yminlabel
        Ymaxedit % field for introducing upper limit of a sweep
        Ymaxlabel
        Ystepedit % field for introducing number of steps along Y axis
        Ysteplabel
        Ysetfinishedit % field for introducing value which should be set after the measurement
        Ysetfinishbox
        Ysetfinishlabel
        
        CustomSuffixedit % field for adding additional suffix to name of the measurement
        CustomSuffixlabel
        
        button1D % button for performing 1D scan
        button2D % button for performing 2D scan
        
        browserFigure % figure for browser
    end
    properties(Dependent)
        activeInputsNames % list of currently active inputs
    end
    
    methods
        function obj = EquipmentBrowser(q)
            % constructor of EquipmentBrowser object
            % Here I create handle to q object which gives me access to the
            % setup, store and inputs
            % Each element of the variableList will contain:
            % 1. name (correcponding to row label in the table),
            % 2.functions for setting and getting values,
            % 3. name of instrument class of instrument corresponding to this variable
            % and for DecaDAC variables
            % 4. functions for setting and getting the offset and divider
            % Each element of the inputList contains... This should be
            % optimized...
            % createBrowserWindow() creates a window
            obj.q = handle(q);
            obj.variableList = {};
            obj.inputList = {};
            obj.createBrowserWindow();
        end
        
        % creates a neat window to display all the variables and input
        % channels
        function createBrowserWindow(obj)
            % create a window
            obj.browserFigure = figure('NumberTitle','off',...
                'Name','Equipment Browser',...
                'MenuBar','none',...
                'Units', 'normalized',...
                'Position',[0.5 0.05 0.4 0.9],...
                'ResizeFcn',@obj.resizeCallback);
            
            % creating table of variables
            cnames = {'Value', 'Min', 'Max', 'Divider', 'Offset','Polarity'};
            cwidth = {'auto' 40 40 50 50 50};
            obj.variableTable = uitable('Parent',obj.browserFigure,...
                'Units', 'normalized',...
                'ColumnName', cnames,...
                'ColumnWidth', cwidth,...
                'ColumnEditable',[true true true true true true],...
                'CellEditCallback',@obj.variableCellEditCallback);
            
            % creating table of inputs
            cnames = {'Active', 'Unit', 'Mutiplier'};
            cwidth = {'auto' 50 60};
            obj.inputTable = uitable('Parent',obj.browserFigure,...
                'Units', 'normalized',...
                'ColumnName', cnames,...
                'ColumnWidth', cwidth,...
                'ColumnEditable',[true true true],...
                'ColumnFormat',{'logical' {'V', 'A', 'G'} 'numeric'},...
                'CellEditCallback',@obj.inputCellEditCallback);
            
            % creating panel for funning measurements
            obj.sweepPanel = uipanel('Parent',obj.browserFigure,...
                'Units', 'normalized');
            % popups for choosing sweeped axes, limits and number of steps
            % X (slower) axis
            obj.Xpopup = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'popupmenu',...
                'Units', 'normalized');
            obj.Xpopuplabel = uicontrol('Parent', obj.sweepPanel,...
                'Style', 'text',...
                'Units', 'normalized',...
                'String', 'X:');
            obj.Xminedit = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'edit',...
                'Units', 'normalized');
            obj.Xminlabel = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'text',...
                'Units', 'normalized',...
                'String', 'Min X:');
            obj.Xmaxedit = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'edit',...
                'Units', 'normalized');
            obj.Xmaxlabel = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'text',...
                'Units', 'normalized',...
                'String', 'Max X:');
            obj.Xstepedit = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'edit',...
                'Units', 'normalized');
            obj.Xsteplabel = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'text',...
                'Units', 'normalized',...
                'String', 'Steps X:');
            obj.Xsetfinishedit = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'edit',...
                'Units', 'normalized');
            obj.Xsetfinishbox = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'checkbox',...
                'Units', 'normalized');
            obj.Xsetfinishlabel = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'text',...
                'Units', 'normalized',...
                'String', 'Set X to:');
            % Y (faster) axis
            obj.Ypopup = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'popupmenu',...
                'Units', 'normalized');
            obj.Ypopuplabel = uicontrol('Parent', obj.sweepPanel,...
                'Style', 'text',...
                'Units', 'normalized',...
                'String', 'Y:');
            obj.Yminedit = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'edit',...
                'Units', 'normalized');
            obj.Yminlabel = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'text',...
                'Units', 'normalized',...
                'String', 'Min Y:');
            obj.Ymaxedit = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'edit',...
                'Units', 'normalized');
            obj.Ymaxlabel = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'text',...
                'Units', 'normalized',...
                'String', 'Max Y:');
            obj.Ystepedit = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'edit',...
                'Units', 'normalized');
            obj.Ysteplabel = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'text',...
                'Units', 'normalized',...
                'String', 'Steps Y:');
            obj.Ysetfinishedit = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'edit',...
                'Units', 'normalized');
            obj.Ysetfinishbox = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'checkbox',...
                'Units', 'normalized');
            obj.Ysetfinishlabel = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'text',...
                'Units', 'normalized',...
                'String', 'Set Y to:');
            
            % windows for adding additional suffix to measurement
            obj.CustomSuffixedit = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'edit',...
                'Units', 'normalized');
            obj.CustomSuffixlabel = uicontrol('Parent',obj.sweepPanel,...
                'Style', 'text',...
                'Units', 'normalized',...
                'String', 'Custom suffix:');
            
            % buttons for running 1D and 2D sweeps
            obj.button1D = uicontrol('Parent', obj.sweepPanel,...
                'Style', 'pushbutton',...
                'Units', 'normalized',...
                'String', 'Do 1D sweep',...
                'Callback', @obj.do1dCallback);
            obj.button2D = uicontrol('Parent', obj.sweepPanel,...
                'Style', 'pushbutton',...
                'Units', 'normalized',...
                'String', 'Do 2D sweep',...
                'Callback', @obj.do2dCallback);
            
            obj.resizeCallback()
        end
        
        % this function is called when the window is resized
        function resizeCallback(obj,varargin)
            figPos = get(obj.browserFigure,'Position');
            set(obj.variableTable,'Position',[0 0 0.6 1]);
            
            set(obj.inputTable,'Position',[0.6 0.6 0.4 0.4]);
            set(obj.sweepPanel,'Position',[0.6 0.4 0.4 0.2]);
            
            set(obj.Xpopup,'Position',[0.15 0.85 0.3 0.1]);
            set(obj.Xpopuplabel,'Position',[0.05 0.82 0.1 0.1]);
            
            set(obj.Xminedit,'Position',[0.21 0.7 0.2 0.1]);
            set(obj.Xminlabel,'Position',[0.05 0.7 0.15 0.1]);
            set(obj.Xmaxedit,'Position',[0.21 0.6 0.2 0.1]);
            set(obj.Xmaxlabel,'Position',[0.05 0.6 0.15 0.1]);
            set(obj.Xstepedit,'Position',[0.21 0.5 0.2 0.1]);
            set(obj.Xsteplabel,'Position',[0.05 0.5 0.15 0.1]);
            set(obj.Xsetfinishedit,'Position',[0.21 0.4 0.2 0.1]);
            set(obj.Xsetfinishbox,'Position',[0.42 0.4 0.05 0.1]);
            set(obj.Xsetfinishlabel,'Position',[0.05 0.4 0.15 0.1]);
            
            set(obj.Ypopup,'Position',[0.65 0.85 0.3 0.1]);
            set(obj.Ypopuplabel,'Position',[0.55 0.82 0.1 0.1]);
            
            set(obj.Yminedit,'Position',[0.71 0.7 0.2 0.1]);
            set(obj.Yminlabel,'Position',[0.55 0.7 0.15 0.1]);
            set(obj.Ymaxedit,'Position',[0.71 0.6 0.2 0.1]);
            set(obj.Ymaxlabel,'Position',[0.55 0.6 0.15 0.1]);
            set(obj.Ystepedit,'Position',[0.71 0.5 0.2 0.1]);
            set(obj.Ysteplabel,'Position',[0.55 0.5 0.15 0.1]);
            set(obj.Ysetfinishedit,'Position',[0.71 0.4 0.2 0.1]);
            set(obj.Ysetfinishbox,'Position',[0.92 0.4 0.05 0.1]);
            set(obj.Ysetfinishlabel,'Position',[0.55 0.4 0.15 0.1]);
            
            set(obj.CustomSuffixedit,'Position',[0.35 0.25 0.55 0.1]);
            set(obj.CustomSuffixlabel,'Position',[0.05 0.25 0.3 0.1]);
            
            set(obj.button1D,'Position',[0.05 0.05 0.4 0.15]);
            set(obj.button2D,'Position',[0.55 0.05 0.4 0.15]);
        end
        
        % function adds variables that corrwespond to all channels that can
        % be set with instrument.setc()
        function addVariable(obj, id, setup)
            chanName = strsplit(id,'/');
            if  strcmp(chanName{2},'ALL')                       % check if user want to load all channels
                instruments = setup.ins();                      % load structure with instruments
                instrument = instruments.(chanName{1});         % pick up the instrument you want
                channels = instrument.channels();               % get names of all channels
                for ch = channels
                    % read value on channel and try to set the same value
                    % if error 'Not supported.' is thrown, do nothing
                    try
                        val = instrument.getc(ch{1});
                        instrument.setc(ch{1},val)
                    catch err
                        if  strcmp(err.identifier,'')
                            continue
                        else
                            rethrow(err)
                        end
                    end
                    obj.addVariable([chanName{1} '/' ch{1}],setup)  % add the variable
                end
            else
                instruments = setup.ins();                      % load structure with instruments
                instrument = instruments.(chanName{1});         % pick up the instrument you want
                
                channel = setup.find_channel(id);               % find a channel you want to add in the setup
                variable = struct();                            % create the struct for storing information about variable
                variable.name = strrep(channel.name, '/', '_'); % set the variable name
                variable.setval = @(val) channel.set(val);      % create a handle to a function setting your variable
                variable.getval = @() channel.get();            %                               getting
                variable.instrument_class = class(instrument);  % set the name of the instrument class this variable corresponds to
                
                % checking if given channel is a DecaDAC channel
                % if yes then create set and get functions for the
                % limits, offset and divider of the DAC channel
                if strcmp(variable.instrument_class, 'qd.ins.multiple_DecaDAC')
                    variable.setlimits  = @(limits) instrument.set_limits(chanName{2},limits);
                    variable.getlimits  = @() instrument.limits.(chanName{2});
                    variable.setdivider = @(divider) instrument.set_divider(chanName{2},divider);
                    variable.getdivider = @() instrument.divider.(chanName{2});
                    variable.setoffset  = @(offset) instrument.set_offset(chanName{2},offset);
                    variable.getoffset  = @() instrument.offset.(chanName{2});
                    variable.setranges  = @(ranges) instrument.set_ranges(chanName{2},ranges);
                    variable.getranges  = @() instrument.ranges.(chanName{2});
                end
                
                obj.variableList.(variable.name) = variable;    % add the variable to struct holding the list of variables
            end
        end
        
        % updates the variableTable
        function updateVariableTable(obj)
            rnames = fieldnames(obj.variableList);                  % load names of all variables you want to have in the GUI
            set(obj.variableTable,'RowName', rnames)                % set names of rows in the table
            
            % into cell array 'table' all data we want to have in a GUI
            % table will be loaded
            table = {};
            % and now we fill this table
            % we do loop over the variables
            for i = 1:numel(rnames)
                var = obj.variableList.(rnames{i});                     % get name of the variable
                table{i,1} = var.getval();                              % read its current value
%                 table{i,1} = sprintf('%.4f',var.getval());
                 if strcmp(var.instrument_class, 'qd.ins.multiple_DecaDAC')  % if variable coresponding to DAC channel than:
                     limits = var.getlimits();                               % get limits from the driver
                     table{i,2} = limits(1);                                 % put limits in the table
                     table{i,3} = limits(2);
                     table{i,4} = var.getdivider();                          % put divider in the table
                     table{i,5} = var.getoffset();                           % put offset in the table
                     ranges = var.getranges();
                     if all(ranges == [-10 10])
                         table{i,6} = 0;
                     elseif all(ranges == [0 10])
                         table{i,6} = 1;
                     elseif all(ranges == [-10 0])
                         table{i,6} = -1;
                     end
                 end
            end
            set(obj.variableTable, 'Data', table)               % load newly created table into GUI
            
            set(obj.Xpopup, 'String', rnames)                   % set list of channel that can be sweeped
            set(obj.Ypopup, 'String', rnames)
        end
        
        % handling user's edit in the variable table
        function ret = variableCellEditCallback(obj, table, eventdata)
            indices = eventdata.Indices;                                % get indicies numbering edited cell
            rnames = fieldnames(obj.variableList);                      % get names of all channels
            data = get(table,'Data');                                   % get data stored in the variableTable
            variable = obj.variableList.(rnames{indices(1)});           % find the variable for which the editing was done
            switch(indices(2))                              % depending on the column number do different thing
                case 1                                      % for column 1 set value of variable:
                    if ~strcmp(variable.instrument_class,'qd.ins.multiple_DecaDAC')	% if it's not e DAC channel, set the value
                        obj.variableList.(rnames{indices(1)}).setval(eventdata.NewData)
                    elseif (eventdata.NewData < data{indices(1),2})               	% if it's DAC make sure that the value is within limits
                        display('Given value is too small!')
                    elseif (eventdata.NewData > data{indices(1),3})
                        display('Given value is too large!')
                    else                                                           	% if values are within limits than set voltage
                        variable.setval(eventdata.NewData)
                    end
                    realVal = variable.getval();                % read the real value on the channel
                    data{indices(1),1} = realVal;               % put real value in the table
                case {2,3}                                  % for column 2 or 3 set limits (assuming it is a variable corresponding to DAC channel!)
                    limits = [data{indices(1),2} data{indices(1),3}];
                    variable.setlimits(limits)
                case 4                                      % for column 4 set divider (assuming it is a variable corresponding to DAC channel!)
                    div = str2double(eventdata.EditData); 
                    variable.setdivider(div);
                    realVal = variable.getval();
                    data{indices(1),1} = realVal;
                    data{indices(1),4} = div;
                case 5                                      % for column 5 set offset (assuming it is a variable corresponding to DAC channel!)
                    off = str2double(eventdata.EditData); 
                    variable.setoffset(off);
                    realVal = variable.getval();
                    data{indices(1),1} = realVal;
                    data{indices(1),5} = off;
                case 6                                      % for column 6 set the ranges of the DAC (corresponding to the switch)
                    switch str2double(eventdata.EditData)
                        case 0  % Range is [-10 10]
                            variable.setranges([-10 10])
                        case 1  % Range  is [0 10]
                            variable.setranges([0 10])
                        case -1  % Range is [-10 0]
                            variable.setranges([-10 0])
                        otherwise
                            data{indices(1),6} = str2double(eventdata.PreviousData);
                            
                    end
            end
            set(obj.variableTable,'Data',data)      % load table int GUI
            obj.saveSettings()                      % save new settings in external file
        end
        
        % function adds input channel
        function addInput(obj, id)
            obj.q.remove_input(id);         % remove input from q.inputs if for some strange reason it was there
%             chanName = strsplit(id,'/');
            name = strrep(id, '/', '_');
            input = struct();               % make a struct for storing information about the input
            input.name = name;              % set input name
            input.id = id;                  % set input id
            input.multipliers = struct();   % create a struct for storing values of multipliers for various units (TODO)
            obj.inputList.(name) = input;   % add input to inputList
        end
        
        % update the input table
        function updateInputTable(obj)
            rnames = fieldnames(obj.inputList);         % read names of inputs
            set(obj.inputTable,'RowName', rnames)       % set row names in the GUI
            table = get(obj.inputTable,'Data');         % load table of data from GUI
            for i = 1:numel(rnames)                     % do loop over all inputs
                input = obj.inputList.(rnames{i});                          % choose the right input
                table{i,1} = any(strcmp(input.id, obj.activeInputsNames));  % find out if this input is in q.inputs and put true/false in the table
            end
            set(obj.inputTable,'Data',table)            % upload the table to GUI
        end
        
        % handling user's edit in the input table
        function ret = inputCellEditCallback(obj, table, eventdata)
            indices = eventdata.Indices;                    % read the indicies describing location of edited cell
            rnames = fieldnames(obj.inputList);             % get names of all inputs
            data = get(table,'Data');                       % read the table from GUI
            input = obj.inputList.(rnames{indices(1)});     % choose the input for which the change occured
            switch indices(2)                   % do something depending on the column in which the change occured
                case 1                              % for column storing information about whether input is active or not
                    is_active = any(strcmp(input.id, obj.activeInputsNames));       % find out whether the input is active
                    if (eventdata.NewData && ~is_active)                            % if newly set value is true and the channel is not active yet than activate it
                        obj.q.add_input(input.id);
                    elseif ~eventdata.NewData                                       % if newly set channel is false - deactivate the input
                        obj.q.remove_input(input.id)
                    end
                case 2              % TODO
                    data{indices(1),2} = eventdata.EditData;
                    if any(strcmp(data{indices(1),2},fieldnames(input.multipliers)));
                        data{indices(1),3} = input.multipliers.(eventdata.EditData);
                    else
                        data{indices(1),3} = 1;
                    end
                    set(obj.inputTable,'Data',data)
                case 3              % TODO
                    data{indices(1),3} = str2double(eventdata.EditData);
                    set(obj.inputTable,'Data',data)
                    obj.inputList.(rnames{indices(1)}).multipliers.(data{indices(1),2}) = str2double(eventdata.EditData);
            end
%             obj.updateInputTable()
            obj.saveSettings()          % export settings to external table
        end
        
        % get function for dependent variable activeInputsNames
        function activeInputsNames = get.activeInputsNames(obj)
            activeInputsNames = {};
            for i = 1:numel(obj.q.inputs.inputs)
                activeInputsNames{end+1} = obj.q.inputs.inputs{1,i}.name;
            end
        end
        
        % function for saving current settings of tables
        function saveSettings(obj)
            % get tables (also names of rows) from the GUI and save them
            variableTableData = get(obj.variableTable,'Data');
            variableTableName = get(obj.variableTable,'RowName');
            inputTableData = get(obj.inputTable,'Data');
            inputTableName = get(obj.inputTable,'RowName');
            inputList = obj.inputList;          % we want also to save information about multipliers (TODO?)
            save([obj.q.store.directory '/recent_EB_settings.m'],...
                'variableTableData','variableTableName',...
                'inputTableData','inputTableName',...
                'inputList');
        end
        
        % function for loading settings of variables and inputs
        function loadSettings(obj,varargin)
            % load settings from the file in which it was stored
            % by default read recent settings
            if nargin == 1
                filename = [obj.q.store.directory '/recent_EB_settings.m'];
            else
                filename = varargin{1};
            end
            if ~exist(filename,'file')
                return;
            end
            load(filename,'-mat')
            
            % setting Variable Table parameters
            vrnames = get(obj.variableTable,'RowName');     % read present settings in the GUI
            vdata = get(obj.variableTable,'Data');
            variableDataSize = size(variableTableData);     % read size of loaded table corresponding to variableTable
            % in the loop we update the data, remembering that the order of
            % the rows can be different in loaded table than in present
            % table. Real values of the variables ARE NOT CHANGED!
            for i = 1:numel(variableTableName)
                rnum = find(strcmp(variableTableName{i},vrnames));
                if (~isempty(rnum) && ~isempty(variableTableData{i,2}))
                    vdata{rnum,2} = variableTableData{i,2};
                    vdata{rnum,3} = variableTableData{i,3};
                    obj.variableList.(variableTableName{i}).setlimits([vdata{rnum,2} vdata{rnum,3}])
                end
                if (~isempty(rnum) && variableDataSize(2)>3 && ~isempty(variableTableData{i,4}))
                    vdata{rnum,4} = variableTableData{i,4};
                    obj.variableList.(variableTableName{i}).setdivider(vdata{rnum,4})
                end
                if (~isempty(rnum) && variableDataSize(2)>4 && ~isempty(variableTableData{i,5}))
                    vdata{rnum,5} = variableTableData{i,5};
                    obj.variableList.(variableTableName{i}).setoffset(vdata{rnum,5})
                end
            end
            set(obj.variableTable,'Data',vdata);        % update the table in the GUI
            
            % updatin g inputList
            % update every input that was already in the inputList
            % inputs that are not presently in the inputList will NOT BE ADDED
            inputListName = fieldnames(inputList);
            for i = 1:numel(inputListName)
                if any(strcmp(inputListName{i},fieldnames(obj.inputList)))
                    obj.inputList.(inputListName{i}) = inputList.(inputListName{i});
                end
            end
            
            % the table in the GUI
            irnames = get(obj.inputTable,'RowName');
            idata = get(obj.inputTable,'Data');
            for i = 1:numel(inputTableName)
                rnum = find(strcmp(inputTableName{i},irnames));
                if (~isempty(rnum) && ~isempty(variableTableData{i,2}))
                    input = obj.inputList.(inputTableName{i});
                    idata{rnum,1} = inputTableData{i,1};
                    % activate/deactivate channels it necessary, depending
                    % on loaded data
                    is_active = any(strcmp(input.id, obj.activeInputsNames));
                    if (inputTableData{i,1} && ~is_active)
                        obj.q.add_input(input.id);
                    elseif ~inputTableData{i,1}
                        obj.q.remove_input(input.id)
                    end
%                     idata{rnum,2} = inputTableData{i,2};
%                     idata{rnum,3} = inputTableData{i,3};
                end
            end
            set(obj.inputTable,'Data',idata);
        end
        
        % perform 1d scan
        function do1dCallback(obj, pb, eventdata)
            display('Measuring...')
            % read name sof avaliable variables
            allNames = get(obj.Xpopup,'String');
            % get parameters of the sweep freom the gui
            Xchnum = get(obj.Xpopup,'Value');
            Xch = strrep(allNames{Xchnum},'_','/');
            Xmin = str2double(get(obj.Xminedit,'String'));
            Xmax = str2double(get(obj.Xmaxedit,'String'));
            Xstep = str2double(get(obj.Xstepedit,'String'));
            
            % add custom suffix to the name of the sweep
            suffix = get(obj.CustomSuffixedit,'String');
            if strcmp(suffix, '')
                sweepName = [Xch ' ' suffix];
            else
                sweepName = Xch
            end
            
            % run the sweep
            obj.q.sw(Xch,Xmin,Xmax,Xstep).go(sweepName);
            display('Done!')
            
            % if user checked the 'Set X to:' box than set value of the
            % variable after the sweep
            if get(obj.Xsetfinishbox,'Value')
                variable = obj.variableList.(Xchnum);
                variable.setval(str2double(get(obj.Xsetfinishedit,'String')));
            end
            
            % update the variable table
            obj.updateVariableTable();
        end
        
        % perform 2d scan
        function do2dCallback(obj, pb, eventdata)
            % works just like 1d, but does 2d sweep...
            display('Measuring...')
            allNames = get(obj.Xpopup,'String');
            
            Xchnum = get(obj.Xpopup,'Value');
            Xch = strrep(allNames{Xchnum},'_','/');
            Xmin = str2double(get(obj.Xminedit,'String'));
            Xmax = str2double(get(obj.Xmaxedit,'String'));
            Xstep = str2double(get(obj.Xstepedit,'String'));
            
            Ychnum = get(obj.Ypopup,'Value');
            Ych = strrep(allNames{Ychnum},'_','/');
            Ymin = str2double(get(obj.Yminedit,'String'));
            Ymax = str2double(get(obj.Ymaxedit,'String'));
            Ystep = str2double(get(obj.Ystepedit,'String'));
            
            suffix = get(obj.CustomSuffixedit,'String');
            sweepName = [Xch ' ' Ych ' ' suffix];
            obj.q.sw(Xch,Xmin,Xmax,Xstep).sw(Ych,Ymin,Ymax,Ystep).go(sweepName);
            display('Done!')
            
            if get(obj.Xsetfinishbox,'Value')
                variable = obj.variableList.(Xchnum);
                variable.setval(str2double(get(obj.Xsetfinishedit,'String')));
            end
            if get(obj.Ysetfinishbox,'Value')
                variable = obj.variableList.(Ychnum);
                variable.setval(str2double(get(obj.Ysetfinishedit,'String')));
            end
            
            obj.updateVariableTable();
        end
    end
end