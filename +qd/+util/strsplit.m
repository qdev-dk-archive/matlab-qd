function parts = strsplit(str, delim)
    qd.util.assert(ischar(str));
    idxs = strfind(str, delim);
    idxs(end + 1) = length(str);
    parts = {};
    last = 1;
    for idx = idxs
        parts{end+1} = str(last:idx);
        last = idx + length(delim);
    end
end