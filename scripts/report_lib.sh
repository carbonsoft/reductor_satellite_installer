#!/usr/bin/env bash


declare -A admin
declare -A autoupdate

create_report() {
	show_reports $1 stat > $DATADIR/$1.report
}

create_reports() {
	echo "# Первая проверка"
	cat $DATADIR.first/first.report
	echo "# Повторный проход по незаблокированным"
	cat $DATADIR/repeat.report
}

send_reports() {
	# shellcheck disable=SC2154
	receiver="${admin['email']:-${autoupdate['email']:-}}"
	if [ -z "${receiver:-}" ]; then
		echo "Пропускаем отправку, так как нет получателя"
		return
	fi
	for mail in $receiver; do
		echo /opt/reductor_satellite/bin/send_report.sh $mail
		/opt/reductor_satellite/bin/send_report.sh $mail
	done
}

show_report_stat() {
	echo "$1 $2 ok $3"
	echo "$1 $2 fail $4"
	echo "$1 $2 not_open $5"
	echo "$1 $2 total $6"
}

show_report_full() {
	echo
	echo "### Not blocked by $1"
	cat $2/1
	echo
}

show_report_oneline() {
	echo "$(date +"%Y.%m.%d %H:%M:%S") $1: $3 ok | $4 fail | $5 not open | $2 total"
}

get_result() {
	total="$(wc -l < $1 | tr -d ' ')"
	ok=$(wc -l < $2/0 | tr -d ' ')
	fail=$(wc -l < $2/1 | tr -d ' ')
	not_open=$(wc -l < $2/2 | tr -d ' ')
	total=$((total*2))  # http(s) checked by curl/wget, dns by A/AAAA
	echo $total $ok $fail $not_open
}

show_report() {
	local proto dir list total ok fail not_open
	proto="$1"
	report_type="${3:-}"
	dir="$DATADIR/$proto"
	list="${lists[$proto]}"

	read total ok fail not_open <<< "$(get_result $list $dir)"

	show_report_oneline $proto $total $ok $fail $not_open
	if [ "${2:-short}" == 'stat' ]; then
		show_report_stat $proto $report_type $ok $fail $not_open $total >> $DATADIR/report.sys
	fi
	[ "$fail" == 0 ] && return 0
	if [ "${2:-short}" == 'full' ]; then
		show_report_full $proto $dir
	fi
}

show_reports() {
	RETVAL=$?
	if [ "$RETVAL" != 0 ]; then
		echo -n "ERROR($RETVAL): $0 "
		for ((i=${#FUNCNAME[@]}; i>0; i--)); do
			echo -n "${FUNCNAME[$i-1]} "
		done | $SED -e 's/ $/\n/; s/ / -> /g'
		flock -u 3
	fi
	local proto
	echo
	if [ "$FINISHED" = '0' ]; then
		for proto in "${global_params[@]}"; do
			show_report $proto ${2:-full} ${1:-}
		done
	else
		create_reports
	fi
}
