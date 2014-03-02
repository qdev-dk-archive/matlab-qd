function set(varargin)
    % qd.util.set(chan, val, [chan, val, ...])
    %
    % Set several channels in parallel.
    futures = {};
    for i = 1:2:length(varargin)
        futures{end+1} = varargin{i}.set_async(varargin{i + 1});
    end
    for f = futures
        f{1}.exec();
    end
end