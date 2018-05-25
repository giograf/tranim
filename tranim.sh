#!/bin/bash
# Traffic animation script that displays number of HTTP(S) packets transfered at time of recording.

# Secondary ###################################################################
DEBUG=0
VERBOSE=0
debug() { ((DEBUG)) && echo "$0[debug]: $@" >&2; }
verbose() { ((VERBOSE)) && echo "$0[info]: $@" >&2; }
err() { echo "$0[error]: $@" >&2; exit 1; }
usage() { echo "
Usage:  $0 [-v] [-y label] [-x label] [-r recordings_min] [-T seconds] [-F frames_sec] [-l legend] [-f config_path] [-n rec_name] [datafile]
        $0 -h
	"; }
help() { 
	usage
	echo "
	-y set the label for the y axis
	-x set the label for the x axis
	-r traffic recordings done per minute (max=60) 
	   milliseconds are not used => RPM is not precise.
	-T recording duration (in seconds)
	-F number of frames per second (in animation)
	-l legend of the plot
	-f path to a config file
	-n name of recording

        -v  verbose
        -h  help
"; 
}

###############################################################################
# Read options & arguments ####################################################
CONFIG_PATH="$HOME/.tranim/tranim.conf";
IMAGE_PATH="/tmp/tranim/images";
RESULT_FILE="/tmp/tranim/result.txt";
DATA_PATH="/tmp/tranim/sniff.txt";
while getopts y:x:r:T:F:l:g:e:f:n:vh parm; do
	case $parm in
		y)
			# yLabel
			Ylabel="\"$OPTARG\"";
			;;
		x)
			# xLabel
			Xlabel="\"$OPTARG\"";
			;;
		r)
			if [ "$OPTARG" -lt 61 ] && [ "$OPTARG" -gt 0 ]
			then
				RPM=$OPTARG;
			else
				err "Valid number of recordings per minute is [1; 60]!"
			fi
			;;
		T) 
			Time=$OPTARG
			;;
		F)
			FPS=$OPTARG;
			;;
		l)
			Legend="\"$OPTARG\"";
			;;
		f)
			# Config File
			CONFIG_PATH=$OPTARG;
			;;
		n)
			Name=$OPTARG;
			;;
		v)
			VERBOSE=1;
			;;
		h)	
			help
			exit 0;		
			;;
		*)	usage;
			err "Incorrect argument was supplied";
	esac
done
shift $((OPTIND-1));

###############################################################################
# Final Configuration & Preparation ###########################################
XlabelConf=$(cat "$CONFIG_PATH" | grep "^Xlabel " | cut -d" " -f2);
YlabelConf=$(cat "$CONFIG_PATH" | grep "^Ylabel " | cut -d" " -f2);
TimeConf=$(cat "$CONFIG_PATH" | grep "^Time " | cut -d" " -f2);
RPMConf=$(cat "$CONFIG_PATH" | grep "^RPM " | cut -d" " -f2);
FPSConf=$(cat "$CONFIG_PATH" | grep "^FPS " | cut -d" " -f2);
LegendConf=$(cat "$CONFIG_PATH" | grep "^Legend " | cut -d" " -f2);
NameConf=$(cat "$CONFIG_PATH" | grep "^Name " | cut -d" " -f2);
[ -n "$Xlabel" ] || Xlabel=$XlabelConf;
[ -n "$Ylabel" ] || Ylabel=$YlabelConf;
[ -n "$RPM" ] || RPM=$RPMConf;
[ -n "$Time" ] || Time=$TimeConf;
[ -n "$FPS" ] || FPS=$FPSConf;
[ -n "$Legend" ] || Legend=$LegendConf;
[ -n "$Name" ] || Name=$NameConf;
verbose "Default configuration is loaded.";
# Create folder for the temporary images (if non-existent)
[ ! -d /tmp/tranim ] && mkdir -p /tmp/tranim && verbose "Creating temporary folder:
/tmp/tranim";
[ ! -d "$IMAGE_PATH" ] && mkdir -p $IMAGE_PATH && verbose "Creating temporary folder: $IMAGE_PATH";

###############################################################################
# Get Data ####################################################################
# Check whether recording was supplied (not live then)
[ -n "$1" ] && RECORD_PATH="$1" && verbose "File with records was supplied: $1";
# Sniff
[ -z "$1" ] && verbose "Sniffing traffic..."
[ -z "$1" ] && timeout $Time tcpdump -w /tmp/tranim/sniff.pcap 'port 80 or port 443' > /dev/null 2>&1;
# Put data to text and remove content-unrelated lines
[ -z "$1" ] && tcpdump -ttttt -qns 0 -r /tmp/tranim/sniff.pcap 2>&1 | cut -d"." -f1 | cut -d" " -f2 > "$DATA_PATH";
[ -n "$1" ] && tcpdump -ttttt -qns 0 -r $RECORD_PATH 2>&1 | cut -d"." -f1 | cut -d" " -f2 > "$DATA_PATH";
sed -i '1d' "$DATA_PATH";

