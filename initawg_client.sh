#!/bin/ash
# Установка awg-client с поддержкой VK TURN
# Запускать из директории репозитория: ./script/initawg_client.sh
# или из install_amneziawg.sh (шаг 10)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/awg-client.sh"
TARGET="/usr/local/bin/awg-client"

if [ ! -f "$SOURCE" ]; then
    printf "Ошибка: файл %s не найден\n" "$SOURCE"
    printf "Убедитесь что запускаете скрипт из директории репозитория\n"
    exit 1
fi

printf "Установка awg-client...\n"
cp "$SOURCE" "$TARGET"
chmod +x "$TARGET"

printf "awg-client установлен: %s\n" "$TARGET"
printf "\nДоступные команды:\n"
printf "  awg-client add <имя>       — создать клиента (прямой + VK TURN)\n"
printf "  awg-client add-vk <имя>    — добавить VK TURN конфиг\n"
printf "  awg-client list            — список клиентов\n"
printf "  awg-client show <имя>      — показать оба конфига\n"
printf "  awg-client show-vk <имя>   — показать VK TURN конфиг\n"
printf "  awg-client qr <имя>        — QR прямого конфига\n"
printf "  awg-client qr-vk <имя>     — QR VK TURN конфига\n"
printf "  awg-client remove <имя>    — удалить клиента\n"
