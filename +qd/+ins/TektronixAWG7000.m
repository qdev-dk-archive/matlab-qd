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
            chunk_size = 90;
            for i = 1:ceil(length(waveform)/chunk_size)
                s_index = (i-1)*chunk_size;
                chunk = waveform(s_index+1:min(s_index+chunk_size, length(waveform)));
                as_bytes = typecast(single(chunk), 'uint8');
                % We put a single 0 byte after every 4 bytes for the marker day.
                with_markers = reshape([reshape(as_bytes, 4, []); zeros(1, length(chunk))], 1, []);
                block = char(with_markers);
                qd.util.assert(log10(length(block)) < 4);
                q = sprintf('wlist:wav:data "%s",%d,%d,#4%04d%s', ...
                    name, s_index, length(chunk), length(block), block);
                obj.send(q);
            end
        end

        % Will delete any existing waveform with this name.
        % Waveform is an array of integral values.
        function upload_waveform_int(obj, name, waveform)
            qd.util.assert(false);
            obj.sendf('wlist:wav:del "%s"', name);
            obj.sendf('wlist:wav:new "%s", %d, INT', name, length(waveform));
            % TODO
        end

        function r = describe(obj, register)
            r = obj.describe@qd.classes.ComInstrument(register);
            r.sour_freq = obj.querym('sour:freq?', '%f');
            r.outp1_stat = obj.query('outp1:stat?');
            r.outp2_stat = obj.query('outp2:stat?');
        end
    end
end