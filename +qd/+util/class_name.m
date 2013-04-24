function r = class_name(obj, varargin)
    m = metaclass(obj);
    qd.util.assert(length(varargin) < 2);
    if length(varargin) == 1
        qd.util.assert(strcmp(varargin{1}, 'full'));
        r = m.Name;
    else
        p = qd.util.strsplit(m.Name, '.');
        r = p(end);
    end
end