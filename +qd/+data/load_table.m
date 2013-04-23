function [table, view] = load_table(directory, name)
    data_path = fullfile(directory, [name '.dat']);
    meta_path = fullfile(directory, [name '.json']);
    if ~exist(data_path, 'file')
        error('Could not locate table');
    end
    meta = json.read(meta_path);
    data = dlmread(data_path);
    table = {};
    view = struct();
    i = 1;
    for c = meta
        c.data = data(:, i);
        table{end+1} = c;
        i = i + 1;
        if qd.util.validate_name(c.name)
            view.(c.name) = c.data;
        end
    end
end