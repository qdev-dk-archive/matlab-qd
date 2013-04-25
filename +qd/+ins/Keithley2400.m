classdef Keithley2400 < qd.classes.FileLikeInstrument
	% Currently this class only supports current mode.
	% TODO set range.
    methods

    	function obj = Keithley2400(com)
    		obj = obj@qd.classes.FileLikeInstrument(com);
    	end

        function r = model(obj)
            r = 'Keithley 2400 SourceMeter';
        end

        function r = channels(obj)
            r = {'curr', 'volt', 'resist'};
        end

        function reset(obj)
        	obj.send('*rst');
        	obj.init();
       	end

       	function init(obj)
        	obj.send(':form:elem volt,curr');
        end

       	function set_curr_compliance(obj, level)
       		obj.sendf(':CURR:PROT %.16E', level);
       	end

       	function turn_on_output(obj)
       		% TODO handle volt mode.
       		obj.send(':CONF:CURR')
       	end

       	function turn_off_output(obj)
       		obj.send(':OUTP:STAT 0');
       	end

       	function setc(obj, channel, value)
       		switch channel
       			case 'volt'
       				obj.sendf('SOUR:VOLT %.16E', value)
       			otherwise
       				error('not supported.')
       		end
       	end

       	function val = getc(obj, channel)
       		switch channel
       			case 'curr'
       				res = obj.querym(':READ?', '%g, %g'); % voltage, current
       				val = res(2);
       			case 'volt'
       				res = obj.querym(':READ?', '%g, %g');
       				val = res(1);
       			case 'resist'
       				res = obj.querym(':READ?', '%g, %g');
       				val = res(1) / res(2);
       			otherwise
       				error('not supported.')
       		end
       	end
   		
    end
end