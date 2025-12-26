cat > /usr/local/bin/awg-client << 'CLIENT_SCRIPT'
#!/bin/bash

# Конфигурация
SERVER_CONFIG="/etc/amnezia/awg/wg0.conf"
CLIENTS_DIR="/etc/amnezia/awg/clients"
SERVER_PUBLIC_KEY_FILE="/etc/amnezia/awg/server_public.key"
SERVER_IP_FILE="/etc/amnezia/awg/server_ip.txt"
VPN_NETWORK="10.8.1"
NETWORK_MASK="24"
SERVER_PORT="36058"

# Параметры обфускации
JC=5
JMIN=10
JMAX=50
S1=73
S2=32
H1=29823259
H2=2105934488
H3=1834425522
H4=20681889

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Ошибка: запустите с правами root${NC}"
    exit 1
fi

# Проверка существования файлов
if [ ! -f "$SERVER_CONFIG" ]; then
    echo -e "${RED}Ошибка: серверный конфиг не найден${NC}"
    exit 1
fi

# Создание директории для клиентов
mkdir -p "$CLIENTS_DIR"

# Получение данных сервера
SERVER_PUBLIC_KEY=$(cat "$SERVER_PUBLIC_KEY_FILE" 2>/dev/null)
SERVER_IP=$(cat "$SERVER_IP_FILE" 2>/dev/null)

