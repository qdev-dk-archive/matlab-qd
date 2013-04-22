function val = match(str, pat)
% val = match(str, pat)
%
% Like sscanf, but matches one and only one instance of pat. Will return [] if
% pat was not found or if there was extra data after the first match.
    [val, count, err, next] = sscanf(str, pat);
    if count ~= 1 && next ~= length(str) + 1
        val = [];
        return;
    end
end