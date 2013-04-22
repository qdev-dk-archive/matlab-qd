classdef Setup < handle
    properties
        instruments = {}
        channels = {}
        meta = struct()
    end
    methods

        function add_instrument(obj, ins)
            obj.instruments{end + 1} = ins;
        end

        function add_channel(obj, chan)
            obj.channels{end + 1} = chan;
        end

        function chan = name_channel(obj, id, name)
        % name_channel(id, name)
        %
        % Finds the channel named id among the configured instruments,
        % instantiates it, and names it. The channel is added to the setup.
        % This function returns the added channel.
            chan = obj.find_in_instruments(id);
            chan.name = name;
            obj.add_channel(chan);
        end

        function chan = find_channel(obj, id)
            for ch = obj.channels
                ch = ch{1};
                if strcmp(ch.name, id)
                    chan = ch;
                    return;
                end
            end
            if length(qd.util.strsplit(id, '/')) == 2
                chan = obj.find_in_instruments(id);
            end
        end

        function meta = describe(obj)
            meta = struct();
            meta.meta = obj.meta;
            instrs = {};
            chans = {};
            for ins = obj.instruments
                ins = ins{1};
                instrs{end + 1} = ins.describe();
            end
            meta.instruments = instrs;
            for chan = obj.channels
                chan = chan{1};
                if ismember(chan.instrument, obj.instruments)
                    chans{end + 1} = chan.describe_without_instrument();
                else
                    chans{end + 1} = chan.describe();
                end
            end
            meta.channels = chans;
        end
    end
    methods(Access=private)
        function chan = find_in_instruments(obj, id)
            parts = qd.util.strsplit(id, '/');
            if length(parts) ~= 2
                error(['Input should contain one "/" delimiting the '...
                    'instrument name from the channel name']);
            end
            [ins_name, chan_name] = parts{:};
            ins = [];
            for instr = obj.instruments
                instr = instr{1};
                if strcmp(instr.name, ins_name)
                    ins = instr;
                end
            end
            if isempty(ins)
                error('No such instrument');
            end
            chan = [];
            for name = ins.channels()
                name = name{1};
                if strcmp(name, chan_name)
                    chan = ins.channel(name);
                end
            end
            if isempty(chan)
                error('No such channel on the instrument');
            end
        end
    end
end