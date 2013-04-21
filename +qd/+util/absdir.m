function r = absdir(rel)
% absdir(rel)
%
% Returns the absolute path to an existing directory rel.
    save_dir = pwd();
    cd(rel);
    r = pwd();
    cd(save_dir);
end