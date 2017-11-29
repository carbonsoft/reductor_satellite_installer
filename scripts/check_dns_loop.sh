#!/bin/bash

set -eu

. /opt/reductor_satellite/bin/filter_config.sh

DOMAIN="$1"
PROTO="${2:-dns}"
j=0
while true; do
	((j++)) || true
	for i in {1..100}; do
		DEBUG=${DEBUG:-0} /opt/reductor_satellite/bin/check_dns.sh "$DOMAIN" "$PROTO" && echo -n + || exit 1
	done
	echo " $i ($j) ok"
	sleep 0.1
done
