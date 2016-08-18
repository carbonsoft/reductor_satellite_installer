#!/usr/bin/env bash

set -u

# для нового wget
CONST=/opt/reductor_satellite/etc/const
SYSCONFIG=/etc/sysconfig/satellite
LOCKDIR=/var/lock/reductor/
LOCKFILE=$LOCKDIR/rkn_download.lock

declare -A admin
declare -A autoupdate

if [ ! -f $CONST ]; then
	MAINDIR="./"
	LISTDIR="$MAINDIR/lists"
	HOOKDIR="$MAINDIR/userinfo/hooks"
else
	. $CONST
	. $CONFIG
fi

if [ -f $SYSCONFIG ]; then
	. $SYSCONFIG
fi

declare -A lists
# shellcheck disable=SC2154
lists['http']="${http:-$LISTDIR/rkn.list}"
# shellcheck disable=SC2154
lists['dns']="${dns:-$LISTDIR//rkn.httpslist}"
# shellcheck disable=SC2154
lists['https']="${https:-$LISTDIR//rkn.https_urls}"

VERBOSE="${VERBOSE:-0}"
THREADS=15
FIRST_BYTES_FOR_CHECK=3000
DATADIR=$MAINDIR/var
TMPDIR=/tmp/filter_check/
MARKER="${MARKER:-"<title>Доступ ограничен</title>"}"
DNS_IP="${DNS_IP:-10.50.140.73}"
SED=/usr/local/bin/gsed
[ -f $SED ] || SED=sed
CURL="curl --insecure --connect-timeout 10 -m 15 -sSL"
WGET="/usr/local/bin/wget --content-on-error --no-check-certificate -t 1 -T 10 -q -O-"
FINISHED=0

trap show_reports EXIT
trap show_reports HUP

catch_lock() {
	mkdir -p $LOCKDIR
	exec 3>$LOCKFILE
	echo "Ждём lockfile (max 60 sec).." >&2
	if ! flock -w 15 -x 3; then
		echo "Не дождались освобождения lockfile" >&2
		exit 1
	fi
	echo "Выполняем проверку" >&2
}

clean() {
	mkdir -p $DATADIR/{dns,http,https} $TMPDIR/
	for f in 0 1 2; do
		for d in $DATADIR/{dns,http,https}; do
			> $d/$f
		done
	done
	egrep -v "^$ip_regex$" "${lists['dns']}" > "${lists['dns']}".noip || true
	mv -f "${lists['dns']}".noip "${lists['dns']}"
}

check_dns_a() {
	dig "$1" A | grep -q "$2"
}

check_dns_aaaa() {
	dig "$1" AAAA | grep -q 'ANSWER: 0'
}

check_dns() {
	local proto dir
	proto=$2
	dir="$DATADIR/$proto"
	check_dns_a "$1" "$DNS_IP"
	echo "$1" >> $dir/$?
	check_dns_aaaa "$1"
	echo "$1" >> $DATADIR/dns/$?
}

check_url() {
	local file
	local dir
	local rc
	dir="$DATADIR/$2"
	file="$(mktemp $TMPDIR/XXXXXX)"
	for METHOD in "$CURL" "$WGET"; do
		$METHOD "$1" > $file 2>/dev/null
		rc=$?                   # wget return 8 on 404
		if [ "$rc" -gt 0 ] && ! [ "$rc" = "8" -a "$METHOD" = "$WGET" ]; then
			echo "$1" >> $dir/2
			rm -f $file
			return
		fi
		head -c $FIRST_BYTES_FOR_CHECK "$file" | grep -q "$MARKER"
		echo "$1" >> $dir/$?
		rm -f $file
	done
}

checker() {
	local func proto list
	func=$1
	proto=$2
	list="${3:-${lists[$proto]}}"
	echo "Начинаем проверять фильтрацию протокола $proto по файлу $list"
	sleep 0.5
	sort -u "$list" > "$list.sorted"
	mv -f "$list.sorted" "$list"
	while sleep 0.1; do
		for _ in $(seq 1 $THREADS); do
			read -t 1 entry || break 2
			$func "$entry" "$proto" &
		done
		wait
		show_report "$proto"
	done < "$list"
	wait # after break 2 we can have some background jobs
	show_report "$proto"
}

http() {
	checker check_url http
}

https() {
	checker check_url https
}

dns() {
	checker check_dns dns
}

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
	/opt/reductor_satellite/bin/send_report.sh $receiver
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

post_hook() { :; }
pre_hook() { :; }

use_hook() {
	hook=$HOOKDIR/${0##*/}
	[ -x $hook ] && . $hook || true
}

main() {
	pre_hook
	catch_lock
	clean
	> $DATADIR/report
	> $DATADIR/report.sys
	for test in "${global_params[@]}"; do
		$test
	done
	create_report first
	rm -rf $DATADIR.first
	cp -a "$DATADIR" "$DATADIR.first"
	lists['http']=$DATADIR.first/http/1
	lists['dns']=$DATADIR.first/dns/1
	lists['https']=$DATADIR.first/https/1
	clean
	for test in "${global_params[@]}"; do
		$test
	done
	create_report repeat
	FINISHED=1
	create_reports > $DATADIR/report
	send_reports
	post_hook
}

use_hook
[ "$#" -gt 0 ] || set -- http https dns
declare -a global_params
global_params=( "$@" )
main "${global_params[@]}"
