classdef Time < qd.classes.Instrument
    properties(Access=private)
        start_time;
    end
    
    methods
        function r = model(obj)
            r = 'Time';
        end

        function r = channels(obj)
            r = {'time'};
        end
        
        function reset(obj)
            obj.start_time = [];
        end
        
        function begin(obj)
            obj.start_time = tic;
        end
                  
        function setc(obj, channel, val)
            switch channel
                case 'time'
                    if(val == 0)
                        obj.reset();
                    end
                    if isempty(obj.start_time)
                        obj.begin();
                    end
                    wait_time = max(0, val - toc(obj.start_time));
                    pause(wait_time)
                otherwise
                    error('not supported.')
            end
        end
        
        function val = getc(obj, channel)
            switch channel
                case 'time'
                    if isempty(obj.start_time)
                        obj.begin();
                    end
                    val = toc(obj.start_time);
                otherwise
                    error('not supported.')
            end
        end
        
    end
end