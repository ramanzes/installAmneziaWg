#!/bin/bash
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Логирование
LOG_FILE="/var/log/amneziawg_install.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}=== AmneziaWG Auto Installer v1.1 ===${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Ошибка: запустите скрипт с правами root${NC}"
    exit 1
fi

# Определение ОС
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo -e "${RED}Не удалось определить ОС${NC}"
    exit 1
fi

echo -e "${GREEN}Обнаружена ОС: $OS $VER${NC}"

# Проверка поддерживаемых ОС
if [[ ! "$OS" =~ ^(ubuntu|debian)$ ]]; then
    echo -e "${RED}Поддерживаются только Ubuntu и Debian${NC}"
    exit 1
fi

# ============================================
# 1. НАСТРОЙКА DNS
# ============================================
echo -e "\n${YELLOW}[1/8] Настройка DNS...${NC}"

# Резервная копия
cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true

# Настройка DNS
cat > /etc/resolv.conf << 'DNSEOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
nameserver 77.88.8.8
DNSEOF

# Для systemd-resolved
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    mkdir -p /etc/systemd/resolved.conf.d/
    cat > /etc/systemd/resolved.conf.d/dns.conf << 'DNSEOF2'
[Resolve]
DNS=8.8.8.8 1.1.1.1 8.8.4.4
FallbackDNS=77.88.8.8
DNSEOF2
    systemctl restart systemd-resolved 2>/dev/null || true
fi

# Проверка DNS с таймаутом
DNS_OK=false
for i in {1..3}; do
    if timeout 3 ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        DNS_OK=true
        break
    fi
    sleep 1
done

if [ "$DNS_OK" = false ]; then
    echo -e "${YELLOW}Предупреждение: проблемы с сетью, продолжаем...${NC}"
fi

echo -e "${GREEN}✓ DNS настроен${NC}"

# ============================================
# 2. ОБНОВЛЕНИЕ СИСТЕМЫ
# ============================================
echo -e "\n${YELLOW}[2/8] Обновление системы...${NC}"

export DEBIAN_FRONTEND=noninteractive

# Обновление с retry
for i in {1..3}; do
    if apt-get update -qq 2>/dev/null; then
        break
    fi
    echo -e "${YELLOW}Повторная попытка обновления ($i/3)...${NC}"
    sleep 2
done

apt-get upgrade -y -qq 2>/dev/null || true

# Установка пакетов
apt-get install -y -qq \
    build-essential \
    git \
    curl \
    wget \
    unzip \
    linux-headers-$(uname -r) \
    dkms \
    pkg-config \
    iptables \
    iptables-persistent \
    resolvconf \
    net-tools \
    qrencode \
    bc 2>/dev/null || echo -e "${YELLOW}Некоторые пакеты не установлены${NC}"

echo -e "${GREEN}✓ Система обновлена${NC}"

# ============================================
# 3. НАСТРОЙКА SYSCTL
# ============================================
echo -e "\n${YELLOW}[3/8] Оптимизация сетевых параметров...${NC}"

cat > /etc/sysctl.d/99-amnezia-vpn.conf << 'SYSCTLEOF'
# File system limits
fs.file-max = 51200

# Network core settings
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096

# IPv4 settings
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

# Enable IP forwarding
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
SYSCTLEOF

sysctl -p /etc/sysctl.d/99-amnezia-vpn.conf >/dev/null 2>&1 || true

# Настройка limits
if ! grep -q "AmneziaWG limits" /etc/security/limits.conf; then
    cat >> /etc/security/limits.conf << 'LIMITSEOF'

# AmneziaWG limits
* soft nofile 51200
* hard nofile 51200
LIMITSEOF
fi

echo -e "${GREEN}✓ Сетевые параметры оптимизированы${NC}"

# ============================================
# 4. УСТАНОВКА AMNEZIAWG МОДУЛЯ
# ============================================
echo -e "\n${YELLOW}[4/8] Установка AmneziaWG модуля ядра...${NC}"

cd /usr/src

# Очистка старых установок
rm -rf amneziawg-linux-kernel-module amneziawg-tools awg-*.zip 2>/dev/null || true

# Функция скачивания через wget
download_with_wget() {
    local url=$1
    local output=$2
    local max_attempts=3
    
    for attempt in $(seq 1 $max_attempts); do
        echo -e "${YELLOW}Попытка скачивания $attempt/$max_attempts...${NC}"
        if wget --timeout=30 --tries=3 -q "$url" -O "$output" 2>/dev/null; then
            return 0
        fi
        sleep 2
    done
    return 1
}

