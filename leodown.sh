#!/usr/bin/bash

torrent_daemon="transmission-daemon"

scriptDir=$(dirname "$(realpath $0)")
notifier () {
	while read line; do
		echo -e "$line"
		case "$line" in
			MSG*)
				notify-send "Checking: " "$(echo $line| cut -d'|' -f2)" -a "leodown"
				;;
			ADD*)
				transmission-remote -a "$(echo $line| cut -d'|' -f3)"
				notify-send 'Torrent Added: ' "$(echo $line| cut -d'|' -f2)" -u critical -a "leodown"
				;;
		esac
	done
}

pgrep -f $torrent_daemon &>/dev/null || $torrent_daemon &>/dev/null &
$scriptDir/leodown.pl $@| notifier

