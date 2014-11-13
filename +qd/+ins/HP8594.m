classdef HP8594 < qd.classes.ComInstrument
    properties
        frequencyLimits = [9e3 2.9e9]   % The frequency limits of the spectrum analyzer
        startFrequency  = 9e3
        stopFrequency   = 2.9e9
    end
    methods
        
        function obj = HP8594(com)
            com.InputBufferSize = 2^12;
            obj = obj@qd.classes.ComInstrument(com);
            obj.com.EOIMode = 'on';
            obj.com.EOSMode = 'none';
            
            % Set default properties
            obj.start_freq(obj.startFrequency)
            obj.stop_freq(obj.stopFrequency)
        end
        
        function start_freq(obj,value)
            if value >= min(obj.frequencyLimits) && value <= max(obj.frequencyLimits)
                obj.send(['FA',num2str(value),'HZ;'])
                obj.startFrequency = value;
            else
                display('Error, frequency outside range')
            end
        end
        
        function stop_freq(obj,value)
            if value >= min(obj.frequencyLimits) && value <= max(obj.frequencyLimits)
                obj.send(['FB',num2str(value),'HZ;'])
                obj.stopFrequency = value;
            else
                display('Error, frequency outside range')
            end
        end

        function span_freq(obj,value)
            if value <= (max(obj.frequencyLimits) - min(obj.frequencyLimits)) 
                obj.send(['SP',num2str(value),'HZ;'])
                
                % Get the start and stop frequency
                obj.getStartStopFrequency()
            else
                display('Error, frequency outside range')
            end
        end

        function center_freq(obj,value)
            if value >= min(obj.frequencyLimits) && value <= max(obj.frequencyLimits) 
                obj.send(['CF',num2str(value),'HZ;'])

                % Get the start and stop frequency
                obj.getStartStopFrequency()
            else
                display('Error, frequency outside range')
            end
        end

        
        function [amplitude, frequency] = get_trace(obj)
           
            % Send command to acquire single trace
            obj.send('SNGLS;')  % SiNGLe Sweep
            obj.send('TS;')     % Take Sweep

            % Prepare data output
            obj.send('TDF P;')  % Trace Data Format Point; sends data in real number format
            obj.send('MDS W;')  % Measurement Data Size Word; data is sent as 16-bit 
            obj.send('TA;')     % Transfer A; data is transfered from channel A
            
            % Retrieve data in blocks of 64
            amplitude = fscanf(obj.com,'%f',401);

            % Update frequency
            obj.getStartStopFrequency()
            frequency = linspace(obj.startFrequency,obj.stopFrequency,length(amplitude))';

        end

        function getStartStopFrequency(obj)
            obj.startFrequency = str2double(obj.query('FA?;'));
            obj.stopFrequency  = str2double(obj.query('FB?;'));
        end
        
    end

    methods (Static)
        function r = model()
            r = 'HP8594 Spectrum Analyser';
        end
    end
end