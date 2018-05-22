# tranim
**HTTP traffic animation CLI software.**
Uses tcpdump to capture the traffic.
Traffic is subsequently analyzed and number of ip packets transfered is displayed against time.

Usage:  $0 [-v] [-y label] [-x label] [-r recordings_min] [-T seconds] [-F frames_sec] [-l legend] [-g GNUparams] [-e effects] [-f config_path] [-n rec_name] [datafile]
        $0 -h
___
        Options:      
	        -y set the label for the y axis
	        -x set the label for the x axis
	        -r traffic recordings done per minute (max=60) 
	           milliseconds are not used => RPM is not precise.
	        -T recording duration (in seconds)
	        -F number of frames per second (in animation)
	        -l legend of the plot
	        -g GNUplot parameters
	        -e effect parameters
	        -f path to a config file
	        -n name of recording
            -v verbose
            -h help
            
___

Example:
`./tranim.sh -T 10 -r 60 -n "newestr" -F 1 -f tranim.conf -v`
