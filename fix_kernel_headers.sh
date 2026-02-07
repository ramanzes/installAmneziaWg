#!/bin/bash
set -e

echo "=== Исправление заголовков ядра ==="

# Текущее ядро
KERNEL_VERSION=$(uname -r)
echo "Текущее ядро: $KERNEL_VERSION"

# Проверяем наличие build директории
if [ -d "/lib/modules/$KERNEL_VERSION/build" ]; then
    echo "✓ Заголовки ядра уже настроены"
    exit 0
fi

echo "Заголовки ядра не настроены, исправляем..."

# Находим последние установленные заголовки
HEADERS_DIR=$(find /usr/src -maxdepth 1 -name "linux-headers-*" -type d | sort -Vr | head -1)

if [ -z "$HEADERS_DIR" ]; then
    echo "Устанавливаем заголовки ядра..."
    apt-get update
    apt-get install -y linux-headers-amd64
    HEADERS_DIR=$(find /usr/src -maxdepth 1 -name "linux-headers-*" -type d | sort -Vr | head -1)
fi

if [ -n "$HEADERS_DIR" ]; then
    echo "Найдены заголовки: $HEADERS_DIR"
    
    # Создаем директорию для модуля если нужно
    mkdir -p "/lib/modules/$KERNEL_VERSION"
    
    # Создаем симлинк
    ln -sf "$HEADERS_DIR" "/lib/modules/$KERNEL_VERSION/build"
    
    # Проверяем
    if [ -L "/lib/modules/$KERNEL_VERSION/build" ]; then
        echo "✓ Симлинк создан: /lib/modules/$KERNEL_VERSION/build -> $HEADERS_DIR"
        ls -la "/lib/modules/$KERNEL_VERSION/build"
    else
        echo "✗ Ошибка создания симлинка"
        exit 1
    fi
else
    echo "✗ Не удалось найти заголовки ядра"
    echo "Рекомендуется обновить ядро:"
    echo "  apt-get update && apt-get install -y linux-image-amd64 && reboot"
    exit 1
fi

echo "✓ Заголовки ядра настроены успешно"
