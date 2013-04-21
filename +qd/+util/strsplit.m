function parts = strsplit(str, delim)
    qd.util.assert(ischar(str));
    idxs = strfind(str, delim);
    idxs(end + 1) = numel(str);
    parts = {};
    last = 1;
    for idx = idxs
        parts{end+1} = str(last:idx);
        last = idx + numel(delim);
    end
end