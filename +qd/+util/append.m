function result = append(struct_array, new_struct)
% This inane function appends a struct to an array.
% The appended struct must have the same fields as
% the ones in the array. If struct_array is empty,
% it does not matter what type it has.
    if isempty(struct_array)
        result = new_struct;
        return;
    end
    result = [struct_array new_struct];
end