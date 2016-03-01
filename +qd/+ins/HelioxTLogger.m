classdef HelioxTLogger < qd.classes.Instrument
    properties
        log_directory;
    end

    methods
        function obj = HelioxTLogger(log_directory)
            log_directory_type = exist(log_directory);
            % Assert that log_directory is a folder (which has magic number 7).
            assert(log_directory_type==7);
            obj.log_directory = log_directory;
        end

        function r = channels(obj)
            r = {'Time', 'Sorb', 'Pot_low', 'Pot_high', 'Switch', 'PTC_2nd'};
        end

        function setc(obj, channel, val)
            error('Not supported. Use Labview to set temperature.')
        end

        function val = getc(obj, channel)
            channels = obj.channels();
            index = 1;
            for test_channel = channels
                if strcmp(channel, test_channel{1});
                    temperature_list = obj.read_temps();
                    val = temperature_list(index);
                    return
                end
                index = index + 1;
            end
            if index > 6
                error('Channel not available.')
            end
        end

        function temperature_list = read_temps(obj)
            full_path = obj.get_full_path_of_last_modified();
            last_line = obj.read_last_line(full_path);
            temperature_list = str2num(last_line);
        end

        function full_path = get_full_path_of_last_modified(obj)
            pattern = strcat(obj.log_directory, '\*.dat');
            d = dir(pattern);
            [~,idx] = max([d.datenum]);
            filename = d(idx).name;
            full_path = fullfile(obj.log_directory, filename);
        end

        function last_line = read_last_line(obj, full_path)
            % Open the text file as a binary file, seek to the end of the file,
            % and read single characters (i.e. bytes) backwards from the end of
            % the file.
            % This code will read characters from the end of the file until it hits a
            % newline character (ignoring a newline if it finds it at the very end of
            % the file). From
            % http://stackoverflow.com/questions/2659375/matlab-command-to-access-the-last-line-of-each-file
            fid = fopen(full_path, 'r');
            last_line = '';
            offset = 1;
            fseek(fid, -offset, 'eof');
            newChar = fread(fid, 1, '*char');
            while (~strcmp(newChar,char(10))) || (offset==1)
                last_line = [newChar last_line];
                offset = offset + 1;
                fseek(fid, -offset, 'eof');
                newChar = fread(fid, 1, '*char');
            end
            fclose(fid);
        end
    end
end
