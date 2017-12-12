#!/usr/bin/env bash

set -eu

export LANG=ru_RU.UTF-8

declare -A netrc
netrc['A']=0
netrc['AAAA']=0

TMPDIR=/tmp/filter_check/dns/$$/
mkdir -p $TMPDIR

net() {
	local url="$1"
	local method="$2"
	local dir="$3"
	if [ "$method" = 'A' ]; then
		[ "${NO_A:-0}" == '1' ] && return 0
		if ! dig +short "${method}" "$url" > $TMPDIR/A; then
			return 0
		fi
		egrep -q "$DNS_IP" $TMPDIR/A 
	elif [ "$method" = 'AAAA' ]; then
		[ "${NO_AAAA:-0}" == '1' ] && return 0
		if ! dig "${method}" "$url" > $TMPDIR/AAAA; then
			return 0
		fi
		egrep -q 'ANSWER: 0' $TMPDIR/AAAA
	else
		echo "Ошибка программистов, передан неожиданный метод: $method, аргументы: $*"
		return 3
	fi
}

analyze() {
	local perfect=(0 0)
	local all=( "${netrc[@]}" )
	if [ "${netrc['A']}" -gt 0 ] || [ "${netrc['AAAA']}" -gt 0 ]; then
		return 1
	elif [[ "${all[@]}" == "${perfect[@]}" ]]; then
		return 0
	else
		# shellcheck disable=SC2046
		echo $(date) Мы что-то не обработали $(set | egrep '^netrc')
		return 3
	fi
}

main() {
	local url="$1"
	local dir="$DATADIR/$2"
	for method in "A" "AAAA"; do
		net "$url" "$method" "$dir" || netrc[$method]=$?
	done
	analyze
	rm -rf $TMPDIR
}

main "$@"
