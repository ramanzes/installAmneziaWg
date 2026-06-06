#!/bin/ash

# Конфигурация
SERVER_CONFIG="/etc/amnezia/awg/wg0.conf"
CLIENTS_DIR="/etc/amnezia/awg/clients"
SERVER_PUBLIC_KEY_FILE="/etc/amnezia/awg/server_public.key"
SERVER_IP_FILE="/etc/amnezia/awg/server_ip.txt"
VPN_NETWORK="10.8.1"
NETWORK_MASK="24"
SERVER_PORT="36058"
VK_TURN_PORT="56000"

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

# Проверка прав root
if [ "$(id -u)" -ne 0 ]; then
    printf "Ошибка: запустите с правами root\n"
    exit 1
fi

if [ ! -f "$SERVER_CONFIG" ]; then
    printf "Ошибка: серверный конфиг не найден\n"
    exit 1
fi

mkdir -p "$CLIENTS_DIR"

SERVER_PUBLIC_KEY=$(cat "$SERVER_PUBLIC_KEY_FILE" 2>/dev/null)
SERVER_IP=$(cat "$SERVER_IP_FILE" 2>/dev/null)

if [ -z "$SERVER_PUBLIC_KEY" ] || [ -z "$SERVER_IP" ]; then
    printf "Ошибка: не найдены данные сервера\n"
    exit 1
fi

# ФУНКЦИИ

get_next_ip() {
    USED_IPS=$(grep "AllowedIPs = ${VPN_NETWORK}" "$SERVER_CONFIG" 2>/dev/null | awk '{print $3}' | cut -d'/' -f1 | cut -d'.' -f4 | sort -n)
    LAST_IP=$(echo "$USED_IPS" | tail -1)
    if [ -z "$LAST_IP" ] || [ "$LAST_IP" -eq 1 ]; then
        echo "2"
    else
        echo $((LAST_IP + 1))
    fi
}

# Генерация VK TURN конфига для клиента
generate_vk_config() {
    CLIENT_NAME=$1
    CLIENT_DIR="$CLIENTS_DIR/$CLIENT_NAME"

    if [ ! -d "$CLIENT_DIR" ]; then
        printf "Ошибка: клиент '%s' не найден\n" "$CLIENT_NAME"
        return 1
    fi

    CLIENT_PRIVATE_KEY=$(cat "$CLIENT_DIR/private.key" 2>/dev/null)
    CLIENT_PRESHARED_KEY=$(cat "$CLIENT_DIR/preshared.key" 2>/dev/null)
    CLIENT_IP=$(cat "$CLIENT_DIR/ip.txt" 2>/dev/null)

    if [ -z "$CLIENT_PRIVATE_KEY" ] || [ -z "$CLIENT_IP" ]; then
        printf "Ошибка: не найдены ключи клиента\n"
        return 1
    fi

    cat > "$CLIENT_DIR/${CLIENT_NAME}-vk.conf" << VKEOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = ${CLIENT_IP}/32
DNS = 1.1.1.1, 8.8.8.8
MTU = 1280
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
Endpoint = 127.0.0.1:9000
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
VKEOF

    if command -v qrencode >/dev/null 2>&1; then
        qrencode -t ansiutf8 < "$CLIENT_DIR/${CLIENT_NAME}-vk.conf" > "$CLIENT_DIR/qr-vk.txt" 2>/dev/null || true
        qrencode -t png -o "$CLIENT_DIR/${CLIENT_NAME}-vk-qr.png" < "$CLIENT_DIR/${CLIENT_NAME}-vk.conf" 2>/dev/null || true
    fi
}

