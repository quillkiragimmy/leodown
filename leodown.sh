#!/usr/bin/bash
##############################
# download new anime from leopard
# raws base on date checking.
##############################

txtrst='\e[0m'    # Text Reset
txtpur='\e[0;35m' # Purple

leolist=~/leodown.list
leourl="http://leopard-raws.org/index.php?search="
leotmp="/tmp/leotmp.lst"

torrent_adder='transmission-remote -a' # command for adding torrents.
torrent_daemon='transmission-daemon' # torrent client daemon.
name_added=''
torrent_list=()
date_base_new=''

date_compare(){
	(( $(date -d "$1" '+%s') > $(date -d "$2" '+%s') )) && return 0 || return 1
}

search(){
	keywords="$@"

	curl -s "$leourl"$(echo $keywords| tr ' ' '+')\
		| xmllint --html --xpath '//*[@id="torrents"]' - 2>/dev/null\
		| fgrep  'hash'\
		| sed 's|.*href=".\(.*\)".*] \(.*\)</a.*$|\2 :\t http://leopard-raws.org\1|g'

	echo 'Add Torrents? (Y/n)'
	read yn
	if [ "$yn" != 'n' ]; then
		echo -e "$(echo $keywords| tr ' ' '.')\t1970-01-01 00:00:00" >> $leolist
	fi

}

check(){	# title date_base
	date_base_new="$2"
	date_base="$2"

	# get <torrent \t name \t date_time> list.
	curl -s "$leourl"$(echo $1| tr '.' '+') 2>/dev/null\
		| xmllint --html --xpath '//*[@id="torrents"]' - 2>/dev/null\
		| egrep 'Date|hash'\
		| sed 's|.*href=".\(.*\)".*] \(.*\) (.*$|http://leopard-raws.org\1\t\2|g'\
		| sed 's/.*Date: \(.*\) | Comment.*$/\t\1#/g'\
		| tr -d '\n' | tr '#' '\n' > $leotmp

	while read line; do
		date_upped="$(echo "$line"| cut -f3)"
		torrent=$(echo "$line"| cut -f1)
		name=$(echo "$line"| cut -f2)
		
		case "$name" in
			*END*)
				sed -i "s|\(.*$1.*\)$|#\1|" $leolist
				;&
			*RAW*)
				if date_compare "$date_upped"  "$date_base"; then
					name_added+="$name\n"
					torrent_list+=( "$torrent" )
					if date_compare "$date_upped" "$date_base_new"; then
						date_base_new="$date_upped"
					fi
				fi
				;;
		esac

	done < $leotmp

	rm -f $leotmp
}

manpg(){
	echo -e "usage: leodown.sh [ keywords | -h ]\n"
	echo -e "Without params, script will auto check & add new released anime."
	echo -e "-h --help\t\tShow this help."
	echo -e "keywords\t\tSearch & add to watch list.\n"
	echo -e "To check or modify your list, edit $HOME/leodown.list."
	echo -e "Ended animes will be prefixed with '#', which will be ignored when update."
}

	# test libxml2.
[[ ! $(type -t xmllint) ]] && ( echo "Please install libxml2 first." >&2; exit 0 )
	# test torrent-adder & torrent_daemon.
[[ ! $(type -t $torrent_daemon) ]] && ( echo "Please define your torrent-daemon. " >&2; exit 0 )
[[ ! $(type -t $torrent_adder) ]] && ( echo "Please define your torrent-adder. " >&2; exit 0 )
pgrep -f $torrent_daemon &>/dev/null || ( echo "launch $torrent_daemon."; $torrent_daemon &>/dev/null & )

if [ "$#" != '0' ]; then
	case "$1" in
		-h|--help)
			manpg
			exit 0
			;;
		*)
			search "$@"
			;;
	esac
fi

num=$(cat $leolist| grep -v '#'| wc -l)
notify-send "Update List:" "$(cat $leolist| grep -v '#'| cut -f1)" -a "leodown"
i=0
while read title date time; do
	if echo $title| grep -q "#"; then
		continue;
	fi

	check "$title" "$(echo $date $time)"
	sed -i "s|$title.*$|$title\t$date_base_new|g" $leolist

	(( i++ ))
	pcent=$((i*100 / num))
	notify-send 'leopard-update' -h int:value:$pcent -u low -a "leodown"
	echo -ne "\b\b\b$(printf '%02d' $pcent)%" >&2

done < $leolist

	# add torrents.
for (( i=0;i<${#torrent_list};i++ )); do
	$torrent_adder ${torrent_list[i]} &>/dev/null &
done

notify-send 'leopard-update' "$name_added" -u critical -a "leodown"
echo -e "$name_added"

