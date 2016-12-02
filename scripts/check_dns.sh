#!/bin/bash

set -eu

check_dns_a() {
	dig "$1" A | grep -q "$2"
}

check_dns_aaaa() {
	dig "$1" AAAA | grep -q 'ANSWER: 0'
}

main() {
	local proto dir rc
	rc=0
	check_dns_a "$1" "$DNS_IP" || rc=$?
	echo "$1" >> $DATADIR/dns/$rc
	if [ "$rc" -gt 0 ]; then
		echo "$(date) failed dig $1 A"
	fi

	rc=0
	check_dns_aaaa "$1" || rc=$?
	echo "$1" >> $DATADIR/dns/$rc
	if [ "$rc" -gt 0 ]; then
		echo "$(date) failed dig $1 AAAA"
	fi
}

main "$@"
