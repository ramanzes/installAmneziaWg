#!/bin/ash
set -e

# Логирование
LOG_FILE="/var/log/amneziawg_install.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

printf "========================================\n"
printf "=== AmneziaWG Auto Installer v1.4 for Alpine ===\n"
printf "========================================\n\n"

# Проверка прав root
if [ "$(id -u)" -ne 0 ]; then
    printf "Ошибка: запустите скрипт с правами root\n"
    exit 1
fi

# Определение ОС (для Alpine)
if grep -q 'ID=alpine' /etc/os-release; then
    OS="alpine"
else
    printf "Ошибка: Поддерживается только Alpine\n"
    exit 1
fi

printf "Обнаружена ОС: %s\n" "$OS"

# 1. НАСТРОЙКА DNS
printf "\n[1/9] Настройка DNS...\n"
cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true

cat > /etc/resolv.conf << 'DNSEOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
nameserver 77.88.8.8
DNSEOF

# Проверка DNS
DNS_OK=false
i=1
while [ $i -le 3 ]; do
    if timeout 3 ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        DNS_OK=true
        break
    fi
    sleep 1
    i=$((i + 1))
done

if [ "$DNS_OK" = false ]; then
    printf "Предупреждение: проблемы с сетью, продолжаем...\n"
fi

printf "DNS настроен\n"

# 2. ОПРЕДЕЛЕНИЕ ЯДРА И УСТАНОВКА ЗАГОЛОВКОВ
printf "\n[2/9] Определение ядра и установка заголовков...\n"

KERNEL_VERSION=$(uname -r)
printf "Версия ядра: %s\n" "$KERNEL_VERSION"

# Определяем тип ядра (lts, virt, edge, etc)
KERNEL_TYPE="lts"
if echo "$KERNEL_VERSION" | grep -q "virt"; then
    KERNEL_TYPE="virt"
elif echo "$KERNEL_VERSION" | grep -q "edge"; then
    KERNEL_TYPE="edge"
fi

printf "Тип ядра: %s\n" "$KERNEL_TYPE"

# Установка заголовков
apk update
apk add linux-${KERNEL_TYPE}-dev

# Проверка установки заголовков
if [ -d "/usr/src/linux-headers-${KERNEL_VERSION}" ] || [ -d "/lib/modules/${KERNEL_VERSION}/build" ]; then
    printf "Заголовки ядра установлены\n"
else
    printf "Предупреждение: заголовки могут быть установлены некорректно\n"
fi

# 3. ОБНОВЛЕНИЕ СИСТЕМЫ
printf "\n[3/9] Обновление системы...\n"
apk upgrade -U

# Установка пакетов
apk add build-base git curl wget unzip linux-headers iptables net-tools qrencode bc

printf "Система обновлена\n"

# 4. НАСТРОЙКА SYSCTL
printf "\n[4/9] Оптимизация сетевых параметров...\n"

cat > /etc/sysctl.conf << 'SYSCTLEOF'
fs.file-max = 51200
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = hybla
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
SYSCTLEOF

sysctl -p /etc/sysctl.conf >/dev/null 2>&1 || true

# Настройка limits для Alpine
if [ ! -d /etc/security ]; then
    mkdir -p /etc/security
fi

if ! grep -q "AmneziaWG limits" /etc/security/limits.conf 2>/dev/null; then
    cat > /etc/security/limits.conf << 'LIMITSEOF'
# AmneziaWG limits
* soft nofile 51200
* hard nofile 51200
LIMITSEOF
fi

printf "Сетевые параметры оптимизированы\n"

# 5. УСТАНОВКА AMNEZIAWG МОДУЛЯ
printf "\n[5/9] Установка AmneziaWG модуля ядра...\n"

# Создаём директорию /usr/src если не существует
if [ ! -d /usr/src ]; then
    mkdir -p /usr/src
fi

cd /usr/src

rm -rf amneziawg-linux-kernel-module amneziawg-tools awg-*.zip 2>/dev/null || true

# Функция скачивания
download_with_wget() {
    url=$1
    output=$2
    max_attempts=3
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        printf "Попытка скачивания %d/%d...\n" $attempt $max_attempts
        if wget --timeout=30 --tries=3 -q "$url" -O "$output" 2>/dev/null; then
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
    done
    return 1
}

MODULE_DOWNLOADED=false
if command -v git >/dev/null 2>&1; then
    printf "Попытка клонирования через git...\n"
    if timeout 30 git clone --depth 1 https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git 2>/dev/null; then
        MODULE_DOWNLOADED=true
        printf "Репозиторий клонирован через git\n"
    fi
