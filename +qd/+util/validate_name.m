function validate_name(name)
% validate_name(name)
%
% Throws an error if the string name does not:
%   1) start with a letter, and
%   2) contain nothing but letters, digits, and underscores.
    [s, e] = regexp(name, '[a-zA-Z][a-zA-Z0-9_]*', 'once');
    if s ~= 1 && e ~= numel(name)
        error(sprintf(['name must start with a letter and contain nothing but '...
            'letters, digits, and underscores ("%s" is invalid)'], name))
    end
end