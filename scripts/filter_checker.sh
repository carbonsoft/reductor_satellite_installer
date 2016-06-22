#!/bin/bash

. /opt/reductor_satellite/etc/const
. $CONFIG

VERBOSE="${VERBOSE:-0}"
THREADS=15
FIRST_BYTES_FOR_CHECK=3000
DATADIR=$MAINDIR/var/
TMPDIR=/tmp/filter_check/
RKN_LIST=$MAINDIR/lists/rkn.list
CURL="curl --insecure --connect-timeout 10 -sSL"
WGET="wget -t 1 -T 10 -q -O-"

trap show_report EXIT
trap show_report HUP

check_url() {
	local rc
	local file="$(mktemp $TMPDIR/XXXXXX)"
	if ! $CURL "$1" > $file; then
		echo "$1" >> $DATADIR/2
		rm -f $file
		return
	fi
	head -c $FIRST_BYTES_FOR_CHECK "$file" | grep -q '<title>Доступ ограничен</title>'
	rc=$?
	echo "$1" >> $DATADIR/$rc
	[ "$rc" != 0 -a "$VERBOSE" = '1' ] && head -c "$FIRST_BYTES_FOR_CHECK" "$file" && exit
	rm -f $file

	if ! $WGET "$1" > "$file"; then
		echo "$1" >> "$DATADIR/2"
		rm -f $file
		return
	fi
	head -c $FIRST_BYTES_FOR_CHECK "$file" | grep -q '<title>Доступ ограничен</title>'
	echo "$1" >> $DATADIR/$?
	rm -f $file
}

clean() {
	mkdir -p $DATADIR/ $TMPDIR/
	for f in 0 1 2; do
		> $DATADIR/$f
	done
}

main_loop() {
	while sleep 0.1; do
		for i in $(seq 1 $THREADS); do
			read -t 1 url || break 2
			check_url "$url" &
		done
		wait
		show_report
	done
}

show_report() {
	echo $(date) $(wc -l < $DATADIR/0) ok / $(wc -l < $DATADIR/1) fail / $(wc -l < $DATADIR/2) not open
	cat $DATADIR/1
}

create_report() {
	echo "# Первый проход по всем URL от РКН"
	show_report

	if [ ! -s $DATADIR/1 ]; then
		echo "# Всё URL блокируются"		
		return
	fi

	echo "# Проход по незаблокированным в первом прогоне"
	sort -u $DATADIR/1 > $DATADIR/first_check
	clean
	main_loop < $DATADIR/first_check &>/dev/null
	show_report
	
	echo "# Оставшиеся незаблокированными"
	cat $DATADIR/1
}

post_hook() { : }
pre_hook() { : }
use_hook() {
	hook=$HOOKDIR/${0##*/}
	[ -x $hook ] && . $hook
}

use_hook
pre_hook
clean
main_loop < "${1:-$RKN_LIST}"
create_report > $DATADIR/report
/opt/reductor_satellite/bin/send_report.sh "${admin['ip']:-${autoupdate['email']}}"
post_hook
