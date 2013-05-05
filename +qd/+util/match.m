function val = match(str, pat)
% val = match(str, pat)
%
% Like sscanf, but matches one and only one instance of pat. Will throw an
% error if pat was not found or if there was extra data after the first match.
    [val, count, err, next] = sscanf(str, pat);
    if count ~= 1 && next ~= length(str) + 1
        error('could not match (%s) to the pattern (%s).', str, pat);
    end
end