fi

if [ "$MODULE_DOWNLOADED" = false ]; then
    printf "Git недоступен, скачиваем через wget...\n"
    if download_with_wget "https://github.com/amnezia-vpn/amneziawg-linux-kernel-module/archive/refs/heads/master.zip" "awg-kernel.zip"; then
        unzip -q awg-kernel.zip 2>/dev/null || unzip awg-kernel.zip
        mv amneziawg-linux-kernel-module-master amneziawg-linux-kernel-module
        rm awg-kernel.zip
        MODULE_DOWNLOADED=true
        printf "Модуль скачан через wget\n"
    else
        printf "Не удалось скачать модуль\n"
        exit 1
    fi
fi

printf "Компиляция модуля ядра...\n"
cd amneziawg-linux-kernel-module/src

# Для Alpine может потребоваться явное указание пути к заголовкам
if [ ! -d "/lib/modules/${KERNEL_VERSION}/build" ]; then
    # Создаём символическую ссылку на заголовки
    mkdir -p /lib/modules/${KERNEL_VERSION}
    if [ -d "/usr/src/linux-headers-${KERNEL_VERSION}" ]; then
        ln -sf /usr/src/linux-headers-${KERNEL_VERSION} /lib/modules/${KERNEL_VERSION}/build
    fi
fi

make -j$(nproc) 2>&1 || {
    printf "Ошибка компиляции, показываем детали:\n"
    printf "Путь к заголовкам: /lib/modules/${KERNEL_VERSION}/build\n"
    ls -la /lib/modules/${KERNEL_VERSION}/ || true
    ls -la /usr/src/ | grep linux || true
    exit 1
}

make install >/dev/null 2>&1

modprobe amneziawg 2>/dev/null || true

echo "amneziawg" > /etc/modules

if lsmod | grep -q amneziawg; then
    printf "Модуль ядра установлен и загружен\n"
else
    printf "Предупреждение: модуль не загружен, но продолжаем...\n"
    printf "Попробуйте загрузить вручную после перезагрузки: modprobe amneziawg\n"
fi

# 6. УСТАНОВКА AMNEZIAWG УТИЛИТ
printf "\n[6/9] Установка AmneziaWG утилит...\n"
cd /usr/src

TOOLS_DOWNLOADED=false
if command -v git >/dev/null 2>&1; then
    printf "Попытка клонирования через git...\n"
    if timeout 30 git clone --depth 1 https://github.com/amnezia-vpn/amneziawg-tools.git 2>/dev/null; then
        TOOLS_DOWNLOADED=true
        printf "Утилиты клонированы через git\n"
    fi
fi

if [ "$TOOLS_DOWNLOADED" = false ]; then
    printf "Скачиваем утилиты через wget...\n"
    if download_with_wget "https://github.com/amnezia-vpn/amneziawg-tools/archive/refs/heads/master.zip" "awg-tools.zip"; then
        unzip -q awg-tools.zip 2>/dev/null || unzip awg-tools.zip
        mv amneziawg-tools-master amneziawg-tools
        rm awg-tools.zip
        TOOLS_DOWNLOADED=true
        printf "Утилиты скачаны через wget\n"
    else
        printf "Не удалось скачать утилиты\n"
        exit 1
    fi
fi

printf "Компиляция утилит...\n"
cd amneziawg-tools/src
make WITH_WGQUICK=yes -j$(nproc) >/dev/null 2>&1 || make WITH_WGQUICK=yes -j$(nproc)
make install WITH_WGQUICK=yes >/dev/null 2>&1

if command -v awg >/dev/null 2>&1 && command -v awg-quick >/dev/null 2>&1; then
    printf "Утилиты установлены\n"
    awg --version
else
    printf "Ошибка установки утилит\n"
    exit 1
fi

# 7. ОПРЕДЕЛЕНИЕ ВНЕШНЕГО IP
printf "\n[7/9] Определение внешнего IP...\n"

IP_SERVICES="ifconfig.me icanhazip.com ipinfo.io/ip api.ipify.org ifconfig.co ident.me ipecho.net/plain"
SERVER_IP=""

for service in $IP_SERVICES; do
    printf "Пробуем %s...\n" "$service"
    IP=$(timeout 5 curl -s --max-time 5 "$service" 2>/dev/null | grep -oE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' | head -1)
    if [ -n "$IP" ]; then
        SERVER_IP="$IP"
        printf "IP получен через %s\n" "$service"
        break
    fi
    sleep 1
done

if [ -z "$SERVER_IP" ]; then
    printf "Не удалось автоматически определить IP\n"
    SERVER_IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1)
    
    if [ -z "$SERVER_IP" ]; then
        printf "Введите внешний IP сервера вручную: "
        read SERVER_IP
    fi