# Попытка клонирования через git
MODULE_DOWNLOADED=false
if command -v git &> /dev/null; then
    echo -e "${YELLOW}Попытка клонирования через git...${NC}"
    if timeout 30 git clone --depth 1 https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git 2>/dev/null; then
        MODULE_DOWNLOADED=true
        echo -e "${GREEN}✓ Репозиторий клонирован через git${NC}"
    fi
fi

# Если git не сработал, используем wget
if [ "$MODULE_DOWNLOADED" = false ]; then
    echo -e "${YELLOW}Git недоступен, скачиваем через wget...${NC}"
    if download_with_wget "https://github.com/amnezia-vpn/amneziawg-linux-kernel-module/archive/refs/heads/master.zip" "awg-kernel.zip"; then
        unzip -q awg-kernel.zip 2>/dev/null || unzip awg-kernel.zip
        mv amneziawg-linux-kernel-module-master amneziawg-linux-kernel-module
        rm awg-kernel.zip
        MODULE_DOWNLOADED=true
        echo -e "${GREEN}✓ Модуль скачан через wget${NC}"
    else
        echo -e "${RED}✗ Не удалось скачать модуль${NC}"
        exit 1
    fi
fi

# Компиляция модуля
echo -e "${YELLOW}Компиляция модуля ядра...${NC}"
cd amneziawg-linux-kernel-module/src
if ! make -j$(nproc) >/dev/null 2>&1; then
    echo -e "${RED}Ошибка компиляции, повторная попытка с выводом...${NC}"
    make -j$(nproc)
fi
make install >/dev/null 2>&1

# Загрузка модуля
modprobe amneziawg 2>/dev/null || true

# Автозагрузка
echo "amneziawg" > /etc/modules-load.d/amneziawg.conf

# Проверка загрузки
if lsmod | grep -q amneziawg; then
    echo -e "${GREEN}✓ Модуль ядра установлен и загружен${NC}"
else
    echo -e "${RED}✗ Ошибка загрузки модуля, но продолжаем...${NC}"
fi

# ============================================
# 5. УСТАНОВКА AMNEZIAWG УТИЛИТ
# ============================================
echo -e "\n${YELLOW}[5/8] Установка AmneziaWG утилит...${NC}"

cd /usr/src

TOOLS_DOWNLOADED=false
if command -v git &> /dev/null; then
    echo -e "${YELLOW}Попытка клонирования через git...${NC}"
    if timeout 30 git clone --depth 1 https://github.com/amnezia-vpn/amneziawg-tools.git 2>/dev/null; then
        TOOLS_DOWNLOADED=true
        echo -e "${GREEN}✓ Утилиты клонированы через git${NC}"
    fi
fi

if [ "$TOOLS_DOWNLOADED" = false ]; then
    echo -e "${YELLOW}Скачиваем утилиты через wget...${NC}"
    if download_with_wget "https://github.com/amnezia-vpn/amneziawg-tools/archive/refs/heads/master.zip" "awg-tools.zip"; then
        unzip -q awg-tools.zip 2>/dev/null || unzip awg-tools.zip
        mv amneziawg-tools-master amneziawg-tools
        rm awg-tools.zip
        TOOLS_DOWNLOADED=true
        echo -e "${GREEN}✓ Утилиты скачаны через wget${NC}"
    else
        echo -e "${RED}✗ Не удалось скачать утилиты${NC}"
        exit 1
    fi
fi

# Компиляция утилит
echo -e "${YELLOW}Компиляция утилит...${NC}"
cd amneziawg-tools/src
make WITH_WGQUICK=yes -j$(nproc) >/dev/null 2>&1 || make WITH_WGQUICK=yes -j$(nproc)
make install WITH_WGQUICK=yes >/dev/null 2>&1

if command -v awg &> /dev/null && command -v awg-quick &> /dev/null; then
    echo -e "${GREEN}✓ Утилиты установлены${NC}"
    awg --version
else
    echo -e "${RED}✗ Ошибка установки утилит${NC}"
    exit 1
fi

# ============================================
# 6. ОПРЕДЕЛЕНИЕ ВНЕШНЕГО IP
# ============================================
echo -e "\n${YELLOW}[6/8] Определение внешнего IP...${NC}"

