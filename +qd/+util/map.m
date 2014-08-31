function out = map(f, in, unbox)
    if nargin == 2
        unbox = false;
    end
    if unbox
        out = arrayfun(@(x) f(x{:}), in, 'UniformOutput', false);
    else
        out = arrayfun(f, in, 'UniformOutput', false);
    end
end