#!/bin/bash

# (c) Carbon Soft

MAINDIR=/opt/reductor_satellite
RPM_URL="${RPM_URL:-http://download5.carbonsoft.ru/reductor/reductor.rpm}"

set_env() {
	rm -rf $MAINDIR/
	yum -y install tar cronie # бывает что их нету
	yum -y install $RPM_URL
	cp -ap /usr/local/Reductor/ $MAINDIR/
	yum -y erase reductor
	mkdir -p /var/log/reductor/
}

cleanup_src() {
	echo "Удаляем ненужное"
	for i in cache lists menu restart.sh start.sh stop.sh tests; do
		rm -rf $MAINDIR/$i
	done
}

patch_path() {
	echo "Патчим пути"
	for file in $(find $MAINDIR/{bin,usr,etc,contrib,reductor_container/virtualenv/bin}/ -type f); do
		sed -e "s|/usr/local/Reductor|$MAINDIR|g" -i $file
	done
}

fix_update() {
	echo "Немного модифицируем выгрузку"
	grep -B 1000 rkn_download.sh $MAINDIR/bin/update.sh | tr -d '&' > /tmp/update.sh
	cat /tmp/update.sh > $MAINDIR/bin/update.sh
}

fix_sync_time() {
	echo "Заставляем ntpdate работать без чрута"
	sed -e 's|setsid.*|ntpdate -4 -t 1 $((RANDOM%3)).centos.pool.ntp.org|g' -i $MAINDIR/bin/sync_time.sh
}

fix_master() {
	echo "Урезаем мастер настройки"
	grep -v "^main$" $MAINDIR/bin/setup_master.sh > /tmp/setup_master.sh
	cat /tmp/setup_master.sh > $MAINDIR/bin/setup_master.sh
	echo "main() {
	# registration
	rkn_update
}

main
" >> $MAINDIR/bin/setup_master.sh
}

reduce_config() {
	echo "Удаляем лишнее из конфига"
	egrep -w "(bash|(^declare -A |^)autoupdate)" $MAINDIR/userinfo/config > /tmp/config
	cat /tmp/config > $MAINDIR/userinfo/config
}

create_rkn_hook() {
	echo "Ещё немного модифицируем выгрузки"
	mkdir -p $MAINDIR/userinfo/hooks/
	cp -a ${MAINDIR}_installer/contrib/rkn_download.sh.hook $MAINDIR/userinfo/hooks/rkn_download.sh
	chmod a+x $MAINDIR/userinfo/hooks/rkn_download.sh
}

symlinks() {
	echo "Создаём симлинки для удобства"
	ln -s $MAINDIR/bin/menu /usr/bin/menu
}

restore() {
	if [ -f /root/reductor_backup.tar.gz ]; then
		mkdir -p /tmp/reductor_backup/
		tar -xzf /root/reductor_backup.tar.gz -C /tmp/reductor_backup usr/local/Reductor/userinfo/{config,provider.pem}
		cp -apv /tmp/reductor_backup/usr/local/Reductor/userinfo/{config,provider.pem} $MAINDIR/userinfo/
		rm -rf /tmp/reductor_backup
	fi
}

finish_msg() {
	echo "Отлично, установка завершена!"
	echo "Запустите $MAINDIR/bin/setup_master.sh или menu для дальнейшей настройки"
	echo "(находясь на сервере с carbon reductor satellite)"
}

put_crontab() {
	egrep -w "(^(#|[A-Z]+)|update.sh)" $MAINDIR/contrib/etc/cron.d/reductor > /etc/cron.d/satellite
	service crond restart
}

copy_contrib() {
	echo "Добавляем дополнительные скрипты"
	cp -av /opt/reductor_satellite_installer/scripts/*.sh $MAINDIR/bin/
}

new_wget() {
	echo "Собираем и устанавливаем новый wget с опцией --content-on-error"
	if wget --help | grep -q content-on-error; then
		return 0
	fi
	if [ ! -x /usr/bin/ansible ]; then
		if [ ! -f /etc/yum.repos.d/epel.repo ]; then
			yum -y install epel-release
		fi
		yum -y install ansible
	fi
	ansible-playbook /opt/reductor_satellite_installer/contrib/wget.yml
}

main() {
	set_env
	cleanup_src
	patch_path
	fix_update
	fix_master
	put_crontab
	create_rkn_hook
	restore
	symlinks
	reduce_config
	copy_contrib
	new_wget
	finish_msg
}

${@:-main}
