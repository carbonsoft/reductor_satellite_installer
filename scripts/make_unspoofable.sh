#!/bin/bash

. /opt/reductor_satellite/etc/const
. $CONFIG

mkdir -p $TMPDIR
$BINDIR/dump_parser_ip_https.py $DUMPXML > $TMPDIR/ip_https_unspoofable.txt
md5="$(md5sum /etc/hosts | awk '{print $1}')"
mv /etc/hosts /etc/hosts.$md5
awk '{print $1" "$2}' < $TMPDIR/ip_https_unspoofable.txt | sort -u > /etc/hosts
