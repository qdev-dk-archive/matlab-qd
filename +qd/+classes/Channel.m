classdef Channel < qd.classes.Nameable
    properties
        instrument
        channel_id
    end
    methods
        function r = default_name(obj)
            r = [obj.instrument.name '/' obj.channel_id];
        end

        function r = describe_without_instrument(obj)
            r = struct();
            r.name = obj.name;
            r.default_name = obb.default_name;
            r.channel_id = obj.channel_id;
            r.instrument_name = obj.instrument.name;
        end

        function r = describe(obj)
            r = obj.describe_without_instrument;
            rmfield(r, 'instrument_name');
            r.instrument = obj.instrument.describe();
        end

        function val = get(obj)
            val = obj.instrument.getc(obj.channel_id);
        end

        function set(obj, val)
            obj.instrument.setc(obj.channel_id, val);
        end
    end
end