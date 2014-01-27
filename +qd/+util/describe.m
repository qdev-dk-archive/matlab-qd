% This function will pretty-print the description of a channel or an
% instrument, along with everything that is placed in the register when
% describing the object. For instance, when describing a channel, the
% associated instrument is placed in the register.
function describe(obj)
    m = metaclass(obj);
    for x = (m.MethodList).'
        if strcmp(x.Name, 'describe')
            if length(x.InputNames) == 1
                % It only takes obj. Do describeSimpl
                describeSimpl(obj);
                return;
            end
        end
    end
    describeReg(obj);
end

function describeSimpl(obj)
    disp(json.dump(obj.describe(), 'indent', 2));
end

function describeReg(obj)
    r = qd.classes.Register;
    d = obj.describe(r);
    disp('Register:');
    disp(json.dump(r.describe(), 'indent', 2));
    disp(' ');
    disp('Object:');
    disp(json.dump(d, 'indent', 2));
end