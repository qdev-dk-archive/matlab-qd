classdef HP3561A < qd.classes.ComInstrument
    properties
        %bla bla
    end
    methods
        
        function obj = HP3561A(com)
            obj = obj@qd.classes.ComInstrument(com);
            obj.com.EOIMode = 'on';
            obj.com.EOSMode = 'none';
            obj.send('KEYD;');
            obj.send('SNGL;');
            obj.send('VSLI;');
            obj.send('HANN;');
        end
        
        function r = model(obj)
            r = 'HP3561A Spectrum Analyser';
        end
        
        function start_freq(obj,value)
            obj.send(['SF',num2str(value),'HZ;'])
        end
        
        function span_freq(obj,value)
            obj.send(['SP',num2str(value),'HZ;'])
        end
        
        function get_trace(obj,start,stop)
            obj.send('DSTB;');
            junkbytes1 = fread(obj.com, 2);
            junkbytes2 = fread(obj.com, 2);
            clear junkbytes1
            clear junkbytes2
            tempdata = [fread(obj.com, 512); fread(obj.com, 512)];
            tempdata = tempdata(1:802);
            tempdata = tempdata(1:2:end).*256 + tempdata(2:2:end);
            datadB = tempdata.*0.005; %Convert to dB
            bandwidth = (stop-start)/400*1.5; %1.5 for Hanning window
            data = 10.^(datadB/20)./2.4214e13; %Convert to mV_RMS
            freq = [0:1:400];
            freq = ck.scaledata(freq,start,stop);
            plot(freq,data)
            grid on
            title(['@ 3.6T, nu = 2, Rxy, Bias = 0nA, Bandwidth = ',num2str(bandwidth),'Hz, AC coupled ,ground@BOB'])
            xlabel('Frequency [Hz]');
            ylabel('Peak [mV_{RMS}]');
            %export_fig C:\Users\QDevTriton2\Documents\MATLAB\+ck\Data\Noise_140213\Rxy_bias0nA_span100Hz_nu=2_jappreampnoground_ground@BOB.pdf -transparent
        end
        
        function move_marker(obj,value)
            obj.send(['MMKP',num2str(value),'HZ;'])
        end
        
        function move_marker_to_peak(obj)
            obj.send('MMK;')
        end
    end
end