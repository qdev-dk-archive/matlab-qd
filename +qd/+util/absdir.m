function r = absdir(rel)
% absdir(rel)
%
% Returns the absolute canonical path to a file or directory.
    r = char(java.io.File(rel).getCanonicalPath());
end