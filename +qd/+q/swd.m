function r = swd(chan, from, to, point_density)
% recipe = swd(chan, from, to, point_density)
%
% This function constructs a recipe of type qd.q.sw. Instead of giving the
% number of points, you give the density of points. Specifically
%
%   qd.q.swd(c, f, t, d) == qd.q.sw(c, f, t, ceil(abs(t - f)*d) + 1)
%
% Such that the points in the constructed sweep are no further apart than
% (1/point_density).
    r = qd.q.sw(chan, from, to, ceil(abs(to - from)*point_density) + 1)
end