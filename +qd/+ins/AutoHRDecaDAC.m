classdef AutoHRDecaDAC < qd.classes.ComInstrument
	% - Use the AutoHRDecaDAC driver as you use the DecaDac or HRDecaDac drivers.
    % - The AutoHR version supports corarse and fine channels and automaticly set fine channels, set by
    %   *.set_board_mode({1,0,2,2,3}); % Modes 0:off, 1:fine  2:coarse 3: auto-fine.
    %   Set board mode before accessing channels, i.e. before naming them. CHANGE this stupid thing.

    properties(Access=private)
        board_mode = {2,2,2,2,2} % Modes 0:off, 1:fine  2:coarse (default), 3: auto-fine.
    end
    
    methods
        function obj = HRDecaDAC(port)
            obj.com = serial(port, ...
                'BaudRate', 9600, ...
                'Parity',   'none', ...
                'DataBits', 8, ...
                'StopBits', 1);
            fopen(obj.com); % will be closed on delete by ComInstrument.
            obj.set_board_mode(obj.board_mode) % Set boards mode to coarse by default.
        end
        
        function r = model(obj)
            r = 'DecaDAC';
        end

        function r = channels(obj)
            r = qd.util.map(@(n)['CH' num2str(n)], 0:19);
        end

        function chan = channel(obj, id)
            try
                n = qd.util.match(id, 'CH%d');
            catch
                error('No such channel (%s).', id);
            end
            mode = obj.board_mode{floor(n/4)+1};
            chan = qd.ins.AutoHRDecaDACChannel(n,mode);
            chan.channel_id = id;
            chan.instrument = obj;
        end

    	function set_board_mode(obj, boards)
        	    obj.board_mode = boards;
        	    % Put the boards in off, coarse, fine or auto-fine modes
        	    % Modes: 0:off, 1:fine,  2:coarse, 3:auto-fine.
        	    for i = 1:5;
        	        mode = boards{i};
        	        if ~any(mode == [0,1,2,3])
        	            mode = 0;
        	            warning('Mode must be 0,1,2 or 3. Now set to 0')
         	        end
        	        obj.queryf('B%d;M%d;', i-1, mode);
        	        board_channels = {obj.channels{1+4*(i-1):4+4*(i-1)}};
        	        for board_channel = board_channels
        	            obj.channel(board_channel{1}).set_mode(boards{i});
        	        end
        	    end
        end
        
        
        function r = get_board_mode(obj)
            r = obj.board_mode;
        end
        
        function r = describe(obj, register)
            r = obj.describe@qd.classes.ComInstrument(register);
            r.current_values = struct();
            for q = obj.channels()
                r.current_values.(q{1}) = obj.getc(q{1});
            end
        end
    end
end