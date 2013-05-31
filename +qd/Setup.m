classdef Setup < handle
    properties
        instruments = {}
        channels = {}
        meta = struct()
        meta_funcs = {}
    end
    properties(Dependent)
        ins
        chans
    end
    methods

        function ins = get.ins(obj)
            ins = struct();
            for instrument = obj.instruments
                name = instrument{1}.name;
                if isvarname(name)
                    ins.(name) = instrument{1};
                end
            end
        end

        function chans = get.chans(obj)
            chans = struct();
            for channel = obj.channels
                name = channel{1}.name;
                if isvarname(name)
                    chans.(name) = channel{1};
                end
            end
        end

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
                return
            end
            error('Channel not found.')
        end

        function meta = describe(obj, register)
            meta = struct();
            meta.meta = obj.meta;
            instrs = {};
            chans = {};
            for ins = obj.instruments
                instrs{end + 1} = register.put('instruments', ins{1});
            end
            meta.instruments = instrs;
            for chan = obj.channels
                chans{end + 1} = register.put('channels', chan{1});
            end
            meta.channels = chans;
            for v = obj.meta_funcs
                [name, func] = v{1}{:};
                meta.meta.(name) = func();
            end
        end

        function add_meta_function(obj, func, name)
        % When describe is called, each function added using 
        % add_meta_function will be called. The output of the functions
        % are stored under meta.(name).
            obj.meta_funcs{end + 1} = {name, func};
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