add_client() {
    CLIENT_NAME=$1

    if [ -z "$CLIENT_NAME" ]; then
        printf "Ошибка: укажите имя клиента\n"
        printf "Использование: awg-client add <имя_клиента>\n"
        exit 1
    fi

    if ! echo "$CLIENT_NAME" | grep -qE '^[a-zA-Z0-9_-]+$'; then
        printf "Ошибка: имя может содержать только буквы, цифры, _ и -\n"
        exit 1
    fi

    if [ -d "$CLIENTS_DIR/$CLIENT_NAME" ]; then
        printf "Ошибка: клиент '%s' уже существует\n" "$CLIENT_NAME"
        exit 1
    fi

    printf "========================================\n"
    printf "Создание клиента: %s\n" "$CLIENT_NAME"
    printf "========================================\n"

    mkdir -p "$CLIENTS_DIR/$CLIENT_NAME"

    printf "Генерация ключей...\n"
    awg genkey | tee "$CLIENTS_DIR/$CLIENT_NAME/private.key" | awg pubkey > "$CLIENTS_DIR/$CLIENT_NAME/public.key"
    awg genpsk > "$CLIENTS_DIR/$CLIENT_NAME/preshared.key"

    CLIENT_PRIVATE_KEY=$(cat "$CLIENTS_DIR/$CLIENT_NAME/private.key")
    CLIENT_PUBLIC_KEY=$(cat "$CLIENTS_DIR/$CLIENT_NAME/public.key")
    CLIENT_PRESHARED_KEY=$(cat "$CLIENTS_DIR/$CLIENT_NAME/preshared.key")

    CLIENT_IP_LAST=$(get_next_ip)
    CLIENT_IP="${VPN_NETWORK}.${CLIENT_IP_LAST}"

    echo "$CLIENT_IP" > "$CLIENTS_DIR/$CLIENT_NAME/ip.txt"
    echo "$(date +%Y-%m-%d)" > "$CLIENTS_DIR/$CLIENT_NAME/created.txt"

    printf "Добавление в серверный конфиг...\n"
    cat >> "$SERVER_CONFIG" << PEEREOF

# Client: $CLIENT_NAME (created: $(date +%Y-%m-%d))
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = ${CLIENT_IP}/32
PEEREOF

    printf "Создание прямого конфига (AWG)...\n"
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

    printf "Создание VK TURN конфига...\n"
    generate_vk_config "$CLIENT_NAME"

    if command -v qrencode >/dev/null 2>&1; then
        printf "Генерация QR-кодов...\n"
        qrencode -t ansiutf8 < "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf" > "$CLIENTS_DIR/$CLIENT_NAME/qr.txt" 2>/dev/null || true
        qrencode -t png -o "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}-qr.png" < "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf" 2>/dev/null || true
    fi

    printf "Перезагрузка сервиса...\n"
    rc-service amnezia-awg reload

    printf "\n========================================\n"
    printf "Клиент '%s' успешно создан!\n" "$CLIENT_NAME"
    printf "========================================\n"
    printf "IP адрес : %s\n" "$CLIENT_IP"
    printf "\n--- Прямой конфиг (обычное подключение) ---\n"
    printf "Файл: %s/%s.conf\n" "$CLIENTS_DIR/$CLIENT_NAME" "$CLIENT_NAME"
    printf "\n--- VK TURN конфиг (для белых списков) ---\n"
    printf "Файл: %s/%s-vk.conf\n" "$CLIENTS_DIR/$CLIENT_NAME" "$CLIENT_NAME"
    printf "Команда Termux/iSH:\n"
    printf "  ./client -listen 127.0.0.1:9000 -peer %s:%s -vk-link ССЫЛКА -n 3\n" "$SERVER_IP" "$VK_TURN_PORT"
    printf "\n========================================\n"
    printf "ПРЯМОЙ конфиг:\n"
    printf "========================================\n"
    cat "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf"

    if [ -f "$CLIENTS_DIR/$CLIENT_NAME/qr.txt" ]; then
        printf "\nQR (прямой):\n"
        cat "$CLIENTS_DIR/$CLIENT_NAME/qr.txt"
    fi

    printf "\n========================================\n"
    printf "VK TURN конфиг:\n"
    printf "========================================\n"
    cat "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}-vk.conf"

    if [ -f "$CLIENTS_DIR/$CLIENT_NAME/qr-vk.txt" ]; then
        printf "\nQR (VK TURN):\n"
        cat "$CLIENTS_DIR/$CLIENT_NAME/qr-vk.txt"
    fi
}

