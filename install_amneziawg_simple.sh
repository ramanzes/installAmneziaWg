#!/bin/bash
set -e

echo "=== Установка AmneziaWG через DKMS ==="

# Установите зависимости
apt-get update
apt-get install -y git build-essential dkms libelf-dev linux-headers-amd64

# Клонируйте репозиторий
cd /usr/src
git clone https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git
cd amneziawg-linux-kernel-module

# Создайте DKMS конфигурацию
cat > dkms.conf << DKMS_EOF
PACKAGE_NAME="amneziawg"
PACKAGE_VERSION="1.0"
BUILT_MODULE_NAME[0]="amneziawg"
DEST_MODULE_LOCATION[0]="/updates"
AUTOINSTALL="yes"
DKMS_EOF

# Установите через DKMS
dkms add .
dkms build amneziawg/1.0
dkms install amneziawg/1.0

# Загрузите модуль
modprobe amneziawg

echo "✓ Модуль ядра установлен!"
