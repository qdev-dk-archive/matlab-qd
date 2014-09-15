classdef LinOutputMix < qd.classes.Instrument
% Derive new channels from existing using a linear transformation.
%
% LinOutputMix(base_channels, transform, [names])
%
%   Constructs a LinOutputMix from a cell-array of n channels each supporting
%   the set method, an m-by-n matrix (let us call this T), and optionally a
%   cell-array of m strings. The constructed object is an instrument with m
%   channels with names from the 'names' argument. The instrument caches the
%   last set value from each of the m channels, let us call the vector of
%   these values V. Whenever one of the m derived channels are set, the vector
%   V is updated and
%
%       V' = T V
%   
%   is calculated. The base channels are then set to the values in V'.
%
%   In addition to the constructed channels, the instrument has a set of
%   channels with the same name, but prefixed with the string '_cache_'. This
%   lets you write to the cache directly without triggering a write to all the
%   base channels.
%
%   > m = qd.comb.LinOutputMix({gate1, gate2}, [1, 0.5; 1, -0.5], {'v', 'delta'});
%   > m.setc('_cache_delta', 0);  % This line will not cause base channels to be set
%   > m.setc('v', 1.4);           % This line will cause base channels to be set
%
%   Note: at the time of construction, get is called for each channel in
%   base_channels, and an initial V is calculated as V = T' V' where T' is the
%   Moore-Penrose pseudoinverse of T (which is equal to the inverse if it
%   exists).
    properties(GetAccess=public, SetAccess=private)
        base_channels
        transform
        inverse
        transform_has_inverse
        derived_channel_names
        cached_values
        future
    end
    methods
        function obj = LinOutputMix(base_channels, transform, derived_channel_names)
            transform_size = size(transform);
            qd.util.assert(length(base_channels) == transform_size(1));
            if nargin == 2
                derived_channel_names = qd.util.map(@(x) ['CH' num2str(x)], 1:transform_size(2));
            else
                qd.util.assert(length(derived_channel_names) == transform_size(2));
            end
            obj.derived_channel_names = derived_channel_names;
            obj.base_channels = base_channels;
            obj.transform = transform;
            % pinv(transform) is the pseudo inverse of transform.
            obj.inverse = pinv(transform);
            % The transform is invertible if it is square and has a non-zero
            % determinant. Here we check if the magnitude of the determinant
            % is much larger than zero compared to the machine precision.
            obj.transform_has_inverse = transform_size(1) == transform_size(2) && abs(det(transform)) > eps*1E4
            obj.reinitialize();
        end

        function chans = channels(obj)
            chans = obj.derived_channel_names;
            chans = [chans qd.util.map(@(x) ['_cache_' x], chans)];
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.Instrument(register);
            r.transform = obj.transform;
            r.inverse = obj.inverse;
            r.transform_has_inverse = obj.transform_has_inverse;
            r.cached_values = obj.cached_values;
            r.base_channels = {};
            for chan = obj.base_channels
                r.base_channels{end + 1} = register.put('channels', chan{1});
            end
        end

        function future = setc_async(obj, chan, val)
            if ~isempty(obj.future)
                obj.future.resolve();
            end
            if strncmp(chan, '_cache_', 7)
                n = obj.get_chan_num(chan(8:end));
                obj.cached_values(n, 1) = val;
                future = qd.classes.SetFuture.do_nothing_future();
                return
            end
            n = obj.get_chan_num(chan);
            obj.cached_values(n, 1) = val;
            base_values = obj.transform * obj.cached_values;
            future = [];
            for i = 1:length(obj.base_channels)
                future = future & obj.base_channels{i}.set_async(base_values(i, 1));
            end
            obj.future = future;
        end

        function reinitialize(obj)
        % Normally, the LinOutputMix class caches the currently set values of
        % derived channels. This function will cause the class to get the
        % value of each base channel, and perform a pseudo inverse of the
        % transform to find the current values of derived channels.
        %
        % This function is called by the constructor.
            num = length(obj.base_channels);
            base_values = NaN(num, 1);
            for i = 1:num
                base_values(i, 1) = obj.base_channels{i}.get();
            end
            obj.cached_values = obj.inverse * base_values;
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