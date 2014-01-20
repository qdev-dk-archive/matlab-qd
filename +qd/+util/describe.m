% This function will pretty-print the description of a channel or an
% instrument, along with everything that is placed in the register when
% describing the object. For instance, when describing a channel, the
% associated instrument is placed in the register.
function describe(obj)
    r = qd.classes.Register;
    d = obj.describe(r);
    disp('Register:')
    disp(json.dump(r.describe(), 'indent', 2)) 
    disp(' ')
    disp('Object:')
    disp(json.dump(d, 'indent', 2)) 
end