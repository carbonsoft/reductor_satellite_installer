# Carbon Reductor Satellite (установщик)

Устанавливает, а затем превращает продукт Carbon Reductor в упрощённую систему выгрузок единого реестра (обычно используется для перестраховки). 

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

- Повторная выгрузка при неудаче
- Уведомления при повторной неудаче
- Уведомления при устаревании списков на 6+ часов
- GostSSL в комплекте
- Установка одной командой
- Поддерживает настройку из бэкапа с Carbon Reductor (подхват конфига и сертификата)
- Не требует ручной установки дополнительных пакетов

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

    service satellite export /root/backup.tar.gz
    yum -y erase reductor
    cd /opt/reductor_satellite_installer/
    git pull origin master
    ./install.sh
    service satellite import /root/backup.tar.gz