###############################################################################
# Precalculate Data ###########################################################
# Find time last packet was sent
TimeLastPacketRaw=$(tail -n 1 "$DATA_PATH" | cut -d" " -f2);
# Calculate number of frames to be created
HourLastPacket=$(echo "$TimeLastPacketRaw" | cut -d":" -f1 );
MinuteLastPacket=$(echo "$TimeLastPacketRaw" | cut -d":" -f2 );
SecondLastPacket=$(echo "$TimeLastPacketRaw" | cut -d":" -f3 | cut -d"." -f1);
debug $SecondLastPacket;
TimeLastPacket=$(echo "scale=2; $HourLastPacket * 3600 + $MinuteLastPacket * 60 + $SecondLastPacket" | bc); 
verbose "Length of recording: $TimeLastPacket seconds";
# Frame step (in seconds)
Step=$( echo "scale=1; 60/$RPM" | bc | cut -d"." -f1);
Frames=$(((TimeLastPacket/Step) + 1));
debug $Frames;
digits=${#Frames};
verbose "Frames to be created: $Frames";
if [ "$Frames" -lt 1 ]
then
	verbose "No traffic was captured \nQuiting.";
	exit 0;
fi
# Set Current Read-Time
ReadHourEnd=0;
ReadMinuteEnd=0;
ReadSecondEnd=0;
ReadSecondStart=0;
ReadMinuteStart=0;
ReadHourStart=0;

###############################################################################
# Calculate & Build the plot & Save the frames ################################
verbose "Creating frames: "
for ((i=1; i<=Frames; i++))
do
	# 1. Calculate Frame.
	# ((100*i/Frames % 10)) || verbose "$((100*i/Frames))% done";
	((VERBOSE)) && printf '\b\b\b\b%3d%% done' $((100*i/Frames))		
	[[ $((100*i/Frames)) == 100  ]] && echo " "; 
	ReadSecondStart=$ReadSecondEnd;
	ReadMinuteStart=$ReadMinuteEnd;
	ReadHourStart=$ReadHourEnd;
	ReadSecondEnd=$((ReadSecondEnd+Step));
	debug "ReadSecondEnd: $ReadSecondEnd";
	if [ "$ReadSecondEnd" -gt 59 ] 
	then
		debug "ReadSecondEnd $ReadSecondEnd";
		ReadMinuteEnd=$((ReadMinuteEnd+1));
		debug "ReadMinuteEnd: $ReadMinuteEnd";
		ReadSecondEnd=$((Step-(60-ReadSecondStart)));
		debug "ReadSecondEnd: $ReadSecondEnd";
		if [ "$ReadMinuteEnd" -gt 60 ]
		then
			$ReadMinuteEnd=0;
			$ReadHourEnd=$((ReadHourEnd+1));
		fi
	fi
	TimeStart=$(date -d"$ReadHourStart:$ReadMinuteStart:$ReadSecondStart" +"%H:%M:%S");
	debug "TimeStart: $TimeStart";
	TimeEnd=$(date -d"$ReadHourEnd:$ReadMinuteEnd:$ReadSecondEnd" +"%H:%M:%S");
	debug "TimeEnd: $TimeEnd";
	# 2. Create one frame of animation (one image)
	# 2.a. Prepare data for one frame
	sed -rne "/$TimeStart/,/$TimeEnd/ p" $DATA_PATH | wc -l >> $RESULT_FILE;
    	Range=$( sort -n "$RESULT_FILE" | sed -n '1h;${H;g;s/\n/:/;p}' );
	if [ $i -eq 1 ]
	then
		RangeValue=$(cat "$RESULT_FILE" | cut -d":" -f1);
		Range="-1:$RangeValue"
	fi
	debug "Y-axis range for frame #$i: $Range"
	head -n $i "$RESULT_FILE" > data;
	# 2.b. Create frame
	gnuplot <<-GNUPLOT
		set terminal png
		set title $Legend
		set ylabel $Ylabel
		set xlabel $Xlabel
		set output "$( printf "$IMAGE_PATH/%0${digits}d.png" $i )"
		plot [0:$Frames][$Range] 'data' with lines
GNUPLOT
done

###############################################################################
# Build an animation ##########################################################
# Deleting file with the same name if exists.
[ -s "${Name%.*}.mp4" ] && rm ${Name%.*}".mp4";
verbose "Joining frames into video file ${Name%.*}.mp4";
case $VERBOSE in
	0|1) ffmpeg -y -r "$FPS" -i "$IMAGE_PATH/%0${digits}d.png" "${Name%.*}.mp4" 2>/dev/null;;
 	*) ffmpeg -y -r "$FPS" -i "$IMAGE_PATH/%0${digits}d.png" "${Name%.*}.mp4";;  
esac
verbose "Video file processing finished.";
###############################################################################

# Clean-up ####################################################################
# Delete the frames
rm -rf $IMAGE_PATH;
# Delete the result file
[ -s "$RESULT_FILE" ] && rm $RESULT_FILE;
[ -s data ] && rm data;
verbose "Temporary files were deleted."
###############################################################################

exit 0
