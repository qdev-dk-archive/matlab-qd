function [reshaped1, reshaped2, reshaped3] = reshape2d(column1, column2, column3)
    different_from_first = find(column1 ~= column1(1), 1);
    if isempty(different_from_first)
        error('every value in column1 is identical');
    else
        sweep_length = different_from_first(1) - 1;
    end
    if sweep_length == 1
        error('the first two value in column 1 are unequal')
    end
    number_of_sweeps = floor(length(column1) / sweep_length);
    number_of_good_points = number_of_sweeps * sweep_length;

    % We make an anonymous function to reshape all the columns.
    f = @(c) reshape(c(1:number_of_good_points), sweep_length, number_of_sweeps);
    reshaped1 = f(column1);
    reshaped2 = f(column2);
    reshaped3 = f(column3);

    % Test result
    if ~isempty(find(reshaped1 ~= circshift(reshaped1, [1 0])))
        error('column1 varies within a sweep');
    end
    if ~isempty(find(reshaped2 ~= circshift(reshaped2, [0 1])))
        error('column2 does not attain the same values in every sweep');
    end
end