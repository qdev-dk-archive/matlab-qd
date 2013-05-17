function bool = is_reimplemented(obj, method, origin)
% Check if a method of obj has been changed from the 
% definition given in the class origin.
%
% - method: a string.
% - origin: a metaclass.
    m = metaclass(obj);
    i = find(strcmp(method, {m.MethodList.Name}));
    qd.util.assert(length(i) == 1);
    bool = m.MethodList(i).DefiningClass ~= origin;
end