if [ -z "$SERVER_PUBLIC_KEY" ] || [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Ошибка: не найдены данные сервера${NC}"
    exit 1
fi

# ============================================
# ФУНКЦИИ
# ============================================

# Получение следующего свободного IP
get_next_ip() {
    USED_IPS=$(grep "AllowedIPs = ${VPN_NETWORK}" "$SERVER_CONFIG" 2>/dev/null | awk '{print $3}' | cut -d'/' -f1 | cut -d'.' -f4 | sort -n)
    LAST_IP=$(echo "$USED_IPS" | tail -1)
    
    if [ -z "$LAST_IP" ] || [ "$LAST_IP" -eq 1 ]; then
        echo "2"
    else
        echo $((LAST_IP + 1))
    fi
}

# Добавление клиента
add_client() {
    CLIENT_NAME=$1
    
    if [ -z "$CLIENT_NAME" ]; then
        echo -e "${RED}Ошибка: укажите имя клиента${NC}"
        echo "Использование: awg-client add <имя_клиента>"
        exit 1
    fi
    
    # Проверка валидности имени
    if [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Ошибка: имя может содержать только буквы, цифры, _ и -${NC}"
        exit 1
    fi
    
    # Проверка существования
    if [ -d "$CLIENTS_DIR/$CLIENT_NAME" ]; then
        echo -e "${RED}Ошибка: клиент '$CLIENT_NAME' уже существует${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}Создание клиента: $CLIENT_NAME${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # Создание директории
    mkdir -p "$CLIENTS_DIR/$CLIENT_NAME"
    
    # Генерация ключей
    echo -e "${YELLOW}Генерация ключей...${NC}"
    awg genkey | tee "$CLIENTS_DIR/$CLIENT_NAME/private.key" | awg pubkey > "$CLIENTS_DIR/$CLIENT_NAME/public.key"
    awg genpsk > "$CLIENTS_DIR/$CLIENT_NAME/preshared.key"
    
    CLIENT_PRIVATE_KEY=$(cat "$CLIENTS_DIR/$CLIENT_NAME/private.key")
    CLIENT_PUBLIC_KEY=$(cat "$CLIENTS_DIR/$CLIENT_NAME/public.key")
    CLIENT_PRESHARED_KEY=$(cat "$CLIENTS_DIR/$CLIENT_NAME/preshared.key")
    
    # Получение IP
    CLIENT_IP_LAST=$(get_next_ip)
    CLIENT_IP="${VPN_NETWORK}.${CLIENT_IP_LAST}"
    
    echo "$CLIENT_IP" > "$CLIENTS_DIR/$CLIENT_NAME/ip.txt"
    echo "$(date +%Y-%m-%d)" > "$CLIENTS_DIR/$CLIENT_NAME/created.txt"
    
    # Добавление в серверный конфиг
    echo -e "${YELLOW}Добавление в серверный конфиг...${NC}"
    cat >> "$SERVER_CONFIG" << PEEREOF

# Client: $CLIENT_NAME (created: $(date +%Y-%m-%d))
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = ${CLIENT_IP}/32
PEEREOF
    
    # Создание клиентского конфига
    echo -e "${YELLOW}Создание клиентского конфига...${NC}"
    cat > "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf" << CLIENTEOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = ${CLIENT_IP}/32
DNS = 1.1.1.1, 8.8.8.8
Jc = $JC
Jmin = $JMIN
Jmax = $JMAX
S1 = $S1
S2 = $S2
H1 = $H1
H2 = $H2
H3 = $H3
H4 = $H4

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
Endpoint = $SERVER_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
CLIENTEOF
    
    # Генерация QR-кода
    if command -v qrencode &> /dev/null; then
        echo -e "${YELLOW}Генерация QR-кода...${NC}"
        qrencode -t ansiutf8 < "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf" > "$CLIENTS_DIR/$CLIENT_NAME/qr.txt" 2>/dev/null || true
        qrencode -t png -o "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}-qr.png" < "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf" 2>/dev/null || true
    fi
    
    # Перезагрузка сервиса
    echo -e "${YELLOW}Перезагрузка сервиса...${NC}"
    systemctl reload amnezia-awg
    
    # Вывод результата
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Клиент '$CLIENT_NAME' успешно создан!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${YELLOW}IP адрес:${NC} $CLIENT_IP"
    echo -e "${YELLOW}Конфиг:${NC} $CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf"
    if [ -f "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}-qr.png" ]; then
        echo -e "${YELLOW}QR-код:${NC} $CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}-qr.png"
    fi
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}Конфигурация для клиента:${NC}"
    echo -e "${BLUE}========================================${NC}"
    cat "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf"
    echo -e "${BLUE}========================================${NC}"
    
    if [ -f "$CLIENTS_DIR/$CLIENT_NAME/qr.txt" ]; then
        echo ""
        echo -e "${YELLOW}QR-код для сканирования:${NC}"
        cat "$CLIENTS_DIR/$CLIENT_NAME/qr.txt"
    fi
}

# Удаление клиента
remove_client() {
    CLIENT_NAME=$1
    
    if [ -z "$CLIENT_NAME" ]; then
        echo -e "${RED}Ошибка: укажите имя клиента${NC}"
        echo "Использование: awg-client remove <имя_клиента>"
        exit 1
    fi
    
    if [ ! -d "$CLIENTS_DIR/$CLIENT_NAME" ]; then
        echo -e "${RED}Ошибка: клиент '$CLIENT_NAME' не найден${NC}"
        exit 1
    fi
    
    # Подтверждение
    read -p "Удалить клиента '$CLIENT_NAME'? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Отменено"
        exit 0
    fi
    
    CLIENT_PUBLIC_KEY=$(cat "$CLIENTS_DIR/$CLIENT_NAME/public.key" 2>/dev/null)
    
    # Удаление из конфига
    if [ -n "$CLIENT_PUBLIC_KEY" ]; then
        sed "/# Client: $CLIENT_NAME/,/AllowedIPs.*32/d" "$SERVER_CONFIG" > "$SERVER_CONFIG.tmp"
        mv "$SERVER_CONFIG.tmp" "$SERVER_CONFIG"
    fi
    
    # Резервная копия директории клиента
    BACKUP_DIR="$CLIENTS_DIR/.deleted"
    mkdir -p "$BACKUP_DIR"
    mv "$CLIENTS_DIR/$CLIENT_NAME" "$BACKUP_DIR/${CLIENT_NAME}_$(date +%Y%m%d_%H%M%S)"
    
    # Перезагрузка сервиса
    systemctl reload amnezia-awg
    
    echo -e "${GREEN}✓ Клиент '$CLIENT_NAME' удалён${NC}"
    echo -e "${YELLOW}Резервная копия сохранена в: $BACKUP_DIR${NC}"
}

# Список клиентов
list_clients() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}Список клиентов AmneziaWG${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [ ! -d "$CLIENTS_DIR" ] || [ -z "$(ls -A "$CLIENTS_DIR" 2>/dev/null)" ]; then
        echo "Клиенты не найдены"
        return
    fi
    
    printf "%-20s %-15s %-12s %-10s\n" "ИМЯ" "IP АДРЕС" "ДАТА" "СТАТУС"
    echo "----------------------------------------------------------------"
    
    for client_dir in "$CLIENTS_DIR"/*; do
        if [ -d "$client_dir" ] && [ "$(basename "$client_dir")" != ".deleted" ]; then
            CLIENT_NAME=$(basename "$client_dir")
            CLIENT_IP=$(cat "$client_dir/ip.txt" 2>/dev/null || echo "N/A")
            CLIENT_DATE=$(cat "$client_dir/created.txt" 2>/dev/null || echo "N/A")
            CLIENT_PUBLIC_KEY=$(cat "$client_dir/public.key" 2>/dev/null)
            
            # Проверка онлайн статуса
            STATUS="OFFLINE"
            if [ -n "$CLIENT_PUBLIC_KEY" ]; then
                if awg show wg0 2>/dev/null | grep -q "$CLIENT_PUBLIC_KEY"; then
                    LAST_HANDSHAKE=$(awg show wg0 latest-handshakes 2>/dev/null | grep "$CLIENT_PUBLIC_KEY" | awk '{print $2}')
                    CURRENT_TIME=$(date +%s)
                    
                    if [ -n "$LAST_HANDSHAKE" ] && [ $((CURRENT_TIME - LAST_HANDSHAKE)) -lt 180 ]; then
                        STATUS="${GREEN}ONLINE${NC}"
                    fi
                fi
            fi
            
            printf "%-20s %-15s %-12s %-10b\n" "$CLIENT_NAME" "$CLIENT_IP" "$CLIENT_DATE" "$STATUS"
        fi
    done
    
    echo ""
    TOTAL=$(find "$CLIENTS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".deleted" 2>/dev/null | wc -l)
    echo -e "${YELLOW}Всего клиентов: $TOTAL${NC}"
}

# Показ конфига клиента
show_client() {
    CLIENT_NAME=$1
    
    if [ -z "$CLIENT_NAME" ]; then
        echo -e "${RED}Ошибка: укажите имя клиента${NC}"
        echo "Использование: awg-client show <имя_клиента>"
        exit 1
    fi
    
    if [ ! -d "$CLIENTS_DIR/$CLIENT_NAME" ]; then
        echo -e "${RED}Ошибка: клиент '$CLIENT_NAME' не найден${NC}"
        exit 1
    fi
    
    CLIENT_IP=$(cat "$CLIENTS_DIR/$CLIENT_NAME/ip.txt" 2>/dev/null)
    CLIENT_DATE=$(cat "$CLIENTS_DIR/$CLIENT_NAME/created.txt" 2>/dev/null)
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}Клиент: $CLIENT_NAME${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}IP:${NC} $CLIENT_IP"
    echo -e "${YELLOW}Создан:${NC} $CLIENT_DATE"
    echo -e "${YELLOW}Конфиг:${NC} $CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf"
    echo ""
    echo -e "${YELLOW}Конфигурация:${NC}"
    echo "----------------------------------------"
    cat "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf"
    echo "----------------------------------------"
}

# Показ QR-кода
show_qr() {
    CLIENT_NAME=$1
    
    if [ -z "$CLIENT_NAME" ]; then
        echo -e "${RED}Ошибка: укажите имя клиента${NC}"
        echo "Использование: awg-client qr <имя_клиента>"
        exit 1
    fi
    
    if [ ! -d "$CLIENTS_DIR/$CLIENT_NAME" ]; then
        echo -e "${RED}Ошибка: клиент '$CLIENT_NAME' не найден${NC}"
        exit 1
    fi
    
    if [ -f "$CLIENTS_DIR/$CLIENT_NAME/qr.txt" ]; then
        echo -e "${YELLOW}QR-код для клиента '$CLIENT_NAME':${NC}"
        echo ""
        cat "$CLIENTS_DIR/$CLIENT_NAME/qr.txt"
    else
        echo -e "${YELLOW}Генерация QR-кода...${NC}"
        if command -v qrencode &> /dev/null; then
            qrencode -t ansiutf8 < "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf"
        else
            echo -e "${RED}qrencode не установлен${NC}"
            exit 1
        fi
    fi
}

# Информация о сервере
server_info() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}Информация о сервере${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}IP сервера:${NC} $SERVER_IP"
    echo -e "${YELLOW}Порт:${NC} $SERVER_PORT"
    echo -e "${YELLOW}Публичный ключ:${NC} $SERVER_PUBLIC_KEY"
    echo -e "${YELLOW}Сеть VPN:${NC} ${VPN_NETWORK}.0/$NETWORK_MASK"
    echo ""
    
    if systemctl is-active --quiet amnezia-awg; then
        echo -e "${GREEN}Статус: RUNNING${NC}"
    else
        echo -e "${RED}Статус: STOPPED${NC}"
    fi
    echo ""
    
    echo -e "${YELLOW}Статистика интерфейса:${NC}"
    awg show wg0 2>/dev/null || echo "Интерфейс недоступен"
}

# Экспорт всех конфигов
export_all() {
    EXPORT_DIR="/tmp/amnezia-clients-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$EXPORT_DIR"
    
    echo -e "${YELLOW}Экспорт всех конфигураций...${NC}"
    
    for client_dir in "$CLIENTS_DIR"/*; do
        if [ -d "$client_dir" ] && [ "$(basename "$client_dir")" != ".deleted" ]; then
            CLIENT_NAME=$(basename "$client_dir")
            cp "$client_dir/${CLIENT_NAME}.conf" "$EXPORT_DIR/" 2>/dev/null || true
            cp "$client_dir/${CLIENT_NAME}-qr.png" "$EXPORT_DIR/" 2>/dev/null || true
        fi
    done
    
    echo -e "${GREEN}✓ Конфигурации экспортированы в: $EXPORT_DIR${NC}"
    ls -lh "$EXPORT_DIR"
}

# ============================================
# ГЛАВНОЕ МЕНЮ
# ============================================

case "$1" in
    add)
        add_client "$2"
        ;;
    remove|delete|del|rm)
        remove_client "$2"
        ;;
    list|ls)
        list_clients
        ;;
    show|cat)
        show_client "$2"
        ;;
    qr)
        show_qr "$2"
        ;;
    info|status)
        server_info
        ;;
    export)
        export_all
        ;;
    *)
        echo -e "${BLUE}========================================${NC}"
        echo -e "${YELLOW}AmneziaWG Client Manager${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
        echo "Использование: awg-client {command} [options]"
        echo ""
        echo -e "${YELLOW}Команды:${NC}"
        echo "  add <имя>       - Добавить нового клиента"
        echo "  remove <имя>    - Удалить клиента"
        echo "  list            - Список всех клиентов"
        echo "  show <имя>      - Показать конфиг клиента"
        echo "  qr <имя>        - Показать QR-код клиента"
        echo "  info            - Информация о сервере"
        echo "  export          - Экспортировать все конфиги"
        echo ""
        echo -e "${YELLOW}Примеры:${NC}"
        echo "  awg-client add alice"
        echo "  awg-client list"
        echo "  awg-client qr alice"
        echo "  awg-client remove bob"
        echo ""
        exit 1
        ;;
esac

CLIENT_SCRIPT

chmod +x /usr/local/bin/awg-client
