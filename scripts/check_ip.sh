#!/usr/bin/env bash

set -eu

declare -A netrc
netrc['CURL']=0
netrc['PING']=0

declare -A datarc
datarc['CURL']=0
datarc['PING']=0

net() {
	local ip="$1"
	local method="$2"
	local dir="$3"
	local file="$4"
	local rc=0
	${!method} "$ip" > $file 2>/dev/null || rc=$?
	# shellcheck disable=SC2166
	if [ "$rc" -gt 0 ]; then
		echo "net_netrc" ${netrc[$method]} "net_rc" "$rc"
		netrc[$method]="$rc"
		rm -f $file
		return "$rc"
	fi
	return 0
}

data() {
	local ip="$1"
	local method="$2"
	local dir="$3"
	local file="$4"
	local rc=0
	if [ "$rc" == '0' ]; then
		echo "$(date) failed ${!method} $ip"
		rc="1"
	fi
	datarc[$method]="$rc"
	rm -f $file
}

analyze() {
	if [ "${datarc['CURL']}" -gt 0 ] || [ "${datarc['PING']}" -gt 0 ]; then
		return 1
	elif [ "${datarc['CURL']}" = 0 ] && [ "${datarc['PING']}" = 0 ]; then
		return 0
	else
		# shellcheck disable=SC2046
		echo $(date) Мы что-то не обработали $(set | egrep '^(data|net)rc')
		return 3
	fi
}

main() {
	local rc
	local file
	local ip="$1"
	local dir="$DATADIR/$2"
	file="$(mktemp $TMPDIR/XXXXXX)"
	for method in "CURL" "PING"; do
		echo "main_method=" "$method"
		if net "$ip" "$method" "$dir" "$file"; then
			data "$ip" "$method" "$dir" "$file"
		fi
	done
	analyze
}

main "$@"