# Список сервисов для определения IP
IP_SERVICES=(
    "ifconfig.me"
    "icanhazip.com"
    "ipinfo.io/ip"
    "api.ipify.org"
    "ifconfig.co"
    "ident.me"
    "ipecho.net/plain"
)

SERVER_IP=""
for service in "${IP_SERVICES[@]}"; do
    echo -e "${YELLOW}Пробуем $service...${NC}"
    IP=$(timeout 5 curl -s --max-time 5 "$service" 2>/dev/null | grep -oE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' | head -1)
    if [ -n "$IP" ]; then
        SERVER_IP="$IP"
        echo -e "${GREEN}✓ IP получен через $service${NC}"
        break
    fi
    sleep 1
done

# Если автоопределение не удалось
if [ -z "$SERVER_IP" ]; then
    echo -e "${YELLOW}Не удалось автоматически определить IP${NC}"
    echo -e "${YELLOW}Попытка определить через интерфейс...${NC}"
    
    # Пытаемся получить IP из сетевого интерфейса
    SERVER_IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1)
    
    if [ -z "$SERVER_IP" ]; then
        echo ""
        echo -e "${RED}========================================${NC}"
        read -p "Введите внешний IP сервера вручную: " SERVER_IP
        echo -e "${RED}========================================${NC}"
        
        if [ -z "$SERVER_IP" ]; then
            echo -e "${RED}IP не указан. Выход.${NC}"
            exit 1
        fi
    fi
fi

