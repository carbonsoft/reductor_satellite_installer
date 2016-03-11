# Carbon Reductor Satellite (установщик)

Устанавливает, а затем превращает продукт Carbon Reductor в упрощённую систему выгрузок единого реестра (обычно используется для перестраховки). Имеет возможность работы в режиме мониторинга работы фильтрации трафика, в случае если подключен в сеть как обычный абонент.

**Внимание** - ни в коем случае не устанавливайте на систему на которую уже установлен Carbon Reductor, это приведёт к его поломке.

## Обычный сценарий использования

0. Устанавливаем CentOS, например на отдельную виртуальную машину (много ресурсов не требуется)
1. Заходим на сервер с настроенным Carbon Reductor
2. Запускаем скрипт установки с параметром - ip новой машины, где будет стоять satellite
3. Два раза вводим пароль для ssh
4. Заходим на сервер с Carbon Reductor Satellite
5. Проверяем работу выгрузок
6. Радуемся жизни

## Фишки

- Повторная выгрузка при неудаче;
- Уведомления при повторной неудаче;
- Уведомления при устаревании списков на 6+ часов;
- GostSSL в комплекте;
- Установка одной командой;
- Поддерживает настройку из бэкапа с Carbon Reductor (подхват конфига и сертификата);
- Не требует ручной установки дополнительных пакетов;
- Позволяет производить проверку фильтрации трафика в автоматическом режиме с отчётами на почту;
- Может работать не только на железе/KVM/XEN/VMWare, но и в контейнерах LXC/OpenVZ;
- Достаточно 256мб оперативной памяти и 1 ядра процессора.

## Установка

### С Carbon Reductor

    # /usr/local/Reductor/bin/setup_satellite.sh 
    Usage: /usr/local/Reductor/bin/setup_satellite.sh <ip of satellite machine> [ssh port]
    Example: /usr/local/Reductor/bin/setup_satellite.sh 10.90.30.35
    Example: /usr/local/Reductor/bin/setup_satellite.sh 10.90.30.36 33

### Без Carbon Reductor

    yum -y install git
    git clone https://github.com/carbonsoft/reductor_satellite_installer.git /opt/reductor_satellite_installer/
    /opt/reductor_satellite_installer/install.sh

## Настройка

При установке с настроенного Carbon Reductor ничего настраивать не надо, просто проверьте выгрузки.

Запустите эту команду, включите обновление списков, укажите название компании, инн, огрн и почту для того чтобы выгрузки работали:

    /opt/reductor_satellite/bin/setup_master.sh

затем подложите в /opt/reductor_satellite/userinfo/provider.pem экспортированный сертификат для работы выгрузок. Этого должно быть достаточно чтобы выгрузка работала.

### Настройка проверки фильтрации трафика

Для проверки 4 раза в день, добавьте в /etc/crontab строчку:
    
    0 0,6,12,18 * * * root /opt/reductor_satellite/bin/filter_checker.sh < /opt/reductor_satellite/lists/rkn.list &>/dev/null

Подробнее о том, как настроить время запуска проверки можно прочитать здесь:

    man 5 crontab

### Сохранять выгруженные реестры

Запускайте по cron'у /opt/reductor_satellite/bin/keep_dumps.sh 

Если необходимо подстроить формат именования файла под себя, можете заглянуть в него, он довольно простой.

## Проверка работоспособности

    /opt/reductor_satellite/bin/update.sh

## Цена

Абсолютно бесплатно, но поддержка оказывается только при наличии лицензии Carbon Reductor (любое SLA).

## Поддерживаемые ОС

Только CentOS 6. В теории должны работать любые современные RHEL-based дистрибутивы, но их не тестировали.
Можно легко крутить в виртуальных машинах и контейнерах (lxc, openvz)

## FAQ:

### Как забрать списки с satellite

Список подкладывается в файл:

    /opt/reductor_satellite/reductor_container/gost-ssl/php/dump.xml

Вы можете установить и настроить на этом же сервере vsftpd, nginx или закинуть ключи ssh и забирать этот список с помощью SCP или забирать файл любым другим удобным способом - вы полностью свободны в выборе удобного для Вас средства, а satellite - инструмент, хорошо выполняющий свою задачу - выгрузку реестра.

### Как обновить Carbon Reductor Satellite

Правильного способа пока нет. Временное решение:

    /opt/reductor_satellite/bin/export.sh /root/backup.tar.gz
    cd /opt/reductor_satellite_installer/
    git pull origin master
    ./install.sh
    /opt/reductor_satellite/bin/import.sh /root/backup.tar.gz

Для обновления скриптов проверки фильтрации можно обойтись:
    
    cd /opt/reductor_satellite_installer/
    git pull origin master
    ./install.sh copy_contrib
    
### Какие известные минусы имеются у программы

- Проверка фильтрации трафика проводится только с помощью curl для http;
- Отсутствие веб-интерфейса;
- Отсутствие удобного механизма обновления.
