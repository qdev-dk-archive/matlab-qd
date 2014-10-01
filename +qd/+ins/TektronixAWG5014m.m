% Commands, taken from programming manual and condensed

% Commands marked with @ have been implemented below
%	ABOR
%	AWGC:DOUT[1|2]{ OFF=0| ON=1|?}							awg5014direct
%	AWGC:EVEN
%	AWGC:EVEN:SOFT <NR1>									AWGjump
%	AWGC:RMOD{ CONT| TRIG| GAT| ENH|?}						awg5014mode
%	AWGC:RST?													AWGrun520
%	AWGC:RUN													AWGrun520
%	AWGC:SRES <file_name>[,<msus>]							AWGsavesettings
%	AWGC:SSAV <file_name>[,<msus>]							awg5014loadsettings
%	AWGC:STOP												AWGrun520
%	CAL?														AWGcal
%	*CLS														awg5014cls
%	DIAG:DATA?
%	DIAG[?]
%	DIAG:SEL{ ALL| OUTP| RMOD| ROSC| SMEM| SYST| WMEM|?}
%	DISP:BRIG{ NRf|?}											awg5014bright
%	*ESE{ <NR1>|?}
%	*ESR?
%	HCOP:DEV:LANG{ BMP| TIFF|?}
%	HCOP
%	*IDN?
%	MMEM:CAT? [<msus>]										AWGcatalog
%	MMEM:CDIR{ <directory_name>|?}								AWGcd
%	MMEM:COPY <file_source>,<file_destination>					AWGcopy
%	MMEM:DATA <file_name>,<data>								awg5014sendpattern
%	MMEM:DEL <file_name>[,<msus>]								AWGdelete
%	MMEM:MDIR <directory_name>[,<msus>]						AWGmkdir
%	MMEM:MSIS[ "[MAIN|FLOP|NET1|NET2|NET3]"|?]				AWGdisk
%	MMEM:MOVE <file_source>,<file_destination>					AWGmove
%	MMEM:NAME[ <file_name>[,<msus>]|?]
%	*OPT?
%	OUTP[1|2]:FILT:FREQ[ <NRf>Hz| INF|?]							awg5014filter
%	OUTP[1|2|7]:STAT{ OFF=0| ON=1|?}							awg5014runchan
%	*PSC{ 0| 1|?}
%	*RST														awg5014rst
%	SOUR1:COMB:FEED{ "SOUR7"| "SOUR8"| ""|?}
%	SOUR:FREQ{ <NRf>Hz|?}										awg5014freq
%	SOUR[1|2]:FUNC:USER{ <file_name>[,<msus>]|?}				awg5014func
%	SOUR[1|2]:MARK[1|2]:DEL{ <NRf>s|?}							awg5014markerdelay
%	SOUR[1|2]:MARK[1|2]:VOLT:HIGH{ <NRf>|?}					awg5014markerlevel
%   SOUR[1|2]:MARK[1|2]:VOLT:LOW{ <NRf>|?}						awg5014markerlevel
%	SOUR7:POW{ <NRf>|?}
%	SOUR:ROSC:SOUR{ INT| EXT|?}
%	SOUR[1|2]:VOLT{ <NRf>mV|?}									awg5014amp
%	SOUR[1|2]:VOLT:OFFS{ <NRf>|?}								awg5014offset
%	*SRE{ <NR1>|?}
%	STAT:OPER:COND?
%	STAT:OPER:ENAB{ <NR1>|?}
%	STAT:OPER?
%	STAT:PRES
%	STAT:QUES:COND?
%	STAT:QUES:ENAB{ <NR1>|?}
%	STAT:QUES?
%	*STB?
%	SYST:BEEP
%	(lots of SYST:COMM commands about using IP)
%	SYST:DATE{ <YYYY>,<MM>,<DD>|?}                              AWGtimesync
%	SYST:ERR?													awg5014error
%	SYST:KDIR{ FORW| BACK|?}
%	SYST:KLOC{ OFF=0| ON=1|?}									AWGlock
%	SYST:TIME{ <HH>,<MM>,<SS>|?}								AWGtimesync
%	SYST:UPT?
%	SYST:VERS?
%	TRIG														AWGrun520
%	TRIG:IMP{ 50| 1e3|?}										awg5014trigsetup
%	TRIG:LEV{ <NRf>|?}											awg5014trigsetup
%	TRIG:POL{ POS: NEG|?}										awg5014trigsetup
%	TRIG:SLOP{ POS| NEG|?}										awg5014trigsetup
%	TRIG:SOUR{ INT| EXT|?}										awg5014trigsetup
%	TRIG:TIM{ <NR3>s|?}											awg5014reptime
%   *TST?

%
%	Higher level commands
%