# Валидация IP
if [[ ! "$SERVER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e "${RED}Неверный формат IP: $SERVER_IP${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Внешний IP: $SERVER_IP${NC}"

# ============================================
# 7. ГЕНЕРАЦИЯ КОНФИГУРАЦИИ
# ============================================
echo -e "\n${YELLOW}[7/8] Генерация конфигурации сервера...${NC}"

# Создание директорий
mkdir -p /etc/amnezia/awg/clients

# Генерация ключей сервера
awg genkey | tee /etc/amnezia/awg/server_private.key | awg pubkey > /etc/amnezia/awg/server_public.key
chmod 600 /etc/amnezia/awg/server_private.key
chmod 644 /etc/amnezia/awg/server_public.key

SERVER_PRIVATE_KEY=$(cat /etc/amnezia/awg/server_private.key)
SERVER_PUBLIC_KEY=$(cat /etc/amnezia/awg/server_public.key)

# Создание серверного конфига
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
CONFEOF

chmod 600 /etc/amnezia/awg/wg0.conf

# Сохранение IP
echo "$SERVER_IP" > /etc/amnezia/awg/server_ip.txt

echo -e "${GREEN}✓ Конфигурация сервера создана${NC}"

# ============================================
# 7.1 НАСТРОЙКА FIREWALL
# ============================================
echo -e "\n${YELLOW}Настройка firewall...${NC}"

# Определение основного интерфейса
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

if [ -z "$MAIN_INTERFACE" ]; then
    # Альтернативный метод
    MAIN_INTERFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -1)
fi

if [ -z "$MAIN_INTERFACE" ]; then
    echo -e "${YELLOW}Не удалось определить интерфейс, используем eth0${NC}"
    MAIN_INTERFACE="eth0"
fi

echo -e "${GREEN}Обнаружен интерфейс: $MAIN_INTERFACE${NC}"

# Создание скрипта firewall
cat > /etc/amnezia/awg/firewall.sh << FWEOF
#!/bin/bash

MAIN_INTERFACE="$MAIN_INTERFACE"

# Очистка старых правил
iptables -D INPUT -i wg0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i wg0 -j ACCEPT 2>/dev/null || true
iptables -D OUTPUT -o wg0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i wg0 -o \$MAIN_INTERFACE -s 10.8.1.0/24 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
iptables -t nat -D POSTROUTING -s 10.8.1.0/24 -o \$MAIN_INTERFACE -j MASQUERADE 2>/dev/null || true
iptables -D INPUT -p udp --dport 36058 -j ACCEPT 2>/dev/null || true

# Применение правил
iptables -A INPUT -i wg0 -j ACCEPT
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A OUTPUT -o wg0 -j ACCEPT
iptables -A FORWARD -i wg0 -o \$MAIN_INTERFACE -s 10.8.1.0/24 -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.1.0/24 -o \$MAIN_INTERFACE -j MASQUERADE
iptables -A INPUT -p udp --dport 36058 -j ACCEPT

echo "Firewall configured for interface: \$MAIN_INTERFACE"
FWEOF

chmod +x /etc/amnezia/awg/firewall.sh

echo -e "${GREEN}✓ Firewall настроен${NC}"

# ============================================
# 8. СОЗДАНИЕ SYSTEMD СЕРВИСА
# ============================================
echo -e "\n${YELLOW}[8/8] Создание systemd сервиса...${NC}"

cat > /etc/systemd/system/amnezia-awg.service << 'SERVICEEOF'
[Unit]
Description=AmneziaWG VPN Tunnel
After=network-online.target nss-lookup.target
Wants=network-online.target nss-lookup.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/awg-quick up /etc/amnezia/awg/wg0.conf
ExecStart=/etc/amnezia/awg/firewall.sh
ExecStop=/usr/bin/awg-quick down /etc/amnezia/awg/wg0.conf
ExecReload=/bin/bash -c '/usr/bin/awg-quick down /etc/amnezia/awg/wg0.conf; sleep 1; /usr/bin/awg-quick up /etc/amnezia/awg/wg0.conf; /etc/amnezia/awg/firewall.sh'
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload

systemctl enable amnezia-awg >/dev/null 2>&1

# Запуск с повторными попытками
STARTED=false
for attempt in {1..3}; do
    echo -e "${YELLOW}Попытка запуска сервиса ($attempt/3)...${NC}"
    if systemctl start amnezia-awg 2>/dev/null; then
        sleep 2
        if systemctl is-active --quiet amnezia-awg; then
            STARTED=true
            break
        fi
    fi
    sleep 2
done

if [ "$STARTED" = true ]; then
    echo -e "${GREEN}✓ Сервис запущен успешно${NC}"
else
    echo -e "${RED}✗ Ошибка запуска сервиса${NC}"
    echo -e "${YELLOW}Попытка диагностики...${NC}"
    systemctl status amnezia-awg --no-pager
    journalctl -u amnezia-awg -n 20 --no-pager
    
    # Попытка ручного запуска
    echo -e "${YELLOW}Попытка ручного запуска...${NC}"
    /usr/bin/awg-quick up /etc/amnezia/awg/wg0.conf || true
    /etc/amnezia/awg/firewall.sh || true
fi

# Финальная проверка
sleep 2
if ip link show wg0 &>/dev/null; then
    echo -e "${GREEN}✓ Интерфейс wg0 активен${NC}"
else
    echo -e "${YELLOW}⚠ Интерфейс wg0 не обнаружен${NC}"
fi

# ============================================
# ЗАВЕРШЕНИЕ
# ============================================
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}=== Установка завершена! ===${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Информация о сервере:${NC}"
echo -e "  Внешний IP: ${GREEN}$SERVER_IP${NC}"
echo -e "  Порт: ${GREEN}36058/UDP${NC}"
echo -e "  Публичный ключ: ${GREEN}$SERVER_PUBLIC_KEY${NC}"
echo -e "  Сетевой интерфейс: ${GREEN}$MAIN_INTERFACE${NC}"
echo ""
echo -e "${YELLOW}Файлы конфигурации:${NC}"
echo -e "  Серверный конфиг: /etc/amnezia/awg/wg0.conf"
echo -e "  IP сервера: /etc/amnezia/awg/server_ip.txt"
echo -e "  Firewall: /etc/amnezia/awg/firewall.sh"
echo ""
echo -e "${YELLOW}Управление сервисом:${NC}"
echo -e "  systemctl status amnezia-awg"
echo -e "  systemctl restart amnezia-awg"
echo -e "  awg show wg0"
echo ""
echo -e "${YELLOW}Управление клиентами:${NC}"
echo -e "  awg-client add <имя>"
echo -e "  awg-client list"
echo -e "  awg-client qr <имя>"
echo ""
echo -e "${YELLOW}Логи:${NC} $LOG_FILE"
echo ""

# Показываем статус
echo -e "${YELLOW}Текущий статус:${NC}"
systemctl status amnezia-awg --no-pager -l || true
echo ""
awg show wg0 2>/dev/null || echo -e "${YELLOW}Интерфейс wg0 пока не активен${NC}"

