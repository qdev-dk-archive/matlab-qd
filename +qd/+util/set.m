function set(varargin)
    % qd.util.set(chan, val, [chan, val, ...])
    %
    % Set several channels in parallel.
    f = []
    for i = 1:2:length(varargin)
        f = f & varargin{i}.set_async(varargin{i + 1});
    end
    f.exec();
end