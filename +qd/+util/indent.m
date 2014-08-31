function r = indent(text, n)
    if nargin == 1
        n = 2;
    end
    r = qd.util.prefix_every_line(text, blanks(n));
end