classdef Instrument < qd.classes.Nameable
% The base class of all instruments.
    methods
        function r = model(obj)
        % The name of the type of instrument as given by the manufacturer. For
        % instance, this could be 'SR530' for a model 530 lock-in amplifier

            % The default implementation returns the name of the class.
            r = qd.util.class_name(obj);
        end

        function r = default_name(obj)
            r = obj.model();
        end

        function r = channels(obj)
            r = {};
        end

        function r = describe(obj, register)
            r = struct;
            r.name = obj.name;
            r.model = obj.model;
            r.class = qd.util.class_name(obj, 'full');
            r.channels = obj.channels;
        end

        function chan = channel(obj, id)
        % Get a channel instance for the channel with name 'id'. 'id' should
        % be a string.
            if obj.has_channel(id)
                chan = qd.classes.Channel();
                chan.instrument = obj;
                chan.channel_id = id;
            else
                error('Channel not found (%s)', id);
            end
        end

        function r = has_channel(obj, id)
        % 'id' should be a string.
            r = ~isempty(find(strcmp(obj.channels(), id)));
        end

        function val = getc(obj, id)
        % Get the value of the channel with name 'id'.
        % Equivalent to ins.channel(id).get().
            if qd.util.is_reimplemented(obj, 'getc_async', ?qd.classes.Instrument)
                val = obj.getc_async(id).exec();
                return
            end
            chan = obj.channel_if_reimplemented(id);
            val = chan.get();
        end

        function future = getc_async(obj, id)
            chan = obj.channel_if_reimplemented(id);
            val = chan.get_async();
        end

        function setc(obj, id, val)
        % Set the value of the channel with name 'id'.
        % Equivalent to ins.channel(id).set(val).
            if qd.util.is_reimplemented(obj, 'setc_async', ?qd.classes.Instrument)
                obj.setc_async(id, val).exec();
                return
            end
            chan = obj.channel_if_reimplemented(id);
            chan.set(val);
        end

        function future = setc_async(obj, id, val)
            chan = obj.channel_if_reimplemented(id);
            future = chan.set_async(val);
        end
    end
    methods(Access=private)
        function chan = channel_if_reimplemented(obj, id)
            if ~obj.has_channel(id)
                error('Channel not found (%s)', id);
            end
            % The default implementation of Instrument::channel is to return a
            % channel which will call back getc and setc, this will cause an
            % infinite loop. Here we check if channel has been reimplemented
            % before we call it.
            if ~qd.util.is_reimplemented(obj, 'channel', ?qd.classes.Instrument)
                error('Not supported.')
            end
            chan = obj.channel(id);
        end
    end
end