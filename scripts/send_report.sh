#!/bin/bash

. /opt/reductor_satellite/etc/const

IP="$(ip -o r g 8.8.8.8 | sed 's/.*src //; s/ .*//')"
FROM=alarm@alarm.carbonsoft.ru
TO="$1"

HEADER="From: Reductor Satellite ($IP) <$FROM>
To: $TO
Content-Type: text/plain; charset = \"UTF-8\"
Subject: Отчёт о фильтрации Reductor"

russification() {
	sed 's/ok/заблокировано/;s/fail/не заблокировано/;s/not open/не открывается/;s/total/всего/'
}

ru_names() {
	sed -e 's|/opt/reductor_satellite/var.first|Первая проверка|g; s|/opt/reductor_satellite/var/|Повторная проверка |g; s|/1||;'
}

errors_exist() {
	for errors in $(find /opt/reductor_satellite/var.first/ -type f -name "1"); do
		[ ! -s $errors ] || return 0
	done
	return 1
}

show_errors() {
	echo
	if ! errors_exist; then
		echo "# Пропуски фильтрации отсутствуют"
		return 0
	fi
	echo "# Список пропусков фильтрации:"
	for errors in $(find /opt/reductor_satellite/var{.first,}/ -type f -name "1"); do
		[ -s $errors ] || continue
		echo
		echo "## $errors"
		echo
		cat $errors
	done | ru_names
}

echo "$HEADER" > /tmp/report
russification < /opt/reductor_satellite/var/report | tr '#' '\n' >> /tmp/report
show_errors >> /tmp/report
sendmail -f $FROM -t $TO < /tmp/report
