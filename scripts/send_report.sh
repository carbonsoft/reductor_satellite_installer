#!/bin/bash

. /opt/reductor_satellite/etc/const

IP="$(ip -o r g 8.8.8.8 | sed 's/.*src //; s/ .*//')"
FROM=alarm@alarm.carbonsoft.ru
TO="$1"

HEADER="From: Reductor Satellite ($IP) <$FROM>
To: $TO
Content-Type: text/plain; charset = \"UTF-8\"
Subject: Отчёт о фильтрации Reductor"

echo "$HEADER" > /tmp/report

russification() {
	sed 's/ok/заблокировано/;s/fail/не заблокировано/;s/not open/не открывается/;'
}

russification < /opt/reductor_satellite/var/report | tr '#' '\n' >> /tmp/report
sendmail -f $FROM -t $TO < /tmp/report
