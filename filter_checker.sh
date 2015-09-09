#!/bin/bash

THREADS=10
MAINDIR=/opt/reductor_filter_monitoring
DATADIR=$MAINDIR/var/

trap show_report EXIT

check_url() {
	curl -sL "$1" | grep -q '<title>Доступ ограничен</title>'
	echo "$1" >> $DATADIR/$?
}

clean() {
	mkdir -p $DATADIR/
	for f in 0 1; do
		> $DATADIR/$f
	done
}

main_loop() {
	while sleep 0.1; do
		for i in $(seq 1 $THREADS); do
			read url || break 2
			check_url $url &
		done
		wait
	done
}

show_report() {
	echo
	echo $(wc -l < $DATADIR/0) ok
	echo $(wc -l < $DATADIR/1) fail
}

clean
main_loop
