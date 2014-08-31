function r = prefix_every_line(text, prefix)
% r = prefix_every_line(text, prefix)
%
% Puts the string prefix in front of every line in text.
    nl = sprintf('\n');
    r = [prefix, strrep(text, nl, [nl, prefix])];
end