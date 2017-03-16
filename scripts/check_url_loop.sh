#!/bin/bash

. /opt/reductor_satellite/bin/filter_config.sh

while sleep 0.001; do
	DEBUG=${DEBUG:-0} /opt/reductor_satellite/bin/check_url.sh "$1" "${2:-http}" && echo -n + || exit 1
done
