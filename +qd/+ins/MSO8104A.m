classdef MSO8104A < qd.classes.ComInstrument
    methods
        
        function obj = MSO8104A(com)
            com.InputBufferSize = 100000;   % This number needs to be adjusted so all data is read.
            obj = obj@qd.classes.ComInstrument(com);
            obj.com.EOIMode = 'on';
            obj.com.EOSMode = 'none';
            
        end
        
        function range = get_oscilRange(obj)
            range = str2double(obj.query(':TIMEbase:RANGe'));
        end
        
        function set_oscilRange(obj,range)
            obj.send(['TIMEBASE:RANGe ' num2str(range)])
        end
    
        function [signal,time] = get_trace(obj,channel)
            if ~any(channel==[1 2 3 4])
                display('Error: Channel has to be between 1 and 4')
            else
                obj.send('*CLS')
                obj.send([':waveform:source channel' num2str(channel)]) % Choose channel
                obj.send(':waveform:format ascii') % trace acquisition FOR ASCII
                
                obj.send(':waveform:data?'); % Ask for data
                signal = sscanf(strrep(obj.read(),',',' '),'%f'); % Read data
                

                tStart = obj.oscilXorigin();    % Get time start
                tDelta = obj.oscilXincrement();     % Get time stepsize
                
                % Calculate time scale
                time = (0:length(signal)-1)*tDelta + tStart;
	
            end
        end
        
        function xOrigin =  oscilXorigin(obj)	
            obj.send('*CLS');
            xOrigin = str2double(obj.query(':waveform:xorigin?'));
        end
        
        function xIncrement =  oscilXincrement(obj)	
            obj.send('*CLS');
            xIncrement = str2double(obj.query(':waveform:xinc?'));
        end
      
    end
    methods (Static)
        function r = model()
            r = 'Agilent Infiniium MSO8104A Scope';
        end
    end
end