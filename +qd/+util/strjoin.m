function r = strjoin(strs, delim)
    if numel(strs) == 0
        r = '';
    end
    r = strs{1};
    for s = strs(2:end)
        r = [r delim s{1}];
    end
end