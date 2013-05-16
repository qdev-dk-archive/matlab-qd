function view = view_table(table)
    view = struct();
    view.map = containers.Map();
    for column = table
        if isvarname(column{1}.name) && ~strcmp(column{1}.name, 'map')
            view.(column{1}.name) = column{1}.data;
        end
        view.map(column{1}.name) = column{1}.data;
    end
end