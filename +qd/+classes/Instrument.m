classdef Instrument < qd.classes.Nameable
    properties(Access=private)
        disable_default = false
    end
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

        function r = describe(obj)
            r = struct;
            r.name = obj.name;
            r.model = obj.model;
            r.class = class_name(obj, 'full');
            r.channels = obj.channels;
        end

        function chan = channel(obj, id)
            if obj.has_channel(id)
                if obj.disable_default
                    error('Not supported by this channel.');
                end
                chan = qd.classes.Channel();
                chan.instrument = obj;
                chan.channel_id = id;
            else
                error(sprintf('Channel not found (%s)', id));
            end
        end

        function r = has_channel(obj, channel)
            r = ~isempty(find(strcmp(obj.channels(), channel)));
        end

        function val = getc(obj, channel)
            chan = obj.channel_if_reimplemented(channel);
            val = chan.get();
        end

        function setc(obj, channel, val)
            chan = obj.channel_if_reimplemented(channel);
            chan.set(val);
        end
    end
    methods(Access=private)
        function chan = channel_if_reimplemented(obj, channel)
            % The default implementation of Instrument::channel is to return a
            % channel which will call back getc and setc, this will cause an
            % infinite loop. Here we set disable_default = true to disable the
            % default implementation of channel for the duration of this call.
            obj.disable_default = true;
            try
                chan = obj.channel(channel);
            catch err
                obj.disable_default = false;
                rethrow(err)
            end
            obj.disable_default = false;
        end
    end
end