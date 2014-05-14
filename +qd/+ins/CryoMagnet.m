classdef CryoMagnet < qd.classes.ComInstrument
    properties
        buffer_cleared
        lasterror
        
    end
    methods
        function obj = CryoMagnet(port)
            % Attocube Piezo step controller ANC150
            obj.com = serial(port, ...
                'BaudRate', 9600, ...
                'Parity',   'none', ...
                'DataBits', 8, ...
                'StopBits', 1, ...
                'Terminator', 'CR/LF');
            fopen(obj.com); % will be closed on delete by ComInstrument.
            obj.buffer_cleared = false;
            obj.lasterror = '';
        end
        
        function write(obj, req)
            fprintf(obj.com, '%s', req);
        end
        
        function rep = query(obj, req)
            % Send command and read the response.
            fprintf(obj.com, req);
            line=fscanf(obj.com);
            if(strfind(line, '------->'))
                error('Unrecognized command: %s', req)
            else
                rep = line;
            end
        end
        
        function setc(obj, channel, val)
            switch channel
                case 'rate'
                    % Pause on
                    obj.write('PAUSE ON');
                    % Set sweep rate
                    obj.write(['SET RAMP', rate]);
                case 'bfield'
                    % Set units to T
                    obj.write('TESLA ON');
                    % Turn mid off, set max on
                    obj.write('SET MID 0');
                    obj.write('HEATER ON');
                    obj.write(['SET MAX',bfield]);
                    % Go to field value
                    obj.write('RAMP MAX');
                    % Pause off
                    obj.write('PAUSE OFF');
                otherwise
                    error('Not supported.');
            end
        end
        
        function val = getc(obj, channel)
            switch channel
                case 'field'
                    try
                        % Set in tesla mode
                        obj.query('T 1');
                        % Get output
                        output = obj.query('G O');
                        val = output(strfind(output, 'OUTPUT: ')+8:strfind(output, ' TESLA'));
                        val = str2double(val);
                    catch err
                        disp(err)
                        val = obj.lasterror;
                    end
                case 'current'
                    try
                        % Set in tesla mode
                        obj.query('T 0');
                        % Get output
                        output = obj.query('G O');
                        val = output(strfind(output, 'OUTPUT: ')+8:strfind(output, ' AMPS'));
                        val = str2double(val);
                    catch err
                        disp(err)
                        val = obj.lasterror;
                    end
                case 'rate'
                    try
                        % Get rate
                        output = obj.query('G R');
                        val = output(strfind(output, 'RATE: ')+6:strfind(output, ' A/SEC'));
                        val = str2double(val);
                    catch err
                        disp(err)
                        val = obj.lasterror;
                    end
                otherwise
                    error('Not supported.');
            end
        end
    end
end