add_vk() {
    CLIENT_NAME=$1

    if [ -z "$CLIENT_NAME" ]; then
        printf "Ошибка: укажите имя клиента\n"
        printf "Использование: awg-client add-vk <имя_клиента>\n"
        exit 1
    fi

    if [ ! -d "$CLIENTS_DIR/$CLIENT_NAME" ]; then
        printf "Ошибка: клиент '%s' не найден\n" "$CLIENT_NAME"
        exit 1
    fi

    printf "Генерация VK TURN конфига для '%s'...\n" "$CLIENT_NAME"
    generate_vk_config "$CLIENT_NAME"
    printf "\n========================================\n"
    printf "VK TURN конфиг для '%s':\n" "$CLIENT_NAME"
    printf "========================================\n"
    cat "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}-vk.conf"

    if [ -f "$CLIENTS_DIR/$CLIENT_NAME/qr-vk.txt" ]; then
        printf "\nQR (VK TURN):\n"
        cat "$CLIENTS_DIR/$CLIENT_NAME/qr-vk.txt"
    fi

    printf "\nКоманда Termux/iSH:\n"
    printf "  ./client -listen 127.0.0.1:9000 -peer %s:%s -vk-link ССЫЛКА -n 3\n" "$SERVER_IP" "$VK_TURN_PORT"
}

remove_client() {
    CLIENT_NAME=$1

    if [ -z "$CLIENT_NAME" ]; then
        printf "Ошибка: укажите имя клиента\n"
        printf "Использование: awg-client remove <имя_клиента>\n"
        exit 1
    fi

    if [ ! -d "$CLIENTS_DIR/$CLIENT_NAME" ]; then
        printf "Ошибка: клиент '%s' не найден\n" "$CLIENT_NAME"
        exit 1
    fi

    printf "Удалить клиента '%s'? (yes/no): " "$CLIENT_NAME"
    read confirm
    if [ "$confirm" != "yes" ]; then
        printf "Отменено\n"
        exit 0
    fi

    CLIENT_PUBLIC_KEY=$(cat "$CLIENTS_DIR/$CLIENT_NAME/public.key" 2>/dev/null)

    if [ -n "$CLIENT_PUBLIC_KEY" ]; then
        sed "/# Client: $CLIENT_NAME/,/AllowedIPs.*32/d" "$SERVER_CONFIG" > "$SERVER_CONFIG.tmp"
        mv "$SERVER_CONFIG.tmp" "$SERVER_CONFIG"
    fi

    BACKUP_DIR="$CLIENTS_DIR/.deleted"
    mkdir -p "$BACKUP_DIR"
    mv "$CLIENTS_DIR/$CLIENT_NAME" "$BACKUP_DIR/${CLIENT_NAME}_$(date +%Y%m%d_%H%M%S)"

    rc-service amnezia-awg reload

    printf "Клиент '%s' удалён\n" "$CLIENT_NAME"
    printf "Резервная копия: %s\n" "$BACKUP_DIR"
}

