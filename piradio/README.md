piradio
=======

Play internet radio on Raspberry Pi 3 using Raspbian Wheezy

This is a fork of `https://github.com/ednl/piradio`

## Original project

This project was cloned from `https://github.com/ednl/piradio`

Changes made to the bash script
* The volume mixer `amixer` package wasn't available using `apt-get install` so I replaced it with the package `alsamixer`
* Added the command `next` to jump to the next radio station (the next line in `radio.txt`)

------------------------

## Channels
Specify channels in `radio.txt` 
Each line should contain one channel with the format: `channelName streamUrl`

For example
```
bbc4 		http://bbcwssc.ic.llnwd.net/stream/bbcwssc_mp1_ws-eieuk
Heartland 	http://rockthecradle.stream.publicradio.org/radioheartland.mp3
````

## Run the script
The bash scripts can be used on their own for the command line interface

1. Install packages: `sudo apt-get install mpd mpc alsamixer bc at`
2. Move radio.txt to your home folder `mv radio.txt /home/pi/radio.txt`
3. Start the script with `./piradio.sh play`

## Commands
`./piradio.sh help` - display info
`./piradio.sh list` - list commands
`./npiradio.sh bbc4` - play a specific channel where `bbc4` is a channelName listed in `radio.txt`
`./piradio.sh next` - play the next channel listed in `radio.txt` (assumes something is already playing)
`./piradio.sh play` - starts playing (and sets an automatic 3hr sleep timer)
`./piradio.sh stop` - stops. you can resume later 

### Tech used for CLI

* `mpc` is the player and `mpd` is the media server
* `alsamixer` is used to control the volume


## Other Interfaces

### Web interface
The php files are only used for the web interface

1. Install packages: `sudo apt-get install apache2 libapache2-mod-php`
2. copy .php and .png files to /var/www/html. 
3. Set permissions: sudo visudo, add: "www-data ALL=(ALL) NOPASSWD: /usr/bin/at, /usr/bin/amixer, /sbin/shutdown".

### LCD display interface
The python files are only used for the LCD interface for `Pimoroni "Display-o-Tron 3000" HAT`.

Control with DotHAT using this Python script: https://github.com/ednl/python/blob/master/radiocontrols.py
- Add "radio.txt" file to /home/pi
- Add "station" and "snooze" scripts to /usr/local/bin
- Optional: add "radiocontrols.py" script to /usr/local/bin
- Edit /etc/rc.local, add: "radiocontrols.py &"