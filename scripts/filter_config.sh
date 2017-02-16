#!/bin/bash

# для нового wget
CONST=/opt/reductor_satellite/etc/const
SYSCONFIG=/etc/sysconfig/satellite
LOCKDIR=/var/lock/reductor/
LOCKFILE=$LOCKDIR/rkn_download.lock

if [ ! -f $CONST ]; then
	MAINDIR="./"
	LISTDIR="$MAINDIR/lists"
	HOOKDIR="$MAINDIR/userinfo/hooks"
else
	# shellcheck disable=SC1090
	. $CONST
	# shellcheck disable=SC1090
	. $CONFIG
fi

if [ -f $SYSCONFIG ]; then
	# shellcheck disable=SC1090
	. $SYSCONFIG
else
        echo "Не настроен до конца satellite. Создайте файл $SYSCONFIG и"
	echo "укажите в нём переменную DNS_IP, указывающую IP адрес страницы-заглушки."
	echo "Это необходимо для корректной проверки DNS-фильтрации."
	echo "Все опции $SYSCONFIG:"
	echo "https://github.com/carbonsoft/reductor_satellite_installer#Специфика-провайдера"
	exit 2
fi

# shellcheck disable=SC1090
. $MAINDIR/bin/report_lib.sh

declare -A lists
# shellcheck disable=SC2154
lists['http']="${http:-$LISTDIR/rkn/rkn.url_http}"
# shellcheck disable=SC2154
lists['dns']="${dns:-$LISTDIR/rkn/rkn.domain_exact}"
# shellcheck disable=SC2154
lists['https']="${https:-$LISTDIR/rkn/rkn.url_https}"

export VERBOSE="${VERBOSE:-0}"
export THREADS="${THREADS:-15}"
export FIRST_BYTES_FOR_CHECK=3000
export DATADIR=$MAINDIR/var
export TMPDIR=/tmp/filter_check/
export MARKER="${MARKER:-"<title>Доступ ограничен</title>"}"
export DNS_IP="${DNS_IP:-10.50.140.73}"
export SED=/usr/local/bin/gsed
[ -f $SED ] || SED=sed
export CURL="curl --insecure --connect-timeout 10 -m 15 -sSL"
export WGET="/usr/local/bin/wget --content-on-error --no-hsts --no-check-certificate -t 1 -T 10 -q -O-"
export FINISHED=0
