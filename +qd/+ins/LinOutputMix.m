classdef LinOutputMix < qd.classes.Instrument
    properties(GetAccess=public, SetAccess=private)
        base_channels
        transform
        derived_channel_names
        cached_values
    end
    methods
        function obj = LinOutputMix(base_channels, transform, varargin)
            transform_size = size(transform);
            qd.util.assert(length(base_channels) == transform_size(1));
            p = inputParser();
            p.addOptional('derived_channel_names', [], @(x) length(x) == transform_size(2));
            p.parse(varargin{:});
            obj.derived_channel_names = p.Results.derived_channel_names;
            obj.base_channels = base_channels;
            obj.transform = transform;
            if isempty(obj.derived_channel_names)
                obj.derived_channel_names = qd.util.map(@(x) ['CH' num2str(x)], 1:transform_size(2));
            end
            obj.reinitialize_values_from_base_channels();
        end

        function chans = channels(obj)
            chans = obj.derived_channel_names;
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Instrument(register);
            r.transform = obj.transform;
            r.cached_values = obj.cached_values;
            r.base_channels = {};
            for chan = obj.base_channels
                r.base_channels{end + 1} = register.put('channels', chan{1});
            end
        end

        function reinitialize_values_from_base_channels(obj)
        % Normally, the LinOutputMix class caches the currently set values of
        % derived channels. This function will cause the class to get the
        % value of each base channel, and perform an pseudo inverse of the
        % transform to find the current values of derived channels.
        %
        % This function is called by the constructor.
            num = length(obj.base_channels);
            base_values = NaN(num, 1);
            for i = 1:num
                base_values(i, 1) = obj.base_channels{i}.get();
            end
            obj.cached_values = pinv(obj.transform) * base_values;
        end

        function val = getc(obj, chan)
            n = obj.get_chan_num(chan);
            val = obj.cached_values(n, 1);
        end

        function setc(obj, chan, val)
            n = obj.get_chan_num(chan);
            obj.cached_values(n, 1) = val;
            base_values = obj.transform * obj.cached_values;
            for i = 1:length(obj.base_channels)
                obj.base_channels{i}.set(base_values(i, 1));
            end
        end
    end
    methods(Access = private)
        function n = get_chan_num(obj, chan)
            n = find(strcmp(obj.derived_channel_names, chan));
            if isempty(n)
                error('Channel not found');
            elseif length(n) ~= 1
                error('Multiple channels have that name');
            end
        end
    end
end