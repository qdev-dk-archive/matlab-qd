function [reshaped1, reshaped2, reshaped3] = reshape2d(column1, column2, column3)
    different_from_first = find(column1 ~= column1(1));
    if isempty(different_from_first)
        sweep_length = length(column1);
    else
        sweep_length = different_from_first(1) - 1;
    end
    number_of_sweeps = floor(length(column1) / sweep_length);
    number_of_good_points = number_of_sweeps * sweep_length;

    % We make an anonymous function to reshape all the columns.
    f = @(c) reshape(c(1:number_of_good_points), sweep_length, number_of_sweeps);
    reshaped1 = f(column1);
    reshaped2 = f(column2);
    reshaped3 = f(column3);
    
    % Next up, we reverse columns that are swept in reverse direction.
    if reshaped1(end) < reshaped1(1)
        % g reverses the x-direction
        g = @(c) c(1, end:-1:1);
    else
        g = @(c) c;
    end
    if reshaped2(end) < reshaped2(1)
        h = @(c) c(end:-1:1, 1);
    else
        h = @(c) c;
    end
    reshaped1 = h(g(reshaped1));
    reshaped2 = h(g(reshaped2));
    reshaped3 = h(g(reshaped3));
end