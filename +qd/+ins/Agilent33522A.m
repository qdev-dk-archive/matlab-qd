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
            r = {'freq','volt','offset','wave'};
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
         
          function val = getc(obj, output, channel)
                switch output
                  case 1
                    switch channel
                        case 'freq'
                            val = obj.querym('SOUR1:FREQ?', '%f');
                        case 'volt'
                            val = obj.querym('SOUR1:VOLT?', '%f');
                        case 'offset'
                            val = obj.querym('SOUR1:VOLT:OFFS?', '%f');
                        otherwise
                            error('not supported.')
                    end
                  case 2
                      switch channel
                        case 'freq'
                            val = obj.querym('SOUR2:FREQ?', '%f');
                        case 'volt'
                            val = obj.querym('SOUR2:VOLT?', '%f');
                        case 'offset'
                            val = obj.querym('SOUR2:VOLT:OFFS?', '%f');
                        otherwise
                            error('not supported.')
                      end
                end
          end
          
          function setc(obj, output, channel, value)
            switch output
                  case 1
                    switch channel
                        % Set et output mode. Choose between
                        % SIN,DC,SQU,RAMP,PULS,NOIS,PRBS,ARB
                        case 'wave'
                            obj.sendf('SOUR1:FUNC %s', value);
                        case 'freq'
                            obj.sendf('SOUR1:FREQ %.16E', value);
                        case 'volt'
                            if value < 0.001
                                error('Vpp output must be => 0.001 V');
                            end
                            obj.send('SOUR1:VOLT:UNIT VRMS'); % setting units to RMS voltage
                            obj.sendf('SOUR1:VOLT %.16E', value);
                        case 'offset'
                            % Use offset in DC mode
                            obj.sendf('SOUR1:VOLT:OFFS %.16E', value);
                        otherwise
                            error('not supported.')
                    end
                  case 2
                      switch channel
                            % Set et output mode. Choose between
                            % SIN,DC,SQU,RAMP,PULS,NOIS,PRBS,ARB
                            case 'wave'
                                obj.sendf('SOUR2:FUNC %s', value);
                            case 'freq'
                                obj.sendf('SOUR2:FREQ %.16E', value);
                            case 'volt'
                                if value < 0.001
                                    error('Vpp output must be => 0.001 V')
                                end
                                obj.sendf('SOUR2:VOLT:UNIT VRMS'); % setting units to RMS voltage
                                obj.sendf('SOUR2:VOLT %.16E', value);
                            case 'offset'
                              % Use offset in DC mode
                              obj.sendf('SOUR2:VOLT:OFFS %.16E', value);
                            otherwise
                                error('not supported.')
                      end
            end   
        end
    end

end