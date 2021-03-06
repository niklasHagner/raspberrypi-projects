#!/usr/bin/env bash

#######################################################################
# Made by    : Ewoud Dronkert
# Licence    : GNU GPL v3
# Platform   : Raspberry Pi
# Requires   : bash, mpd, mpc, amixer, bc, at
# Location   : /usr/local/bin/
# Name       : piradio
# Version    : 1.3.1
# Date       : 2016-07-13
# Purpose    : Play radio streams via local mpd audio server
#              Use station abbreviations from user file radio.txt
#              Shutdown (auto-off) after 3 hours using 'at'
# Parameters : <none> | <station> | list |
#              vol [ + | = | - | min | max | def | 0..100 ] |
#              on | off | help
# Exit     0 : success
#          1 : help displayed
#          2 : radio.txt local user file not found
#          3 : station abbreviation not recognised
#          4 : mpc, amixer, bc or at executables not found
#######################################################################

# Variables
PLAYER=/usr/bin/mpc
MIXER=/usr/bin/alsamixer
BCBIN=/usr/bin/bc
ATBIN=/usr/bin/at
ATCMD="$PLAYER stop"
PIHOME=$(cat /etc/passwd | grep -e '^pi:' | cut -d':' -f6)
DBFILE=$PIHOME/radio.txt
DEFVOL=85
ADJVOL=5

#if [[ "curstation" > 0 ]]; then
#	echo "the current channel was already set to $curstation"
#else	
#	echo "the current channel wasn't set, so let's start at 1."
#	curstation=1
#fi


# Error codes
declare -i ERR_OK=0
declare -i ERR_HELP=1
declare -i ERR_DBNOTFOUND=2
declare -i ERR_IDNOTFOUND=3
declare -i ERR_APPNOTFOUND=4

# Copy/redirect output to stderr
function StdErr () {
	cat - 1>&2

}

if [ ! -x "$PLAYER" ]; then
	echo | StdErr
	echo "   Radio player not found: $PLAYER" | StdErr
	echo | StdErr
	exit $ERR_APPNOTFOUND
fi

if [ ! -x "$MIXER" ]; then
	echo | StdErr
	echo "   Mixer for volume control not found: $MIXER" | StdErr
	echo | StdErr
	exit $ERR_APPNOTFOUND
fi

if [ ! -x "$BCBIN" ]; then
	echo | StdErr
	echo "   Calc tool for volume control not found: $BCBIN" | StdErr
	echo | StdErr
	exit $ERR_APPNOTFOUND
fi

if [ ! -x "$ATBIN" ]; then
	echo | StdErr
	echo "   Scheduler for snooze not found: $ATBIN" | StdErr
	echo | StdErr
	exit $ERR_APPNOTFOUND
fi

# "at" with sudo to catch scheduled times across all users
# Requires visudo: add /usr/bin/at for user www-data
function SnoozeClear () {
	for i in $(sudo $ATBIN -l | grep -oP '^\d+' | sort | xargs); do
		j=$(sudo $ATBIN -c $i | tail -n 1)
		if [[ "$j" == "$ATCMD" ]]; then
			sudo $ATBIN -r $i &> /dev/null
		fi
	done
}

function SnoozeReset () {
	SnoozeClear
	echo -n "$ATCMD" | sudo $ATBIN -M now + 3 hours &> /dev/null
}

# Return earliest snooze time via standard out
function SnoozeFind () {
	for i in $(sudo $ATBIN -l | grep -oP '^\d+' | sort | xargs); do
		j=$(sudo $ATBIN -c $i | tail -n 1)
		if [[ "$j" == "$ATCMD" ]]; then
			#sudo $ATBIN -l | grep -P "^$i\t" | cut -d" " -f4 | cut -d":" -f1-2
			sudo $ATBIN -l | grep -P "^$i\t" | grep -oP '\d\d:\d\d'
		fi
	done
}

