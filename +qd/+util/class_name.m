function r = class_name(obj, varargin)
    p = inputParser();
    p.addOptional('full', [], @(x)strcmp(x, 'full'));
    p.parse(varargin{:});
    m = metaclass(obj);
    if ~isempty(p.Results.full)
        r = m.Name;
    else
        p = qd.util.strsplit(m.Name, '.');
        r = p{end};
    end
end