#!/bin/bash

THREADS=15
MAINDIR=/opt/reductor_satellite/
DATADIR=$MAINDIR/var/
TMPDIR=/tmp/filter_check/
RKN_LIST=$MAINDIR/lists/rkn.list

trap show_report EXIT
trap show_report HUP

check_url() {
	local file=$TMPDIR/$((RANDOM))
	if ! curl -sSL "$1" > $file; then
		echo "$1" >> $DATADIR/2
		rm -f $file
		return
	fi
	grep -q '<title>Доступ ограничен</title>' $file
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
			check_url $url &
		done
		wait
		show_report
	done
}

show_report() {
	echo $(date) $(wc -l < $DATADIR/0) ok / $(wc -l < $DATADIR/1) fail / $(wc -l < $DATADIR/2) not open
}

create_report() {
	echo "# Первый проход по всем URL от РКН"
	show_report

	if [ ! -s $DATADIR/1 ]; then
		echo "# Всё URL блокируются"		
		return
	fi

	cp $DATADIR/1 $DATADIR/first_check

	echo "# Проход по незаблокированным в первом прогоне"
	clean
	main_loop < $DATADIR/first_check &>/dev/null
	show_report
	
	echo "# Оставшиеся незаблокированными"
	cat $DATADIR/1
}

clean
main_loop < "${1:-$RKN_LIST}"
create_report > $DATADIR/report
/opt/reductor_satellite/bin/send_report.sh