# Returns volume as a percentage 0-100 via standard out
function GetVolume () {
	$PLAYER volume | grep -oE '[0-9]+'
	#GET=$(sudo $MIXER cget numid=1)
	#MIN=$(echo "$GET" | /bin/grep -oE ',min=[^,]+' | /bin/grep -oE '[0-9-]+')
	#MAX=$(echo "$GET" | /bin/grep -oE ',max=[^,]+' | /bin/grep -oE '[0-9-]+')
	#VAL=$(echo "$GET" | /bin/grep -oE ': values=[0-9+-]+' | /bin/grep -oE '[0-9-]+')
	#echo "(100*($VAL-($MIN))+0.5*($MAX-($MIN)))/($MAX-($MIN))" | $BCBIN
}

# Required argument: volume as a percentage 0-100
function SetVolume () {
	VOL="${1//[^0-9]/}"
	LEN=${#VOL}
	if (( LEN >= 1 && LEN <= 3 && VOL >= 0 && VOL <= 100 )); then
		mpc -q volume $VOL
		#sudo $MIXER -q cset numid=1 -- "${VOL}%"
	fi
}

# Help
if [[ "$1" == "help" || "$1" == "--help" || "$1" == "/help" || \
      "$1" == "-h" || "$1" == "/h" || \
      "$1" == "?" || "$1" == "-?" || "$1" == "/?" ]]; then
	echo | StdErr
	echo "   Usage:" | StdErr
	echo "   - Which station is on?  : piradio" | StdErr
	echo "   - Tune to a station     : piradio <station-id>" | StdErr
	echo "   - List all stations     : piradio list" | StdErr
	echo "   - Show or adjust volume : piradio vol [ + | = | - | min | max | def | 0..100 ]" | StdErr
	echo "   - Mute or unmute        : piradio mute" | StdErr
	echo "   - Turn radio on or off  : piradio on | off" | StdErr
	echo | StdErr
	exit $ERR_HELP
fi

# Display current station/stream/volume if no argument
if [ -z "$1" ]; then
	curvolume=$(GetVolume)
	curstream=$($PLAYER -f "%file%" current)
	if [ -z "$curstream" ]; then
		curstation="(no stream found)"
	else
		if [ -f $DBFILE ]; then
			curstation=$(cat $DBFILE \
				| grep --colour=never -m 1 -F "$curstream" \
				| grep --colour=never -oP '^\S+')
			if [ -z "$curstation" ]; then
				curstation="(station not found)"
			fi
		else
			curstation="(station database not found at \"$DBFILE\")"
		fi
	fi
	snooze=$(SnoozeFind)
	echo
	[ -z "$curstation" ] || echo "   Station : $curstation"
	[ -z "$curstream" ]  || echo "   Stream  : $curstream"
	[ -z "$curvolume" ]  || echo "   Volume  : $curvolume"
	[ -z "$snooze" ]     || echo "   Snooze  : $snooze"
	echo
	exit $ERR_OK
fi

# List station IDs from station database
if [[ "$1" == "list" ]]; then
	if [ -f $DBFILE ]; then
		echo
		echo "   List of all stations:"
		cat $DBFILE | grep --color=never -oP "^\S+" | sort | sed s/^/\\t/
		echo
		exit $ERR_OK
	else
		echo | StdErr
		echo "   Station database not found at \"$DBFILE\"" | StdErr
		echo | StdErr
		exit $ERR_DBNOTFOUND
	fi
fi

# Turn radio on
if [[ "$1" == "on" || "$1" == "play" ]]; then
	# TODO: check if a radio stream is lined up
	$PLAYER play
	SnoozeReset
	exit $ERR_OK
fi

# Turn radio off
if [[ "$1" == "off" || "$1" == "stop" ]]; then
	$PLAYER stop > /dev/null
	SnoozeClear
	exit $ERR_OK
fi

# Display volume, optionally set or adjust or mute/unmute
if [[ "$1" == "vol" || "$1" == "mute" ]]; then
	declare -i curvol=$(GetVolume)
	declare -i newvol=$curvol
	declare -i minvol=$ADJVOL
	declare -i maxvol=100
	if [[ "$1" == "mute" || "$2" == "mute" ]]; then
		if (( curvol > minvol )); then
			# mute
			newvol=$minvol
		else
			# unmute
			newvol=$DEFVOL
		fi
	else
		if [ -n "$2" ]; then
			case "$2" in
				min) newvol=$minvol;;
				max) newvol=$maxvol;;
				def) newvol=$DEFVOL;;
				+)   (( newvol = curvol + ADJVOL ));;
				=)   (( newvol = curvol + ADJVOL ));;
				-)   (( newvol = curvol - ADJVOL ));;
				*)   newvol="$2";;
			esac
			if (( newvol >= maxvol )); then
				newvol=$maxvol
			elif (( newvol <= minvol )); then
				newvol=$minvol
			fi
		fi
	fi
	if (( newvol != curvol )); then
		# volume adjustment
		SetVolume $newvol
		curvol=$newvol
	fi
	echo
	echo "   Volume: $curvol"
	echo
	exit $ERR_OK
