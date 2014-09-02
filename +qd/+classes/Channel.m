classdef Channel < qd.classes.Nameable
    properties
        instrument
        channel_id
        meta = struct()
    end
    methods
        function r = default_name(obj)
            if ~isempty(obj.instrument)
                r = [obj.instrument.name '/' obj.channel_id];
            else
                r = ['special/' obj.channel_id];
            end
        end

        function r = describe(obj, register)
            r = struct();
            r.name = obj.name;
            r.default_name = obj.default_name;
            r.channel_id = obj.channel_id;
            r.meta = obj.meta;
            r.class = qd.util.class_name(obj, 'full');
            if ~isempty(obj.instrument)
                r.instrument = register.put('instruments', obj.instrument);
            end
        end

        function val = get(obj)
            if qd.util.is_reimplemented(obj, 'get_async', ?qd.classes.Channel)
                val = obj.get_async().exec();
            elseif ~isempty(obj.instrument)
                val = obj.instrument.getc(obj.channel_id);
            else
                error('Not supported');
            end
        end

        function set(obj, val)
            if qd.util.is_reimplemented(obj, 'set_async', ?qd.classes.Channel)
                obj.set_async(val).exec();
            elseif ~isempty(obj.instrument)
                obj.instrument.setc(obj.channel_id, val);
            else
                error('Not supported');
            end
        end

        function future = get_async(obj)
            if ~isempty(obj.instrument) && ...
                    qd.util.is_reimplemented(obj.instrument, 'getc_async', ?qd.classes.Instrument)
                future = obj.instrument.getc_async(obj.channel_id);
                return
            end
            future = qd.classes.GetFuture(@()obj.get());
        end

        function future = set_async(obj, val, varargin)
            if ~isempty(obj.instrument) && ...
                    qd.util.is_reimplemented(obj.instrument, 'setc_async', ?qd.classes.Instrument)
                future = obj.instrument.setc_async(obj.channel_id, val, varargin{:});
                return
            end
            future = qd.classes.SetFuture(@()obj.set(val));
        end

        function obj = set_meta(obj, meta)
            obj.meta = meta;
        end
    end
end
