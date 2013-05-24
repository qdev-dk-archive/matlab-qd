function [reshaped_data, extents] = reshape_data(data, sweeps)
    if ~iscell(sweeps)
        sweeps = num2cell(sweeps);
    end
    dimensions = arrayfun(@(x)x{1}.points, sweeps);
    % if this is a 2d sweep, then slice_size is the number of points in the y
    % direction.
    slice_size = prod(dimensions(2:end));
    % We want square data, so we throw out all data which does not form a
    % complete slice.
    full_slices = floor(length(data) / slice_size);
    good_dimensions = [full_slices dimensions(2:end)];
    good_data = data(1:prod(good_dimensions));
    reshaped_data = reshape(good_data, good_dimensions(end:-1:1));
    % We want each axes to be increasing
    for i = 1:length(sweeps)
        if sweeps{i}.from > sweeps{i}.to
            reshaped_data = flipdim(reshaped_data, length(sweeps) + 1 - i);
        end
    end
    extents = [];
    % How long did we actually get along the x-direction in this measurement.
    along_x_direction = sweeps{1}.from ...
        + (sweeps{1}.to - sweeps{1}.from)/(sweeps{1}.points-1) * (full_slices-1);
    extents(1,1) = min(sweeps{1}.from, along_x_direction);
    extents(1,2)  = max(sweeps{1}.from, along_x_direction);
    for i = 2:length(sweeps)
        extents(i, 1) = min(sweeps{i}.from, sweeps{i}.to);
        extents(i, 2) = max(sweeps{i}.from, sweeps{i}.to);
    end
end