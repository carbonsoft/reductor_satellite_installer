#!/bin/bash

check_dns_a() {
	dig "$1" A | grep -q "$2"
}

check_dns_aaaa() {
	dig "$1" AAAA | grep -q 'ANSWER: 0'
}

main() {
	local proto dir
	proto=$2
	dir="$DATADIR/$proto"
	check_dns_a "$1" "$DNS_IP"
	echo "$1" >> $dir/$?
	check_dns_aaaa "$1"
	echo "$1" >> $DATADIR/dns/$?
}

main "$@"
