# Carbon Reductor Satellite (установщик)

**! Внимание** - ни в коем случае не устанавливайте на систему на которую уже установлен Carbon Reductor, это приведёт к его поломке.

## Сценарии использования

0. Система выгрузок единого реестра(обычно используется для перестраховки).

1. Мониторинг фильтрации трафика Carbon Reductor, в случае если подключен в сеть как обычный абонент.


## Использование в качестве системы выгрузок единого реестра

0. Устанавливаем CentOS, например на отдельную виртуальную машину (много ресурсов не требуется)
1. Клонируем репозиторий reductor_satellite_installer и запускаем установку
2. Выполняем настройку Satellite, а именно заполняем конфигурационный файл и выбираем тип выгрузок(команда **menu**)
3. Проверяем работу выгрузок
4. Радуемся жизни

## Использование в качестве мониторинга фильтрации трафика Carbon Reductor

0. Устанавливаем CentOS, например на отдельную виртуальную машину (много ресурсов не требуется)
1. Клонируем репозиторий reductor_satellite_installer и запускаем установку
2. Выполняем настройку Satellite, а именно заполняем конфигурационный файл и выбираем тип выгрузок(команда **menu**)
3. Проверяем работу выгрузок
4. Прописываем запуск по cron-у скрипта filter_checker.sh
5. Проверяем отчет о фильтрации Carbon Reductor и радуемся жизни

Более подробная документация по установке [на нашем сайте](http://docs.carbonsoft.ru/67928072)

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
- Позволяет проверять работу блокировок HTTP, HTTPS, DNS и IP ресурсов без отправки отчёта в РКН
- Позволяет совершать быструю частичную проверку чтобы быстро оценить текущее состояние работы фильтрации

## Установка

На сервере, на который будет установлен Carbon Reductor Satellite выполняем:

    yum -y install git
    git clone https://github.com/carbonsoft/reductor_satellite_installer.git /opt/reductor_satellite_installer/
    /opt/reductor_satellite_installer/install.sh

## Настройка

Запустите эту команду, включите обновление списков, укажите название компании, инн, огрн и почту для того чтобы выгрузки работали:

    /opt/reductor_satellite/bin/setup_master.sh

затем подложите в /opt/reductor_satellite/userinfo/provider.pem экспортированный сертификат для работы выгрузок. Этого должно быть достаточно чтобы выгрузка работала.

### Настройка проверки фильтрации трафика

Для проверки 4 раза в день, добавьте в /etc/crontab строчку:

    0 0,6,12,18 * * * root /opt/reductor_satellite/bin/filter_checker.sh &>/dev/null

Подробнее о том, как настроить время запуска проверки можно прочитать здесь:

    man 5 crontab

### Специфика провайдера

Также можно и нужно указать специфичные для satellite опции в файле ```/etc/sysconfig/satellite``` (если файл отсутствует - его надо создать), это:

- **DNS_IP** - IP адрес используемой страницы-заглушки. Обязательно.
- **MARKER** - текст, по которому можно определить, что открылась именно страница заглушка. Необязательно.
- **http** - файл со списком HTTP URL для проверки. Необязательно, нужно только для переопределения.
- **https** - файл со списком HTTPS URL для проверки. Необязательно, нужно только для переопределения.
- **dns** - файл со списком доменов, которые надо блокировать. Необязательно, нужно только для переопределения.
- **ip** - файл со списком ip-адресов, которые надо блокировать. Необязательно, нужно только для переопределения.
- **admin['email']** - отдельный список email'ов для отправки отчётов о фильтрации (если не хотите чтобы они приходили на почту указанную для выгрузки)

Пример:

``` shell
DNS_IP="1.2.3.4"
MARKER="<title>Доступ ограничен</title>"
#dns="/root/my.domains.txt"
#Пример заполнения, в случае использования раскомментировать
declare -A admin
admin['email']='admin@example.com admin2@example.com'
```

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

    /opt/reductor_satellite_installer/update.sh

Можно явно задать URL RPM-пакета

    cd /opt/reductor_satellite_installer
    RPM_URL=http://download5.carbonsoft.ru//reductor/master/reductor-711-107-master.el6.x86_64.rpm ./update.sh

или

    cd  /opt/reductor_satellite_installer
    RPM_URL=http://download5.carbonsoft.ru//reductor/devel/reductor.rpm ./update.sh

Для обновления скриптов проверки фильтрации можно обойтись:

    cd /opt/reductor_satellite_installer/
    git pull origin master
    ./install.sh copy_contrib

### Как запустить быструю проверку по случайным доменам?

```
LIMIT=300 /opt/reductor_satellite/bin/filter_checker.sh
```

где LIMIT - число URL, доменов для каждого вида проверки.

Также можно указать конкретный вид проверяемой фильтрации:

```
LIMIT=100 /opt/reductor_satellite/bin/filter_checker.sh dns
```

Можно ограничить проверку конкретным файлом:

```
http=/root/unblocked_http_urls.txt /opt/reductor_satellite/bin/filter_checker.sh http
```

или несколькими файлами:
```
dns=/root/unblocked_domains.txt http=/root/unblocked_http_urls.txt ip=/root/unblocked_ip.txt /opt/reductor_satellite/bin/filter_checker.sh http dns ip

```
### Какие известные минусы имеются у программы

- Отсутствие веб-интерфейса;
- Отсутствие автоматического обновления.
