classdef TektronixAWG7000 < qd.classes.ComInstrument
    methods
        function obj = TektronixAWG7000(varargin)
            obj@qd.classes.ComInstrument(varargin{:});
        end

        % Will delete any existing waveform with this name.
        % Waveform is an array of floating point values.
        function upload_waveform_real(obj, name, waveform)
            obj.sendf('wlist:wav:del "%s"', name);
            obj.sendf('wlist:wav:new "%s",%d,REAL', name, length(waveform));
            as_bytes = typecast(single(waveform), 'uint8');
            % We put a single 0 byte after every 4 bytes for the marker day.
            with_markers = reshape([reshape(as_bytes, 4, []); zeros(1, length(waveform))], 1, []);
            block = char(with_markers);
            qd.util.assert(log10(length(block)) < 9);
            q = sprintf('wlist:wav:data "%s",#%1d%d%s', ...
                name, ceil(log10(length(block))), length(block), block);
            obj.send(q);
        end

        % Will delete any existing waveform with this name.
        % Waveform is an array of integral values.
        function upload_waveform_int(obj, name, waveform)
            qd.util.assert(false);
            obj.sendf('wlist:wav:del "%s"', name);
            obj.sendf('wlist:wav:new "%s", %d, INT', name, length(waveform));
            % TODO
        end
    end
end