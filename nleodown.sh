#!/usr/bin/bash

torrent_daemon="transmission-daemon"	
leourl="http://leopard-raws.org/?search="
leolist="$HOME/leodown.list"
leosrc="$HOME/.leosrc"

touch $leosrc $leolist 

main(){
	if [ "$1" == "list" ]; then
		curl -sL $leourl > $leosrc
		xmllint --html --htmlout --xpath '//div[@class="ongoings-content"]' $leosrc 2> /dev/null |perl -pe 's/<.*?>//g' |grep -v '^\s*$' |perl -pe 's/^\s*//g'

	elif [ "$1" == '' ]; then

		while read list; do
			if echo $list|fgrep '#'; then continue; fi
			title=$(echo $list|cut -f1)
			preDate=$(echo $list|cut -f2)
			echo "updating $title..."
			update $title $preDate
		done < $leolist

		
	else
		echo 'searching...'
		curl -sL $leourl$(echo $@| tr ' ' '+') > $leosrc
		xmllint --html --htmlout --xpath '//div[@class="torrent_name"]' $leosrc 2> /dev/null |perl -pe 's/<.*?>//g' |perl -pe 's/^\s*//g' |grep -v '^\s*$'
		
		echo -e "\nadd to leodown.list?(N/y)"
		read yn
		if [ "$yn" == "y" ]; then
			echo -e "$(echo $@|tr ' ' '_')\t1970/01/02" >> $leolist
			main
		fi
	fi
}

update(){ #params: title, date
	curl -sL "$leourl$(echo $1|tr '_' '+')" > $leosrc
	if [ -z $leosrc ]; then echo "Error when getting source."; fi
	preDate=$2
	xmllint --html --htmlout --xpath '//div[@class="torrent_name"]' $leosrc 2> /dev/null| perl -pe 's/<.*?>//g'|perl -pe 's/^ *//g'|grep -v '^\s*$' > /tmp/.leoname
	xmllint --html --htmlout --xpath '//div[@class="torrent_name"]' $leosrc 2> /dev/null|perl -pe 's/.*href="\.//g'|perl -pe 's/">.*$//g'|grep -v div > /tmp/.leourl
	xmllint --html --htmlout --xpath '//div[@class="info"]' $leosrc 2> /dev/null| perl -pe 's/<.*?>//g'|perl -pe 's/^ *//g'|grep -v '^\s*$'|perl -pe 's/^Date: //g'| perl -pe 's/ .*$//g' > /tmp/.leotime
	n=$(wc -l /tmp/.leotime|cut -d' ' -f1)

	newDate="1970/01/02"
	for((i=n;i>0;i--)) do
		# download if date > preDate.
		if [ $(date -d"$(sed -n "$i"p /tmp/.leotime)" +%s) -gt $(date -d"$preDate" +%s) ]; then
			transmission-remote -a "http://leopard-raws.org$(sed -n "$i"p /tmp/.leourl)"
			echo "add $(sed -n "$i"p /tmp/.leoname)"
			# find the largest date.
			if [ $(date -d"$(sed -n "$i"p /tmp/.leotime)" +%s) -gt $(date -d"$newDate" +%s) ]; then
				newDate=$(sed -n "$i"p /tmp/.leotime)
			fi
			# update list.
			if sed -n "$i"p /tmp/.leoname| fgrep "END" ; then
				echo "find end"
				sed -i "s/$1/#$1/g" $leolist
			fi
			echo -e "updating line $1 to $1\t$newDate."
			sed -i "s|$1.*$|$1\t$newDate|g" $leolist
		fi
	done
	rm /tmp/.leo*
}

pgrep -f $torrent_daemon &>/dev/null || $torrent_daemon -e /dev/null &	
main $@
