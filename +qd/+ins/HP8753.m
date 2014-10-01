classdef HP8753 < qd.classes.ComInstrument
    properties
        numberOfPoints = 201;       % The default number of points is set to 201
        numberOfAverages = 1;       % Averaging is default set to 1

        outputBuffer = [];          % Buffer to hold the output data
    end

    methods

        function obj = HP8753(com)
                        
            % Increase InputBufferSize
            set(com, 'InputBufferSize', 30000);
            
            % Increase wait time
            set(com, 'Timeout', 30);
            
            % Create instrument
            obj@qd.classes.ComInstrument(com);
            
            % Check instrument is a HP8753
            answer = regexp(query(com,'*IDN?;'),',','split');
            if ~strcmpi(strtrim(answer{2}),'8753D')
                fclose(com);
                delete(obj);
                error('HP8753 is not found on specified port')  
            end
        end


        function value = getc(obj, channel)
            if any(strcmpi(channel,{'Mag','Phase'}))
                    % Check if there is data in the outputBuffer
                    if isempty(obj.outputBuffer)

                        % Read data from Network Analyzer
                        obj.fillOutputBuffer(channel)

                    end

                    % Read from the outputBuffer
                    value = obj.outputBuffer(1);
                    obj.outputBuffer(1) = [];

            elseif strcmpi(channel,'Power')
                    value = obj.getPower();
            else
                    error('Error: Channel not supported.')
            end
        end

        function setc(obj,channel,value)
            switch channel
                case 'Power'
                    obj.setPower(value)
                otherwise
                    error('Error: Channel not supported.')
            end
        end

        function fillOutputBuffer(obj, channel)
            [mag, phase] = obj.read_waveform();

            % Save data for output
            switch lower(channel)
                case 'mag'
                    % Calculate magnitude and store in outputbuffer
                    obj.outputBuffer = mag;
                case 'phase'
                    % Calculate phase and store in outputbuffer
                    obj.outputBuffer = phase;
            end
        end

        function [mag, phase] = read_waveform(obj)

            % Set data return format and trigger a single measurement
            success = obj.query(['FORM5; OPC?; NUMG ' num2str(obj.numberOfAverages) ';']);
            if ~success
                error('Error: Measurement not succesfull')
            end

            % Read data back from analyzer
            % Ask for data
            obj.send('OUTPDATA');

            % Read out #A from binblock
            fread(obj.com, 2, 'char');

            % Read out block size
            BlockSize=fread(obj.com, 1, 'uint16')/4;

            % Read out trace data
            rawData=fread(obj.com, BlockSize, 'float32');

            numberOfPoints=BlockSize/2;

            % Allocate space for data array
            data=zeros(numberOfPoints,2);

            % Reshape output array into two columns
            data(:,1) = rawData(1:2:end); % Odd points
            data(:,2) = rawData(2:2:end); % Even points

            mag = 20*log10(sqrt(data(:,1).^2+data(:,2).^2));
            phase = unwrap(angle(data(:,1)+1i*data(:,1)));
        end


        function setPower(obj,excitationPower)
            % Set power output
            obj.send(['POWE ' num2str(excitationPower) ';']);

            % Check power has been set
            if obj.verifyQuery( excitationPower, obj.getPower() )
                error('Error: Power not set correctly')
            end
        end

        function excitationPower = getPower(obj)
            % get power output
            excitationPower = str2double(obj.query('POWE?;'));
        end

        function setStartFrequency(obj,frequency)
            % Set start frequency
            obj.send(['STAR ' num2str(frequency) ';']);

            % Check start frequency has been set
            if obj.verifyQuery( frequency, obj.getStartFrequency() )
                error('Error: Start frequency not set correctly')
            end
        end

        function startFrequency = getStartFrequency(obj)
            % Get start frequency
            startFrequency = str2double(obj.query(['STAR?;']));
        end

        function setStopFrequency(obj,frequency)
            % Set stop frequency
            obj.send(['STOP ' num2str(frequency) ';']);

            % Check stop frequency has been set
            if obj.verifyQuery( frequency, obj.getStopFrequency() )
                error('Error: Stop frequency not set correctly')
            end
        end

        function stopFrequency = getStopFrequency(obj)
            % Get stop frequency
            stopFrequency = str2double(obj.query(['STOP?;']));
        end

        function setNumberOfPoints(obj,numberOfPoints)
            % Check number of points is valid
            if ~any(numberOfPoints == [3 11 21 26 51 101 201 401 801 1601])
                error('Error: Number of points must be in {3, 11, 21, 26, 51, 101, 201, 401, 801, 1601}')
            end

            % Set number of points
            obj.send(['POIN ' num2str(numberOfPoints) ';']);

            % Check number of points has been set
            if obj.verifyQuery( numberOfPoints, obj.getNumberOfPoints() )
                error('Error: Number of points not set correctly')
            end
        end

        function numberOfPoints = getNumberOfPoints(obj)
            % Get number of points
            numberOfPoints = round(str2double(obj.query('POIN?;')));

            % Store in object
            obj.numberOfPoints = numberOfPoints;
        end

        function setNumberOfAverages(obj,numberOfAverages)
            % Check if averaging should be enabled
            if numberOfAverages > 1
                obj.send('AVERON;'); % Enable averaging
            else
                obj.send('AVEROFF;'); % disable averaging
            end

            % Send number of averages to the instrument
            obj.send(['AVERFACT ' num2str(numberOfAverages) ';']);
            if obj.verifyQuery( numberOfAverages, obj.getNumberOfAverages() )
                error('Error: Averaging not set correctly')
            end
        end

        function numberOfAverages = getNumberOfAverages(obj)
            % Get number of averages
            numberOfAverages = str2double(obj.query('AVERFACT?;'));

            % Store the number of averages
            obj.numberOfAverages = numberOfAverages;
        end

    end

    methods (Static)
        function r = model()
            r = 'HP8753 Network Analyzer';
        end

        function r = channels()
            r = {'Mag' 'Phase' 'Power'};
        end

        function result = verifyQuery(inquiry,answer)
            result = ~eq(inquiry,answer);
        end
    end
end
