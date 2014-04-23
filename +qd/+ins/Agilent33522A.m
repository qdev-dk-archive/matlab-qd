classdef Agilent33522A < qd.classes.ComInstrument
    properties
    end
    
    methods
         function  obj = Agilent33522A(com)
            obj@qd.classes.ComInstrument(com);
         end
         
         function r = model(obj)
            r = 'Agilent33522A AWG';
         end
         
         function r = channels(obj)
            r = {'freq1','volt1','offset1','wave1','freq2','volt2','offset2','wave2'};
         end
        
         function turn_on_output(obj, output)
             switch output
                 case 1
                    obj.send('OUTP1 ON')
                 case 2
                     obj.send('OUTP2 ON')
             end
         end

         function turn_off_output(obj, output)
             switch output
                 case 1
                    obj.send('OUTP1 OFF')
                 case 2
                     obj.send('OUTP2 OFF')
             end
         end
         
          function val = getc(obj, channel)
            switch channel
                case 'freq1'
                    val = obj.querym('SOUR1:FREQ?', '%f');
                case 'volt1'
                    val = obj.querym('SOUR1:VOLT?', '%f');
                case 'offset1'
                    val = obj.querym('SOUR1:VOLT:OFFS?', '%f');
                case 'freq2'
                    val = obj.querym('SOUR2:FREQ?', '%f');
                case 'volt2'
                    val = obj.querym('SOUR2:VOLT?', '%f');
                case 'offset2'
                    val = obj.querym('SOUR2:VOLT:OFFS?', '%f');
                otherwise
                    error('not supported.')
            end
          end
          
          function setc(obj, channel, value)
            switch channel
            % Set et output mode. Choose between
            % SIN,DC,SQU,RAMP,PULS,NOIS,PRBS,ARB
                case 'wave1'
                    obj.sendf('SOUR1:FUNC %s', value);
                case 'freq1'
                    obj.sendf('SOUR1:FREQ %.16E', value);
                case 'volt1'
                    obj.send('SOUR1:VOLT:UNIT VRMS'); % setting units to RMS voltage
                    obj.sendf('SOUR1:VOLT %.16E', value);
                case 'offset1'
                % Use offset in DC mode
                    obj.sendf('SOUR1:VOLT:OFFS %.16E', value);
                % Set et output mode. Choose between
                % SIN,DC,SQU,RAMP,PULS,NOIS,PRBS,ARB
                case 'wave2'
                    obj.sendf('SOUR2:FUNC %s', value);
                case 'freq2'
                    obj.sendf('SOUR2:FREQ %.16E', value);
                case 'volt2'
                    obj.sendf('SOUR2:VOLT:UNIT VRMS'); % setting units to RMS voltage
                    obj.sendf('SOUR2:VOLT %.16E', value);
                case 'offset2'
                % Use offset in DC mode
                    obj.sendf('SOUR2:VOLT:OFFS %.16E', value);
                otherwise
                    error('not supported.')
            end
          end   
    end

end