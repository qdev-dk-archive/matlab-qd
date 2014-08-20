function reshaped = reshape_using_meta(data, meta)
    shape = qd.q.shape_from_meta(meta);
    if length(shape) < 2
        % data is one-dimensional
        reshaped = reshape(data, 1, []);
    else
        n = numel(data);
        m = prod(shape(1:end-1));
        shape(end) = floor(n / m);
        n = shape(end) * m;
        c = num2cell(shape);
        reshaped = reshape(data(1:n), c{:});
    end
end