#!/bin/bash

set -eu

. /opt/reductor_satellite/bin/filter_config.sh

URL="$1"
PROTO="${2:-http}"
while sleep 0.001; do
	DEBUG=${DEBUG:-0} /opt/reductor_satellite/bin/check_url.sh "$URL" "$PROTO" && echo -n + || exit 1
done