fi

printf "Внешний IP: %s\n" "$SERVER_IP"

# 8. ГЕНЕРАЦИЯ КЛЮЧЕЙ И КОНФИГА
printf "\n[8/9] Генерация ключей и конфигурации...\n"

mkdir -p /etc/amnezia/awg/clients

awg genkey | tee /etc/amnezia/awg/server_private.key | awg pubkey > /etc/amnezia/awg/server_public.key
chmod 600 /etc/amnezia/awg/server_private.key
chmod 644 /etc/amnezia/awg/server_public.key

SERVER_PRIVATE_KEY=$(cat /etc/amnezia/awg/server_private.key)
SERVER_PUBLIC_KEY=$(cat /etc/amnezia/awg/server_public.key)

# Определяем основной сетевой интерфейс
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$MAIN_INTERFACE" ]; then
    MAIN_INTERFACE="eth0"
fi

printf "Обнаружен интерфейс: %s\n" "$MAIN_INTERFACE"

cat > /etc/amnezia/awg/wg0.conf << CONFEOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 10.8.1.1/24
ListenPort = 36058
Jc = 5
Jmin = 10
Jmax = 50
S1 = 73
S2 = 32
H1 = 29823259
H2 = 2105934488
H3 = 1834425522
H4 = 20681889
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $MAIN_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $MAIN_INTERFACE -j MASQUERADE
CONFEOF

chmod 600 /etc/amnezia/awg/wg0.conf

echo "$SERVER_IP" > /etc/amnezia/awg/server_ip.txt

printf "Конфигурация создана\n"

# 9. НАСТРОЙКА СЕРВИСА И FIREWALL
printf "\n[9/9] Настройка сервиса и firewall...\n"

cat > /etc/init.d/amnezia-awg << 'SERVICEEOF'
#!/sbin/openrc-run

description="AmneziaWG VPN Service"

depend() {
    need net
    use dns logger
}

start() {
    ebegin "Starting AmneziaWG"
    /usr/bin/awg-quick up /etc/amnezia/awg/wg0.conf
    eend $?
}

stop() {
    ebegin "Stopping AmneziaWG"
    /usr/bin/awg-quick down /etc/amnezia/awg/wg0.conf
    eend $?
}

reload() {
    ebegin "Reloading AmneziaWG"
    /usr/bin/awg syncconf wg0 <(awg-quick strip /etc/amnezia/awg/wg0.conf)
    eend $?
}

status() {
    if /usr/bin/awg show wg0 >/dev/null 2>&1; then
        einfo "AmneziaWG is running"
        /usr/bin/awg show wg0
        return 0
    else
        eerror "AmneziaWG is not running"
        return 1
    fi
}
SERVICEEOF

chmod +x /etc/init.d/amnezia-awg

rc-update add amnezia-awg default

# Запуск сервиса
if rc-service amnezia-awg start; then
    printf "Сервис запущен успешно\n"
else
    printf "Ошибка запуска сервиса (возможно нужна перезагрузка для загрузки модуля)\n"
fi

# Настройка firewall persistence
mkdir -p /etc/iptables
if command -v iptables-save >/dev/null 2>&1; then
    iptables-save > /etc/iptables/rules-save
    rc-update add iptables default
fi

printf "\n========================================\n"
printf "Установка завершена!\n"
printf "========================================\n"
printf "Сервер IP: %s\n" "$SERVER_IP"
printf "Порт: 36058/UDP\n"
printf "Публичный ключ: %s\n" "$SERVER_PUBLIC_KEY"
printf "Интерфейс: %s\n" "$MAIN_INTERFACE"
printf "Ядро: %s\n" "$KERNEL_VERSION"
printf "\n⚠️  ВАЖНО: Если модуль не загрузился, перезагрузите систему:\n"
printf "  reboot\n"
printf "\nУправление сервисом:\n"
printf "  rc-service amnezia-awg {start|stop|restart|reload|status}\n"
printf "\nУправление клиентами:\n"
printf "  awg-client add <имя>\n"
printf "  awg-client list\n"
printf "  awg-client show <имя>\n"
printf "  awg-client qr <имя>\n"
printf "\nПроверка статуса:\n"
printf "  lsmod | grep amneziawg\n"
printf "  awg show wg0\n"
printf "  rc-service amnezia-awg status\n"
printf "\nЛоги: %s\n" "$LOG_FILE"
printf "========================================\n"
