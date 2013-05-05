function r = absdir(rel)
% absdir(rel)
%
% Returns the absolute path to an existing directory rel.
    save_dir = pwd();
    cleanup = onCleanup(@()cd(save_dir));
    cd(rel);
    r = pwd();
end