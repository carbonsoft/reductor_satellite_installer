#!/usr/bin/env bash

set -eu

declare -A netrc
netrc['CURL']=0
netrc['PING']=0

net() {
	local ip="$1"
	local method="$2"
	local dir="$3"
	local rc=0
	${!method} "$ip" > /dev/null 2>&1 || rc=$?
	if [ "$rc" == 0 ]; then
		netrc[$method]="1"
		return "$rc"
	fi
	return 0
}

analyze() {
	if [ "${netrc['CURL']}" -gt 0 ] || [ "${netrc['PING']}" -gt 0 ]; then
		return 1
	elif [ "${netrc['CURL']}" = 0 ] && [ "${netrc['PING']}" = 0 ]; then
		return 0
	else
		# shellcheck disable=SC2046
		echo $(date) Мы что-то не обработали $(set | egrep '^netrc')
		return 3
	fi
}

main() {
	local ip="$1"
	local dir="$DATADIR/$2"
	for method in "CURL" "PING"; do
		net "$ip" "$method" "$dir" || netrc[$method]=$?
	done
	analyze
}

main "$@"
