function r = validate_name(name)
% validate_name(name)
%
% Returns false if the string name does not:
%   1) start with a letter, and
%   2) contain nothing but letters, digits, and underscores.
    [s, e] = regexp(name, '[a-zA-Z][a-zA-Z0-9_]*', 'once');
    r = s == 1 && e == length(name);
end