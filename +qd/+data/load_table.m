function table = load_table(directory, name)
    data_path = fullfile(directory, [name '.dat']);
    meta_path = fullfile(directory, [name '.json']);
    if ~exist(run_path, 'file')
        error('Could not locate table');
    end
    meta = json.read(meta_path);
    data = dlmread(data_path);
    table = {};
    i = 1;
    for c = meta
        c.data = transpose(data(:, i));
        table{end+1} = c;
        i = i + 1;
    end
end