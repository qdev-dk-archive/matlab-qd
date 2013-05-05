function r = class_name(obj, varargin)
    p = inputParser();
    p.addOptional('full', []);
    p.parse(varargin{:});
    m = metaclass(obj);
    if ~isempty(p.Result.full)
        qd.util.assert(strcmp(p.Result.full, 'full'));
        r = m.Name;
    else
        p = qd.util.strsplit(m.Name, '.');
        r = p{end};
    end
end