#!/usr/bin/env bash

THREADS=15
LINES=18
BIG_FILE=/opt/reductor_satellite/lists/rkn/rkn.url_http
TEST_FILE=/tmp/filter_check/check.http

orig_count() {
    wc -l < "$1"
}

parts_count() {
    wc -l /tmp/filter_check/check.http.parts/* | tail -1 | awk '{print $1}'
}

main() {
    set -eu
    shuf -n $LINES $BIG_FILE > $TEST_FILE
    /opt/reductor_satellite/bin/file_cutter.sh $TEST_FILE $THREADS
    ORIG_COUNT="$(orig_count "$TEST_FILE")"
    PARTS_COUNT="$(parts_count $TEST_FILE)"

    [ "$ORIG_COUNT" = "$PARTS_COUNT" ] || echo "FAIL $ORIG_COUNT != $PARTS_COUNT"
}

main "$@"
