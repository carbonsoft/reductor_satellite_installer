# Reductor Satellite (установщик)

Устанавливает, а затем превращает продукт Carbon Reductor в упрощённую систему выгрузок единого реестра (обычно используется для перестраховки).

## Фишки

- Повторная выгрузка при неудаче
- Уведомления при повторной неудаче
- Уведомления при устаревании списков на 6+ часов
- GostSSL в комплекте
- Установка одной командой
- Поддерживает настройку из бэкапа с Carbon Reductor
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
    bash /opt/reductor_satellite_installer/install.sh

## Поддерживаемые ОС

Только CentOS 6. В теории должны работать любые современные RHEL-based дистрибутивы, но их не тестировали.
