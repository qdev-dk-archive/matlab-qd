classdef Alazar9440 < qd.classes.Instrument
    properties
        systemID = 1                % TODO: Add support for more than one system
        boardID                     % ID of the board
        boardHandle                 % Hande for Alazar Api
        
        configuration               % Name of the loaded configuration
        channelConfig = struct      % Infomation about channel config
        clockConfig = struct        % Infomation about clock config
        triggerConfig = struct      % Infomation about trigger config
        acquisitionConfig = struct  % Infomation about acquisition config
        
        outputBuffer                % Buffer to hold data
        
        AlazarDefs                  % Definitions for Alazar Api
        verbose = false             % verbose option
    end
    
    methods
        function obj = Alazar9440(boardID)
            % Load the Alazar Definitions
            obj.loadAlazarDefs;
            
            % Store the ID of the board
            obj.boardID = boardID;
            
            % initilize alazar API and get handle to board
            obj.initilize;
            
            % Set initial properties of Alazar
            obj.acquisitionConfig.triggerMode = 'NPT';
            
            % Run default channel configuration
            obj.configureChannel(1,'DC',4)
            obj.configureChannel(2,'DC',4)
            obj.configureChannel(3,'DC',4)
            obj.configureChannel(4,'DC',4)
        end
        
        function obj = initilize(obj)
            % Load Alazar Defs as a
            a = obj.AlazarDefs;
            
            % Disable warnings for Alazar API during library loading
            warning('off','MATLAB:loadlibrary:TypeNotFound')
            
            % Load driver library
            if ~obj.alazarLoadLibrary()
                error('Error: ATSApi.dll not loaded');
            end
            
            
            % Get number of Alazar systems
            systemCount = calllib('ATSApi','AlazarNumOfSystems');
            
            % Print System information to command window
            if systemCount < 1
                error('Error: No Alazar systems found');
            elseif systemCount > 1
                % TODO implement support for multiple systems
            else
                % Print the found systems to command window
                display(sprintf('Found Alazar System, SystemID %u', obj.systemID));
                
                ID = obj.boardID;
                hBoard = calllib('ATSApi', 'AlazarGetBoardBySystemID', obj.systemID, ID);
                setdatatype(hBoard, 'voidPtr', 1, 1);
                
                % Check that boardhandle is valid
                if hBoard.Value == 0
                    error('Error: Unable to open board system ID %u board ID %u', obj.systemID, ID);
                end
                
                % Check if board is ATS9440
                if ~strcmpi('ATS9440',obj.boardTypeIdToText(calllib('ATSApi','AlazarGetBoardKind',hBoard)));
                    error('Error: ATS9400 not found at specified boardID')
                else
                    % Store the boardhandle
                    obj.boardHandle = hBoard;
                end
                
                
                % Display the driver library (ATSApi.dll) version
                if obj.verbose
                    [returnCode, sdkMajor, sdkMinor, sdkRevision] 	=	...
                        calllib('ATSApi', 'AlazarGetSDKVersion', 0, 0, 0);
                    
                    % Check for errors
                    if returnCode ~= a.ApiSuccess
                        error('Error: AlazarGetSDKVersion failed -- %s',obj.errorToText(returnCode));
                    else
                        display(sprintf('SDK version = %d.%d.%d', sdkMajor, sdkMinor, sdkRevision));
                    end
                    
                    % Use AlazarTech function to acquire full board information
                    if ~obj.displaySystemInfo()
                        error('Error: Board information gathering failed');
                    end
                    
                    if ~obj.displayBoardInfo()
                        error('Error: Board information gathering failed');
                    end
                    
                end
            end
        end
        
        function value = getc(obj, channel)
            
            % Check if there is data in the outputBuffer
            if isempty(obj.outputBuffer)
              
                % Read data from Alazar
                obj.read(channel)
                
            end
            
            % Read from the outputBuffer
            value = obj.outputBuffer(1);
            obj.outputBuffer(1) = [];
            
            
        end % TODO
        
        function configureChannel(obj,channel,varargin)
            % Load Alazar Defs as a
            a = obj.AlazarDefs;
            
            % Parse the varargin arguments
            if length(varargin) == 2
                coupling = varargin{1};
                range = varargin{2};
                
                
                % Verify the coupling
                switch upper(coupling)
                    case 'AC'
                        obj.channelConfig(channel).coupling = a.AC_COUPLING;
                    case 'DC'
                        obj.channelConfig(channel).coupling = a.DC_COUPLING;
                    otherwise
                        error('Channel coupling has to be AC or DC')
                end
                
                % Verify the range
                if any(range==[100 0.1])
                    obj.channelConfig(channel).range = a.INPUT_RANGE_PM_100_MV;
                elseif any(range==[200 0.2])
                    obj.channelConfig(channel).range = a.INPUT_RANGE_PM_200_MV;
                elseif any(range==[400 0.4])
                    obj.channelConfig(channel).range = a.INPUT_RANGE_PM_400_MV;
                elseif any(range==[1000 1])
                    obj.channelConfig(channel).range = a.INPUT_RANGE_PM_1_V;
                elseif any(range==[2000 2])
                    obj.channelConfig(channel).range = a.INPUT_RANGE_PM_2_V;
                elseif any(range==[4000 4])
                    obj.channelConfig(channel).range = a.INPUT_RANGE_PM_4_V;
                else
                    error('Error: Range has to be in [0.1 0.2 0.4 1 2 4]')
                end
                
                
                
            else % Use loaded config
                if isempty(obj.channelConfig(channel).coupling)
                    error('Error: Channel coupling not set')
                end
                if isempty(obj.channelConfig(channel).range)
                    error('Error: Channel range not set')
                end
            end
            
            
            % Send the input configuration to the card
            returnCode = calllib('ATSApi','AlazarInputControl', ...
                obj.boardHandle,                    ... % Board ID
                2^(channel-1),                      ... % Channel to be configured
                obj.channelConfig(channel).coupling,... % Coupling type (AC/DC)
                obj.channelConfig(channel).range,   ... % Input range
                a.IMPEDANCE_50_OHM);                    % Input impedance
            
            % Check for errors
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarInputControl failed -- %s',errorToText(returnCode));
            end
            
            % Retrieve the input of the channel to convert to a voltage
            % later
            obj.channelConfig(channel).inputRange = obj.inputRangeIdToVolts(obj.channelConfig(channel).range);
        end
        
        function configureClock(obj,varargin)
            % Load Alazar Defs as a
            a = obj.AlazarDefs;
            
            % Parse the varargin arguments
            if length(varargin) == 4
                type = varargin{1};
                sampleRate = varargin{2};
                edge = varargin{3};
                decimation = varargin{4};
                
                
                % Verify the type
                switch upper(type)
                    case 'INTERNAL_CLOCK'
                        obj.channelConfig(channel).coupling = a.INTERNAL_CLOCK;
                    case 'FAST_EXTERNAL_CLOCK'
                        obj.channelConfig(channel).coupling = a.FAST_EXTERNAL_CLOCK;
                    case 'SLOW_EXTERNAL_CLOCK'
                        obj.channelConfig(channel).coupling = a.SLOW_EXTERNAL_CLOCK;
                    case 'EXTERNAL_CLOCK_10MHZ_REF'
                        obj.channelConfig(channel).coupling = a.EXTERNAL_CLOCK_10MHz_REF;
                    otherwise
                        error('Clock type not recognized')
                end
                
                % TODO Verify the sample
                % TODO Verify the edge
                % TODO Verify the decimation
                
                
            else % Use loaded config
                if isempty(obj.clockConfig.type)
                    error('Error: Clock type not set')
                end
                if isempty(obj.clockConfig.sampleRate)
                    error('Error: Clock sampleRate not set')
                end
                if isempty(obj.clockConfig.edge)
                    error('Error: Clock edge not set')
                end
                if isempty(obj.clockConfig.decimation)
                    error('Error: Clock decimation not set')
                end
            end
            
            
            % Set the options for the clock to the Alazar Card
            returnCode = calllib('ATSApi','AlazarSetCaptureClock',  ...
                obj.boardHandle,                ... % Board to be configured
                obj.clockConfig.type,           ... % Specify the type of clock, internal vs external
                obj.clockConfig.sampleRate,     ... % Set the sample rate, in case of external clock, this is just defined from the clock.
                obj.clockConfig.edge,           ... % Set the edge to trigger on (rising vs falling)
                obj.clockConfig.decimation);        % Set the decimation. in case of external clock, decimation is disabled.
            
            % Check for errors
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarSetCaptureClock failed -- %s',obj.errorToText(returnCode));
            end
        end % TODO
        
        function configureTrigger(obj,varargin)
            % Load Alazar Defs as a
            a = obj.AlazarDefs;
            
            % Parse the varargin arguments
            if length(varargin) == 9
                operation 	= varargin{1};
                engineID_J 	= varargin{2};
                channel_J 	= varargin{3};
                slope_J 	= varargin{4};
                level_J 	= varargin{5};
                engineID_K 	= varargin{6};
                channel_K 	= varargin{7};
                slope_K 	= varargin{8};
                level_K 	= varargin{9};
                
                
                
                % TODO Verify operation
                % TODO Verify engineID_J
                % TODO Verify channel_J
                % TODO Verify slope_J
                % TODO Verify level_J
                % TODO Verify engineID_K
                % TODO Verify channel_K
                % TODO Verify slope_K
                % TODO Verify level_K
                
                
            else % Use loaded config
                
                if isempty(obj.triggerConfig.operation)
                    error('Error: Trigger operation not set')
                end
                if isempty(obj.triggerConfig.engineID_J)
                    error('Error: Trigger engineID_J not set')
                end
                if isempty(obj.triggerConfig.channel_J)
                    error('Error: Trigger channel_J not set')
                end
                if isempty(obj.triggerConfig.slope_J)
                    error('Error: Trigger slope_J not set')
                end
                if isempty(obj.triggerConfig.level_J)
                    error('Error: Trigger level_J not set')
                end
                if isempty(obj.triggerConfig.engineID_K)
                    error('Error: Trigger engineID_K not set')
                end
                if isempty(obj.triggerConfig.channel_K)
                    error('Error: Trigger channel_K not set')
                end
                if isempty(obj.triggerConfig.slope_K)
                    error('Error: Trigger slope_K not set')
                end
                if isempty(obj.triggerConfig.level_K)
                    error('Error: Trigger level_K not set')
                end
                
            end
            
            
            
            % Set the trigger inputs and trigger levels
            returnCode = calllib('ATSApi','AlazarSetTriggerOperation',  ...
                obj.boardHandle,                ... % Board to be configured
                obj.triggerConfig.operation,     ... % Trigger engine operation: determine trigger event from up to two trigger sources
                obj.triggerConfig.engineID_J,    ... % Source1: Set the engine to be configured
                obj.triggerConfig.channel_J,     ... % Source1:  Specify the channel of the trigger signal
                obj.triggerConfig.slope_J,       ... % Source1:  Set the slope to trigger from, (positive or negative)
                obj.triggerConfig.level_J,       ... % Source1:  Set the trigger level from 0 (-range) to 255 (+range)
                obj.triggerConfig.engineID_K,    ... % Source2: Set the engine to be configured
                obj.triggerConfig.channel_K,     ... % Source2: Specify the channel of the trigger signal
                obj.triggerConfig.slope_K,       ... % Source2: Set the slope to trigger from, (positive or negative)
                obj.triggerConfig.level_K);          % Source2: Set the trigger level from 0 (-range) to 255 (+range)
            
            % Check for errors
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarSetExternalTrigger failed -- %s',obj.errorToText(returnCode));
            end
            
            % Set the external trigger settings, (if external trigger is used)
            if obj.triggerConfig.channel_J == a.TRIG_EXTERNAL || obj.triggerConfig.channel_K == a.TRIG_EXTERNAL
                returnCode = calllib('ATSApi', 'AlazarSetExternalTrigger',  ...
                    obj.boardHandle,                    ... % Board to be configured
                    obj.triggerConfig.Ext_coupling,     ... % Trigger coupling type (AC or DC)
                    obj.triggerConfig.Ext_range);           % Trigger voltage range
                
                % Check for errors
                if returnCode ~= a.ApiSuccess
                    error('Error: AlazarSetExternalTrigger failed -- %s', errorToText(returnCode));
                end
            end
            
        end % TODO
        
        function loadConfig(obj,config)
            
            % Extract configuration from configfile
            if exist([config '.mat'],'file') == 2
                config = load([config '.mat']);
                obj.configuration = config;
            else
                disp('Configuration is not available, construct one using AlazarGUI')
                return;
            end
            
            
            % Import information from config file (Old style).
            obj.channelConfig(1).coupling 	= config.CH1_coupling;
            obj.channelConfig(1).range 		= config.CH1_range;
            obj.channelConfig(2).coupling 	= config.CH2_coupling;
            obj.channelConfig(2).range 		= config.CH2_range;
            obj.channelConfig(3).coupling 	= config.CH3_coupling;
            obj.channelConfig(3).range 		= config.CH3_range;
            obj.channelConfig(4).coupling 	= config.CH4_coupling;
            obj.channelConfig(4).range 		= config.CH4_range;
            
            obj.clockConfig.type 			= config.CLK_type;
            obj.clockConfig.sampleRate 		= config.CLK_sampleRate;
            obj.clockConfig.frequency 		= config.CLK_frequency;
            obj.clockConfig.edge 			= config.CLK_edge;
            obj.clockConfig.decimation 		= config.CLK_decimation;
            
            obj.triggerConfig.operation 	= config.TRIG_operation;
            obj.triggerConfig.engineID_J 	= config.TRIG_engineID1;
            obj.triggerConfig.channel_J 	= config.TRIG_channel1;
            obj.triggerConfig.slope_J 		= config.TRIG_slope1;
            obj.triggerConfig.level_J 		= config.TRIG_level1;
            obj.triggerConfig.engineID_K 	= config.TRIG_engineID2;
            obj.triggerConfig.channel_K 	= config.TRIG_channel2;
            obj.triggerConfig.slope_K 		= config.TRIG_slope2;
            obj.triggerConfig.level_K 		= config.TRIG_level2;
            obj.triggerConfig.Ext_coupling	= config.TRIG_coupling;
            obj.triggerConfig.Ext_range		= config.TRIG_range;
            obj.triggerConfig.delay 		= config.TRIG_delay;
            obj.triggerConfig.timeout 		= config.TRIG_timeout;
            obj.triggerConfig.triggerMode 	= config.triggerMode;
            
            obj.acquisitionConfig.triggerMode 				= config.triggerMode;
            obj.acquisitionConfig.acquisitionMode 	 		= config.acqmode;
            obj.acquisitionConfig.preTriggerSamples			= config.preTriggerSamples;
            obj.acquisitionConfig.postTriggerSamples		= config.postTriggerSamples;
            obj.acquisitionConfig.recordsPerBuffer			= config.recordsPerBuffer;
            obj.acquisitionConfig.bufferCount			    = 2; % TODO, consider of more than two buffer is needed
            obj.acquisitionConfig.buffersPerAcquisition     = 1; % TODO, consider of more than one buffer is needed
            obj.acquisitionConfig.bufferTimeout_ms			= config.bufferTimeout_ms;
            
            
            % Run configuration
            obj.configureChannel(1)
            obj.configureChannel(2)
            obj.configureChannel(3)
            obj.configureChannel(4)
            
            obj.configureClock()
            obj.configureTrigger()
            
            
            
        end
        
        function read(obj,channel)

            switch upper(channel)
                case 'A'
                    channel = 1;
                case 'B'
                    channel = 2;
                case 'C'
                    channel = 3;
                case 'D'
                    channel = 4;
            end
            
            % Alazar uses a channelMask to set the channel it uses.
            % Consider the 4 digit binary representation (d_D d_C d_B d_A')
            % Each digit (d_k) can be 1 or zero, and determines if the
            % channel is in use.
            channelMask = 2^(channel-1);
            
            
            % Load Alazar Defs as a
            a = obj.AlazarDefs;
            
            % Get the maximum sample size and memory size from the board
            [returnCode, obj.boardHandle, maxSamplesPerRecord, bitsPerSample] 	=	...
                calllib('ATSApi', 'AlazarGetChannelInfo', obj.boardHandle, 0, 0);
            
            % Check for errors
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarGetChannelInfo failed -- %s',obj.errorToText(returnCode));
            end
            
            % Store a few variables in shorthand for convience
            postTriggerSamples = obj.acquisitionConfig.postTriggerSamples;
            preTriggerSamples = obj.acquisitionConfig.preTriggerSamples;
            recordsPerBuffer = obj.acquisitionConfig.recordsPerBuffer;
            buffersPerAcquisition = obj.acquisitionConfig.buffersPerAcquisition;
            
            % Calculate the number of samplesPerRecord to check for memory constrains
            samplesPerRecord = preTriggerSamples + postTriggerSamples;
            
            % Check for errors
            if ~~mod(samplesPerRecord,64)
                if obj.verbose
                    warning('Warning: samplesPerRecord is not a multiple of 64 (required for buffer alignment)');
                end
                % Adjust samples per record to ensure buffer alignment
                samplesPerRecord    = samplesPerRecord      +   64-mod(samplesPerRecord,64);
                postTriggerSamples  = postTriggerSamples    + 64-mod(postTriggerSamples,64);
            end
            
            if samplesPerRecord > maxSamplesPerRecord
                warning('Error: Too many samples per record %u max %u', samplesPerRecord, maxSamplesPerRecord);
                return
            end
            
            
            
            % Calculate the size of each buffer in bytes
            bytesPerSample = ceil(double(bitsPerSample) / double(8));						% We round up to the nearest byte
            samplesPerBuffer = samplesPerRecord * recordsPerBuffer;                         % We calculate the number of samples in a buffer
            bytesPerBuffer = bytesPerSample * samplesPerBuffer;								% and use it to find the number of bytes in a buffer
            
            
            % Create an array of DMA buffers
            % The number of DMA buffers must be greater than 2 to allow a board to DMA into
            % one buffer while, the application processes another buffer.
            buffers = cell(1,obj.acquisitionConfig.bufferCount);
            for j = 1 : obj.acquisitionConfig.bufferCount
                pbuffer = calllib('ATSApi', 'AlazarAllocBufferU16', obj.boardHandle, samplesPerBuffer);
                if pbuffer == 0
                    fprintf('Error: AlazarAllocBufferU16 %u samples failed', samplesPerBuffer);
                    return
                end
                buffers(1, j) = { pbuffer };
            end
            
            
            
            % Set the record size based on the pre-set number of preTriggerSamples and postTriggerSamples
            returnCode = calllib('ATSApi', 'AlazarSetRecordSize', obj.boardHandle, preTriggerSamples, postTriggerSamples);
            
            % Check for errors
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarSetRecordSize failed -- %s',obj.errorToText(returnCode));
            end
            
            
            
            switch obj.acquisitionConfig.triggerMode
                
                % Mode is CS (Continous Sampling)
                case 'CS'
                    
                    % We set the AutoDMA flags according to the mode
                    % ADMA_CONTINUOUS_MODE - acquire a single gapless record spanning multiple buffers
                    % ADMA_EXTERNAL_STARTCAPTURE - call AlazarStartCapture to begin the acquisition
                    admaFlags = a.ADMA_EXTERNAL_STARTCAPTURE + a.ADMA_CONTINUOUS_MODE;
                    
                    % Configure the board to make an AutoDMA acquisition
                    recordsPerAcquisition = recordsPerBuffer * buffersPerAcquisition;
                    returnCode = calllib('ATSApi', 'AlazarBeforeAsyncRead', obj.boardHandle, channelMask, -int32(preTriggerSamples), samplesPerRecord, recordsPerBuffer, recordsPerAcquisition, admaFlags);
                    
                    % Check for errors
                    if returnCode ~= a.ApiSuccess
                        error('Error: AlazarBeforeAsyncRead failed -- %s',obj.errorToText(returnCode));
                    end
                    
                    % Mode is NPT (No Pre-trigger)
                case 'NPT'
                    
                    % We set the AutoDMA flags according to the mode
                    % ADMA_NPT - Acquire multiple records with no-pre-trigger samples
                    % ADMA_EXTERNAL_STARTCAPTURE - Wait for call to AlazarStartCapture to begin the acquisition
                    admaFlags = a.ADMA_EXTERNAL_STARTCAPTURE + a.ADMA_NPT;
                    
                    % Configure the board to make an AutoDMA acquisition
                    recordsPerAcquisition = recordsPerBuffer * buffersPerAcquisition;
                    returnCode = calllib('ATSApi', 'AlazarBeforeAsyncRead', obj.boardHandle, channelMask, -int32(preTriggerSamples), samplesPerRecord, recordsPerBuffer, recordsPerAcquisition, admaFlags);
                    
                    % Check for errors
                    if returnCode ~= a.ApiSuccess
                        error('Error: AlazarBeforeAsyncRead failed -- %s',obj.errorToText(returnCode));
                    end
                    
            end % switch triggerMode
            
            % Post the buffers to the board
            for bufferIndex = 1 : obj.acquisitionConfig.bufferCount
                pbuffer = buffers{1, bufferIndex};
                returnCode = calllib('ATSApi', 'AlazarPostAsyncBuffer', obj.boardHandle, pbuffer, bytesPerBuffer);
                
                % Check for errors
                if returnCode ~= a.ApiSuccess
                    error('Error: AlazarPostAsyncBuffer failed -- %s',obj.errorToText(returnCode));
                end
            end


            % Arm the board system to wait for triggers
            returnCode = calllib('ATSApi', 'AlazarStartCapture', obj.boardHandle);
            
            % Check for errors
            if returnCode ~= a.ApiSuccess
                warning('Error: AlazarStartCapture failed -- %s', errorToText(returnCode));
            end
            
            
            % Wait for sufficient data to arrive to fill a buffer, process the buffer,
            % and repeat until the acquisition is complete
            startTickCount = tic;
            updateTickCount = tic;
            updateInterval_sec = 0.1;
            buffersCompleted = 0;
            captureDone = false;
            
            while ~captureDone
                
                % Set current buffer (cycles through buffers until completion)
                bufferIndex = mod(buffersCompleted, obj.acquisitionConfig.bufferCount) + 1;
                
                % Get pointer to buffer
                pbuffer = buffers{1, bufferIndex};
                
                % Wait for the first available buffer to be filled by the board
                [returnCode, obj.boardHandle, bufferOut]	=	...
                    calllib('ATSApi', 'AlazarWaitAsyncBufferComplete', obj.boardHandle, pbuffer, obj.acquisitionConfig.bufferTimeout_ms);
                
                % Check for success/errors
                if returnCode == a.ApiSuccess
                    % This buffer is full
                    bufferFull = true;
                    captureDone = false;
                    
                elseif returnCode == a.ApiWaitTimeout
                    % The wait timeout expired before this buffer was filled.
                    % The board may not be triggering, or the timeout period may be too short.
                    warning('Error: AlazarWaitAsyncBufferComplete timeout -- Verify trigger!');
                    bufferFull = false;
                    captureDone = true;
                else
                    % The acquisition failed
                    warning('Error: AlazarWaitAsyncBufferComplete failed -- %s', errorToText(returnCode));
                    bufferFull = false;
                    captureDone = true;
                end
                
                
                if bufferFull
                    % NOTE:
                    % While you are processing this buffer, the board is already
                    % filling the next available DMA buffer.
                    %
                    % You must finish processing this buffer before the board fills
                    % all of its available DMA buffers and on-board memory.
                    %
                    % Records are arranged in the buffer as follows:
                    % R0A, R1A, R2A ... RnA, R0B, R1B, R2B ...
                    %
                    % Samples values are arranged contiguously in each record.
                    % A 14-bit sample code is stored in the most significant bits of
                    % in each 14-bit sample value.
                    %
                    % Sample codes are unsigned by default where:
                    % - 0x0000 represents a negative full scale input signal;
                    % - 0x2000 represents a 0V signal;
                    % - 0x3fff represents a positive full scale input signal.
                    
                    
                    % Set datatype of buffer to unsigned 16-bit
                    setdatatype(bufferOut, 'uint16Ptr', 1, samplesPerBuffer);
                    
                    
                    % Modify buffer according to mode
                    switch obj.acquisitionConfig.acquisitionMode
                        case 'Scope'
                            % Read out the data
                            data = double(bufferOut.Value)./4;
                            
                        case 'Average'
                            % Read out the data
                            data = reshape(double(bufferOut.Value),samplesPerRecord,recordsPerBuffer)./4;
                            % Perform averaging
                            data = sum(data./recordsPerBuffer,2);
    
                    end
                                       
                    % The scope data is converted into volts.
                    % Output data is between 0 (full negative
                    % signal) and 16383 (full positive), and are modified
                    % by the inputrange and the Alazar calibration
                    
                    bitsPerSample = 14;
                    % AlazarTech digitizers are calibrated as
                    % follows:
                    codeZero = bitshift(1,bitsPerSample-1) - 0.5;
                    codeRange = bitshift(1,bitsPerSample-1) - 0.5;
                    
                    % The codeZero and codeRange gives the signal relative to the input
                    % range, and the bsxfun multiplies this relative signal with the input
                    % range to get the signal in voltage
                    obj.outputBuffer = (data-codeZero)/codeRange*obj.channelConfig(channel).inputRange;
                    
                    
                    
                    % Make the buffer available to be filled again by the board
                    returnCode = calllib('ATSApi', 'AlazarPostAsyncBuffer', obj.boardHandle, pbuffer, bytesPerBuffer);
                    if returnCode ~= a.ApiSuccess
                        warning('Error: AlazarPostAsyncBuffer failed -- %s', errorToText(returnCode));
                        captureDone = true;
                    end
                    
                    
                    
                    % Update progress
                    buffersCompleted = buffersCompleted + 1;
                    if buffersCompleted >= obj.acquisitionConfig.buffersPerAcquisition
                        captureDone = true;
                        
                        
                        
                    elseif toc(updateTickCount) > updateInterval_sec
                        updateTickCount = tic;
                    end
                    
                end % if bufferFull
                
            end % while ~captureDone
            
            
                        
            % Abort the acquisition
            returnCode = calllib('ATSApi', 'AlazarAbortAsyncRead', obj.boardHandle);
            
            % Check for errors
            if returnCode ~= a.ApiSuccess
                warning('Error: AlazarAbortAsyncRead failed -- %s', errorToText(returnCode));
            end
            
            
            % Save the transfer time
            transferTime_sec = toc(startTickCount);
            
            % Display results
            if buffersCompleted > 0
                bytesTransferred 	= double(buffersCompleted) * double(bytesPerBuffer);
                recordsTransferred 	= recordsPerBuffer * buffersCompleted;
                
                if transferTime_sec > 0
                    buffersPerSec 	= buffersCompleted / transferTime_sec;
                    bytesPerSec 	= bytesTransferred / transferTime_sec;
                    recordsPerSec 	= recordsTransferred / transferTime_sec;
                else
                    buffersPerSec 	= 0;
                    bytesPerSec 	= 0;
                    recordsPerSec 	= 0;
                end
                
                if obj.verbose
                    display(sprintf('Captured %u buffers in %g sec (%g buffers per sec)', buffersCompleted, transferTime_sec, buffersPerSec));
                    display(sprintf('Captured %u records (%.4g records per sec)', recordsTransferred, recordsPerSec));
                    display(sprintf('Transferred %u bytes (%.4g  per sec)', bytesTransferred, bytesPerSec));
                end
                
            else
                % Data acquisition not successful
                warning('Error: Data acquisition not successful')
                return;
            end


            % Release the buffers
            for bufferIndex = 1:obj.acquisitionConfig.bufferCount
                pbuffer = buffers{1, bufferIndex};
                returnCode = calllib('ATSApi', 'AlazarFreeBufferU16', obj.boardHandle, pbuffer);
                if returnCode ~= a.ApiSuccess
                    warning('Error: AlazarFreeBufferU16 failed -- %s', errorToText(returnCode));
                end
                clear pbuffer;
            end


        end
             
        function [text] = errorToText(~,errorCode)
            % Convert an error number to a string
            
            %---------------------------------------------------------------------------
            %
            % Copyright (c) 2008-2013 AlazarTech, Inc.
            %
            % AlazarTech, Inc. licenses this software under specific terms and
            % conditions. Use of any of the software or derivatives thereof in any
            % product without an AlazarTech digitizer board is strictly prohibited.
            %
            % AlazarTech, Inc. provides this software AS IS, WITHOUT ANY WARRANTY,
            % EXPRESS OR IMPLIED, INCLUDING, WITHOUT LIMITATION, ANY WARRANTY OF
            % MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. AlazarTech makes no
            % guarantee or representations regarding the use of, or the results of the
            % use of, the software and documentation in terms of correctness, accuracy,
            % reliability, currentness, or otherwise; and you rely on the software,
            % documentation and results solely at your own risk.
            %
            % IN NO EVENT SHALL ALAZARTECH BE LIABLE FOR ANY LOSS OF USE, LOSS OF
            % BUSINESS, LOSS OF PROFITS, INDIRECT, INCIDENTAL, SPECIAL OR CONSEQUENTIAL
            % DAMAGES OF ANY KIND. IN NO EVENT SHALL ALAZARTECH%S TOTAL LIABILITY EXCEED
            % THE SUM PAID TO ALAZARTECH FOR THE PRODUCT LICENSED HEREUNDER.
            %
            %---------------------------------------------------------------------------
            
            errorText = calllib('ATSApi', 'AlazarErrorToText', errorCode);
            text = sprintf('%s (%d)', errorText, errorCode);
        end
        
        function [result] = displayBoardInfo(obj)
            % Display information about a board
            
            % MODIFIED TO WRITE TO A GIVEN FILE
            % Rasmus Skytte Eriksen
            
            %---------------------------------------------------------------------------
            %
            % Copyright (c) 2008-2011 AlazarTech, Inc.
            %
            % AlazarTech, Inc. licenses this software under specific terms and
            % conditions. Use of any of the software or derivatives thereof in any
            % product without an AlazarTech digitizer board is strictly prohibited.
            %
            % AlazarTech, Inc. provides this software AS IS, WITHOUT ANY WARRANTY,
            % EXPRESS OR IMPLIED, INCLUDING, WITHOUT LIMITATION, ANY WARRANTY OF
            % MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. AlazarTech makes no
            % guarantee or representations regarding the use of, or the results of the
            % use of, the software and documentation in terms of correctness, accuracy,
            % reliability, currentness, or otherwise; and you rely on the software,
            % documentation and results solely at your own risk.
            %
            % IN NO EVENT SHALL ALAZARTECH BE LIABLE FOR ANY LOSS OF USE, LOSS OF
            % BUSINESS, LOSS OF PROFITS, INDIRECT, INCIDENTAL, SPECIAL OR CONSEQUENTIAL
            % DAMAGES OF ANY KIND. IN NO EVENT SHALL ALAZARTECH%S TOTAL LIABILITY EXCEED
            % THE SUM PAID TO ALAZARTECH FOR THE PRODUCT LICENSED HEREUNDER.
            %
            %---------------------------------------------------------------------------
            
            % Load Alazar Defs as a
            a = obj.AlazarDefs;
            
            % set default return code to indicate failure
            result = false;
            
            % Get on-board memory information
            [returnCode, obj.boardHandle, samplesPerChannel, bitsPerSample] = calllib('ATSApi', 'AlazarGetChannelInfo', obj.boardHandle, 0, 0);
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarGetChannelInfo failed -- %s',obj.errorToText(returnCode));
            end
            
            % Get FPGA signature
            [returnCode, obj.boardHandle, asopcType] = calllib('ATSApi', 'AlazarQueryCapability', obj.boardHandle, a.ASOPC_TYPE, 0, 0);
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarQueryCapability failed -- %s',obj.errorToText(returnCode));
            end
            fpgaMajor = mod(floor(double(asopcType) / double(2^16)), 256);
            fpgaMinor = mod(floor(double(asopcType) / double(2^24)), 16);
            
            % Get CPLD version
            [returnCode, obj.boardHandle, cpldMajor, cpldMinor] = calllib('ATSApi', 'AlazarGetCPLDVersion', obj.boardHandle, 0, 0);
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarGetCPLDVersion failed -- %s',obj.errorToText(returnCode));
            end
            
            % Get serial number
            [returnCode, obj.boardHandle, serialNumber] = calllib('ATSApi', 'AlazarQueryCapability', obj.boardHandle, a.GET_SERIAL_NUMBER, 0, 0);
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarQueryCapability failed -- %s',obj.errorToText(returnCode));
            end
            
            % Get calibration information
            [returnCode, obj.boardHandle, latestCalDate] = calllib('ATSApi', 'AlazarQueryCapability', obj.boardHandle, a.GET_LATEST_CAL_DATE, 0, 0);
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarQueryCapability failed -- %s',obj.errorToText(returnCode));
            end
            
            % Get PCI Express link speed
            [returnCode, obj.boardHandle, linkSpeed] = calllib('ATSApi', 'AlazarQueryCapability', obj.boardHandle, a.GET_PCIE_LINK_SPEED, 0, 0);
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarQueryCapability failed -- %s', AlazarErrorToText(returnCode));
            end
            
            % Get PCI Express link width
            [returnCode, obj.boardHandle, linkWidth] = calllib('ATSApi', 'AlazarQueryCapability', obj.boardHandle, a.GET_PCIE_LINK_WIDTH, 0, 0);
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarQueryCapability failed -- %s', AlazarErrorToText(returnCode));
            end
            
            transfersPerSec = 2.5e9 * double(linkSpeed);
            bytesPerSec = double(linkWidth) * transfersPerSec / 10;
            
            % Display information about this board
            display(sprintf('System ID                 = %u', obj.systemID));
            display(sprintf('Board ID                  = %u', obj.boardID));
            display(sprintf('Serial number             = %06d', serialNumber));
            display(sprintf('Bits per sample           = %d', bitsPerSample));
            display(sprintf('Max samples per channel   = %u', samplesPerChannel));
            display(sprintf('CPLD version              = %d.%d', cpldMajor, cpldMinor));
            display(sprintf('FPGA version              = %d.%d', fpgaMajor, fpgaMinor));
            display(sprintf('ASoPC signature           = 0x%08X', asopcType));
            display(sprintf('Latest calibration date   = %d', latestCalDate));
            display(sprintf('PCIe link speed           = %g Gbps', 2.5 * double(linkSpeed)));
            display(sprintf('PCIe link width           = %u lanes', linkWidth));
            display(sprintf('PCIe max transfer rate    = %g MB/s', bytesPerSec * 1e-6));
            
            % Set the return code to indicate success
            result = true;
            
        end
        
        function [result] = displaySystemInfo(obj)
            % Display information about a board system specified by its systemId
            
            % MODIFIED TO WRITE TO A GIVEN FILE
            % Rasmus Skytte Eriksen
            
            %---------------------------------------------------------------------------
            %
            % Copyright (c) 2008-2011 AlazarTech, Inc.
            %
            % AlazarTech, Inc. licenses this software under specific terms and
            % conditions. Use of any of the software or derivatives thereof in any
            % product without an AlazarTech digitizer board is strictly prohibited.
            %
            % AlazarTech, Inc. provides this software AS IS, WITHOUT ANY WARRANTY,
            % EXPRESS OR IMPLIED, INCLUDING, WITHOUT LIMITATION, ANY WARRANTY OF
            % MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. AlazarTech makes no
            % guarantee or representations regarding the use of, or the results of the
            % use of, the software and documentation in terms of correctness, accuracy,
            % reliability, currentness, or otherwise; and you rely on the software,
            % documentation and results solely at your own risk.
            %
            % IN NO EVENT SHALL ALAZARTECH BE LIABLE FOR ANY LOSS OF USE, LOSS OF
            % BUSINESS, LOSS OF PROFITS, INDIRECT, INCIDENTAL, SPECIAL OR CONSEQUENTIAL
            % DAMAGES OF ANY KIND. IN NO EVENT SHALL ALAZARTECH%S TOTAL LIABILITY EXCEED
            % THE SUM PAID TO ALAZARTECH FOR THE PRODUCT LICENSED HEREUNDER.
            %
            %---------------------------------------------------------------------------
            
            % Load Alazar Defs as a
            a = obj.AlazarDefs;
            
            % set default return code to indicate failure
            result = false;
            
            
            % Get the board type in this board system
            boardTypeId = calllib('ATSApi', 'AlazarGetBoardKind', obj.boardHandle);
            
            % Get the driver version for this board type
            [returnCode, driverMajor, driverMinor, driverRev] = calllib('ATSApi', 'AlazarGetDriverVersion', 0, 0, 0);
            if returnCode ~= a.ApiSuccess
                error('Error: AlazarGetDriverVersion failed -- %s', AlazarErrorToText(returnCode));
            end
            
            % Display general information about this board system
            display(sprintf('System ID                 = %u', obj.systemID));
            display(sprintf('Board type                = %s', obj.boardTypeIdToText(boardTypeId)));
            display(sprintf('Driver version            = %d.%d.%d', driverMajor, driverMinor, driverRev));
            
            % set the return code to indicate success
            result = true;
            
        end
        
        function [text] = boardTypeIdToText(obj,boardType)
            % Convert board type id to text
            
            %---------------------------------------------------------------------------
            %
            % Copyright (c) 2008-2013 AlazarTech, Inc.
            %
            % AlazarTech, Inc. licenses this software under specific terms and
            % conditions. Use of any of the software or derivatives thereof in any
            % product without an AlazarTech digitizer board is strictly prohibited.
            %
            % AlazarTech, Inc. provides this software AS IS, WITHOUT ANY WARRANTY,
            % EXPRESS OR IMPLIED, INCLUDING, WITHOUT LIMITATION, ANY WARRANTY OF
            % MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. AlazarTech makes no
            % guarantee or representations regarding the use of, or the results of the
            % use of, the software and documentation in terms of correctness, accuracy,
            % reliability, currentness, or otherwise; and you rely on the software,
            % documentation and results solely at your own risk.
            %
            % IN NO EVENT SHALL ALAZARTECH BE LIABLE FOR ANY LOSS OF USE, LOSS OF
            % BUSINESS, LOSS OF PROFITS, INDIRECT, INCIDENTAL, SPECIAL OR CONSEQUENTIAL
            % DAMAGES OF ANY KIND. IN NO EVENT SHALL ALAZARTECH%S TOTAL LIABILITY EXCEED
            % THE SUM PAID TO ALAZARTECH FOR THE PRODUCT LICENSED HEREUNDER.
            %
            %---------------------------------------------------------------------------
            
            % Load Alazar Defs as a
            a = obj.AlazarDefs;
            
            switch boardType
                case a.ATS850
                    text = 'ATS850';
                case a.ATS310
                    text = 'ATS310';
                case a.ATS330
                    text = 'ATS330';
                case a.ATS855
                    text = 'ATS855';
                case a.ATS315
                    text = 'ATS315';
                case a.ATS335
                    text = 'ATS335';
                case a.ATS460
                    text = 'ATS460';
                case a.ATS860
                    text = 'ATS860';
                case a.ATS660
                    text = 'ATS660';
                case a.ATS9461
                    text = 'ATS9461';
                case a.ATS9462
                    text = 'ATS9462';
                case a.ATS9850
                    text = 'ATS9850';
                case a.ATS9870
                    text = 'ATS9870';
                case a.ATS9310
                    text = 'ATS9310';
                case a.ATS9325
                    text = 'ATS9325';
                case a.ATS9350
                    text = 'ATS9350';
                case a.ATS9351
                    text = 'ATS9351';
                case a.ATS9410
                    text = 'ATS9410';
                case a.ATS9440
                    text = 'ATS9440';
                case a.ATS9360
                    text = 'ATS9360';
                case a.ATS9625
                    text = 'ATS9625';
                case a.ATS9626
                    text = 'ATS9626';
                otherwise
                    text = '?';
            end
            
        end
        
        function [inputRangeVolts] = inputRangeIdToVolts(obj,inputRangeId)
            % Convert input range identifier to volts
            
            %---------------------------------------------------------------------------
            %
            % Copyright (c) 2008-2013 AlazarTech, Inc.
            %
            % AlazarTech, Inc. licenses this software under specific terms and
            % conditions. Use of any of the software or derivatives thereof in any
            % product without an AlazarTech digitizer board is strictly prohibited.
            %
            % AlazarTech, Inc. provides this software AS IS, WITHOUT ANY WARRANTY,
            % EXPRESS OR IMPLIED, INCLUDING, WITHOUT LIMITATION, ANY WARRANTY OF
            % MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. AlazarTech makes no
            % guarantee or representations regarding the use of, or the results of the
            % use of, the software and documentation in terms of correctness, accuracy,
            % reliability, currentness, or otherwise; and you rely on the software,
            % documentation and results solely at your own risk.
            %
            % IN NO EVENT SHALL ALAZARTECH BE LIABLE FOR ANY LOSS OF USE, LOSS OF
            % BUSINESS, LOSS OF PROFITS, INDIRECT, INCIDENTAL, SPECIAL OR CONSEQUENTIAL
            % DAMAGES OF ANY KIND. IN NO EVENT SHALL ALAZARTECH%S TOTAL LIABILITY EXCEED
            % THE SUM PAID TO ALAZARTECH FOR THE PRODUCT LICENSED HEREUNDER.
            %
            %---------------------------------------------------------------------------
            
            % Load Alazar Defs as a
            a = obj.AlazarDefs;
            
            switch inputRangeId
                case a.INPUT_RANGE_PM_20_MV
                    inputRangeVolts = 0.02;
                case a.INPUT_RANGE_PM_40_MV
                    inputRangeVolts = 0.04;
                case a.INPUT_RANGE_PM_50_MV
                    inputRangeVolts = 0.05;
                case a.INPUT_RANGE_PM_80_MV
                    inputRangeVolts = 0.08;
                case a.INPUT_RANGE_PM_100_MV
                    inputRangeVolts = 0.1;
                case a.INPUT_RANGE_PM_200_MV
                    inputRangeVolts = 0.2;
                case a.INPUT_RANGE_PM_400_MV
                    inputRangeVolts = 0.4;
                case a.INPUT_RANGE_PM_500_MV
                    inputRangeVolts = 0.5;
                case a.INPUT_RANGE_PM_800_MV
                    inputRangeVolts = 0.8;
                case a.INPUT_RANGE_PM_1_V
                    inputRangeVolts = 1;
                case a.INPUT_RANGE_PM_2_V
                    inputRangeVolts = 2;
                case a.INPUT_RANGE_PM_4_V
                    inputRangeVolts = 4;
                case a.INPUT_RANGE_PM_5_V
                    inputRangeVolts = 5;
                case a.INPUT_RANGE_PM_8_V
                    inputRangeVolts = 8;
                case a.INPUT_RANGE_PM_10_V
                    inputRangeVolts = 10;
                case a.INPUT_RANGE_PM_20_V
                    inputRangeVolts = 20;
                case a.INPUT_RANGE_PM_40_V
                    inputRangeVolts = 40;
                case a.INPUT_RANGE_PM_16_V
                    inputRangeVolts = 16;
                case a.INPUT_RANGE_PM_1_V_25
                    inputRangeVolts = 1.25;
                case a.INPUT_RANGE_PM_2_V_5
                    inputRangeVolts = 2.5;
                case a.INPUT_RANGE_PM_125_MV
                    inputRangeVolts = 0.125;
                case a.INPUT_RANGE_PM_250_MV
                    inputRangeVolts = 0.250;
                otherwise
                    inputRangeVolts = 0;
            end
            
        end
        
        function obj = loadAlazarDefs(obj)
            % -------------------------------------------------------------------------
            % Title:   AlazarDefs.m
            % Version: 6.1.0
            % Date:    2013/01/30
            % --------------------------------------------------------------------------
            
            %---------------------------------------------------------------------------
            %
            % Copyright (c) 2008-2013 AlazarTech, Inc.
            %
            % AlazarTech, Inc. licenses this software under specific terms and
            % conditions. Use of any of the software or derivatives thereof in any
            % product without an AlazarTech digitizer board is strictly prohibited.
            %
            % AlazarTech, Inc. provides this software AS IS, WITHOUT ANY WARRANTY,
            % EXPRESS OR IMPLIED, INCLUDING, WITHOUT LIMITATION, ANY WARRANTY OF
            % MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. AlazarTech makes no
            % guarantee or representations regarding the use of, or the results of the
            % use of, the software and documentation in terms of correctness, accuracy,
            % reliability, currentness, or otherwise; and you rely on the software,
            % documentation and results solely at your own risk.
            %
            % IN NO EVENT SHALL ALAZARTECH BE LIABLE FOR ANY LOSS OF USE, LOSS OF
            % BUSINESS, LOSS OF PROFITS, INDIRECT, INCIDENTAL, SPECIAL OR CONSEQUENTIAL
            % DAMAGES OF ANY KIND. IN NO EVENT SHALL ALAZARTECH'S TOTAL LIABILITY EXCEED
            % THE SUM PAID TO ALAZARTECH FOR THE PRODUCT LICENSED HEREUNDER.
            %
            %---------------------------------------------------------------------------
            
            %--------------------------------------------------------------------------
            % Return codes
            %--------------------------------------------------------------------------
            
            obj.AlazarDefs.ApiSuccess                              = int32(512);
            obj.AlazarDefs.ApiFailed								= int32(513);
            obj.AlazarDefs.ApiAccessDenied                         = int32(514);
            obj.AlazarDefs.ApiDmaChannelUnavailable				= int32(515);
            obj.AlazarDefs.ApiDmaChannelInvalid					= int32(516);
            obj.AlazarDefs.ApiDmaChannelTypeError					= int32(517);
            obj.AlazarDefs.ApiDmaInProgress						= int32(518);
            obj.AlazarDefs.ApiDmaDone								= int32(519);
            obj.AlazarDefs.ApiDmaPaused							= int32(520);
            obj.AlazarDefs.ApiDmaNotPaused                         = int32(521);
            obj.AlazarDefs.ApiDmaCommandInvalid					= int32(522);
            obj.AlazarDefs.ApiDmaManReady							= int32(523);
            obj.AlazarDefs.ApiDmaManNotReady						= int32(524);
            obj.AlazarDefs.ApiDmaInvalidChannelPriority			= int32(525);
            obj.AlazarDefs.ApiDmaManCorrupted						= int32(526);
            obj.AlazarDefs.ApiDmaInvalidElementIndex				= int32(527);
            obj.AlazarDefs.ApiDmaNoMoreElements					= int32(528);
            obj.AlazarDefs.ApiDmaSglInvalid						= int32(529);
            obj.AlazarDefs.ApiDmaSglQueueFull						= int32(530);
            obj.AlazarDefs.ApiNullParam							= int32(531);
            obj.AlazarDefs.ApiInvalidBusIndex						= int32(532);
            obj.AlazarDefs.ApiUnsupportedFunction					= int32(533);
            obj.AlazarDefs.ApiInvalidPciSpace						= int32(534);
            obj.AlazarDefs.ApiInvalidIopSpace						= int32(535);
            obj.AlazarDefs.ApiInvalidSize							= int32(536);
            obj.AlazarDefs.ApiInvalidAddress						= int32(537);
            obj.AlazarDefs.ApiInvalidAccessType					= int32(538);
            obj.AlazarDefs.ApiInvalidIndex                         = int32(539);
            obj.AlazarDefs.ApiMuNotReady							= int32(540);
            obj.AlazarDefs.ApiMuFifoEmpty							= int32(541);
            obj.AlazarDefs.ApiMuFifoFull							= int32(542);
            obj.AlazarDefs.ApiInvalidRegister						= int32(543);
            obj.AlazarDefs.ApiDoorbellClearFailed					= int32(544);
            obj.AlazarDefs.ApiInvalidUserPin						= int32(545);
            obj.AlazarDefs.ApiInvalidUserState                     = int32(546);
            obj.AlazarDefs.ApiEepromNotPresent                     = int32(547);
            obj.AlazarDefs.ApiEepromTypeNotSupported				= int32(548);
            obj.AlazarDefs.ApiEepromBlank							= int32(549);
            obj.AlazarDefs.ApiConfigAccessFailed					= int32(550);
            obj.AlazarDefs.ApiInvalidDeviceInfo					= int32(551);
            obj.AlazarDefs.ApiNoActiveDriver						= int32(552);
            obj.AlazarDefs.ApiInsufficientResources				= int32(553);
            obj.AlazarDefs.ApiObjectAlreadyAllocated				= int32(554);
            obj.AlazarDefs.ApiAlreadyInitialized					= int32(555);
            obj.AlazarDefs.ApiNotInitialized						= int32(556);
            obj.AlazarDefs.ApiBadConfigRegEndianMode				= int32(557);
            obj.AlazarDefs.ApiInvalidPowerState					= int32(558);
            obj.AlazarDefs.ApiPowerDown							= int32(559);
            obj.AlazarDefs.ApiFlybyNotSupported					= int32(560);
            obj.AlazarDefs.ApiNotSupportThisChannel				= int32(561);
            obj.AlazarDefs.ApiNoAction                             = int32(562);
            obj.AlazarDefs.ApiHSNotSupported						= int32(563);
            obj.AlazarDefs.ApiVPDNotSupported						= int32(564);
            obj.AlazarDefs.ApiVpdNotEnabled						= int32(565);
            obj.AlazarDefs.ApiNoMoreCap							= int32(566);
            obj.AlazarDefs.ApiInvalidOffset						= int32(567);
            obj.AlazarDefs.ApiBadPinDirection						= int32(568);
            obj.AlazarDefs.ApiPciTimeout							= int32(569);
            obj.AlazarDefs.ApiDmaChannelClosed                     = int32(570);
            obj.AlazarDefs.ApiDmaChannelError						= int32(571);
            obj.AlazarDefs.ApiInvalidHandle						= int32(572);
            obj.AlazarDefs.ApiBufferNotReady						= int32(573);
            obj.AlazarDefs.ApiInvalidData							= int32(574);
            obj.AlazarDefs.ApiDoNothing							= int32(575);
            obj.AlazarDefs.ApiDmaSglBuildFailed					= int32(576);
            obj.AlazarDefs.ApiPMNotSupported						= int32(577);
            obj.AlazarDefs.ApiInvalidDriverVersion                 = int32(578);
            obj.AlazarDefs.ApiWaitTimeout							= int32(579);
            obj.AlazarDefs.ApiWaitCanceled                         = int32(580);
            obj.AlazarDefs.ApiBufferTooSmall						= int32(581);
            obj.AlazarDefs.ApiBufferOverflow						= int32(582);
            obj.AlazarDefs.ApiInvalidBuffer						= int32(583);
            obj.AlazarDefs.ApiInvalidRecordsPerBuffer				= int32(584);
            obj.AlazarDefs.ApiDmaPending							= int32(585);
            obj.AlazarDefs.ApiLockAndProbePagesFailed				= int32(586);
            obj.AlazarDefs.ApiWaitAbandoned						= int32(587);
            obj.AlazarDefs.ApiWaitFailed							= int32(588);
            obj.AlazarDefs.ApiTransferComplete                     = int32(589);
            obj.AlazarDefs.ApiPllNotLocked                         = int32(590);
            obj.AlazarDefs.ApiNotSupportedInDualChannelMode        = int32(591);
            obj.AlazarDefs.ApiNotSupportedInQuadChannelMode		= int32(592);
            obj.AlazarDefs.ApiFileIoError							= int32(593);
            obj.AlazarDefs.ApiInvalidClockFrequency				= int32(594);
            
            %--------------------------------------------------------------------------
            % Board types
            %--------------------------------------------------------------------------
            
            obj.AlazarDefs.ATS_NONE        = int32(0);
            obj.AlazarDefs.ATS850          = int32(1);
            obj.AlazarDefs.ATS310          = int32(2);
            obj.AlazarDefs.ATS330          = int32(3);
            obj.AlazarDefs.ATS855          = int32(4);
            obj.AlazarDefs.ATS315          = int32(5);
            obj.AlazarDefs.ATS335          = int32(6);
            obj.AlazarDefs.ATS460          = int32(7);
            obj.AlazarDefs.ATS860          = int32(8);
            obj.AlazarDefs.ATS660          = int32(9);
            obj.AlazarDefs.ATS665          = int32(10);
            obj.AlazarDefs.ATS9462         = int32(11);
            obj.AlazarDefs.ATS9434         = int32(12);
            obj.AlazarDefs.ATS9870         = int32(13);
            obj.AlazarDefs.ATS9350         = int32(14);
            obj.AlazarDefs.ATS9325         = int32(15);
            obj.AlazarDefs.ATS9440         = int32(16);
            obj.AlazarDefs.ATS9410         = int32(17);
            obj.AlazarDefs.ATS9351         = int32(18);
            obj.AlazarDefs.ATS9310         = int32(19);
            obj.AlazarDefs.ATS9461         = int32(20);
            obj.AlazarDefs.ATS9850         = int32(21);
            obj.AlazarDefs.ATS9625         = int32(22);
            obj.AlazarDefs.ATG6500			= int32(23);
            obj.AlazarDefs.ATS9626			= int32(24);
            obj.AlazarDefs.ATS9360			= int32(25);
            obj.AlazarDefs.ATS_LAST        = int32(26);
            
            %--------------------------------------------------------------------------
            % Clock Control
            %--------------------------------------------------------------------------
            
            % Clock sources
            obj.AlazarDefs.INTERNAL_CLOCK              =	hex2dec('00000001');
            obj.AlazarDefs.EXTERNAL_CLOCK              =	hex2dec('00000002');
            obj.AlazarDefs.FAST_EXTERNAL_CLOCK         =	hex2dec('00000002')';
            obj.AlazarDefs.MEDIMUM_EXTERNAL_CLOCK      =	hex2dec('00000003')';
            obj.AlazarDefs.MEDIUM_EXTERNAL_CLOCK       =	hex2dec('00000003')';
            obj.AlazarDefs.SLOW_EXTERNAL_CLOCK         =	hex2dec('00000004')';
            obj.AlazarDefs.EXTERNAL_CLOCK_AC           =	hex2dec('00000005')';
            obj.AlazarDefs.EXTERNAL_CLOCK_DC           =	hex2dec('00000006')';
            obj.AlazarDefs.EXTERNAL_CLOCK_10MHz_REF    =	hex2dec('00000007')';
            obj.AlazarDefs.INTERNAL_CLOCK_DIV_5        =	hex2dec('000000010')';
            obj.AlazarDefs.MASTER_CLOCK                =	hex2dec('000000011')';
            
            % Internal sample rates
            obj.AlazarDefs.SAMPLE_RATE_1KSPS           =	hex2dec('00000001');
            obj.AlazarDefs.SAMPLE_RATE_2KSPS           =	hex2dec('00000002');
            obj.AlazarDefs.SAMPLE_RATE_5KSPS           =	hex2dec('00000004');
            obj.AlazarDefs.SAMPLE_RATE_10KSPS          =	hex2dec('00000008');
            obj.AlazarDefs.SAMPLE_RATE_20KSPS          =	hex2dec('0000000A');
            obj.AlazarDefs.SAMPLE_RATE_50KSPS          =	hex2dec('0000000C');
            obj.AlazarDefs.SAMPLE_RATE_100KSPS         =	hex2dec('0000000E');
            obj.AlazarDefs.SAMPLE_RATE_200KSPS         =	hex2dec('00000010');
            obj.AlazarDefs.SAMPLE_RATE_500KSPS         =	hex2dec('00000012');
            obj.AlazarDefs.SAMPLE_RATE_1MSPS           =	hex2dec('00000014');
            obj.AlazarDefs.SAMPLE_RATE_2MSPS           =	hex2dec('00000018');
            obj.AlazarDefs.SAMPLE_RATE_5MSPS           =	hex2dec('0000001A');
            obj.AlazarDefs.SAMPLE_RATE_10MSPS          =	hex2dec('0000001C');
            obj.AlazarDefs.SAMPLE_RATE_20MSPS          =	hex2dec('0000001E');
            obj.AlazarDefs.SAMPLE_RATE_25MSPS          =	hex2dec('00000021');
            obj.AlazarDefs.SAMPLE_RATE_50MSPS          =	hex2dec('00000022');
            obj.AlazarDefs.SAMPLE_RATE_100MSPS         =	hex2dec('00000024');
            obj.AlazarDefs.SAMPLE_RATE_125MSPS         =   hex2dec('00000025');
            obj.AlazarDefs.SAMPLE_RATE_160MSPS         =   hex2dec('00000026');
            obj.AlazarDefs.SAMPLE_RATE_180MSPS         =   hex2dec('00000027');
            obj.AlazarDefs.SAMPLE_RATE_200MSPS         =	hex2dec('00000028');
            obj.AlazarDefs.SAMPLE_RATE_250MSPS         =   hex2dec('0000002B');
            obj.AlazarDefs.SAMPLE_RATE_400MSPS			= 	hex2dec('0000002D');
            obj.AlazarDefs.SAMPLE_RATE_500MSPS         =   hex2dec('00000030');
            obj.AlazarDefs.SAMPLE_RATE_800MSPS			= 	hex2dec('00000032');
            obj.AlazarDefs.SAMPLE_RATE_1GSPS           =   hex2dec('00000035');
            obj.AlazarDefs.SAMPLE_RATE_1000MSPS        =   hex2dec('00000035');
            obj.AlazarDefs.SAMPLE_RATE_1200MSPS        =   hex2dec('00000037');
            obj.AlazarDefs.SAMPLE_RATE_1500MSPS        =   hex2dec('0000003A');
            obj.AlazarDefs.SAMPLE_RATE_1600MSPS        =   hex2dec('0000003B');
            obj.AlazarDefs.SAMPLE_RATE_1800MSPS        =   hex2dec('0000003D');
            obj.AlazarDefs.SAMPLE_RATE_2000MSPS        =   hex2dec('0000003F');
            obj.AlazarDefs.SAMPLE_RATE_2GSPS           =   hex2dec('0000003F');
            obj.AlazarDefs.SAMPLE_RATE_USER_DEF        =	hex2dec('00000040');
            
            % Clock edges
            obj.AlazarDefs.CLOCK_EDGE_RISING           =	hex2dec('00000000');
            obj.AlazarDefs.CLOCK_EDGE_FALLING          =	hex2dec('00000001');
            
            % Decimation
            obj.AlazarDefs.DECIMATE_BY_8               =   hex2dec('00000008');
            obj.AlazarDefs.DECIMATE_BY_64              =   hex2dec('00000040');
            
            %--------------------------------------------------------------------------
            % Input Control
            %--------------------------------------------------------------------------
            
            % Input channels
            obj.AlazarDefs.CHANNEL_ALL                 =   hex2dec('00000000');
            obj.AlazarDefs.CHANNEL_A                   =   hex2dec('00000001');
            obj.AlazarDefs.CHANNEL_B                   =   hex2dec('00000002');
            obj.AlazarDefs.CHANNEL_C                   =   hex2dec('00000004');
            obj.AlazarDefs.CHANNEL_D                   =   hex2dec('00000008');
            obj.AlazarDefs.CHANNEL_E                   =   hex2dec('00000010');
            obj.AlazarDefs.CHANNEL_F                   =   hex2dec('00000012');
            obj.AlazarDefs.CHANNEL_G                   =   hex2dec('00000014');
            obj.AlazarDefs.CHANNEL_H                   =   hex2dec('00000018');
            
            % Input ranges
            obj.AlazarDefs.INPUT_RANGE_PM_20_MV        =   hex2dec('00000001');
            obj.AlazarDefs.INPUT_RANGE_PM_40_MV        =   hex2dec('00000002');
            obj.AlazarDefs.INPUT_RANGE_PM_50_MV        =   hex2dec('00000003');
            obj.AlazarDefs.INPUT_RANGE_PM_80_MV        =   hex2dec('00000004');
            obj.AlazarDefs.INPUT_RANGE_PM_100_MV       =   hex2dec('00000005');
            obj.AlazarDefs.INPUT_RANGE_PM_200_MV       =   hex2dec('00000006');
            obj.AlazarDefs.INPUT_RANGE_PM_400_MV       =   hex2dec('00000007');
            obj.AlazarDefs.INPUT_RANGE_PM_500_MV       =   hex2dec('00000008');
            obj.AlazarDefs.INPUT_RANGE_PM_800_MV       =   hex2dec('00000009');
            obj.AlazarDefs.INPUT_RANGE_PM_1_V          =   hex2dec('0000000A');
            obj.AlazarDefs.INPUT_RANGE_PM_2_V          = 	hex2dec('0000000B');
            obj.AlazarDefs.INPUT_RANGE_PM_4_V          =	hex2dec('0000000C');
            obj.AlazarDefs.INPUT_RANGE_PM_5_V          =	hex2dec('0000000D');
            obj.AlazarDefs.INPUT_RANGE_PM_8_V          =	hex2dec('0000000E');
            obj.AlazarDefs.INPUT_RANGE_PM_10_V         =	hex2dec('0000000F');
            obj.AlazarDefs.INPUT_RANGE_PM_20_V         =	hex2dec('00000010');
            obj.AlazarDefs.INPUT_RANGE_PM_40_V         =	hex2dec('00000011');
            obj.AlazarDefs.INPUT_RANGE_PM_16_V         =   hex2dec('00000012');
            obj.AlazarDefs.INPUT_RANGE_HIFI            = 	hex2dec('00000020');
            obj.AlazarDefs.INPUT_RANGE_PM_1_V_25		= 	hex2dec('00000021');
            obj.AlazarDefs.INPUT_RANGE_PM_2_V_5         = 	hex2dec('00000025');
            obj.AlazarDefs.INPUT_RANGE_PM_125_MV		=	hex2dec('00000028');
            obj.AlazarDefs.INPUT_RANGE_PM_250_MV		=	hex2dec('00000030');
            
            % Input impedances
            obj.AlazarDefs.IMPEDANCE_1M_OHM            =	hex2dec('00000001');
            obj.AlazarDefs.IMPEDANCE_50_OHM            =	hex2dec('00000002');
            obj.AlazarDefs.IMPEDANCE_75_OHM            =	hex2dec('00000004');
            obj.AlazarDefs.IMPEDANCE_300_OHM           =	hex2dec('00000008');
            obj.AlazarDefs.IMPEDANCE_600_OHM           =	hex2dec('0000000A');
            
            % Input coupling
            obj.AlazarDefs.AC_COUPLING                 =   hex2dec('00000001');
            obj.AlazarDefs.DC_COUPLING                 =	hex2dec('00000002');
            
            %--------------------------------------------------------------------------
            % Trigger Control
            %--------------------------------------------------------------------------
            
            % Trigger engines
            obj.AlazarDefs.TRIG_ENGINE_J                =	hex2dec('00000000');
            obj.AlazarDefs.TRIG_ENGINE_K                =	hex2dec('00000001');
            
            % Trigger engine operations
            obj.AlazarDefs.TRIG_ENGINE_OP_J             =   hex2dec('00000000');
            obj.AlazarDefs.TRIG_ENGINE_OP_K             =	hex2dec('00000001');
            obj.AlazarDefs.TRIG_ENGINE_OP_J_OR_K		=   hex2dec('00000002');
            obj.AlazarDefs.TRIG_ENGINE_OP_J_AND_K		=   hex2dec('00000003');
            obj.AlazarDefs.TRIG_ENGINE_OP_J_XOR_K		=   hex2dec('00000004');
            obj.AlazarDefs.TRIG_ENGINE_OP_J_AND_NOT_K	=   hex2dec('00000005');
            obj.AlazarDefs.TRIG_ENGINE_OP_NOT_J_AND_K	=   hex2dec('00000006');
            
            % Trigger engine sources
            obj.AlazarDefs.TRIG_CHAN_A                 =   hex2dec('00000000');
            obj.AlazarDefs.TRIG_CHAN_B                 =   hex2dec('00000001');
            obj.AlazarDefs.TRIG_EXTERNAL               =   hex2dec('00000002');
            obj.AlazarDefs.TRIG_DISABLE                =   hex2dec('00000003');
            obj.AlazarDefs.TRIG_CHAN_C                 =   hex2dec('00000004');
            obj.AlazarDefs.TRIG_CHAN_D                 =   hex2dec('00000005');
            
            % Trigger slopes
            obj.AlazarDefs.TRIGGER_SLOPE_POSITIVE      =   hex2dec('00000001');
            obj.AlazarDefs.TRIGGER_SLOPE_NEGATIVE      =   hex2dec('00000002');
            
            % External trigger ranges
            obj.AlazarDefs.ETR_DIV5                    =   hex2dec('00000000');
            obj.AlazarDefs.ETR_X1                      =   hex2dec('00000001');
            obj.AlazarDefs.ETR_5V                      =   hex2dec('00000000');
            obj.AlazarDefs.ETR_1V                      =   hex2dec('00000001');
            obj.AlazarDefs.ETR_TTL                     =   hex2dec('00000002');
            obj.AlazarDefs.ETR_2V5                     =   hex2dec('00000003');
            
            %--------------------------------------------------------------------------
            % Auxiliary I/O and LED Control
            %--------------------------------------------------------------------------
            
            % AUX outputs
            obj.AlazarDefs.AUX_OUT_TRIGGER              =	0;
            obj.AlazarDefs.AUX_OUT_PACER                =	2;
            obj.AlazarDefs.AUX_OUT_BUSY                 =	4;
            obj.AlazarDefs.AUX_OUT_CLOCK                =	6;
            obj.AlazarDefs.AUX_OUT_RESERVED             =	8;
            obj.AlazarDefs.AUX_OUT_CAPTURE_ALMOST_DONE	=	10;
            obj.AlazarDefs.AUX_OUT_AUXILIARY			=	12;
            obj.AlazarDefs.AUX_OUT_SERIAL_DATA			=	14;
            obj.AlazarDefs.AUX_OUT_TRIGGER_ENABLE		=	16;
            
            % AUX inputs
            obj.AlazarDefs.AUX_IN_TRIGGER_ENABLE		=	1;
            obj.AlazarDefs.AUX_IN_DIGITAL_TRIGGER		=	3;
            obj.AlazarDefs.AUX_IN_GATE					=	5;
            obj.AlazarDefs.AUX_IN_CAPTURE_ON_DEMAND	=	7;
            obj.AlazarDefs.AUX_IN_RESET_TIMESTAMP		=	9;
            obj.AlazarDefs.AUX_IN_SLOW_EXTERNAL_CLOCK	=	11;
            obj.AlazarDefs.AUX_IN_AUXILIARY			=	13;
            obj.AlazarDefs.AUX_IN_SERIAL_DATA			=	15;
            
            obj.AlazarDefs.AUX_INPUT_AUXILIARY			=	13;
            obj.AlazarDefs.AUX_INPUT_SERIAL_DATA		=	15;
            
            % LED states
            obj.AlazarDefs.LED_OFF                     =	hex2dec('00000000');
            obj.AlazarDefs.LED_ON                      =	hex2dec('00000001');
            
            %--------------------------------------------------------------------------
            % Get/Set Parameters
            %--------------------------------------------------------------------------
            
            obj.AlazarDefs.NUMBER_OF_RECORDS           =   hex2dec('10000001');
            obj.AlazarDefs.PRETRIGGER_AMOUNT           =   hex2dec('10000002');
            obj.AlazarDefs.RECORD_LENGTH               =   hex2dec('10000003');
            obj.AlazarDefs.TRIGGER_ENGINE              =   hex2dec('10000004');
            obj.AlazarDefs.TRIGGER_DELAY               =   hex2dec('10000005');
            obj.AlazarDefs.TRIGGER_TIMEOUT             =   hex2dec('10000006');
            obj.AlazarDefs.SAMPLE_RATE                 =   hex2dec('10000007');
            obj.AlazarDefs.CONFIGURATION_MODE          =   hex2dec('10000008');
            obj.AlazarDefs.DATA_WIDTH                  =   hex2dec('10000009');
            obj.AlazarDefs.SAMPLE_SIZE                 =   obj.AlazarDefs.DATA_WIDTH;
            obj.AlazarDefs.AUTO_CALIBRATE              =   hex2dec('1000000A');
            obj.AlazarDefs.TRIGGER_XXXXX               =   hex2dec('1000000B');
            obj.AlazarDefs.CLOCK_SOURCE                =   hex2dec('1000000C');
            obj.AlazarDefs.CLOCK_SLOPE                 =   hex2dec('1000000D');
            obj.AlazarDefs.IMPEDANCE                   =   hex2dec('1000000E');
            obj.AlazarDefs.INPUT_RANGE                 =   hex2dec('1000000F');
            obj.AlazarDefs.COUPLING                    =   hex2dec('10000010');
            obj.AlazarDefs.MAX_TIMEOUTS_ALLOWED        =   hex2dec('10000011');
            obj.AlazarDefs.ATS_OPERATING_MODE          =   hex2dec('10000012');
            obj.AlazarDefs.CLOCK_DECIMATION_EXTERNAL   =   hex2dec('10000013');
            obj.AlazarDefs.LED_CONTROL                 =   hex2dec('10000014');
            obj.AlazarDefs.ATTENUATOR_RELAY            =   hex2dec('10000018');
            obj.AlazarDefs.EXT_TRIGGER_COUPLING        =   hex2dec('1000001A');
            obj.AlazarDefs.EXT_TRIGGER_ATTENUATOR_RELAY    =  hex2dec('1000001C');
            obj.AlazarDefs.TRIGGER_ENGINE_SOURCE       =   hex2dec('1000001E');
            obj.AlazarDefs.TRIGGER_ENGINE_SLOPE        =   hex2dec('10000020');
            obj.AlazarDefs.SEND_DAC_VALUE              =   hex2dec('10000021');
            obj.AlazarDefs.SLEEP_DEVICE                =   hex2dec('10000022');
            obj.AlazarDefs.GET_DAC_VALUE               =   hex2dec('10000023');
            obj.AlazarDefs.GET_SERIAL_NUMBER           =   hex2dec('10000024');
            obj.AlazarDefs.GET_FIRST_CAL_DATE          =   hex2dec('10000025');
            obj.AlazarDefs.GET_LATEST_CAL_DATE         =   hex2dec('10000026');
            obj.AlazarDefs.GET_LATEST_TEST_DATE        =   hex2dec('10000027');
            obj.AlazarDefs.SEND_RELAY_VALUE            =   hex2dec('10000028');
            obj.AlazarDefs.GET_LATEST_CAL_DATE_MONTH   =   hex2dec('1000002D');
            obj.AlazarDefs.GET_LATEST_CAL_DATE_DAY     =   hex2dec('1000002E');
            obj.AlazarDefs.GET_LATEST_CAL_DATE_YEAR    =   hex2dec('1000002F');
            obj.AlazarDefs.GET_PCIE_LINK_SPEED         =   hex2dec('10000030');
            obj.AlazarDefs.GET_PCIE_LINK_WIDTH         =   hex2dec('10000031');
            obj.AlazarDefs.SETGET_ASYNC_BUFFCOUNT      =   hex2dec('10000040');
            obj.AlazarDefs.SET_DATA_FORMAT             =   hex2dec('10000041');
            obj.AlazarDefs.GET_DATA_FORMAT             =   hex2dec('10000042');
            obj.AlazarDefs.DATA_FORMAT_UNSIGNED        =   0;
            obj.AlazarDefs.DATA_FORMAT_SIGNED          =   1;
            obj.AlazarDefs.SET_SINGLE_CHANNEL_MODE     =   hex2dec('10000043');
            obj.AlazarDefs.MEMORY_SIZE                 =   hex2dec('1000002A');
            obj.AlazarDefs.BOARD_TYPE                  =   hex2dec('1000002B');
            obj.AlazarDefs.ASOPC_TYPE                  =   hex2dec('1000002C');
            obj.AlazarDefs.GET_BOARD_OPTIONS_LOW       =   hex2dec('10000037');
            obj.AlazarDefs.GET_BOARD_OPTIONS_HIGH      =   hex2dec('10000038');
            obj.AlazarDefs.OPTION_STREAMING_DMA        =   uint32(2^0);
            obj.AlazarDefs.OPTION_AVERAGE_INPUT        =   uint32(2^1);
            obj.AlazarDefs.OPTION_EXTERNAL_CLOCK       =   uint32(2^1);
            obj.AlazarDefs.OPTION_DUAL_PORT_MEMORY     =   uint32(2^2);
            obj.AlazarDefs.OPTION_180MHZ_OSCILLATOR    =   uint32(2^3);
            obj.AlazarDefs.OPTION_LVTTL_EXT_CLOCK      =   uint32(2^4);
            obj.AlazarDefs.OPTION_SW_SPI               =	uint32(2^5);
            obj.AlazarDefs.OPTION_ALT_INPUT_RANGES     = 	uint32(2^6);
            obj.AlazarDefs.OPTION_VARIABLE_RATE_10MHZ_PLL	= 	uint32(2^7);
            
            obj.AlazarDefs.TRANSFER_OFFET              =   hex2dec('10000030');
            obj.AlazarDefs.TRANSFER_LENGTH             =   hex2dec('10000031');
            obj.AlazarDefs.TRANSFER_RECORD_OFFSET      =   hex2dec('10000032');
            obj.AlazarDefs.TRANSFER_NUM_OF_RECORDS     =   hex2dec('10000033');
            obj.AlazarDefs.TRANSFER_MAPPING_RATIO      =   hex2dec('10000034');
            obj.AlazarDefs.TRIGGER_ADDRESS_AND_TIMESTAMP = hex2dec('10000035');
            obj.AlazarDefs.MASTER_SLAVE_INDEPENDENT    =   hex2dec('10000036');
            obj.AlazarDefs.TRIGGERED                   =   hex2dec('10000040');
            obj.AlazarDefs.BUSY                        =   hex2dec('10000041');
            obj.AlazarDefs.WHO_TRIGGERED               =   hex2dec('10000042');
            obj.AlazarDefs.SET_DATA_FORMAT				=   hex2dec('10000041');
            obj.AlazarDefs.GET_DATA_FORMAT				=   hex2dec('10000042');
            obj.AlazarDefs.DATA_FORMAT_UNSIGNED         =   0;
            obj.AlazarDefs.DATA_FORMAT_SIGNED			=   1;
            obj.AlazarDefs.SET_SINGLE_CHANNEL_MODE		=   hex2dec('10000043');
            obj.AlazarDefs.GET_SAMPLES_PER_TIMESTAMP_CLOCK	=   hex2dec('10000044');
            obj.AlazarDefs.GET_RECORDS_CAPTURED         =   hex2dec('10000045');
            obj.AlazarDefs.GET_MAX_PRETRIGGER_SAMPLES	=   hex2dec('10000046');
            obj.AlazarDefs.SET_ADC_MODE                 =   hex2dec('10000047');
            obj.AlazarDefs.ECC_MODE                     =   hex2dec('10000048');
            obj.AlazarDefs.ECC_DISABLE					=   0;
            obj.AlazarDefs.ECC_ENABLE					=   1;
            obj.AlazarDefs.GET_AUX_INPUT_LEVEL			=   hex2dec('10000049');
            obj.AlazarDefs.AUX_INPUT_LOW				=   0;
            obj.AlazarDefs.AUX_INPUT_HIGH				=   1;
            obj.AlazarDefs.GET_ASYNC_BUFFERS_PENDING    =   hex2dec('10000050');
            obj.AlazarDefs.GET_ASYNC_BUFFERS_PENDING_FULL =    hex2dec('10000051');
            obj.AlazarDefs.GET_ASYNC_BUFFERS_PENDING_EMPTY =   hex2dec('10000052');
            obj.AlazarDefs.ACF_SAMPLES_PER_RECORD       =   hex2dec('10000060');
            obj.AlazarDefs.ACF_RECORDS_TO_AVERAGE       =   hex2dec('10000061');
            obj.AlazarDefs.EXT_TRIGGER_IMPEDANCE		=   hex2dec('10000065');
            obj.AlazarDefs.EXT_TRIG_50_OHMS             = 	0;
            obj.AlazarDefs.EXT_TRIG_300_OHMS			= 	1;
            obj.AlazarDefs.GET_CHANNELS_PER_BOARD 		= 	hex2dec('10000070');
            obj.AlazarDefs.GET_CPF_DEVICE 				= 	hex2dec('10000071');
            obj.AlazarDefs.CPF_DEVICE_UNKNOWN 			= 	0;
            obj.AlazarDefs.CPF_DEVICE_EP3SL50 			= 	1;
            obj.AlazarDefs.CPF_DEVICE_EP3SE260          = 	2;
            obj.AlazarDefs.PACK_MODE 					= 	hex2dec('10000072');
            obj.AlazarDefs.PACK_DEFAULT 				= 	0;
            obj.AlazarDefs.PACK_8_BITS_PER_SAMPLE 		= 	1;
            obj.AlazarDefs.GET_FPGA_TEMPERATURE         =	hex2dec('10000080');
            
            % Master/Slave Configuration
            obj.AlazarDefs.BOARD_IS_INDEPENDENT        =   hex2dec('00000000');
            obj.AlazarDefs.BOARD_IS_MASTER             =	hex2dec('00000001');
            obj.AlazarDefs.BOARD_IS_SLAVE              =	hex2dec('00000002');
            obj.AlazarDefs.BOARD_IS_LAST_SLAVE         =	hex2dec('00000003');
            
            % Attenuator Relay
            obj.AlazarDefs.AR_X1                       =   hex2dec('00000000');
            obj.AlazarDefs.AR_DIV40                    =   hex2dec('00000001');
            
            % Device Sleep state
            obj.AlazarDefs.POWER_OFF                   =   hex2dec('00000000');
            obj.AlazarDefs.POWER_ON                    =   hex2dec('00000001');
            
            % Software Events control
            obj.AlazarDefs.SW_EVENTS_OFF               =   hex2dec('00000000');
            obj.AlazarDefs.SW_EVENTS_ON                =   hex2dec('00000001');
            
            % TimeStamp Value Reset Control
            obj.AlazarDefs.TIMESTAMP_RESET_FIRSTTIME_ONLY	= hex2dec('00000000');
            obj.AlazarDefs.TIMESTAMP_RESET_ALWAYS			= hex2dec('00000001');
            
            % DAC Names used by API AlazarDACSettingAdjust
            obj.AlazarDefs.ATS460_DAC_A_GAIN			=   hex2dec('00000001');
            obj.AlazarDefs.ATS460_DAC_A_OFFSET			=   hex2dec('00000002');
            obj.AlazarDefs.ATS460_DAC_A_POSITION		=   hex2dec('00000003');
            obj.AlazarDefs.ATS460_DAC_B_GAIN			=   hex2dec('00000009');
            obj.AlazarDefs.ATS460_DAC_B_OFFSET			=   hex2dec('0000000A');
            obj.AlazarDefs.ATS460_DAC_B_POSITION		=   hex2dec('0000000B');
            obj.AlazarDefs.ATS460_DAC_EXTERNAL_CLK_REF	=   hex2dec('00000007');
            
            % DAC Names Specific to the ATS660
            obj.AlazarDefs.ATS660_DAC_A_GAIN			=   hex2dec('00000001');
            obj.AlazarDefs.ATS660_DAC_A_OFFSET			=   hex2dec('00000002');
            obj.AlazarDefs.ATS660_DAC_A_POSITION		=   hex2dec('00000003');
            obj.AlazarDefs.ATS660_DAC_B_GAIN			=   hex2dec('00000009');
            obj.AlazarDefs.ATS660_DAC_B_OFFSET			=   hex2dec('0000000A');
            obj.AlazarDefs.ATS660_DAC_B_POSITION		=   hex2dec('0000000B');
            obj.AlazarDefs.ATS660_DAC_EXTERNAL_CLK_REF	=   hex2dec('00000007');
            
            % DAC Names Specific to the ATS665
            obj.AlazarDefs.ATS665_DAC_A_GAIN			=   hex2dec('00000001');
            obj.AlazarDefs.ATS665_DAC_A_OFFSET			=   hex2dec('00000002');
            obj.AlazarDefs.ATS665_DAC_A_POSITION		=   hex2dec('00000003');
            obj.AlazarDefs.ATS665_DAC_B_GAIN			=   hex2dec('00000009');
            obj.AlazarDefs.ATS665_DAC_B_OFFSET			=   hex2dec('0000000A');
            obj.AlazarDefs.ATS665_DAC_B_POSITION		=   hex2dec('0000000B');
            obj.AlazarDefs.ATS665_DAC_EXTERNAL_CLK_REF	=   hex2dec('00000007');
            
            % Error return values
            obj.AlazarDefs.SETDAC_INVALID_SETGET       = 660;
            obj.AlazarDefs.SETDAC_INVALID_CHANNEL      = 661;
            obj.AlazarDefs.SETDAC_INVALID_DACNAME      = 662;
            obj.AlazarDefs.SETDAC_INVALID_COUPLING     = 663;
            obj.AlazarDefs.SETDAC_INVALID_RANGE        = 664;
            obj.AlazarDefs.SETDAC_INVALID_IMPEDANCE    = 665;
            obj.AlazarDefs.SETDAC_BAD_GET_PTR          = 667;
            obj.AlazarDefs.SETDAC_INVALID_BOARDTYPE    = 668;
            
            % Constants to be used in the Application when dealing with Custom FPGAs
            obj.AlazarDefs.FPGA_GETFIRST               =   hex2dec('FFFFFFFF');
            obj.AlazarDefs.FPGA_GETNEXT                =   hex2dec('FFFFFFFE');
            obj.AlazarDefs.FPGA_GETLAST                =   hex2dec('FFFFFFFC');
            
            %--------------------------------------------------------------------------
            % AutoDMA Control
            %--------------------------------------------------------------------------
            
            % AutoDMA flags
            obj.AlazarDefs.ADMA_EXTERNAL_STARTCAPTURE  =   hex2dec('00000001');
            obj.AlazarDefs.ADMA_ENABLE_RECORD_HEADERS  =   hex2dec('00000008');
            obj.AlazarDefs.ADMA_SINGLE_DMA_CHANNEL     =   hex2dec('00000010');
            obj.AlazarDefs.ADMA_ALLOC_BUFFERS          =   hex2dec('00000020');
            obj.AlazarDefs.ADMA_TRADITIONAL_MODE       =   hex2dec('00000000');
            obj.AlazarDefs.ADMA_CONTINUOUS_MODE        =   hex2dec('00000100');
            obj.AlazarDefs.ADMA_NPT                    =   hex2dec('00000200');
            obj.AlazarDefs.ADMA_TRIGGERED_STREAMING    =   hex2dec('00000400');
            obj.AlazarDefs.ADMA_FIFO_ONLY_STREAMING    =   hex2dec('00000800');
            obj.AlazarDefs.ADMA_INTERLEAVE_SAMPLES     =   hex2dec('00001000');
            obj.AlazarDefs.ADMA_GET_PROCESSED_DATA     =   hex2dec('00002000');
            
            % AutoDMA header constants
            obj.AlazarDefs.ADMA_CLOCKSOURCE            =   hex2dec('00000001');
            obj.AlazarDefs.ADMA_CLOCKEDGE              =   hex2dec('00000002');
            obj.AlazarDefs.ADMA_SAMPLERATE             =   hex2dec('00000003');
            obj.AlazarDefs.ADMA_INPUTRANGE             =   hex2dec('00000004');
            obj.AlazarDefs.ADMA_INPUTCOUPLING          =   hex2dec('00000005');
            obj.AlazarDefs.ADMA_IMPUTIMPEDENCE         =   hex2dec('00000006');
            obj.AlazarDefs.ADMA_EXTTRIGGERED           =   hex2dec('00000007');
            obj.AlazarDefs.ADMA_CHA_TRIGGERED          =   hex2dec('00000008');
            obj.AlazarDefs.ADMA_CHB_TRIGGERED          =   hex2dec('00000009');
            obj.AlazarDefs.ADMA_TIMEOUT                =   hex2dec('0000000A');
            obj.AlazarDefs.ADMA_THISCHANTRIGGERED      =   hex2dec('0000000B');
            obj.AlazarDefs.ADMA_SERIALNUMBER           =   hex2dec('0000000C');
            obj.AlazarDefs.ADMA_SYSTEMNUMBER           =   hex2dec('0000000D');
            obj.AlazarDefs.ADMA_BOARDNUMBER            =   hex2dec('0000000E');
            obj.AlazarDefs.ADMA_WHICHCHANNEL           =   hex2dec('0000000F');
            obj.AlazarDefs.ADMA_SAMPLERESOLUTION       =   hex2dec('00000010');
            obj.AlazarDefs.ADMA_DATAFORMAT             =   hex2dec('00000011');
            
            %--------------------------------------------------------------------------
            % AlazarSetClockSwitchOver
            %--------------------------------------------------------------------------
            
            obj.AlazarDefs.CSO_DUMMY_CLOCK_DISABLE				= 0;
            obj.AlazarDefs.CSO_DUMMY_CLOCK_TIMER				= 1;
            obj.AlazarDefs.CSO_DUMMY_CLOCK_EXT_TRIGGER			= 2;
            obj.AlazarDefs.CSO_DUMMY_CLOCK_TIMER_ON_TIMER_OFF	= 3;
            
            %--------------------------------------------------------------------------
            % User-programmable FPGA
            %--------------------------------------------------------------------------
            
            % AlazarCoprocessorDownload
            obj.AlazarDefs.CPF_OPTION_DMA_DOWNLOAD	 		= 1;
            
            % User-programmable FPGA device types
            obj.AlazarDefs.CPF_DEVICE_UNKNOWN				= 0;
            obj.AlazarDefs.CPF_DEVICE_EP3SL50				= 1;
            obj.AlazarDefs.CPF_DEVICE_EP3SE260				= 2;
            
            % Framework defined registers
            obj.AlazarDefs.CPF_REG_SIGNATURE				= 0;
            obj.AlazarDefs.CPF_REG_REVISION                 = 1;
            obj.AlazarDefs.CPF_REG_VERSION					= 2;
            obj.AlazarDefs.CPF_REG_STATUS					= 3;
            
            %--------------------------------------------------------------------------
            % AlazarSetExternalTriggerOperationForScanning
            %--------------------------------------------------------------------------
            
            obj.AlazarDefs.STOS_OPTION_DEFER_START_CAPTURE	 = 1;
        end

    end
    
    methods (Static)
        function r = model()
            r = 'Alazar ATS-9440';
        end
        
        function r = channels()
            r = {'A','B','C','D'};
        end
        
        function [result] = alazarLoadLibrary()
            % Load ATSApi.dll, the AlazarTech driver shared library
            
            %---------------------------------------------------------------------------
            %
            % Copyright (c) 2008-2013 AlazarTech, Inc.
            %
            % AlazarTech, Inc. licenses this software under specific terms and
            % conditions. Use of any of the software or derivatives thereof in any
            % product without an AlazarTech digitizer board is strictly prohibited.
            %
            % AlazarTech, Inc. provides this software AS IS, WITHOUT ANY WARRANTY,
            % EXPRESS OR IMPLIED, INCLUDING, WITHOUT LIMITATION, ANY WARRANTY OF
            % MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. AlazarTech makes no
            % guarantee or representations regarding the use of, or the results of the
            % use of, the software and documentation in terms of correctness, accuracy,
            % reliability, currentness, or otherwise; and you rely on the software,
            % documentation and results solely at your own risk.
            %
            % IN NO EVENT SHALL ALAZARTECH BE LIABLE FOR ANY LOSS OF USE, LOSS OF
            % BUSINESS, LOSS OF PROFITS, INDIRECT, INCIDENTAL, SPECIAL OR CONSEQUENTIAL
            % DAMAGES OF ANY KIND. IN NO EVENT SHALL ALAZARTECH%S TOTAL LIABILITY EXCEED
            % THE SUM PAID TO ALAZARTECH FOR THE PRODUCT LICENSED HEREUNDER.
            %
            %---------------------------------------------------------------------------
            
            % set default return code to indicate failure
            result = false;
            
            % Load driver library
            if ~libisloaded('ATSApi')
                if strcmpi(computer('arch'), 'win64')
                    % Use protofile for 64-bit MATLAB
                    loadlibrary('ATSApi.dll',@AlazarInclude_pcwin64)
                elseif sscanf(version('-release'), '%d') >= 2009
                    % Use protofile for 32-bit MATLAB 2009 and later
                    loadlibrary('ATSApi.dll',@AlazarInclude_pcwin32)
                else
                    % Use protofile for 32-bit versions of MATLAB ealier than 2009
                    loadlibrary('ATSApi.dll',@AlazarInclude)
                end
                if libisloaded('ATSApi')
                    result = true;
                end
            else
                % The driver is aready loaded
                result = true;
            end
            
        end

        function [result] = alazarUnloadLibrary()
            % Set default return code to indicate failure
            result = false;
            
            % Load driver library
            if libisloaded('ATSApi')
                unloadlibrary('ATSApi')
                if ~libisloaded('ATSApi')
                    result = true;
                end
            else
                % The driver is aready unloaded
                result = true;
            end
            
        end
        
        
        % TODO : Find a way to use load library with function below.
%         function [methodinfo,structs,enuminfo,ThunkLibName] = AlazarInclude_pcwin64()
%             %ALAZARINCLUDE Create structures to define interfaces found in 'AlazarApi'.
%             
%             %This function was generated by loadlibrary.m parser version 1.1.6.29 on Wed Jan 30 15:36:43 2013
%             %perl options:'AlazarApi.i -outfile=AlazarInclude.m -thunkfile=ATSApi_thunk_pcwin64.c'
%             ival={cell(1,0)}; % change 0 to the actual number of functions to preallocate the data.
%             structs=[];enuminfo=[];fcnNum=1;
%             fcns=struct('name',ival,'calltype',ival,'LHS',ival,'RHS',ival,'alias',ival,'thunkname', ival);
%             MfilePath=fileparts(mfilename('fullpath'));
%             ThunkLibName=fullfile(MfilePath,'ATSApi_thunk_pcwin64');
%             % unsigned int AlazarGetOEMFPGAName ( int opcodeID , char * FullPath , unsigned long * error );
%             fcns.thunkname{fcnNum}='uint32int32cstringvoidPtrThunk';fcns.name{fcnNum}='AlazarGetOEMFPGAName'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'int32', 'cstring', 'ulongPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarOEMSetWorkingDirectory ( char * wDir , unsigned long * error );
%             fcns.thunkname{fcnNum}='uint32cstringvoidPtrThunk';fcns.name{fcnNum}='AlazarOEMSetWorkingDirectory'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'cstring', 'ulongPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarOEMGetWorkingDirectory ( char * wDir , unsigned long * error );
%             fcns.thunkname{fcnNum}='uint32cstringvoidPtrThunk';fcns.name{fcnNum}='AlazarOEMGetWorkingDirectory'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'cstring', 'ulongPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarParseFPGAName ( const char * FullName , char * Name , unsigned int * Type , unsigned int * MemSize , unsigned int * MajVer , unsigned int * MinVer , unsigned int * MajRev , unsigned int * MinRev , unsigned int * error );
%             fcns.thunkname{fcnNum}='uint32cstringcstringvoidPtrvoidPtrvoidPtrvoidPtrvoidPtrvoidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarParseFPGAName'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'cstring', 'cstring', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarOEMDownLoadFPGA ( void * h , char * FileName , unsigned int * RetValue );
%             fcns.thunkname{fcnNum}='uint32voidPtrcstringvoidPtrThunk';fcns.name{fcnNum}='AlazarOEMDownLoadFPGA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'cstring', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarDownLoadFPGA ( void * h , char * FileName , unsigned int * RetValue );
%             fcns.thunkname{fcnNum}='uint32voidPtrcstringvoidPtrThunk';fcns.name{fcnNum}='AlazarDownLoadFPGA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'cstring', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarReadWriteTest ( void * h , unsigned int * Buffer , unsigned int SizeToWrite , unsigned int SizeToRead );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtruint32uint32Thunk';fcns.name{fcnNum}='AlazarReadWriteTest'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32Ptr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarMemoryTest ( void * h , unsigned int * errors );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarMemoryTest'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBusyFlag ( void * h , int * BusyFlag );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarBusyFlag'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'int32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarTriggeredFlag ( void * h , int * TriggeredFlag );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarTriggeredFlag'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'int32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBoardsFound ();
%             fcns.thunkname{fcnNum}='uint32Thunk';fcns.name{fcnNum}='AlazarBoardsFound'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
%             % void * AlazarOpen ( char * BoardNameID );
%             fcns.thunkname{fcnNum}='voidPtrcstringThunk';fcns.name{fcnNum}='AlazarOpen'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'cstring'};fcnNum=fcnNum+1;
%             % void AlazarClose ( void * h );
%             fcns.thunkname{fcnNum}='voidvoidPtrThunk';fcns.name{fcnNum}='AlazarClose'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % MSILS AlazarGetBoardKind ( void * h );
%             fcns.thunkname{fcnNum}='MSILSvoidPtrThunk';fcns.name{fcnNum}='AlazarGetBoardKind'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='MSILS'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetCPLDVersion ( void * h , unsigned char * Major , unsigned char * Minor );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarGetCPLDVersion'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetChannelInfo ( void * h , unsigned int * MemSize , unsigned char * SampleSize );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarGetChannelInfo'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetSDKVersion ( unsigned char * Major , unsigned char * Minor , unsigned char * Revision );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarGetSDKVersion'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'uint8Ptr', 'uint8Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetDriverVersion ( unsigned char * Major , unsigned char * Minor , unsigned char * Revision );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarGetDriverVersion'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'uint8Ptr', 'uint8Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarInputControl ( void * h , unsigned char Channel , unsigned int Coupling , unsigned int InputRange , unsigned int Impedance );
%             fcns.thunkname{fcnNum}='uint32voidPtruint8uint32uint32uint32Thunk';fcns.name{fcnNum}='AlazarInputControl'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetPosition ( void * h , unsigned char Channel , int PMPercent , unsigned int InputRange );
%             fcns.thunkname{fcnNum}='uint32voidPtruint8int32uint32Thunk';fcns.name{fcnNum}='AlazarSetPosition'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'int32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetExternalTrigger ( void * h , unsigned int Coupling , unsigned int Range );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32Thunk';fcns.name{fcnNum}='AlazarSetExternalTrigger'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetTriggerDelay ( void * h , unsigned int Delay );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32Thunk';fcns.name{fcnNum}='AlazarSetTriggerDelay'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetTriggerTimeOut ( void * h , unsigned int to_ns );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32Thunk';fcns.name{fcnNum}='AlazarSetTriggerTimeOut'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarTriggerTimedOut ( void * h );
%             fcns.thunkname{fcnNum}='uint32voidPtrThunk';fcns.name{fcnNum}='AlazarTriggerTimedOut'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetTriggerAddress ( void * h , unsigned int Record , unsigned int * TriggerAddress , unsigned int * TimeStampHighPart , unsigned int * TimeStampLowPart );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32voidPtrvoidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarGetTriggerAddress'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetTriggerOperation ( void * h , unsigned int TriggerOperation , unsigned int TriggerEngine1 , unsigned int Source1 , unsigned int Slope1 , unsigned int Level1 , unsigned int TriggerEngine2 , unsigned int Source2 , unsigned int Slope2 , unsigned int Level2 );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32uint32uint32uint32uint32uint32uint32uint32Thunk';fcns.name{fcnNum}='AlazarSetTriggerOperation'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetTriggerOperationForScanning ( void * h , unsigned int slope , unsigned int level , unsigned int options );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32uint32Thunk';fcns.name{fcnNum}='AlazarSetTriggerOperationForScanning'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarAbortCapture ( void * h );
%             fcns.thunkname{fcnNum}='uint32voidPtrThunk';fcns.name{fcnNum}='AlazarAbortCapture'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarForceTrigger ( void * h );
%             fcns.thunkname{fcnNum}='uint32voidPtrThunk';fcns.name{fcnNum}='AlazarForceTrigger'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarForceTriggerEnable ( void * h );
%             fcns.thunkname{fcnNum}='uint32voidPtrThunk';fcns.name{fcnNum}='AlazarForceTriggerEnable'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarStartCapture ( void * h );
%             fcns.thunkname{fcnNum}='uint32voidPtrThunk';fcns.name{fcnNum}='AlazarStartCapture'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCaptureMode ( void * h , unsigned int Mode );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32Thunk';fcns.name{fcnNum}='AlazarCaptureMode'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarStreamCapture ( void * h , void * Buffer , unsigned int BufferSize , unsigned int DeviceOption , unsigned int ChannelSelect , unsigned int * error );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtruint32uint32uint32voidPtrThunk';fcns.name{fcnNum}='AlazarStreamCapture'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarHyperDisp ( void * h , void * Buffer , unsigned int BufferSize , unsigned char * ViewBuffer , unsigned int ViewBufferSize , unsigned int NumOfPixels , unsigned int Option , unsigned int ChannelSelect , unsigned int Record , long TransferOffset , unsigned int * error );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtruint32voidPtruint32uint32uint32uint32uint32longvoidPtrThunk';fcns.name{fcnNum}='AlazarHyperDisp'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint8Ptr', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'long', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarFastPRRCapture ( void * h , void * Buffer , unsigned int BufferSize , unsigned int DeviceOption , unsigned int ChannelSelect , unsigned int * error );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtruint32uint32uint32voidPtrThunk';fcns.name{fcnNum}='AlazarFastPRRCapture'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBusy ( void * h );
%             fcns.thunkname{fcnNum}='uint32voidPtrThunk';fcns.name{fcnNum}='AlazarBusy'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarTriggered ( void * h );
%             fcns.thunkname{fcnNum}='uint32voidPtrThunk';fcns.name{fcnNum}='AlazarTriggered'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetStatus ( void * h );
%             fcns.thunkname{fcnNum}='uint32voidPtrThunk';fcns.name{fcnNum}='AlazarGetStatus'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarDetectMultipleRecord ( void * h );
%             fcns.thunkname{fcnNum}='uint32voidPtrThunk';fcns.name{fcnNum}='AlazarDetectMultipleRecord'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetRecordCount ( void * h , unsigned int Count );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32Thunk';fcns.name{fcnNum}='AlazarSetRecordCount'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetRecordSize ( void * h , unsigned int PreSize , unsigned int PostSize );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32Thunk';fcns.name{fcnNum}='AlazarSetRecordSize'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetCaptureClock ( void * h , unsigned int Source , unsigned int Rate , unsigned int Edge , unsigned int Decimation );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32uint32uint32Thunk';fcns.name{fcnNum}='AlazarSetCaptureClock'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetExternalClockLevel ( void * h , float percent );
%             fcns.thunkname{fcnNum}='uint32voidPtrfloatThunk';fcns.name{fcnNum}='AlazarSetExternalClockLevel'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'single'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetClockSwitchOver ( void * hBoard , unsigned int uMode , unsigned int uDummyClockOnTime_ns , unsigned int uReserved );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32uint32Thunk';fcns.name{fcnNum}='AlazarSetClockSwitchOver'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarRead ( void * h , unsigned int Channel , void * Buffer , int ElementSize , long Record , long TransferOffset , unsigned int TransferLength );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32voidPtrint32longlonguint32Thunk';fcns.name{fcnNum}='AlazarRead'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'voidPtr', 'int32', 'long', 'long', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetParameter ( void * h , unsigned char Channel , unsigned int Parameter , long Value );
%             fcns.thunkname{fcnNum}='uint32voidPtruint8uint32longThunk';fcns.name{fcnNum}='AlazarSetParameter'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'long'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetParameterUL ( void * h , unsigned char Channel , unsigned int Parameter , unsigned int Value );
%             fcns.thunkname{fcnNum}='uint32voidPtruint8uint32uint32Thunk';fcns.name{fcnNum}='AlazarSetParameterUL'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetParameter ( void * h , unsigned char Channel , unsigned int Parameter , long * RetValue );
%             fcns.thunkname{fcnNum}='uint32voidPtruint8uint32voidPtrThunk';fcns.name{fcnNum}='AlazarGetParameter'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'longPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetParameterUL ( void * h , unsigned char Channel , unsigned int Parameter , unsigned int * RetValue );
%             fcns.thunkname{fcnNum}='uint32voidPtruint8uint32voidPtrThunk';fcns.name{fcnNum}='AlazarGetParameterUL'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % void * AlazarGetSystemHandle ( unsigned int sid );
%             fcns.thunkname{fcnNum}='voidPtruint32Thunk';fcns.name{fcnNum}='AlazarGetSystemHandle'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarNumOfSystems ();
%             fcns.thunkname{fcnNum}='uint32Thunk';fcns.name{fcnNum}='AlazarNumOfSystems'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
%             % unsigned int AlazarBoardsInSystemBySystemID ( unsigned int sid );
%             fcns.thunkname{fcnNum}='uint32uint32Thunk';fcns.name{fcnNum}='AlazarBoardsInSystemBySystemID'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBoardsInSystemByHandle ( void * systemHandle );
%             fcns.thunkname{fcnNum}='uint32voidPtrThunk';fcns.name{fcnNum}='AlazarBoardsInSystemByHandle'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % void * AlazarGetBoardBySystemID ( unsigned int sid , unsigned int brdNum );
%             fcns.thunkname{fcnNum}='voidPtruint32uint32Thunk';fcns.name{fcnNum}='AlazarGetBoardBySystemID'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % void * AlazarGetBoardBySystemHandle ( void * systemHandle , unsigned int brdNum );
%             fcns.thunkname{fcnNum}='voidPtrvoidPtruint32Thunk';fcns.name{fcnNum}='AlazarGetBoardBySystemHandle'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetLED ( void * h , unsigned int state );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32Thunk';fcns.name{fcnNum}='AlazarSetLED'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarQueryCapability ( void * h , unsigned int request , unsigned int value , unsigned int * retValue );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32voidPtrThunk';fcns.name{fcnNum}='AlazarQueryCapability'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarMaxSglTransfer ( ALAZAR_BOARDTYPES bt );
%             fcns.thunkname{fcnNum}='uint32ALAZAR_BOARDTYPESThunk';fcns.name{fcnNum}='AlazarMaxSglTransfer'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'BoardTypes'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetMaxRecordsCapable ( void * h , unsigned int RecordLength , unsigned int * num );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32voidPtrThunk';fcns.name{fcnNum}='AlazarGetMaxRecordsCapable'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetWhoTriggeredBySystemHandle ( void * systemHandle , unsigned int brdNum , unsigned int recNum );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32Thunk';fcns.name{fcnNum}='AlazarGetWhoTriggeredBySystemHandle'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetWhoTriggeredBySystemID ( unsigned int sid , unsigned int brdNum , unsigned int recNum );
%             fcns.thunkname{fcnNum}='uint32uint32uint32uint32Thunk';fcns.name{fcnNum}='AlazarGetWhoTriggeredBySystemID'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetBWLimit ( void * h , unsigned int Channel , unsigned int enable );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32Thunk';fcns.name{fcnNum}='AlazarSetBWLimit'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSleepDevice ( void * h , unsigned int state );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32Thunk';fcns.name{fcnNum}='AlazarSleepDevice'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarStartAutoDMA ( void * h , void * Buffer1 , unsigned int UseHeader , unsigned int ChannelSelect , long TransferOffset , unsigned int TransferLength , long RecordsPerBuffer , long RecordCount , int * error , unsigned int r1 , unsigned int r2 , unsigned int * r3 , unsigned int * r4 );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtruint32uint32longuint32longlongvoidPtruint32uint32voidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarStartAutoDMA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint32', 'long', 'uint32', 'long', 'long', 'int32Ptr', 'uint32', 'uint32', 'uint32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetNextAutoDMABuffer ( void * h , void * Buffer1 , void * Buffer2 , long * WhichOne , long * RecordsTransfered , int * error , unsigned int r1 , unsigned int r2 , long * TriggersOccurred , unsigned int * r4 );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrvoidPtrvoidPtrvoidPtrvoidPtruint32uint32voidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarGetNextAutoDMABuffer'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'voidPtr', 'longPtr', 'longPtr', 'int32Ptr', 'uint32', 'uint32', 'longPtr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetNextBuffer ( void * h , void * Buffer1 , void * Buffer2 , long * WhichOne , long * RecordsTransfered , int * error , unsigned int r1 , unsigned int r2 , long * TriggersOccurred , unsigned int * r4 );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrvoidPtrvoidPtrvoidPtrvoidPtruint32uint32voidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarGetNextBuffer'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'voidPtr', 'longPtr', 'longPtr', 'int32Ptr', 'uint32', 'uint32', 'longPtr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCloseAUTODma ( void * h );
%             fcns.thunkname{fcnNum}='uint32voidPtrThunk';fcns.name{fcnNum}='AlazarCloseAUTODma'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarAbortAutoDMA ( void * h , void * Buffer , int * error , unsigned int r1 , unsigned int r2 , unsigned int * r3 , unsigned int * r4 );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrvoidPtruint32uint32voidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarAbortAutoDMA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'int32Ptr', 'uint32', 'uint32', 'uint32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetAutoDMAHeaderValue ( void * h , unsigned int Channel , void * DataBuffer , unsigned int Record , unsigned int Parameter , int * error );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32voidPtruint32uint32voidPtrThunk';fcns.name{fcnNum}='AlazarGetAutoDMAHeaderValue'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'voidPtr', 'uint32', 'uint32', 'int32Ptr'};fcnNum=fcnNum+1;
%             % float AlazarGetAutoDMAHeaderTimeStamp ( void * h , unsigned int Channel , void * DataBuffer , unsigned int Record , int * error );
%             fcns.thunkname{fcnNum}='floatvoidPtruint32voidPtruint32voidPtrThunk';fcns.name{fcnNum}='AlazarGetAutoDMAHeaderTimeStamp'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='single'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'voidPtr', 'uint32', 'int32Ptr'};fcnNum=fcnNum+1;
%             % void * AlazarGetAutoDMAPtr ( void * h , unsigned int DataOrHeader , unsigned int Channel , void * DataBuffer , unsigned int Record , int * error );
%             fcns.thunkname{fcnNum}='voidPtrvoidPtruint32uint32voidPtruint32voidPtrThunk';fcns.name{fcnNum}='AlazarGetAutoDMAPtr'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'voidPtr', 'uint32', 'int32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarWaitForBufferReady ( void * h , long tms );
%             fcns.thunkname{fcnNum}='uint32voidPtrlongThunk';fcns.name{fcnNum}='AlazarWaitForBufferReady'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'long'};fcnNum=fcnNum+1;
%             % unsigned int AlazarEvents ( void * h , unsigned int enable );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32Thunk';fcns.name{fcnNum}='AlazarEvents'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBeforeAsyncRead ( void * hBoard , unsigned int uChannelSelect , long lTransferOffset , unsigned int uSamplesPerRecord , unsigned int uRecordsPerBuffer , unsigned int uRecordsPerAcquisition , unsigned int uFlags );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32longuint32uint32uint32uint32Thunk';fcns.name{fcnNum}='AlazarBeforeAsyncRead'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'long', 'uint32', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarAsyncRead ( void * hBoard , void * pBuffer , unsigned int BytesToRead , OVERLAPPED * pOverlapped );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtruint32voidPtrThunk';fcns.name{fcnNum}='AlazarAsyncRead'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarAbortAsyncRead ( void * hBoard );
%             fcns.thunkname{fcnNum}='uint32voidPtrThunk';fcns.name{fcnNum}='AlazarAbortAsyncRead'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarPostAsyncBuffer ( void * hDevice , void * pBuffer , unsigned int uBufferLength_bytes );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtruint32Thunk';fcns.name{fcnNum}='AlazarPostAsyncBuffer'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarWaitAsyncBufferComplete ( void * hDevice , void * pBuffer , unsigned int uTimeout_ms );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtruint32Thunk';fcns.name{fcnNum}='AlazarWaitAsyncBufferComplete'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarWaitNextAsyncBufferComplete ( void * hDevice , void * pBuffer , unsigned int uBufferLength_bytes , unsigned int uTimeout_ms );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtruint32uint32Thunk';fcns.name{fcnNum}='AlazarWaitNextAsyncBufferComplete'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCreateStreamFileA ( void * hDevice , const char * pszFilePath );
%             fcns.thunkname{fcnNum}='uint32voidPtrcstringThunk';fcns.name{fcnNum}='AlazarCreateStreamFileA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'cstring'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCreateStreamFileW ( void * hDevice , const WCHAR * pszFilePath );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarCreateStreamFileW'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint16Ptr'};fcnNum=fcnNum+1;
%             % long AlazarFlushAutoDMA ( void * h );
%             fcns.thunkname{fcnNum}='longvoidPtrThunk';fcns.name{fcnNum}='AlazarFlushAutoDMA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % void AlazarStopAutoDMA ( void * h );
%             fcns.thunkname{fcnNum}='voidvoidPtrThunk';fcns.name{fcnNum}='AlazarStopAutoDMA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarResetTimeStamp ( void * h , unsigned int resetFlag );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32Thunk';fcns.name{fcnNum}='AlazarResetTimeStamp'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarReadRegister ( void * hDevice , unsigned int offset , unsigned int * retVal , unsigned int pswrd );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32voidPtruint32Thunk';fcns.name{fcnNum}='AlazarReadRegister'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32Ptr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarWriteRegister ( void * hDevice , unsigned int offset , unsigned int Val , unsigned int pswrd );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32uint32Thunk';fcns.name{fcnNum}='AlazarWriteRegister'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarDACSetting ( void * h , unsigned int SetGet , unsigned int OriginalOrModified , unsigned char Channel , unsigned int DACNAME , unsigned int Coupling , unsigned int InputRange , unsigned int Impedance , unsigned int * getVal , unsigned int setVal , unsigned int * error );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32uint8uint32uint32uint32uint32voidPtruint32voidPtrThunk';fcns.name{fcnNum}='AlazarDACSetting'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint8', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32Ptr', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarConfigureAuxIO ( void * hDevice , unsigned int uMode , unsigned int uParameter );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32Thunk';fcns.name{fcnNum}='AlazarConfigureAuxIO'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % const char * AlazarErrorToText ( unsigned int code );
%             fcns.thunkname{fcnNum}='cstringuint32Thunk';fcns.name{fcnNum}='AlazarErrorToText'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='cstring'; fcns.RHS{fcnNum}={'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarConfigureSampleSkipping ( void * hBoard , unsigned int uMode , unsigned int uSampleClocksPerRecord , unsigned short * pwClockSkipMask );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32voidPtrThunk';fcns.name{fcnNum}='AlazarConfigureSampleSkipping'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint16Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCoprocessorRegisterRead ( void * hDevice , unsigned int offset , unsigned int * pValue );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32voidPtrThunk';fcns.name{fcnNum}='AlazarCoprocessorRegisterRead'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCoprocessorRegisterWrite ( void * hDevice , unsigned int offset , unsigned int value );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32Thunk';fcns.name{fcnNum}='AlazarCoprocessorRegisterWrite'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCoprocessorDownloadA ( void * hBoard , char * pszFileName , unsigned int uOptions );
%             fcns.thunkname{fcnNum}='uint32voidPtrcstringuint32Thunk';fcns.name{fcnNum}='AlazarCoprocessorDownloadA'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'cstring', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCoprocessorDownloadW ( void * hBoard , WCHAR * pszFileName , unsigned int uOptions );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtruint32Thunk';fcns.name{fcnNum}='AlazarCoprocessorDownloadW'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint16Ptr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetBoardRevision ( void * hBoard , unsigned char * Major , unsigned char * Minor );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarGetBoardRevision'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarConfigureRecordAverage ( void * hBoard , unsigned int uMode , unsigned int uSamplesPerRecord , unsigned int uRecordsPerAverage , unsigned int uOptions );
%             fcns.thunkname{fcnNum}='uint32voidPtruint32uint32uint32uint32Thunk';fcns.name{fcnNum}='AlazarConfigureRecordAverage'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned char * AlazarAllocBufferU8 ( void * hBoard , unsigned int uSampleCount );
%             fcns.thunkname{fcnNum}='voidPtrvoidPtruint32Thunk';fcns.name{fcnNum}='AlazarAllocBufferU8'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint8Ptr'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarFreeBufferU8 ( void * hBoard , unsigned char * pBuffer );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarFreeBufferU8'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned short * AlazarAllocBufferU16 ( void * hBoard , unsigned int uSampleCount );
%             fcns.thunkname{fcnNum}='voidPtrvoidPtruint32Thunk';fcns.name{fcnNum}='AlazarAllocBufferU16'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint16Ptr'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarFreeBufferU16 ( void * hBoard , unsigned short * pBuffer );
%             fcns.thunkname{fcnNum}='uint32voidPtrvoidPtrThunk';fcns.name{fcnNum}='AlazarFreeBufferU16'; fcns.calltype{fcnNum}='Thunk'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint16Ptr'};fcnNum=fcnNum+1;
%             structs.s_BoardDef.members=struct('RecordCount', 'uint32', 'RecLength', 'uint32', 'PreDepth', 'uint32', 'ClockSource', 'uint32', 'ClockEdge', 'uint32', 'SampleRate', 'uint32', 'CouplingChanA', 'uint32', 'InputRangeChanA', 'uint32', 'InputImpedChanA', 'uint32', 'CouplingChanB', 'uint32', 'InputRangeChanB', 'uint32', 'InputImpedChanB', 'uint32', 'TriEngOperation', 'uint32', 'TriggerEngine1', 'uint32', 'TrigEngSource1', 'uint32', 'TrigEngSlope1', 'uint32', 'TrigEngLevel1', 'uint32', 'TriggerEngine2', 'uint32', 'TrigEngSource2', 'uint32', 'TrigEngSlope2', 'uint32', 'TrigEngLevel2', 'uint32');
%             structs.s_HEADER2.members=struct('TimeStampLowPart', 'uint32');
%             % structs.s_ALAZAR_HEADER.members=struct('hdr0', 'error', 'hdr1', 'error', 'hdr2', 's_HEADER2', 'hdr3', 'error');
%             enuminfo.BoardTypes=struct('ATS_NONE',0,'ATS850',1,'ATS310',2,'ATS330',3,'ATS855',4,'ATS315',5,'ATS335',6,'ATS460',7,'ATS860',8,'ATS660',9,'ATS665',10,'ATS9462',11,'ATS9434',12,'ATS9870',13,'ATS9350',14,'ATS9325',15,'ATS9440',16,'ATS9410',17,'ATS9351',18,'ATS9310',19,'ATS9461',20,'ATS9850',21,'ATS9625',22,'ATG6500',23,'ATS9626',24,'ATS9360',25,'ATS_LAST',26);
%             enuminfo.MSILS=struct('KINDEPENDENT',0,'KSLAVE',1,'KMASTER',2,'KLASTSLAVE',3);
%             methodinfo=fcns;
%         end
%         
%         function [methodinfo,structs,enuminfo,ThunkLibName] = AlazarInclude_pcwin32()
%             %ALAZARINCLUDE Create structures to define interfaces found in 'AlazarApi'.
%             
%             %This function was generated by loadlibrary.m parser version 1.1.6.29 on Tue Jan 29 14:27:14 2013
%             %perl options:'AlazarApi.i -outfile=AlazarInclude.m'
%             ival={cell(1,0)}; % change 0 to the actual number of functions to preallocate the data.
%             structs=[];enuminfo=[];fcnNum=1;
%             fcns=struct('name',ival,'calltype',ival,'LHS',ival,'RHS',ival,'alias',ival);
%             ThunkLibName=[];
%             % unsigned int AlazarGetOEMFPGAName ( int opcodeID , char * FullPath , unsigned long * error );
%             fcns.name{fcnNum}='AlazarGetOEMFPGAName'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'int32', 'cstring', 'ulongPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarOEMSetWorkingDirectory ( char * wDir , unsigned long * error );
%             fcns.name{fcnNum}='AlazarOEMSetWorkingDirectory'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'cstring', 'ulongPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarOEMGetWorkingDirectory ( char * wDir , unsigned long * error );
%             fcns.name{fcnNum}='AlazarOEMGetWorkingDirectory'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'cstring', 'ulongPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarParseFPGAName ( const char * FullName , char * Name , unsigned int * Type , unsigned int * MemSize , unsigned int * MajVer , unsigned int * MinVer , unsigned int * MajRev , unsigned int * MinRev , unsigned int * error );
%             fcns.name{fcnNum}='AlazarParseFPGAName'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'cstring', 'cstring', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarOEMDownLoadFPGA ( void * h , char * FileName , unsigned int * RetValue );
%             fcns.name{fcnNum}='AlazarOEMDownLoadFPGA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'cstring', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarDownLoadFPGA ( void * h , char * FileName , unsigned int * RetValue );
%             fcns.name{fcnNum}='AlazarDownLoadFPGA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'cstring', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarReadWriteTest ( void * h , unsigned int * Buffer , unsigned int SizeToWrite , unsigned int SizeToRead );
%             fcns.name{fcnNum}='AlazarReadWriteTest'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32Ptr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarMemoryTest ( void * h , unsigned int * errors );
%             fcns.name{fcnNum}='AlazarMemoryTest'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBusyFlag ( void * h , int * BusyFlag );
%             fcns.name{fcnNum}='AlazarBusyFlag'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'int32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarTriggeredFlag ( void * h , int * TriggeredFlag );
%             fcns.name{fcnNum}='AlazarTriggeredFlag'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'int32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBoardsFound ();
%             fcns.name{fcnNum}='AlazarBoardsFound'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
%             % void * AlazarOpen ( char * BoardNameID );
%             fcns.name{fcnNum}='AlazarOpen'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'cstring'};fcnNum=fcnNum+1;
%             % void AlazarClose ( void * h );
%             fcns.name{fcnNum}='AlazarClose'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % MSILS AlazarGetBoardKind ( void * h );
%             fcns.name{fcnNum}='AlazarGetBoardKind'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='MSILS'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetCPLDVersion ( void * h , unsigned char * Major , unsigned char * Minor );
%             fcns.name{fcnNum}='AlazarGetCPLDVersion'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetChannelInfo ( void * h , unsigned int * MemSize , unsigned char * SampleSize );
%             fcns.name{fcnNum}='AlazarGetChannelInfo'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetSDKVersion ( unsigned char * Major , unsigned char * Minor , unsigned char * Revision );
%             fcns.name{fcnNum}='AlazarGetSDKVersion'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'uint8Ptr', 'uint8Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetDriverVersion ( unsigned char * Major , unsigned char * Minor , unsigned char * Revision );
%             fcns.name{fcnNum}='AlazarGetDriverVersion'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'uint8Ptr', 'uint8Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarInputControl ( void * h , unsigned char Channel , unsigned int Coupling , unsigned int InputRange , unsigned int Impedance );
%             fcns.name{fcnNum}='AlazarInputControl'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetPosition ( void * h , unsigned char Channel , int PMPercent , unsigned int InputRange );
%             fcns.name{fcnNum}='AlazarSetPosition'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'int32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetExternalTrigger ( void * h , unsigned int Coupling , unsigned int Range );
%             fcns.name{fcnNum}='AlazarSetExternalTrigger'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetTriggerDelay ( void * h , unsigned int Delay );
%             fcns.name{fcnNum}='AlazarSetTriggerDelay'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetTriggerTimeOut ( void * h , unsigned int to_ns );
%             fcns.name{fcnNum}='AlazarSetTriggerTimeOut'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarTriggerTimedOut ( void * h );
%             fcns.name{fcnNum}='AlazarTriggerTimedOut'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetTriggerAddress ( void * h , unsigned int Record , unsigned int * TriggerAddress , unsigned int * TimeStampHighPart , unsigned int * TimeStampLowPart );
%             fcns.name{fcnNum}='AlazarGetTriggerAddress'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetTriggerOperation ( void * h , unsigned int TriggerOperation , unsigned int TriggerEngine1 , unsigned int Source1 , unsigned int Slope1 , unsigned int Level1 , unsigned int TriggerEngine2 , unsigned int Source2 , unsigned int Slope2 , unsigned int Level2 );
%             fcns.name{fcnNum}='AlazarSetTriggerOperation'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetTriggerTimestamp ( void * h , unsigned int Record , U64 * Timestamp_samples );
%             fcns.name{fcnNum}='AlazarGetTriggerTimestamp'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetTriggerOperationForScanning ( void * h , unsigned int slope , unsigned int level , unsigned int options );
%             fcns.name{fcnNum}='AlazarSetTriggerOperationForScanning'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarAbortCapture ( void * h );
%             fcns.name{fcnNum}='AlazarAbortCapture'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarForceTrigger ( void * h );
%             fcns.name{fcnNum}='AlazarForceTrigger'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarForceTriggerEnable ( void * h );
%             fcns.name{fcnNum}='AlazarForceTriggerEnable'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarStartCapture ( void * h );
%             fcns.name{fcnNum}='AlazarStartCapture'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCaptureMode ( void * h , unsigned int Mode );
%             fcns.name{fcnNum}='AlazarCaptureMode'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarStreamCapture ( void * h , void * Buffer , unsigned int BufferSize , unsigned int DeviceOption , unsigned int ChannelSelect , unsigned int * error );
%             fcns.name{fcnNum}='AlazarStreamCapture'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarHyperDisp ( void * h , void * Buffer , unsigned int BufferSize , unsigned char * ViewBuffer , unsigned int ViewBufferSize , unsigned int NumOfPixels , unsigned int Option , unsigned int ChannelSelect , unsigned int Record , long TransferOffset , unsigned int * error );
%             fcns.name{fcnNum}='AlazarHyperDisp'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint8Ptr', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'long', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarFastPRRCapture ( void * h , void * Buffer , unsigned int BufferSize , unsigned int DeviceOption , unsigned int ChannelSelect , unsigned int * error );
%             fcns.name{fcnNum}='AlazarFastPRRCapture'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBusy ( void * h );
%             fcns.name{fcnNum}='AlazarBusy'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarTriggered ( void * h );
%             fcns.name{fcnNum}='AlazarTriggered'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetStatus ( void * h );
%             fcns.name{fcnNum}='AlazarGetStatus'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarDetectMultipleRecord ( void * h );
%             fcns.name{fcnNum}='AlazarDetectMultipleRecord'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetRecordCount ( void * h , unsigned int Count );
%             fcns.name{fcnNum}='AlazarSetRecordCount'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetRecordSize ( void * h , unsigned int PreSize , unsigned int PostSize );
%             fcns.name{fcnNum}='AlazarSetRecordSize'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetCaptureClock ( void * h , unsigned int Source , unsigned int Rate , unsigned int Edge , unsigned int Decimation );
%             fcns.name{fcnNum}='AlazarSetCaptureClock'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetExternalClockLevel ( void * h , float percent );
%             fcns.name{fcnNum}='AlazarSetExternalClockLevel'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'single'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetClockSwitchOver ( void * hBoard , unsigned int uMode , unsigned int uDummyClockOnTime_ns , unsigned int uReserved );
%             fcns.name{fcnNum}='AlazarSetClockSwitchOver'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarRead ( void * h , unsigned int Channel , void * Buffer , int ElementSize , long Record , long TransferOffset , unsigned int TransferLength );
%             fcns.name{fcnNum}='AlazarRead'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'voidPtr', 'int32', 'long', 'long', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetParameter ( void * h , unsigned char Channel , unsigned int Parameter , long Value );
%             fcns.name{fcnNum}='AlazarSetParameter'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'long'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetParameterUL ( void * h , unsigned char Channel , unsigned int Parameter , unsigned int Value );
%             fcns.name{fcnNum}='AlazarSetParameterUL'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetParameter ( void * h , unsigned char Channel , unsigned int Parameter , long * RetValue );
%             fcns.name{fcnNum}='AlazarGetParameter'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'longPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetParameterUL ( void * h , unsigned char Channel , unsigned int Parameter , unsigned int * RetValue );
%             fcns.name{fcnNum}='AlazarGetParameterUL'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % void * AlazarGetSystemHandle ( unsigned int sid );
%             fcns.name{fcnNum}='AlazarGetSystemHandle'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarNumOfSystems ();
%             fcns.name{fcnNum}='AlazarNumOfSystems'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
%             % unsigned int AlazarBoardsInSystemBySystemID ( unsigned int sid );
%             fcns.name{fcnNum}='AlazarBoardsInSystemBySystemID'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBoardsInSystemByHandle ( void * systemHandle );
%             fcns.name{fcnNum}='AlazarBoardsInSystemByHandle'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % void * AlazarGetBoardBySystemID ( unsigned int sid , unsigned int brdNum );
%             fcns.name{fcnNum}='AlazarGetBoardBySystemID'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % void * AlazarGetBoardBySystemHandle ( void * systemHandle , unsigned int brdNum );
%             fcns.name{fcnNum}='AlazarGetBoardBySystemHandle'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetLED ( void * h , unsigned int state );
%             fcns.name{fcnNum}='AlazarSetLED'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarQueryCapability ( void * h , unsigned int request , unsigned int value , unsigned int * retValue );
%             fcns.name{fcnNum}='AlazarQueryCapability'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarMaxSglTransfer ( ALAZAR_BOARDTYPES bt );
%             fcns.name{fcnNum}='AlazarMaxSglTransfer'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'BoardTypes'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetMaxRecordsCapable ( void * h , unsigned int RecordLength , unsigned int * num );
%             fcns.name{fcnNum}='AlazarGetMaxRecordsCapable'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetWhoTriggeredBySystemHandle ( void * systemHandle , unsigned int brdNum , unsigned int recNum );
%             fcns.name{fcnNum}='AlazarGetWhoTriggeredBySystemHandle'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetWhoTriggeredBySystemID ( unsigned int sid , unsigned int brdNum , unsigned int recNum );
%             fcns.name{fcnNum}='AlazarGetWhoTriggeredBySystemID'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetBWLimit ( void * h , unsigned int Channel , unsigned int enable );
%             fcns.name{fcnNum}='AlazarSetBWLimit'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSleepDevice ( void * h , unsigned int state );
%             fcns.name{fcnNum}='AlazarSleepDevice'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarStartAutoDMA ( void * h , void * Buffer1 , unsigned int UseHeader , unsigned int ChannelSelect , long TransferOffset , unsigned int TransferLength , long RecordsPerBuffer , long RecordCount , int * error , unsigned int r1 , unsigned int r2 , unsigned int * r3 , unsigned int * r4 );
%             fcns.name{fcnNum}='AlazarStartAutoDMA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint32', 'long', 'uint32', 'long', 'long', 'int32Ptr', 'uint32', 'uint32', 'uint32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetNextAutoDMABuffer ( void * h , void * Buffer1 , void * Buffer2 , long * WhichOne , long * RecordsTransfered , int * error , unsigned int r1 , unsigned int r2 , long * TriggersOccurred , unsigned int * r4 );
%             fcns.name{fcnNum}='AlazarGetNextAutoDMABuffer'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'voidPtr', 'longPtr', 'longPtr', 'int32Ptr', 'uint32', 'uint32', 'longPtr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetNextBuffer ( void * h , void * Buffer1 , void * Buffer2 , long * WhichOne , long * RecordsTransfered , int * error , unsigned int r1 , unsigned int r2 , long * TriggersOccurred , unsigned int * r4 );
%             fcns.name{fcnNum}='AlazarGetNextBuffer'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'voidPtr', 'longPtr', 'longPtr', 'int32Ptr', 'uint32', 'uint32', 'longPtr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCloseAUTODma ( void * h );
%             fcns.name{fcnNum}='AlazarCloseAUTODma'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarAbortAutoDMA ( void * h , void * Buffer , int * error , unsigned int r1 , unsigned int r2 , unsigned int * r3 , unsigned int * r4 );
%             fcns.name{fcnNum}='AlazarAbortAutoDMA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'int32Ptr', 'uint32', 'uint32', 'uint32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetAutoDMAHeaderValue ( void * h , unsigned int Channel , void * DataBuffer , unsigned int Record , unsigned int Parameter , int * error );
%             fcns.name{fcnNum}='AlazarGetAutoDMAHeaderValue'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'voidPtr', 'uint32', 'uint32', 'int32Ptr'};fcnNum=fcnNum+1;
%             % float AlazarGetAutoDMAHeaderTimeStamp ( void * h , unsigned int Channel , void * DataBuffer , unsigned int Record , int * error );
%             fcns.name{fcnNum}='AlazarGetAutoDMAHeaderTimeStamp'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='single'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'voidPtr', 'uint32', 'int32Ptr'};fcnNum=fcnNum+1;
%             % void * AlazarGetAutoDMAPtr ( void * h , unsigned int DataOrHeader , unsigned int Channel , void * DataBuffer , unsigned int Record , int * error );
%             fcns.name{fcnNum}='AlazarGetAutoDMAPtr'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'voidPtr', 'uint32', 'int32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarWaitForBufferReady ( void * h , long tms );
%             fcns.name{fcnNum}='AlazarWaitForBufferReady'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'long'};fcnNum=fcnNum+1;
%             % unsigned int AlazarEvents ( void * h , unsigned int enable );
%             fcns.name{fcnNum}='AlazarEvents'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBeforeAsyncRead ( void * hBoard , unsigned int uChannelSelect , long lTransferOffset , unsigned int uSamplesPerRecord , unsigned int uRecordsPerBuffer , unsigned int uRecordsPerAcquisition , unsigned int uFlags );
%             fcns.name{fcnNum}='AlazarBeforeAsyncRead'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'long', 'uint32', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarAsyncRead ( void * hBoard , void * pBuffer , unsigned int BytesToRead , OVERLAPPED * pOverlapped );
%             fcns.name{fcnNum}='AlazarAsyncRead'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 's_OVERLAPPEDPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarAbortAsyncRead ( void * hBoard );
%             fcns.name{fcnNum}='AlazarAbortAsyncRead'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarPostAsyncBuffer ( void * hDevice , void * pBuffer , unsigned int uBufferLength_bytes );
%             fcns.name{fcnNum}='AlazarPostAsyncBuffer'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarWaitAsyncBufferComplete ( void * hDevice , void * pBuffer , unsigned int uTimeout_ms );
%             fcns.name{fcnNum}='AlazarWaitAsyncBufferComplete'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarWaitNextAsyncBufferComplete ( void * hDevice , void * pBuffer , unsigned int uBufferLength_bytes , unsigned int uTimeout_ms );
%             fcns.name{fcnNum}='AlazarWaitNextAsyncBufferComplete'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCreateStreamFileA ( void * hDevice , const char * pszFilePath );
%             fcns.name{fcnNum}='AlazarCreateStreamFileA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'cstring'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCreateStreamFileW ( void * hDevice , const WCHAR * pszFilePath );
%             fcns.name{fcnNum}='AlazarCreateStreamFileW'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint16Ptr'};fcnNum=fcnNum+1;
%             % long AlazarFlushAutoDMA ( void * h );
%             fcns.name{fcnNum}='AlazarFlushAutoDMA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='long'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % void AlazarStopAutoDMA ( void * h );
%             fcns.name{fcnNum}='AlazarStopAutoDMA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarResetTimeStamp ( void * h , unsigned int resetFlag );
%             fcns.name{fcnNum}='AlazarResetTimeStamp'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarReadRegister ( void * hDevice , unsigned int offset , unsigned int * retVal , unsigned int pswrd );
%             fcns.name{fcnNum}='AlazarReadRegister'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32Ptr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarWriteRegister ( void * hDevice , unsigned int offset , unsigned int Val , unsigned int pswrd );
%             fcns.name{fcnNum}='AlazarWriteRegister'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarDACSetting ( void * h , unsigned int SetGet , unsigned int OriginalOrModified , unsigned char Channel , unsigned int DACNAME , unsigned int Coupling , unsigned int InputRange , unsigned int Impedance , unsigned int * getVal , unsigned int setVal , unsigned int * error );
%             fcns.name{fcnNum}='AlazarDACSetting'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint8', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32Ptr', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarConfigureAuxIO ( void * hDevice , unsigned int uMode , unsigned int uParameter );
%             fcns.name{fcnNum}='AlazarConfigureAuxIO'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % const char * AlazarErrorToText ( unsigned int code );
%             fcns.name{fcnNum}='AlazarErrorToText'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='cstring'; fcns.RHS{fcnNum}={'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarConfigureSampleSkipping ( void * hBoard , unsigned int uMode , unsigned int uSampleClocksPerRecord , unsigned short * pwClockSkipMask );
%             fcns.name{fcnNum}='AlazarConfigureSampleSkipping'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint16Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCoprocessorRegisterRead ( void * hDevice , unsigned int offset , unsigned int * pValue );
%             fcns.name{fcnNum}='AlazarCoprocessorRegisterRead'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCoprocessorRegisterWrite ( void * hDevice , unsigned int offset , unsigned int value );
%             fcns.name{fcnNum}='AlazarCoprocessorRegisterWrite'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCoprocessorDownloadA ( void * hBoard , char * pszFileName , unsigned int uOptions );
%             fcns.name{fcnNum}='AlazarCoprocessorDownloadA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'cstring', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCoprocessorDownloadW ( void * hBoard , WCHAR * pszFileName , unsigned int uOptions );
%             fcns.name{fcnNum}='AlazarCoprocessorDownloadW'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint16Ptr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetBoardRevision ( void * hBoard , unsigned char * Major , unsigned char * Minor );
%             fcns.name{fcnNum}='AlazarGetBoardRevision'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarConfigureRecordAverage ( void * hBoard , unsigned int uMode , unsigned int uSamplesPerRecord , unsigned int uRecordsPerAverage , unsigned int uOptions );
%             fcns.name{fcnNum}='AlazarConfigureRecordAverage'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned char * AlazarAllocBufferU8 ( void * hBoard , unsigned int uSampleCount );
%             fcns.name{fcnNum}='AlazarAllocBufferU8'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint8Ptr'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarFreeBufferU8 ( void * hBoard , unsigned char * pBuffer );
%             fcns.name{fcnNum}='AlazarFreeBufferU8'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned short * AlazarAllocBufferU16 ( void * hBoard , unsigned int uSampleCount );
%             fcns.name{fcnNum}='AlazarAllocBufferU16'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint16Ptr'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarFreeBufferU16 ( void * hBoard , unsigned short * pBuffer );
%             fcns.name{fcnNum}='AlazarFreeBufferU16'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint16Ptr'};fcnNum=fcnNum+1;
%             structs.s_BoardDef.members=struct('RecordCount', 'uint32', 'RecLength', 'uint32', 'PreDepth', 'uint32', 'ClockSource', 'uint32', 'ClockEdge', 'uint32', 'SampleRate', 'uint32', 'CouplingChanA', 'uint32', 'InputRangeChanA', 'uint32', 'InputImpedChanA', 'uint32', 'CouplingChanB', 'uint32', 'InputRangeChanB', 'uint32', 'InputImpedChanB', 'uint32', 'TriEngOperation', 'uint32', 'TriggerEngine1', 'uint32', 'TrigEngSource1', 'uint32', 'TrigEngSlope1', 'uint32', 'TrigEngLevel1', 'uint32', 'TriggerEngine2', 'uint32', 'TrigEngSource2', 'uint32', 'TrigEngSlope2', 'uint32', 'TrigEngLevel2', 'uint32');
%             structs.s_HEADER2.members=struct('TimeStampLowPart', 'uint32');
%             % structs.s_ALAZAR_HEADER.members=struct('hdr0', 'error', 'hdr1', 'error', 'hdr2', 's_HEADER2', 'hdr3', 'error');
%             structs.s_OVERLAPPED.packing=1;
%             structs.s_OVERLAPPED.members=struct('Internal', 'ulong', 'InternalHigh', 'ulong', 'Offset', 'ulong', 'OffsetHigh', 'ulong', 'hEvent', 'voidPtr');
%             enuminfo.MSILS=struct('KINDEPENDENT',0,'KSLAVE',1,'KMASTER',2,'KLASTSLAVE',3);
%             enuminfo.BoardTypes=struct('ATS_NONE',0,'ATS850',1,'ATS310',2,'ATS330',3,'ATS855',4,'ATS315',5,'ATS335',6,'ATS460',7,'ATS860',8,'ATS660',9,'ATS665',10,'ATS9462',11,'ATS9434',12,'ATS9870',13,'ATS9350',14,'ATS9325',15,'ATS9440',16,'ATS9410',17,'ATS9351',18,'ATS9310',19,'ATS9461',20,'ATS9850',21,'ATS9625',22,'ATG6500',23,'ATS9626',24,'ATS9360',25,'ATS_LAST',26);
%             methodinfo=fcns;
%         end
%         
%         function [methodinfo,structs,enuminfo] = AlazarInclude()
%             %ALAZARINCLUDE Create structures to define interfaces found in 'AlazarApi'.
%             
%             %This function was generated by loadlibrary.m parser version 1.1.6.13 on Wed Jan 30 15:22:08 2013
%             %perl options:'AlazarApi.i -outfile=AlazarInclude.m'
%             ival={cell(1,0)}; % change 0 to the actual number of functions to preallocate the data.
%             fcns=struct('name',ival,'calltype',ival,'LHS',ival,'RHS',ival,'alias',ival);
%             structs=[];enuminfo=[];fcnNum=1;
%             % unsigned int AlazarGetOEMFPGAName ( int opcodeID , char * FullPath , unsigned long * error );
%             fcns.name{fcnNum}='AlazarGetOEMFPGAName'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'int32', 'cstring', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarOEMSetWorkingDirectory ( char * wDir , unsigned long * error );
%             fcns.name{fcnNum}='AlazarOEMSetWorkingDirectory'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'cstring', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarOEMGetWorkingDirectory ( char * wDir , unsigned long * error );
%             fcns.name{fcnNum}='AlazarOEMGetWorkingDirectory'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'cstring', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarParseFPGAName ( const char * FullName , char * Name , unsigned int * Type , unsigned int * MemSize , unsigned int * MajVer , unsigned int * MinVer , unsigned int * MajRev , unsigned int * MinRev , unsigned int * error );
%             fcns.name{fcnNum}='AlazarParseFPGAName'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'cstring', 'cstring', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarOEMDownLoadFPGA ( void * h , char * FileName , unsigned int * RetValue );
%             fcns.name{fcnNum}='AlazarOEMDownLoadFPGA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'cstring', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarDownLoadFPGA ( void * h , char * FileName , unsigned int * RetValue );
%             fcns.name{fcnNum}='AlazarDownLoadFPGA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'cstring', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarReadWriteTest ( void * h , unsigned int * Buffer , unsigned int SizeToWrite , unsigned int SizeToRead );
%             fcns.name{fcnNum}='AlazarReadWriteTest'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32Ptr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarMemoryTest ( void * h , unsigned int * errors );
%             fcns.name{fcnNum}='AlazarMemoryTest'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBusyFlag ( void * h , int * BusyFlag );
%             fcns.name{fcnNum}='AlazarBusyFlag'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'int32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarTriggeredFlag ( void * h , int * TriggeredFlag );
%             fcns.name{fcnNum}='AlazarTriggeredFlag'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'int32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBoardsFound ();
%             fcns.name{fcnNum}='AlazarBoardsFound'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
%             % void * AlazarOpen ( char * BoardNameID );
%             fcns.name{fcnNum}='AlazarOpen'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'cstring'};fcnNum=fcnNum+1;
%             % void AlazarClose ( void * h );
%             fcns.name{fcnNum}='AlazarClose'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % MSILS AlazarGetBoardKind ( void * h );
%             fcns.name{fcnNum}='AlazarGetBoardKind'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='MSILS'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetCPLDVersion ( void * h , unsigned char * Major , unsigned char * Minor );
%             fcns.name{fcnNum}='AlazarGetCPLDVersion'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetChannelInfo ( void * h , unsigned int * MemSize , unsigned char * SampleSize );
%             fcns.name{fcnNum}='AlazarGetChannelInfo'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetSDKVersion ( unsigned char * Major , unsigned char * Minor , unsigned char * Revision );
%             fcns.name{fcnNum}='AlazarGetSDKVersion'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'uint8Ptr', 'uint8Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetDriverVersion ( unsigned char * Major , unsigned char * Minor , unsigned char * Revision );
%             fcns.name{fcnNum}='AlazarGetDriverVersion'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'uint8Ptr', 'uint8Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarInputControl ( void * h , unsigned char Channel , unsigned int Coupling , unsigned int InputRange , unsigned int Impedance );
%             fcns.name{fcnNum}='AlazarInputControl'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetPosition ( void * h , unsigned char Channel , int PMPercent , unsigned int InputRange );
%             fcns.name{fcnNum}='AlazarSetPosition'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'int32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetExternalTrigger ( void * h , unsigned int Coupling , unsigned int Range );
%             fcns.name{fcnNum}='AlazarSetExternalTrigger'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetTriggerDelay ( void * h , unsigned int Delay );
%             fcns.name{fcnNum}='AlazarSetTriggerDelay'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetTriggerTimeOut ( void * h , unsigned int to_ns );
%             fcns.name{fcnNum}='AlazarSetTriggerTimeOut'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarTriggerTimedOut ( void * h );
%             fcns.name{fcnNum}='AlazarTriggerTimedOut'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetTriggerAddress ( void * h , unsigned int Record , unsigned int * TriggerAddress , unsigned int * TimeStampHighPart , unsigned int * TimeStampLowPart );
%             fcns.name{fcnNum}='AlazarGetTriggerAddress'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32Ptr', 'uint32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetTriggerOperation ( void * h , unsigned int TriggerOperation , unsigned int TriggerEngine1 , unsigned int Source1 , unsigned int Slope1 , unsigned int Level1 , unsigned int TriggerEngine2 , unsigned int Source2 , unsigned int Slope2 , unsigned int Level2 );
%             fcns.name{fcnNum}='AlazarSetTriggerOperation'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetTriggerTimestamp ( void * h , unsigned int Record , U64 * Timestamp_samples );
%             fcns.name{fcnNum}='AlazarGetTriggerTimestamp'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetTriggerOperationForScanning ( void * h , unsigned int slope , unsigned int level , unsigned int options );
%             fcns.name{fcnNum}='AlazarSetTriggerOperationForScanning'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarAbortCapture ( void * h );
%             fcns.name{fcnNum}='AlazarAbortCapture'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarForceTrigger ( void * h );
%             fcns.name{fcnNum}='AlazarForceTrigger'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarForceTriggerEnable ( void * h );
%             fcns.name{fcnNum}='AlazarForceTriggerEnable'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarStartCapture ( void * h );
%             fcns.name{fcnNum}='AlazarStartCapture'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCaptureMode ( void * h , unsigned int Mode );
%             fcns.name{fcnNum}='AlazarCaptureMode'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarStreamCapture ( void * h , void * Buffer , unsigned int BufferSize , unsigned int DeviceOption , unsigned int ChannelSelect , unsigned int * error );
%             fcns.name{fcnNum}='AlazarStreamCapture'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarHyperDisp ( void * h , void * Buffer , unsigned int BufferSize , unsigned char * ViewBuffer , unsigned int ViewBufferSize , unsigned int NumOfPixels , unsigned int Option , unsigned int ChannelSelect , unsigned int Record , long TransferOffset , unsigned int * error );
%             fcns.name{fcnNum}='AlazarHyperDisp'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint8Ptr', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32', 'int32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarFastPRRCapture ( void * h , void * Buffer , unsigned int BufferSize , unsigned int DeviceOption , unsigned int ChannelSelect , unsigned int * error );
%             fcns.name{fcnNum}='AlazarFastPRRCapture'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBusy ( void * h );
%             fcns.name{fcnNum}='AlazarBusy'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarTriggered ( void * h );
%             fcns.name{fcnNum}='AlazarTriggered'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetStatus ( void * h );
%             fcns.name{fcnNum}='AlazarGetStatus'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarDetectMultipleRecord ( void * h );
%             fcns.name{fcnNum}='AlazarDetectMultipleRecord'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetRecordCount ( void * h , unsigned int Count );
%             fcns.name{fcnNum}='AlazarSetRecordCount'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetRecordSize ( void * h , unsigned int PreSize , unsigned int PostSize );
%             fcns.name{fcnNum}='AlazarSetRecordSize'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetCaptureClock ( void * h , unsigned int Source , unsigned int Rate , unsigned int Edge , unsigned int Decimation );
%             fcns.name{fcnNum}='AlazarSetCaptureClock'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetExternalClockLevel ( void * h , float percent );
%             fcns.name{fcnNum}='AlazarSetExternalClockLevel'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'single'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetClockSwitchOver ( void * hBoard , unsigned int uMode , unsigned int uDummyClockOnTime_ns , unsigned int uReserved );
%             fcns.name{fcnNum}='AlazarSetClockSwitchOver'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarRead ( void * h , unsigned int Channel , void * Buffer , int ElementSize , long Record , long TransferOffset , unsigned int TransferLength );
%             fcns.name{fcnNum}='AlazarRead'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'voidPtr', 'int32', 'int32', 'int32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetParameter ( void * h , unsigned char Channel , unsigned int Parameter , long Value );
%             fcns.name{fcnNum}='AlazarSetParameter'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'int32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetParameterUL ( void * h , unsigned char Channel , unsigned int Parameter , unsigned int Value );
%             fcns.name{fcnNum}='AlazarSetParameterUL'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetParameter ( void * h , unsigned char Channel , unsigned int Parameter , long * RetValue );
%             fcns.name{fcnNum}='AlazarGetParameter'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'int32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetParameterUL ( void * h , unsigned char Channel , unsigned int Parameter , unsigned int * RetValue );
%             fcns.name{fcnNum}='AlazarGetParameterUL'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % void * AlazarGetSystemHandle ( unsigned int sid );
%             fcns.name{fcnNum}='AlazarGetSystemHandle'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarNumOfSystems ();
%             fcns.name{fcnNum}='AlazarNumOfSystems'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}=[];fcnNum=fcnNum+1;
%             % unsigned int AlazarBoardsInSystemBySystemID ( unsigned int sid );
%             fcns.name{fcnNum}='AlazarBoardsInSystemBySystemID'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBoardsInSystemByHandle ( void * systemHandle );
%             fcns.name{fcnNum}='AlazarBoardsInSystemByHandle'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % void * AlazarGetBoardBySystemID ( unsigned int sid , unsigned int brdNum );
%             fcns.name{fcnNum}='AlazarGetBoardBySystemID'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % void * AlazarGetBoardBySystemHandle ( void * systemHandle , unsigned int brdNum );
%             fcns.name{fcnNum}='AlazarGetBoardBySystemHandle'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetLED ( void * h , unsigned int state );
%             fcns.name{fcnNum}='AlazarSetLED'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarQueryCapability ( void * h , unsigned int request , unsigned int value , unsigned int * retValue );
%             fcns.name{fcnNum}='AlazarQueryCapability'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarMaxSglTransfer ( ALAZAR_BOARDTYPES bt );
%             fcns.name{fcnNum}='AlazarMaxSglTransfer'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'BoardTypes'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetMaxRecordsCapable ( void * h , unsigned int RecordLength , unsigned int * num );
%             fcns.name{fcnNum}='AlazarGetMaxRecordsCapable'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetWhoTriggeredBySystemHandle ( void * systemHandle , unsigned int brdNum , unsigned int recNum );
%             fcns.name{fcnNum}='AlazarGetWhoTriggeredBySystemHandle'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetWhoTriggeredBySystemID ( unsigned int sid , unsigned int brdNum , unsigned int recNum );
%             fcns.name{fcnNum}='AlazarGetWhoTriggeredBySystemID'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSetBWLimit ( void * h , unsigned int Channel , unsigned int enable );
%             fcns.name{fcnNum}='AlazarSetBWLimit'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarSleepDevice ( void * h , unsigned int state );
%             fcns.name{fcnNum}='AlazarSleepDevice'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarStartAutoDMA ( void * h , void * Buffer1 , unsigned int UseHeader , unsigned int ChannelSelect , long TransferOffset , unsigned int TransferLength , long RecordsPerBuffer , long RecordCount , int * error , unsigned int r1 , unsigned int r2 , unsigned int * r3 , unsigned int * r4 );
%             fcns.name{fcnNum}='AlazarStartAutoDMA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint32', 'int32', 'uint32', 'int32', 'int32', 'int32Ptr', 'uint32', 'uint32', 'uint32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetNextAutoDMABuffer ( void * h , void * Buffer1 , void * Buffer2 , long * WhichOne , long * RecordsTransfered , int * error , unsigned int r1 , unsigned int r2 , long * TriggersOccurred , unsigned int * r4 );
%             fcns.name{fcnNum}='AlazarGetNextAutoDMABuffer'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'voidPtr', 'int32Ptr', 'int32Ptr', 'int32Ptr', 'uint32', 'uint32', 'int32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetNextBuffer ( void * h , void * Buffer1 , void * Buffer2 , long * WhichOne , long * RecordsTransfered , int * error , unsigned int r1 , unsigned int r2 , long * TriggersOccurred , unsigned int * r4 );
%             fcns.name{fcnNum}='AlazarGetNextBuffer'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'voidPtr', 'int32Ptr', 'int32Ptr', 'int32Ptr', 'uint32', 'uint32', 'int32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCloseAUTODma ( void * h );
%             fcns.name{fcnNum}='AlazarCloseAUTODma'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarAbortAutoDMA ( void * h , void * Buffer , int * error , unsigned int r1 , unsigned int r2 , unsigned int * r3 , unsigned int * r4 );
%             fcns.name{fcnNum}='AlazarAbortAutoDMA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'int32Ptr', 'uint32', 'uint32', 'uint32Ptr', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetAutoDMAHeaderValue ( void * h , unsigned int Channel , void * DataBuffer , unsigned int Record , unsigned int Parameter , int * error );
%             fcns.name{fcnNum}='AlazarGetAutoDMAHeaderValue'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'voidPtr', 'uint32', 'uint32', 'int32Ptr'};fcnNum=fcnNum+1;
%             % float AlazarGetAutoDMAHeaderTimeStamp ( void * h , unsigned int Channel , void * DataBuffer , unsigned int Record , int * error );
%             fcns.name{fcnNum}='AlazarGetAutoDMAHeaderTimeStamp'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='single'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'voidPtr', 'uint32', 'int32Ptr'};fcnNum=fcnNum+1;
%             % void * AlazarGetAutoDMAPtr ( void * h , unsigned int DataOrHeader , unsigned int Channel , void * DataBuffer , unsigned int Record , int * error );
%             fcns.name{fcnNum}='AlazarGetAutoDMAPtr'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='voidPtr'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'voidPtr', 'uint32', 'int32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarWaitForBufferReady ( void * h , long tms );
%             fcns.name{fcnNum}='AlazarWaitForBufferReady'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'int32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarEvents ( void * h , unsigned int enable );
%             fcns.name{fcnNum}='AlazarEvents'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarBeforeAsyncRead ( void * hBoard , unsigned int uChannelSelect , long lTransferOffset , unsigned int uSamplesPerRecord , unsigned int uRecordsPerBuffer , unsigned int uRecordsPerAcquisition , unsigned int uFlags );
%             fcns.name{fcnNum}='AlazarBeforeAsyncRead'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'int32', 'uint32', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarAsyncRead ( void * hBoard , void * pBuffer , unsigned int BytesToRead , OVERLAPPED * pOverlapped );
%             fcns.name{fcnNum}='AlazarAsyncRead'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 's_OVERLAPPEDPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarAbortAsyncRead ( void * hBoard );
%             fcns.name{fcnNum}='AlazarAbortAsyncRead'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarPostAsyncBuffer ( void * hDevice , void * pBuffer , unsigned int uBufferLength_bytes );
%             fcns.name{fcnNum}='AlazarPostAsyncBuffer'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarWaitAsyncBufferComplete ( void * hDevice , void * pBuffer , unsigned int uTimeout_ms );
%             fcns.name{fcnNum}='AlazarWaitAsyncBufferComplete'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarWaitNextAsyncBufferComplete ( void * hDevice , void * pBuffer , unsigned int uBufferLength_bytes , unsigned int uTimeout_ms );
%             fcns.name{fcnNum}='AlazarWaitNextAsyncBufferComplete'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCreateStreamFileA ( void * hDevice , const char * pszFilePath );
%             fcns.name{fcnNum}='AlazarCreateStreamFileA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'cstring'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCreateStreamFileW ( void * hDevice , const WCHAR * pszFilePath );
%             fcns.name{fcnNum}='AlazarCreateStreamFileW'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint16Ptr'};fcnNum=fcnNum+1;
%             % long AlazarFlushAutoDMA ( void * h );
%             fcns.name{fcnNum}='AlazarFlushAutoDMA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='int32'; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % void AlazarStopAutoDMA ( void * h );
%             fcns.name{fcnNum}='AlazarStopAutoDMA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}=[]; fcns.RHS{fcnNum}={'voidPtr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarResetTimeStamp ( void * h , unsigned int resetFlag );
%             fcns.name{fcnNum}='AlazarResetTimeStamp'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarReadRegister ( void * hDevice , unsigned int offset , unsigned int * retVal , unsigned int pswrd );
%             fcns.name{fcnNum}='AlazarReadRegister'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32Ptr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarWriteRegister ( void * hDevice , unsigned int offset , unsigned int Val , unsigned int pswrd );
%             fcns.name{fcnNum}='AlazarWriteRegister'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarDACSetting ( void * h , unsigned int SetGet , unsigned int OriginalOrModified , unsigned char Channel , unsigned int DACNAME , unsigned int Coupling , unsigned int InputRange , unsigned int Impedance , unsigned int * getVal , unsigned int setVal , unsigned int * error );
%             fcns.name{fcnNum}='AlazarDACSetting'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint8', 'uint32', 'uint32', 'uint32', 'uint32', 'uint32Ptr', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarConfigureAuxIO ( void * hDevice , unsigned int uMode , unsigned int uParameter );
%             fcns.name{fcnNum}='AlazarConfigureAuxIO'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % const char * AlazarErrorToText ( unsigned int code );
%             fcns.name{fcnNum}='AlazarErrorToText'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='cstring'; fcns.RHS{fcnNum}={'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarConfigureSampleSkipping ( void * hBoard , unsigned int uMode , unsigned int uSampleClocksPerRecord , unsigned short * pwClockSkipMask );
%             fcns.name{fcnNum}='AlazarConfigureSampleSkipping'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint16Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCoprocessorRegisterRead ( void * hDevice , unsigned int offset , unsigned int * pValue );
%             fcns.name{fcnNum}='AlazarCoprocessorRegisterRead'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCoprocessorRegisterWrite ( void * hDevice , unsigned int offset , unsigned int value );
%             fcns.name{fcnNum}='AlazarCoprocessorRegisterWrite'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCoprocessorDownloadA ( void * hBoard , char * pszFileName , unsigned int uOptions );
%             fcns.name{fcnNum}='AlazarCoprocessorDownloadA'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'cstring', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarCoprocessorDownloadW ( void * hBoard , WCHAR * pszFileName , unsigned int uOptions );
%             fcns.name{fcnNum}='AlazarCoprocessorDownloadW'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint16Ptr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarGetBoardRevision ( void * hBoard , unsigned char * Major , unsigned char * Minor );
%             fcns.name{fcnNum}='AlazarGetBoardRevision'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8Ptr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned int AlazarConfigureRecordAverage ( void * hBoard , unsigned int uMode , unsigned int uSamplesPerRecord , unsigned int uRecordsPerAverage , unsigned int uOptions );
%             fcns.name{fcnNum}='AlazarConfigureRecordAverage'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint32', 'uint32', 'uint32', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned char * AlazarAllocBufferU8 ( void * hBoard , unsigned int uSampleCount );
%             fcns.name{fcnNum}='AlazarAllocBufferU8'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint8Ptr'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarFreeBufferU8 ( void * hBoard , unsigned char * pBuffer );
%             fcns.name{fcnNum}='AlazarFreeBufferU8'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint8Ptr'};fcnNum=fcnNum+1;
%             % unsigned short * AlazarAllocBufferU16 ( void * hBoard , unsigned int uSampleCount );
%             fcns.name{fcnNum}='AlazarAllocBufferU16'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint16Ptr'; fcns.RHS{fcnNum}={'voidPtr', 'uint32'};fcnNum=fcnNum+1;
%             % unsigned int AlazarFreeBufferU16 ( void * hBoard , unsigned short * pBuffer );
%             fcns.name{fcnNum}='AlazarFreeBufferU16'; fcns.calltype{fcnNum}='cdecl'; fcns.LHS{fcnNum}='uint32'; fcns.RHS{fcnNum}={'voidPtr', 'uint16Ptr'};fcnNum=fcnNum+1;
%             structs.s_BoardDef.packing=8;
%             structs.s_BoardDef.members=struct('RecordCount', 'uint32', 'RecLength', 'uint32', 'PreDepth', 'uint32', 'ClockSource', 'uint32', 'ClockEdge', 'uint32', 'SampleRate', 'uint32', 'CouplingChanA', 'uint32', 'InputRangeChanA', 'uint32', 'InputImpedChanA', 'uint32', 'CouplingChanB', 'uint32', 'InputRangeChanB', 'uint32', 'InputImpedChanB', 'uint32', 'TriEngOperation', 'uint32', 'TriggerEngine1', 'uint32', 'TrigEngSource1', 'uint32', 'TrigEngSlope1', 'uint32', 'TrigEngLevel1', 'uint32', 'TriggerEngine2', 'uint32', 'TrigEngSource2', 'uint32', 'TrigEngSlope2', 'uint32', 'TrigEngLevel2', 'uint32');
%             structs.s_HEADER2.packing=8;
%             structs.s_HEADER2.members=struct('TimeStampLowPart', 'uint32');
%             structs.s_ALAZAR_HEADER.packing=8;
%             % structs.s_ALAZAR_HEADER.members=struct('hdr0', 'error', 'hdr1', 'error', 'hdr2', 's_HEADER2', 'hdr3', 'error');
%             structs.s_OVERLAPPED.packing=8;
%             structs.s_OVERLAPPED.members=struct('Internal', 'uint32', 'InternalHigh', 'uint32', 'Offset', 'uint32', 'OffsetHigh', 'uint32', 'hEvent', 'voidPtr');
%             enuminfo.MSILS=struct('KINDEPENDENT',0,'KSLAVE',1,'KMASTER',2,'KLASTSLAVE',3);
%             enuminfo.BoardTypes=struct('ATS_NONE',0,'ATS850',1,'ATS310',2,'ATS330',3,'ATS855',4,'ATS315',5,'ATS335',6,'ATS460',7,'ATS860',8,'ATS660',9,'ATS665',10,'ATS9462',11,'ATS9434',12,'ATS9870',13,'ATS9350',14,'ATS9325',15,'ATS9440',16,'ATS9410',17,'ATS9351',18,'ATS9310',19,'ATS9461',20,'ATS9850',21,'ATS9625',22,'ATG6500',23,'ATS9626',24,'ATS9360',25,'ATS_LAST',26);
%             methodinfo=fcns;
%         end
    end
end