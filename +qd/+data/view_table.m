function view = view_table(directory, name)
    view = struct();
    view.map = containers.Map();
    table = qd.data.load_table(directory, name);
    for column = table
        if qd.util.validate_name(column{1}.name)
            view.(column{1}.name) = column{1}.data;
        end
        view.map(column{1}.name) = column{1}.data;
    end
end