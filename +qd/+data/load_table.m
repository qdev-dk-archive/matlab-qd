function table = load_table(directory, name)
    data_path = fullfile(directory, [name '.dat']);
    meta_path = fullfile(directory, [name '.json']);
    if ~exist(data_path, 'file')
        error('Could not locate table');
    end
    meta = json.read(meta_path);
    table = {};
    stat = dir(data_path);
    if stat.bytes == 0
        data = zeros(0, length(meta));
    else
        data = dlmread(data_path);
    end
    i = 1;
    for c = meta
        c.data = data(:, i);
        table{end+1} = c;
        i = i + 1;
    end
end