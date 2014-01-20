function describe(obj)
    r = qd.classes.Register;
    d = obj.describe(r);
    disp('Register:')
    disp(json.dump(r.describe(), 'indent', 2)) 
    disp(' ')
    disp('Object:')
    disp(json.dump(d, 'indent', 2)) 
end