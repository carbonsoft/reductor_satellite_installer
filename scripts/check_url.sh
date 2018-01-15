#!/usr/bin/env bash

set -eu

declare -A netrc
netrc['CURL']=0
netrc['WGET']=0

declare -A datarc
datarc['CURL']=0
datarc['WGET']=0

net() {
	local url="$1"
	local method="$2"
	local dir="$3"
	local file="$4"
	local rc=0
	timeout -s 15 25s ${!method} "$url" > $file 2>/dev/null || rc=$?
	# wget return 8 on 404
	# shellcheck disable=SC2166
	if [ "$rc" -gt 0 ] && ! [ "$rc" = "8" -a "$method" = "WGET" ]; then
		netrc[$method]="$rc"
		rm -f $file
		return "$rc"
	fi
	return 0
}

data() {
	local url="$1"
	local method="$2"
	local dir="$3"
	local file="$4"
	local rc=0
	head -c $FIRST_BYTES_FOR_CHECK "$file" | grep -q "$MARKER" || rc=$?
	# it's necessary to write time when error happened
	if [ "$rc" != '0' ]; then
		if [ -n "${UPLINK_MARKER:-}" ] && grep -q "$UPLINK_MARKER" "$file"; then
			echo "$(date) uplink replied ${!method} $url"
		else
			echo "$(date) failed ${!method} $url"
			if [ "${DEBUG:-0}" = '1' ]; then
				echo
				cat $file
				echo
			fi
		fi
	fi
	datarc[$method]="$rc"
	rm -f $file
}

analyze() {
	if [ "${netrc['CURL']}" -gt 0 ] && [ "${netrc['WGET']}" -gt 0 ]; then
		return 2
	elif [ "${datarc['CURL']}" -gt 0 ] || [ "${datarc['WGET']}" -gt 0 ]; then
		return 1
	elif [ "${datarc['CURL']}" = 0 ] && [ "${datarc['WGET']}" = 0 ]; then
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
	local url="$1"
	local dir="$DATADIR/$2"
	file="$(mktemp $TMPDIR/XXXXXX)"
	for method in "CURL" "WGET"; do
		if net "$url" "$method" "$dir" "$file"; then
			data "$url" "$method" "$dir" "$file"
		fi
	done
	analyze
}

main "$@"
