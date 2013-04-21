classdef Mock < qd.classes.Instrument
% A mock instrument for testing purposes
    properties
        a = 0.0
        b = 0.0
    end
    methods
        function r = model(obj)
            r = 'Mock instrument';
        end

        function r = channels(obj)
            r = {'a', 'b', 'c'};
        end

        function r = getc(obj, chan)
            switch chan
                case 'a'
                    r = obj.a;
                case 'b'
                    r = obj.b;
                case 'c'
                    r = sin(obj.a) + obj.b;
                otherwise
                    error('No such channel');
            end
        end

        function setc(obj, chan, val)
            switch chan
                case 'a'
                    obj.a = val;
                case 'b'
                    obj.b = val;
                case 'c'
                    error('Not supported');
                otherwise
                    error('No such channel');
            end
        end
    end
end