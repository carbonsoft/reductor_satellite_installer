#!/bin/bash

set -eu

. /opt/reductor_satellite/bin/filter_config.sh

URL="$1"
PROTO="${2:-http}"
LOG_INTERVAL="${LOG_INTERVAL:-100}"
i=0
while sleep 0.001; do
	rc=0
	((i++)) || true
	DEBUG=${DEBUG:-0} /opt/reductor_satellite/bin/check_url.sh "$URL" "$PROTO" || rc=$?
	if [ "$rc" != '1' ]; then
		if [ "$i" -gt "$LOG_INTERVAL" ]; then
			echo $(date) "$LOG_INTERVAL" ok
			i=0
		fi
	else
		echo $(date) fail
		if [ "${ASSERT:-1}" = '1' ]; then
			exit 1
		fi
	fi
done
