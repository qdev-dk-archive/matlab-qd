function tbls = view_tables(loc)
    num = 0;
    tbls = struct;
    for d = transpose(dir(fullfile(loc, '*.dat')))
        [~, table_name, ~] = fileparts(fullfile(loc, d.name));
        view = qd.data.view_table(loc, table_name{1});
        if qd.util.validate_name(table_name{1})
            tbls.(table_name{1}) = view;
        end
        num = num + 1;
    end
end