fi

# Play next radio station by jumping to the next row in the station file
if [[ "$1" == "next" || "$1" == "prev" ]]; then
	
	# Find the current station number 
	curstream=$($PLAYER -f "%file%" current)
	if [ -z "$curstream" ]; then
		curstation="(no stream found)"
		echo "No stream found. I'm just gonna start the player."
		$PLAYER play
		exit $ERR_OK
	else
		currentStationInfo=$(cat $DBFILE | grep --colour=never -m 1 -F "$curstream")
		CURRENT_CHANNEL_NUMBER=$(grep -n "$currentStationInfo" $DBFILE | cut -f1 -d:)
		echo "Station#: $CURRENT_CHANNEL_NUMBER. Info: $currentStationInfo ."
	fi

	echo "Currently playing # $CURRENT_CHANNEL_NUMBER"
	CURRENT_CHANNEL_NUMBER=$((CURRENT_CHANNEL_NUMBER+1))
	numberOfLinesInFile=$(grep "" -c $DBFILE)
	if [[ "$CURRENT_CHANNEL_NUMBER" > "$numberOfLinesInFile" ]]; then
		CURRENT_CHANNEL_NUMBER=1
	fi
	nextChannelUrl=$(sed "${CURRENT_CHANNEL_NUMBER}q;d" $DBFILE | grep --color=never -oP '\S+$')
	stream=$nextChannelUrl
	echo "Switching to channel# $CURRENT_CHANNEL_NUMBER > $stream"
	echo "playing stream: $stream"
	$PLAYER stop > /dev/null
	$PLAYER clear > /dev/null
	$PLAYER add $stream > /dev/null
	$PLAYER play
	SnoozeReset
	exit $ERR_OK
fi


# Argument is a Station ID
# Escape argument for use with grep -P
# Is it really safe? Not sure. Couldn't make escaping ] work, for instance.
safe=$(echo "$1" \
	| sed -e 's/\s*//g' \
	| sed -e 's/[\[\\^$.*?"-]/\\\0/g')
[ -f $DBFILE ] && stream=$(cat $DBFILE \
	| grep --color=never -m 1 -P "^$safe\s" \
	| grep --color=never -oP '\S+$')

if [ -z "$stream" ]; then
	echo | StdErr
	echo "   Station \"$1\" not found." | StdErr
	echo "   List stations : piradio list" | StdErr
	echo "   Usage info    : piradio help" | StdErr
	echo | StdErr
	exit $ERR_IDNOTFOUND
fi

# EXEMPEL 
# cat /home/pi/radio.txt | grep --color=never -m 1 -P "^p4\s" | grep --color=never -oP '\S+$'
# ger
# http://http-live.sr.se/p4stockholm-aac-192


echo "playing stream: $stream"
$PLAYER stop > /dev/null
$PLAYER clear > /dev/null
$PLAYER add $stream > /dev/null
$PLAYER play
SnoozeReset

exit $ERR_OK