list_clients() {
    printf "========================================\n"
    printf "Список клиентов AmneziaWG\n"
    printf "========================================\n\n"

    if [ ! -d "$CLIENTS_DIR" ] || [ -z "$(ls -A "$CLIENTS_DIR" 2>/dev/null)" ]; then
        printf "Клиенты не найдены\n"
        return
    fi

    printf "%-20s %-15s %-12s %-8s %-8s\n" "ИМЯ" "IP АДРЕС" "ДАТА" "СТАТУС" "VK TURN"
    printf "------------------------------------------------------------------------\n"

    for client_dir in "$CLIENTS_DIR"/*; do
        if [ -d "$client_dir" ] && [ "$(basename "$client_dir")" != ".deleted" ]; then
            CLIENT_NAME=$(basename "$client_dir")
            CLIENT_IP=$(cat "$client_dir/ip.txt" 2>/dev/null || echo "N/A")
            CLIENT_DATE=$(cat "$client_dir/created.txt" 2>/dev/null || echo "N/A")
            CLIENT_PUBLIC_KEY=$(cat "$client_dir/public.key" 2>/dev/null)

            STATUS="OFFLINE"
            if [ -n "$CLIENT_PUBLIC_KEY" ]; then
                LAST_HANDSHAKE=$(awg show wg0 latest-handshakes 2>/dev/null | grep "$CLIENT_PUBLIC_KEY" | awk '{print $2}')
                CURRENT_TIME=$(date +%s)
                if [ -n "$LAST_HANDSHAKE" ] && [ "$LAST_HANDSHAKE" -gt 0 ] && [ $((CURRENT_TIME - LAST_HANDSHAKE)) -lt 180 ]; then
                    STATUS="ONLINE"
                fi
            fi

            VK_STATUS="нет"
            if [ -f "$client_dir/${CLIENT_NAME}-vk.conf" ]; then
                VK_STATUS="есть"
            fi

            printf "%-20s %-15s %-12s %-8s %-8s\n" "$CLIENT_NAME" "$CLIENT_IP" "$CLIENT_DATE" "$STATUS" "$VK_STATUS"
        fi
    done

    printf "\n"
    TOTAL=$(find "$CLIENTS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".deleted" 2>/dev/null | wc -l)
    printf "Всего клиентов: %s\n" "$TOTAL"
}

show_client() {
    CLIENT_NAME=$1

    if [ -z "$CLIENT_NAME" ]; then
        printf "Ошибка: укажите имя клиента\n"
        printf "Использование: awg-client show <имя_клиента>\n"
        exit 1
    fi

    if [ ! -d "$CLIENTS_DIR/$CLIENT_NAME" ]; then
        printf "Ошибка: клиент '%s' не найден\n" "$CLIENT_NAME"
        exit 1
    fi

    CLIENT_IP=$(cat "$CLIENTS_DIR/$CLIENT_NAME/ip.txt" 2>/dev/null)
    CLIENT_DATE=$(cat "$CLIENTS_DIR/$CLIENT_NAME/created.txt" 2>/dev/null)

    printf "========================================\n"
    printf "Клиент: %s\n" "$CLIENT_NAME"
    printf "========================================\n"
    printf "IP: %s | Создан: %s\n" "$CLIENT_IP" "$CLIENT_DATE"
    printf "\n--- Прямой конфиг ---\n"
    cat "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf"

    if [ -f "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}-vk.conf" ]; then
        printf "\n--- VK TURN конфиг ---\n"
        cat "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}-vk.conf"
        printf "\nКоманда Termux/iSH:\n"
        printf "  ./client -listen 127.0.0.1:9000 -peer %s:%s -vk-link ССЫЛКА -n 3\n" "$SERVER_IP" "$VK_TURN_PORT"
    else
        printf "\n[VK TURN конфиг отсутствует — создать: awg-client add-vk %s]\n" "$CLIENT_NAME"
    fi
}

show_qr() {
    CLIENT_NAME=$1

    if [ -z "$CLIENT_NAME" ]; then
        printf "Ошибка: укажите имя клиента\n"
        printf "Использование: awg-client qr <имя_клиента>\n"
        exit 1
    fi

    if [ ! -d "$CLIENTS_DIR/$CLIENT_NAME" ]; then
        printf "Ошибка: клиент '%s' не найден\n" "$CLIENT_NAME"
        exit 1
    fi

    if [ ! -f "$CLIENTS_DIR/$CLIENT_NAME/qr.txt" ]; then
        printf "QR-код не найден, генерирую...\n"
        qrencode -t ansiutf8 < "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}.conf" > "$CLIENTS_DIR/$CLIENT_NAME/qr.txt" 2>/dev/null
    fi

    printf "QR (прямой) для %s:\n" "$CLIENT_NAME"
    cat "$CLIENTS_DIR/$CLIENT_NAME/qr.txt"
}

show_qr_vk() {
    CLIENT_NAME=$1

    if [ -z "$CLIENT_NAME" ]; then
        printf "Ошибка: укажите имя клиента\n"
        printf "Использование: awg-client qr-vk <имя_клиента>\n"
        exit 1
    fi

    if [ ! -d "$CLIENTS_DIR/$CLIENT_NAME" ]; then
        printf "Ошибка: клиент '%s' не найден\n" "$CLIENT_NAME"
        exit 1
    fi

    if [ ! -f "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}-vk.conf" ]; then
        printf "VK TURN конфиг не найден. Создайте его: awg-client add-vk %s\n" "$CLIENT_NAME"
        exit 1
    fi

    if [ ! -f "$CLIENTS_DIR/$CLIENT_NAME/qr-vk.txt" ]; then
        printf "Генерирую QR...\n"
        qrencode -t ansiutf8 < "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}-vk.conf" > "$CLIENTS_DIR/$CLIENT_NAME/qr-vk.txt" 2>/dev/null
    fi

    printf "QR (VK TURN) для %s:\n" "$CLIENT_NAME"
    cat "$CLIENTS_DIR/$CLIENT_NAME/qr-vk.txt"
    printf "\nКоманда Termux/iSH:\n"
    printf "  ./client -listen 127.0.0.1:9000 -peer %s:%s -vk-link ССЫЛКА -n 3\n" "$SERVER_IP" "$VK_TURN_PORT"
}

show_vk() {
    CLIENT_NAME=$1

    if [ -z "$CLIENT_NAME" ]; then
        printf "Ошибка: укажите имя клиента\n"
        printf "Использование: awg-client show-vk <имя_клиента>\n"
        exit 1
    fi

    if [ ! -d "$CLIENTS_DIR/$CLIENT_NAME" ]; then
        printf "Ошибка: клиент '%s' не найден\n" "$CLIENT_NAME"
        exit 1
    fi

    if [ ! -f "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}-vk.conf" ]; then
        printf "VK TURN конфиг не найден. Создайте его: awg-client add-vk %s\n" "$CLIENT_NAME"
        exit 1
    fi

    printf "========================================\n"
    printf "VK TURN конфиг: %s\n" "$CLIENT_NAME"
    printf "========================================\n"
    cat "$CLIENTS_DIR/$CLIENT_NAME/${CLIENT_NAME}-vk.conf"
    printf "\nКоманда Termux/iSH:\n"
    printf "  ./client -listen 127.0.0.1:9000 -peer %s:%s -vk-link ССЫЛКА -n 3\n" "$SERVER_IP" "$VK_TURN_PORT"
}

# Основной парсер команд
case "$1" in
    add)
        add_client "$2"
        ;;
    add-vk)
        add_vk "$2"
        ;;
    remove)
        remove_client "$2"
        ;;
    list)
        list_clients
        ;;
    show)
        show_client "$2"
        ;;
    show-vk)
        show_vk "$2"
        ;;
    qr)
        show_qr "$2"
        ;;
    qr-vk)
        show_qr_vk "$2"
        ;;
    *)
        printf "Использование: awg-client <команда> [имя_клиента]\n\n"
        printf "Команды:\n"
        printf "  add <имя>       Создать клиента (генерирует прямой + VK TURN конфиги)\n"
        printf "  add-vk <имя>    Добавить VK TURN конфиг существующему клиенту\n"
        printf "  remove <имя>    Удалить клиента\n"
        printf "  list            Список всех клиентов (с колонкой VK TURN)\n"
        printf "  show <имя>      Показать оба конфига клиента\n"
        printf "  show-vk <имя>   Показать только VK TURN конфиг\n"
        printf "  qr <имя>        QR-код прямого конфига\n"
        printf "  qr-vk <имя>     QR-код VK TURN конфига\n"
        exit 1
        ;;
esac
