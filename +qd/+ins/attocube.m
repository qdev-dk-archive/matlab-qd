classdef attocube < qd.classes.ComInstrument
    properties
        buffer_cleared
        lasterror
        ref1
        ref2
    end
    methods
        function obj = attocube(port)
            % Attocube Piezo step controller ANC150
            obj.com = serial(port, ...
                'BaudRate', 38400, ...
                'Parity',   'none', ...
                'DataBits', 8, ...
                'StopBits', 1);
            fopen(obj.com); % will be closed on delete by ComInstrument.
            obj.buffer_cleared = false;
            obj.lasterror = '';
        end

        function r = model(obj)
            r = 'attocube';
        end
        
        function clear_buffer(obj)
            try
                fread(obj.com, obj.com.BytesAvailable); % clear hardware buffer
            catch err
                if strcmp(err.identifier, 'MATLAB:serial:fread:invalidSIZEpos')
                    obj.buffer_cleared = true;
                else
                    disp(err);
                end
            end
        end
        
        function write(obj, req)
            fprintf(obj.com, '%s\r\n', req);
            line = '';
            lastline = '';
            while ~(strcmp(line, 'OK') || strcmp(line, 'ERROR'))
                lastline = line;
                line = fscanf(obj.com);
                line = cellstr(line);
                line = line{1};
            end
            if strcmp(line, 'ERROR')
                obj.lasterror = lastline;
                error(obj.lasterror);
            end
        end
        
        function rep = query(obj, req)
            % Send command and read the response.
            fprintf(obj.com, '%s\r\n', req);
            line = '';
            lastline = '';
            while ~(strcmp(line, 'OK') || strcmp(line, 'ERROR'))
                lastline = line;
                line = fscanf(obj.com);
                line = cellstr(line);
                line = line{1};
                if(strcmp(line, ''))
                    obj.clear_buffer();
                end
            end
            if strcmp(line, 'ERROR')
                obj.lasterror = lastline;
                rep = false;
                error(obj.lasterror);
            else
                rep = lastline;
            end
        end
        
        function setc(obj, channel, val)
            switch channel
                case 'mode'
                    obj.write(['setm 1 ' val]);
                case 'volt'
                    obj.write(['setv 1 ' num2str(val)]);
                case 'freq'
                    obj.write(['setf 1 ' num2str(val)]);
                otherwise
                    error('Not supported.');
            end
        end
        
        function stepup(obj, steps)
            obj.write(['stepu 1 ' num2str(steps)]);
        end
        
        function stepdown(obj, steps)
            obj.write(['stepd 1 ' num2str(steps)]);
        end
        
        function val = getc(obj, channel)
            switch channel
                case 'mode'
                    try
                        val = obj.querym('getm 1', 'mode = %s');
                    catch err
                        disp(err)
                        val = obj.lasterror;
                    end
                case 'volt'
                    val = str2num(obj.querym('getv 1', 'voltage = %s V'));
                case 'freq'
                    val = str2num(obj.querym('getf 1', 'frequency = %s Hz'));
                otherwise
                    error('Not supported.');
            end
        end
        
        function stop(obj)
            obj.query('stop 1');
        end
        
        function ret = get_angle(obj)
            ret = -330.14*obj.ref1()/obj.ref2()+191.59;
        end
    end
end