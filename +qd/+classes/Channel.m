classdef Channel < qd.classes.Nameable
    properties
        instrument
        channel_id
    end
    methods
        function r = default_name(obj)
            r = [obj.instrument.name '/' obj.channel_id];
        end

        function r = describe(obj, register)
            r = struct();
            r.name = obj.name;
            r.default_name = obj.default_name;
            r.channel_id = obj.channel_id;
            r.instrument = register.put('instruments', obj.instrument);
        end

        function val = get(obj)
            val = obj.instrument.getc(obj.channel_id);
        end

        function set(obj, val)
            obj.instrument.setc(obj.channel_id, val);
        end
    end
end