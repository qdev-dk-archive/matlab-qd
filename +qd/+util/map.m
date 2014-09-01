function out = map(f, in)
    if iscell(in)
        out = arrayfun(@(x) f(x{:}), in, 'UniformOutput', false);
    else
        out = arrayfun(f, in, 'UniformOutput', false);
    end
end