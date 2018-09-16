#!/bin/bash

set -u

SUPERCONFIG=/opt/reductor_satellite/bin/filter_config.sh
[ -f $SUPERCONFIG ] || SUPERCONFIG=./bin/filter_config.sh
[ -f $SUPERCONFIG ] || exit 11

#shellcheck disable=SC1090
. $SUPERCONFIG

trap show_reports EXIT
trap show_reports HUP

catch_lock() {
	mkdir -p $LOCKDIR
	exec 3>$LOCKFILE
	echo "Ждём lockfile (max 15 sec).." >&2
	if ! flock -w 15 -x 3; then
		echo "Не дождались освобождения lockfile" >&2
		exit 1
	fi
	echo "Выполняем проверку" >&2
}

clean() {
	rm -f ~/.wget-hsts
	mkdir -p $DATADIR/{dns,http,https,ip} $TMPDIR/
	for f in 0 1 2; do
		for d in $DATADIR/{dns,http,https,ip}; do
			> $d/$f
		done
	done
	# shellcheck disable=SC2154
	egrep -v "^$ip_regex$" "${lists['dns']}" > "${lists['dns']}".noip || true
	mv -f "${lists['dns']}".noip "${lists['dns']}"
	if [ "${LIMIT:--1}" == '-1' ]; then
		return 0
	fi
	for list in "${!lists[@]}"; do
		shuf -n $LIMIT "${lists[$list]}" > $TMPDIR/check.$list
		lists[$list]=$TMPDIR/check.$list
	done
}

thread() {
	local func="$1"
	local proto="$2"
	local part_file="$3"
	local basename="${part_file##*/}"
	local counter=1
	local rc=0
	while read -t 1 entry; do
		rc=0
		$BINDIR/$func "$entry" "$proto" || rc=$?
		echo $entry >> $DATADIR/$proto/$rc
		if [ "$rc" == '1' ]; then
			log "failed $proto $entry"
		fi
		((counter++))
		if [ "$basename" = '1' ] && [ "$((counter % THREADS))" = 0 ]; then
			show_report $proto
		fi
	done < $part_file
	wait
}

run_threads() {
	local file="$1"
	local parts="$2"
	local func="$3"
	for part in $(seq 0 $((parts))); do
		thread $func $proto $file.parts/$part &
	done
	wait
}

checker() {
	local func proto list
	func=$1
	proto=${2:-}
	list="${3:-${lists[$proto]}}"
	echo "Начинаем проверять фильтрацию протокола $proto по файлу $list"
	sleep 0.5
	sort -u "$list" > "$list.sorted"
	mv -f "$list.sorted" "$list"
	$BINDIR/file_cutter.sh $list $THREADS
	run_threads $list $THREADS $func $proto
	show_report "$proto"
}

http() {
	checker check_url.sh http
}

https() {
	checker check_url.sh https
}

dns() {
	checker check_dns.sh dns
}

ip() {
	checker check_ip.sh ip
}

post_hook() { :; }
pre_hook() { :; }

use_hook() {
	hook=$HOOKDIR/${0##*/}
	# shellcheck disable=SC1090
	[ -x $hook ] && . $hook || true
}

main() {
	pre_hook
	if [ "${NOUPDATE:-0}" != '1' ]; then
		$BINDIR/update.sh
	fi
	catch_lock
	declare -A lists_orig
	for test in "${global_params[@]}"; do
		lists_orig["$test"]="${lists[$test]}"
	done
	clean
	> $DATADIR/report
	> $DATADIR/report.sys
	for test in "${global_params[@]}"; do
		$test
	done
	create_report first
	rm -rf $DATADIR.first
	cp -a "$DATADIR" "$DATADIR.first"
	# shellcheck disable=SC2154
	lists['http']=$DATADIR.first/http/1
	lists['dns']=$DATADIR.first/dns/1
	# shellcheck disable=SC2154
	lists['https']=$DATADIR.first/https/1
	lists['ip']=$DATADIR.first/ip/1
	clean
	for test in "${global_params[@]}"; do
		$test
	done
	if [ "${DO_RESYNC:-0}" == '1' ]; then
		need_resync=0
		# может и не понадобится пересинхронизация, если всё в порядке
		for test in "${global_params[@]}"; do
			[ -s "$DATADIR/$test/1" ] && need_resync=1 && break
		done
		# Здесь очень тупое неправильное использование локов, но рефакторить сложно, понадеемся что
		# повторных вызовов во время RESYNC не будет происходить и нас спасут таймауты 15 сек в catch_lock
		log "Выполняем синхронизацию повторно чтобы не беспокоить пропусками по удалённым ресурсам"
		if [ "$need_resync" = '1' ]; then
			flock -u 3
			if ${BINDIR}/update.sh; then
				set -x
				for test in "${global_params[@]}"; do
					fgrep -vwf "${lists_orig[$test]}" "$DATADIR/$test/1" > "$DATADIR/$test/1.resync"
					[ ! -s "$DATADIR/$test/1.resync" ] && continue
					log "Пока мы проверяли из реестра исключили $(wc -l < "$DATADIR/$test/1.resync") записей"
					log "Уберём их из результатов повторной проверки"
					fgrep -vwf "$DATADIR/$test/1.resync" "$DATADIR/$test/1" > "$DATADIR/$test/1.fixed"
					mv -f "$DATADIR/$test/1.fixed" "$DATADIR/$test/1"
				done
				set +x
			fi

		fi
		catch_lock
	fi
	create_report repeat
	export FINISHED=1
	create_reports > $DATADIR/report
	send_reports
	find "$TMPDIR" -type f -delete
	post_hook
}

use_hook
[ "$#" -gt 0 ] || set -- http https dns ip
declare -a global_params
global_params=( "$@" )
export global_params
main "${global_params[@]}"
