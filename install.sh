#!/bin/bash

# (c) Carbon Soft

MAINDIR=/opt/reductor_satellite

set_env() {
	rm -rf $MAINDIR/
	yum -y install http://download5.carbonsoft.ru/reductor/reductor.rpm
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
	for file in etc/const bin/{update.sh,rkn_download.sh,sync_time.sh,menu,setup_master.sh} usr/share/menu_lib; do
		sed -e "s|/usr/local/Reductor|$MAINDIR|g" -i $MAINDIR/$file
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
	grep -B 1000 -m 1 save_and_exit $MAINDIR/bin/setup_master.sh > /tmp/setup_master.sh
	cat /tmp/setup_master.sh > $MAINDIR/bin/setup_master.sh
}

reduce_config() {
	echo "Удаляем лишнее из конфига"
	egrep -w "(bash|(^declare -A |^)autoupdate)" $MAINDIR/userinfo/config | egrep -v "(own|url|skip_sign_request)" > /tmp/config
	cat /tmp/config > $MAINDIR/userinfo/config
}

create_rkn_hook() {
	echo "Ещё немного модифицируем выгрузки"
	mkdir -p $MAINDIR/userinfo/hooks/
	echo '#!/bin/bash

main() {
        log "Запущено обновление списков РосКомНадзора"
        log "Запущено обновление списков РосКомНадзора" >> $LOGFILE
        prepare
        check_private_key
        chroot_work
        client_post_hook
        log "Завершено обновление списков РосКомНадзора"
        log "Завершено обновление списков РосКомНадзора" >> $LOGFILE
}' > $MAINDIR/userinfo/hooks/rkn_download.sh
	chmod a+x $MAINDIR/userinfo/hooks/rkn_download.sh
}

symlinks() {
	echo "Создаём симлинки для удобства"
	ln -s $MAINDIR/bin/menu /usr/bin/menu
}

restore() {
	if [ -f /root/reductor_backup.tar.gz ]; then
		echo "TODO: restore from backup"
	fi
}

finish_msg() {
	echo "Отлично, установка завершена!"
	echo "Запустите /opt/reductor_satellite/bin/setup_master.sh"
}
main() {
	set_env
	cleanup_src
	patch_path
	fix_update
	fix_master
	create_rkn_hook
	restore
	reduce_config
}

${@:-main}
