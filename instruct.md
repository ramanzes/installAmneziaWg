# Инструкция: обход белых списков через VK TURN + AmneziaWG

## Что это и зачем

Когда мобильные операторы включают режим белых списков (ТСПУ режет весь трафик кроме VK, Яндекс, Госуслуг),
обычный AmneziaWG перестаёт работать. Этот метод заворачивает трафик через TURN-серверы VK Звонков,
которые всегда в белом списке.

Схема:
```
Телефон → VK TURN-серверы (белый список) → этот сервер :56000 → AmneziaWG :36058 → интернет
```

## Состояние сервера

- **IP сервера:** ВАШ_IP_СЕРВЕРА
- **AWG порт:** 36058 (работает всегда)
- **vk-turn-proxy порт:** 56000 (слушает UDP, пересылает на AWG)
- **Бинарник:** /usr/local/bin/vk-turn-server
- **Автозапуск:** включён (rc-update default)
- **Клиентские конфиги:** /etc/amnezia/awg/clients/

---

## Управление сервером

### Статус
```bash
rc-service vk-turn-proxy status
rc-service amnezia-awg status
```

### Перезапуск
```bash
rc-service vk-turn-proxy restart
```

### Лог
```bash
cat /var/log/vk-turn-proxy.log
```

### Добавить нового клиента AWG
```bash
awg-client add ИМЯ
```

---

## Инструкция для клиентов — Android

### Шаг 1 — Установить Termux
Скачать с F-Droid (не из Google Play — там старая версия):
https://f-droid.org/packages/com.termux/

### Шаг 2 — Скачать клиент vk-turn-proxy в Termux
```bash
curl -L -o client https://github.com/cacggghp/vk-turn-proxy/releases/latest/download/client-android-arm64
chmod +x client
```
> Если телефон старый (32-bit): использовать `client-android-arm`

### Шаг 3 — Получить ссылку на VK Звонок
1. Открыть vk.com → Звонки → Создать звонок
2. Скопировать ссылку вида: `https://vk.com/call/join/...`

### Шаг 4 — Запустить клиент в Termux
```bash
termux-wake-lock
./client -listen 127.0.0.1:9000 -peer ВАШ_IP_СЕРВЕРА:56000 -vk-link ВСТАВИТЬ_ССЫЛКУ_VK -n 3
```
Если появилось сообщение о капче:
```
ACTION REQUIRED: MANUAL CAPTCHA SOLVING NEEDED
Open this URL in your browser: http://localhost:8765
```
— открыть браузер на том же телефоне и перейти на http://127.0.0.1:8765, решить капчу.
После решения клиент продолжит автоматически.

### Шаг 5 — Создать копию конфига в AmneziaVPN
В приложении AmneziaVPN:
1. Нажать на существующий конфиг → Редактировать
2. Создать копию (оригинал не трогать!)
3. В копии изменить:
   - `Endpoint` → `127.0.0.1:9000`
   - Добавить строку `MTU = 1280`
4. В настройках туннеля добавить **Termux в список исключений** (чтобы трафик Termux не шёл в VPN)

### Шаг 6 — Подключение
Порядок важен:
1. Сначала запустить клиент в Termux (шаг 4) и дождаться Connected
2. Потом включить VPN-конфиг из шага 5

Отключение в обратном порядке: сначала VPN, потом закрыть Termux.

---

## Инструкция для клиентов — iOS

### Шаг 1 — Установить iSH Shell
Скачать из App Store (бесплатно):
https://apps.apple.com/ru/app/ish-shell/id1436902243

### Шаг 2 — Скачать клиент в iSH
```bash
apk update && apk add curl
curl -L -o client https://github.com/cacggghp/vk-turn-proxy/releases/latest/download/client-linux-386
chmod +x client
```

### Шаг 3 — Получить ссылку на VK Звонок
Так же как Android: vk.com → Звонки → Создать звонок → скопировать ссылку.

### Шаг 4 — Запустить клиент в iSH
```bash
./client -listen 127.0.0.1:9000 -peer ВАШ_IP_СЕРВЕРА:56000 -vk-link ВСТАВИТЬ_ССЫЛКУ_VK -n 3
```
Капча — аналогично Android: открыть Safari и перейти на http://127.0.0.1:8765

### Шаг 5 — Создать копию конфига в AmneziaVPN
Изменить в копии:
- `Endpoint` → `127.0.0.1:9000`
- Добавить `MTU = 1280` в секцию [Interface]
- Заменить `AllowedIPs` (исключение диапазона VK `155.212.192.0/20`):

```
AllowedIPs = 0.0.0.0/1, 192.0.0.0/2, 160.0.0.0/3, 128.0.0.0/4, 144.0.0.0/5, 156.0.0.0/6, 152.0.0.0/7, 154.0.0.0/8, 155.0.0.0/9, 155.128.0.0/10, 155.224.0.0/11, 155.192.0.0/12, 155.216.0.0/13, 155.208.0.0/14, 155.214.0.0/15, 155.213.0.0/16, 155.212.0.0/17, 155.212.128.0/18, 155.212.224.0/19, 155.212.208.0/20, ::/0
```

Полный пример конфига для iOS (заполнить свои ключи):
```
[Interface]
PrivateKey = <приватный ключ клиента>
Address = 10.8.1.X/32
DNS = 1.1.1.1, 8.8.8.8
MTU = 1280
Jc = 5
Jmin = 10
Jmax = 50
S1 = 73
S2 = 32
H1 = 29823259
H2 = 2105934488
H3 = 1834425522
H4 = 20681889

[Peer]
PublicKey = <PUBLIC_KEY_СЕРВЕРА>
PresharedKey = <preshared ключ клиента>
Endpoint = 127.0.0.1:9000
AllowedIPs = 0.0.0.0/1, 192.0.0.0/2, 160.0.0.0/3, 128.0.0.0/4, 144.0.0.0/5, 156.0.0.0/6, 152.0.0.0/7, 154.0.0.0/8, 155.0.0.0/9, 155.128.0.0/10, 155.224.0.0/11, 155.192.0.0/12, 155.216.0.0/13, 155.208.0.0/14, 155.214.0.0/15, 155.213.0.0/16, 155.212.0.0/17, 155.212.128.0/18, 155.212.224.0/19, 155.212.208.0/20, ::/0
PersistentKeepalive = 25
```

### Шаг 6 — Подключение
1. Сначала запустить клиент в iSH (шаг 4)
2. Потом включить VPN в AmneziaVPN

---

## Частые проблемы

| Проблема | Решение |
|---|---|
| Капча при запуске клиента | Открыть браузер → http://127.0.0.1:8765 и решить |
| Клиент завис, нет Connected | Попробовать с флагом `-udp`: `./client ... -udp` |
| Медленно (~5 Мбит/с) | Уже включён флаг `-n 3` (3 потока, до ~15 Мбит/с). Для большей скорости: `-n 5` |
| VPN отключается | Убедиться что Termux/iSH не убивается системой (termux-wake-lock) |
| iOS: трафик VK не работает | Проверить AllowedIPs — должен быть исключён 155.212.192.0/20 |

---

## Список клиентов

| Имя | IP | Создан |
|---|---|---|
| client01 | 10.8.1.2 | скрыто |
| client02 | 10.8.1.3 | скрыто |
| client03 | 10.8.1.4 | скрыто |
| client04 | 10.8.1.5 | скрыто |
| client05 | 10.8.1.6 | скрыто |
| client06 | 10.8.1.7 | скрыто |
| client07 | 10.8.1.8 | скрыто |
| client08 | 10.8.1.9 | скрыто |
| client09 | 10.8.1.10 | скрыто |
| client10 | 10.8.1.11 | скрыто |
| client11 | 10.8.1.12 | скрыто |
| client12 | 10.8.1.13 | скрыто |
| client13 | 10.8.1.14 | скрыто |
| client14 | 10.8.1.15 | скрыто |
| client15 | 10.8.1.16 | скрыто |

---

## Инструкция для клиентов — Linux (Debian/Ubuntu)

### Шаг 1 — Установить AmneziaWG

**Debian:**
```bash
sudo apt install -y software-properties-common python3-launchpadlib gnupg2 linux-headers-$(uname -r)
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 57290828
echo "deb https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | sudo tee -a /etc/apt/sources.list
echo "deb-src https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get install -y amneziawg resolvconf
```

**Ubuntu:**
```bash
sudo apt install -y software-properties-common linux-headers-$(uname -r)
sudo add-apt-repository ppa:amnezia/ppa
sudo apt-get install -y amneziawg resolvconf
```

### Шаг 2 — Скачать клиент vk-turn-proxy

```bash
curl -L -o ~/vk-turn-client https://github.com/cacggghp/vk-turn-proxy/releases/latest/download/client-linux-amd64
chmod +x ~/vk-turn-client
```

> Для ARM (Raspberry Pi и т.п.): использовать `client-linux-arm64`

### Шаг 3 — Создать конфиги

Создай директорию для конфигов:
```bash
sudo mkdir -p /etc/amnezia/awg
```

**Конфиг 1: прямое подключение** `/etc/amnezia/awg/direct.conf`
```
[Interface]
PrivateKey = <приватный ключ клиента>
Address = 10.8.1.X/32
DNS = 1.1.1.1, 8.8.8.8
Jc = 5
Jmin = 10
Jmax = 50
S1 = 73
S2 = 32
H1 = 29823259
H2 = 2105934488
H3 = 1834425522
H4 = 20681889

[Peer]
PublicKey = <PUBLIC_KEY_СЕРВЕРА>
PresharedKey = <preshared ключ клиента>
Endpoint = ВАШ_IP_СЕРВЕРА:36058
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

**Конфиг 2: через VK TURN** `/etc/amnezia/awg/vk.conf`
```
[Interface]
PrivateKey = <приватный ключ клиента>
Address = 10.8.1.X/32
DNS = 1.1.1.1, 8.8.8.8
MTU = 1280
Jc = 5
Jmin = 10
Jmax = 50
S1 = 73
S2 = 32
H1 = 29823259
H2 = 2105934488
H3 = 1834425522
H4 = 20681889

[Peer]
PublicKey = <PUBLIC_KEY_СЕРВЕРА>
PresharedKey = <preshared ключ клиента>
Endpoint = 127.0.0.1:9000
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

> Ключи (`PrivateKey`, `PresharedKey`, `Address`) берёшь из своего конфига который выдал `awg-client show <имя>` на сервере.

### Шаг 4 — Подключение напрямую (без белых списков)

```bash
sudo awg-quick up /etc/amnezia/awg/direct.conf
```

Проверить что работает:
```bash
curl ifconfig.me   # должен показать IP сервера ВАШ_IP_СЕРВЕРА
```

Отключить:
```bash
sudo awg-quick down /etc/amnezia/awg/direct.conf
```

### Шаг 5 — Подключение через VK TURN (белые списки)

**Получить ссылку на VK Звонок:**
1. Открыть vk.com → Звонки → Создать звонок
2. Скопировать ссылку вида: `https://vk.com/call/join/...`

**Запустить vk-turn-proxy клиент** (в отдельном терминале или через screen/tmux):
```bash
~/vk-turn-client -listen 127.0.0.1:9000 -peer ВАШ_IP_СЕРВЕРА:56000 -vk-link ВСТАВИТЬ_ССЫЛКУ_VK -n 3
```

Дождаться строк:
```
[STREAM 1] Established DTLS connection!
[STREAM 2] Established DTLS connection!
[STREAM 3] Established DTLS connection!
```

**Поднять VPN** (в основном терминале):
```bash
sudo awg-quick up /etc/amnezia/awg/vk.conf
```

Проверить:
```bash
curl ifconfig.me   # должен показать IP сервера ВАШ_IP_СЕРВЕРА
```

**Отключить** (в обратном порядке):
```bash
sudo awg-quick down /etc/amnezia/awg/vk.conf
# потом Ctrl+C в терминале с vk-turn-client
```

### Шаг 6 — Автоматизация через systemd (опционально)

Создать сервис для vk-turn-proxy:
```bash
sudo tee /etc/systemd/system/vk-turn-client.service << 'EOF'
[Unit]
Description=VK TURN Proxy Client
After=network.target

[Service]
ExecStart=/root/vk-turn-client -listen 127.0.0.1:9000 -peer ВАШ_IP_СЕРВЕРА:56000 -vk-link ВСТАВИТЬ_ССЫЛКУ_СЮДА -n 3
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

> Ссылку VK нужно вписать прямо в файл сервиса. Ссылка протухает — при следующем подключении создай новую и обнови файл.

Создать сервис для AWG через VK:
```bash
sudo tee /etc/systemd/system/awg-vk.service << 'EOF'
[Unit]
Description=AmneziaWG via VK TURN
After=vk-turn-client.service
Requires=vk-turn-client.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/awg-quick up /etc/amnezia/awg/vk.conf
ExecStop=/usr/bin/awg-quick down /etc/amnezia/awg/vk.conf

[Install]
WantedBy=multi-user.target
EOF
```

Запустить:
```bash
sudo systemctl daemon-reload
sudo systemctl start vk-turn-client
sudo systemctl start awg-vk
```

Включить автозапуск:
```bash
sudo systemctl enable vk-turn-client awg-vk
```

Статус:
```bash
sudo systemctl status vk-turn-client
sudo systemctl status awg-vk
```

### Получить свои ключи с сервера

Подключиться по SSH и выполнить:
```bash
ssh -p ВАШ_SSH_ПОРТ root@ВАШ_IP_СЕРВЕРА "awg-client show ИМЯ_КЛИЕНТА"
```

Или скопировать готовый конфиг:
```bash
scp -P ВАШ_SSH_ПОРТ root@ВАШ_IP_СЕРВЕРА:/etc/amnezia/awg/clients/ИМЯ/ИМЯ.conf ~/direct.conf
```


---

# WDTT VPN — Полная инструкция

## Что такое WDTT

**WDTT** (WireGuard DTLS TURN Tunnel) — Android-приложение для обхода белых списков.
Трафик идёт через TURN-серверы ВКонтакте, которые всегда в белом списке ТСПУ.

**Отличие от vk-turn-proxy + Termux:**
- Не нужен Termux в фоне
- Автоматическая капча (3 уровня fallback)
- До 4 VK хешей одновременно → больше скорость
- Встроенный VPN-интерфейс, всё в одном приложении

**Схема:**
```
Android WDTT → VK TURN серверы (белый список) → wdtt-server на VPS → интернет
```

---

## Часть 1 — Установка сервера (Alpine Linux)

### Состояние на этом сервере

- **IP:** ВАШ_IP_СЕРВЕРА
- **DTLS порт:** 56000/UDP (wdtt-server)
- **WG порт:** 56001/UDP (внутренний WireGuard wdtt-server)
- **VK-turn-proxy:** 56100/UDP (старый метод через Termux)
- **AWG:** 36058/UDP (AmneziaWG, прямые подключения)
- **Мастер-пароль:** ВАШ_МАСТЕР_ПАРОЛЬ
- **Конфиг:** /etc/wdtt/
- **Лог:** /var/log/wdtt-server.log
- **Подсеть клиентов:** 10.66.66.0/24

### Управление сервисом

```bash
rc-service wdtt-server status     # статус
rc-service wdtt-server restart    # перезапуск
rc-service wdtt-server stop       # остановить
tail -f /var/log/wdtt-server.log  # живые логи
```

### Как был установлен (для новых серверов)

wdtt-server извлечён из APK приложения (бинарник встроен внутрь):

```bash
# 1. Скачать APK
curl -LA 'Mozilla/5.0' -o /tmp/wdtt.apk \
  'https://github.com/amurcanov/proxy-turn-vk-android/releases/download/v1.2.2/WDTT-x86_64.apk'

# 2. Распаковать APK (это ZIP-архив)
mkdir -p /tmp/wdtt_apk && cd /tmp/wdtt_apk
unzip -q /tmp/wdtt.apk

# 3. Установить бинарник
cp /tmp/wdtt_apk/assets/server /usr/local/bin/wdtt-server
chmod +x /usr/local/bin/wdtt-server

# 4. Создать директорию конфига
mkdir -p /etc/wdtt

# 5. Настроить iptables (NAT для подсети wdtt)
iptables -I FORWARD -i wdtt0 -j ACCEPT
iptables -I FORWARD -o wdtt0 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.66.66.0/24 -o eth0 -j MASQUERADE

# 6. Создать OpenRC сервис
cat > /etc/init.d/wdtt-server << 'INIT'
#!/sbin/openrc-run
name="wdtt-server"
description="WDTT VPN Server"
command="/usr/local/bin/wdtt-server"
command_args="-listen 0.0.0.0:56000 -wg-port 56001 -config-dir /etc/wdtt -password ВАШ_ПАРОЛЬ -dns 1.1.1.1,8.8.8.8"
command_background=true
pidfile="/run/wdtt-server.pid"
output_log="/var/log/wdtt-server.log"
error_log="/var/log/wdtt-server.log"
depend() {
    need net
}
start_pre() {
    ip link show wdtt0 >/dev/null 2>&1 && ip link del wdtt0 2>/dev/null || true
}
INIT

chmod +x /etc/init.d/wdtt-server
rc-update add wdtt-server default
rc-service wdtt-server start
```

**Флаги wdtt-server:**
```
-listen       адрес DTLS (default 0.0.0.0:56000)
-wg-port      порт внутреннего WireGuard (default 56001)
-config-dir   директория конфига (default /etc/wdtt)
-password     мастер-пароль владельца
-dns          DNS-серверы (default 1.1.1.1,8.8.8.8)
-bot-token    Telegram Bot Token (опционально)
-admin        Telegram Admin ID (опционально)
```

### Проверка что сервер работает

```bash
tail -5 /var/log/wdtt-server.log
# Должно быть: [SERVER] Готов
# И каждые 10 сек: [СТАТ] Активных: X | ...

ss -ulnp | grep -E '56000|56001'
# Должны быть открыты оба порта
```

---

## Часть 2 — Установка клиента на Android

### Шаг 1 — Установить F-Droid
Скачать с официального сайта: https://f-droid.org/

### Шаг 2 — Установить GitHub Store в F-Droid
1. Открыть F-Droid
2. Настройки → Репозитории → добавить репозиторий:
   `https://raw.githubusercontent.com/ImranR98/Obtainium/refs/heads/main/output/app_unverified.json`
   **или** найти в поиске F-Droid: **Obtainium** (это и есть GitHub Store)

### Шаг 3 — Найти WDTT в Obtainium
1. Открыть Obtainium
2. Нажать **+** → добавить приложение
3. Вставить URL: `https://github.com/amurcanov/proxy-turn-vk-android`
4. Установить → выбрать APK под свою архитектуру:
   - Большинство современных телефонов: **WDTT-arm64-v8a.apk**
   - Старые/бюджетные: WDTT-armeabi-v7a.apk
   - Эмуляторы/x86: WDTT-x86_64.apk

---

## Часть 3 — Подключение через WDTT

### Получить VK хеш

1. Открыть ВКонтакте (приложение или браузер)
2. Перейти в **Звонки** → нажать **Создать звонок** (групповой)
3. Скопировать ссылку приглашения:
   `https://vk.com/call/join/AbCdEfGhIjK`
4. Хеш — это всё что после `/join/`: **AbCdEfGhIjK**

**Важно:** хеш действует пока звонок активен. При завершении звонка — создать новый.
При выходе нажимать **"Просто завершить"**, не **"Завершить для всех"**.

### Вкладка "Туннель" — подключение

| Поле | Значение |
|---|---|
| Сервер | ВАШ_IP_СЕРВЕРА |
| VK хеш | вставить хеш из ссылки |
| Пароль | ВАШ_МАСТЕР_ПАРОЛЬ |
| Потоки | 3–4 |

Нажать **Подключить** → выдать разрешение VPN.

### Автокапча

Если при подключении появляется запрос капчи:
- Приложение автоматически пытается решить 3 раза
- Если не вышло — откроется WebView для ручного решения
- Решить капчу в браузере внутри приложения → подключение продолжится

### Исключения приложений (Split Tunneling)

Вкладка **Исключения** в WDTT:
- **Чёрный список:** выбранные приложения идут мимо VPN
- **Белый список:** только выбранные приложения через VPN

---

## Часть 4 — Диагностика

### Логи на сервере в реальном времени
```bash
tail -f /var/log/wdtt-server.log
```

**Успешное подключение выглядит так:**
```
[AUTH] Клиент аутентифицирован
[WG] Новый пир: 10.66.66.X
[СТАТ] Активных: 1 | ...
```

### Частые проблемы

| Проблема | Причина | Решение |
|---|---|---|
| Кнопка сразу становится "Подключить" | VK хеш истёк или невалиден | Создать новый звонок VK |
| Кнопка сразу становится "Подключить" | Неверный пароль | Проверить пароль: ВАШ_МАСТЕР_ПАРОЛЬ |
| Капча не решается автоматически | VK усложнил капчу | Решить вручную в WebView |
| Подключился, но сайты не открываются | DNS не работает | Проверить -dns флаг в сервисе |
| Сервер не отвечает | wdtt-server упал | rc-service wdtt-server restart |

### Что означает "Кнопка становится Подключить"

Соединение не дошло до сервера — проверить:
1. VK хеш свежий? (создать новый звонок)
2. Звонок ещё активен? (не завершён)
3. Сервер работает? (`tail -5 /var/log/wdtt-server.log`)
4. Порт 56000 доступен? (`ss -ulnp | grep 56000`)

---

## Часть 5 — Сравнение методов обхода белых списков

| Метод | Приложение | Сложность | Скорость |
|---|---|---|---|
| AWG прямой | AmneziaVPN | Простой | Максимальная |
| AWG + vk-turn-proxy | AmneziaVPN + Termux | Средний | ~15 Мбит/с |
| **WDTT** | **WDTT** | **Простой** | **~20+ Мбит/с** |

**Когда что использовать:**
- Нет блокировок → **AWG прямой** (порт 36058)
- Белые списки, есть Termux → **AWG + vk-turn-proxy** (порт 56100)
- Белые списки, хочу проще → **WDTT** (порт 56000)


---

## Часть 6 — Мастер-пароль и управление доступом

### Текущий мастер-пароль

```
ВАШ_МАСТЕР_ПАРОЛЬ
```

Хранится на сервере: `/etc/wdtt/master.key`

```bash
cat /etc/wdtt/master.key   # посмотреть текущий пароль
```

### Где используется

Мастер-пароль вводится в поле **Пароль** в приложении WDTT (вкладка Туннель).
Это пароль владельца — он всегда работает.

### Как сменить пароль

```bash
# 1. Сгенерировать новый пароль
NEW_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
echo $NEW_PASS

# 2. Сохранить в файл
echo $NEW_PASS > /etc/wdtt/master.key

# 3. Обновить в init-скрипте
sed -i s/-password [^ ]*/-password $NEW_PASS/ /etc/init.d/wdtt-server

# 4. Перезапустить сервис
rc-service wdtt-server restart
```

После смены — обновить пароль у всех кто им пользуется.

### Дополнительные пароли для пользователей (Telegram бот)

wdtt-server поддерживает управление доступом через Telegram бот:
- До 10 пользовательских паролей (16 символов)
- Можно установить срок действия
- Привязка к устройству

Чтобы подключить Telegram бота — добавить флаги в init-скрипт:
```bash
-bot-token ВАШ_TELEGRAM_BOT_TOKEN -admin ВАШ_TELEGRAM_ID
```

Команды бота: `/list`, `/add`, `/remove`, `/settings`

---

## Часть 7 — WDTT и AmneziaWG: независимые системы

**Важно:** WDTT и AmneziaWG — полностью раздельные VPN.
Никаких общих конфигов, никаких конфликтов.

| | WDTT | AmneziaWG |
|---|---|---|
| Интерфейс | wdtt0 | wg0 |
| Подсеть | 10.66.66.0/24 | 10.8.1.0/24 |
| Порт | 56000/UDP | 36058/UDP |
| Приложение | WDTT | AmneziaVPN |
| Конфиги | не нужны | /etc/amnezia/awg/clients/ |

### Для подключения через WDTT

**Не нужно** создавать никакие конфиги AWG. Просто:
1. Открыть приложение **WDTT**
2. Вкладка **Туннель**
3. Ввести: сервер + VK хеш + пароль
4. Нажать **Подключить**

Старые конфиги AmneziaVPN остаются для прямого AWG подключения — они работают независимо.

### Какой метод когда использовать

| Ситуация | Метод | Приложение |
|---|---|---|
| Нет блокировок | AWG прямой | AmneziaVPN |
| Белые списки, есть Termux | AWG + vk-turn-proxy | AmneziaVPN + Termux |
| Белые списки, хочу проще | **WDTT** | **WDTT** |


---

## Часть 8 — Установка wdtt-server на чистый VPS (Ubuntu/Debian) через Deploy tab

Это **самый простой способ** для обычных пользователей — приложение само разворачивает сервер по SSH.

### Поддерживаемые ОС

- Ubuntu 20.04, 22.04, 24.04
- Debian 11, 12
- CentOS/RHEL/AlmaLinux/Rocky
- Fedora
- Arch/Manjaro

> Alpine Linux — только ручной метод (см. Часть 1)

### Требования к VPS

- Чистый VPS с публичным IPv4
- Root-доступ по SSH (порт 22 по умолчанию)
- Открытые порты: **56000/UDP** (DTLS) и **56001/UDP** (WireGuard)
- RAM: от 512 МБ, диск: от 5 ГБ

### Шаг 1 — Установить WDTT на телефон

**Через Obtainium (GitHub Store):**
1. Установить F-Droid: https://f-droid.org/
2. В F-Droid найти и установить **Obtainium**
3. В Obtainium: нажать **+** → вставить URL:
   ```
   https://github.com/amurcanov/proxy-turn-vk-android
   ```
4. Выбрать APK под архитектуру телефона:
   - Современные Android-телефоны → **WDTT-arm64-v8a.apk**
   - Старые/бюджетные → WDTT-armeabi-v7a.apk

### Шаг 2 — Открыть вкладку Deploy

В приложении WDTT открыть вкладку **Деплой (Deploy)**.

### Шаг 3 — Ввести данные сервера

| Поле | Что вводить |
|---|---|
| IP / домен | IP-адрес вашего VPS |
| SSH логин | root (или другой с sudo) |
| SSH пароль | пароль от сервера |
| SSH порт | 22 (обычно) |

### Шаг 4 — Установить мастер-пароль

В разделе **Секреты** / **Пароль**:
- Придумать или сгенерировать мастер-пароль (от 8 символов)
- Запомнить — он понадобится при каждом подключении

### Шаг 5 — Запустить установку

Нажать **Установить**. Приложение автоматически:
1. Подключится к серверу по SSH
2. Загрузит бинарник `wdtt-server`
3. Настроит NAT и firewall (iptables)
4. Создаст и запустит systemd-сервис `wdtt.service`
5. Покажет прогресс и результат

Установка занимает **1–3 минуты**.

### Шаг 6 — Проверить установку

На сервере:
```bash
systemctl status wdtt
# Должно быть: active (running)

journalctl -u wdtt -n 10
# Должно быть: [SERVER] Готов
```

### Шаг 7 — Подключиться

Перейти на вкладку **Туннель** и подключиться (см. Часть 3).

---

## Часть 9 — Установка wdtt-server на Alpine Linux (ручной метод)

Используется когда VPS работает на Alpine — Deploy tab не поддерживает Alpine.

### Почему ручной метод?

- Alpine использует **OpenRC** (не systemd) — Deploy tab не умеет
- Бинарник встроен в APK — нужно извлечь вручную
- Всё остальное аналогично Ubuntu-варианту

### Полные шаги

```bash
# 1. Скачать APK и извлечь бинарник
curl -LA 'Mozilla/5.0' -o /tmp/wdtt.apk \
  'https://github.com/amurcanov/proxy-turn-vk-android/releases/download/v1.2.2/WDTT-x86_64.apk'
mkdir -p /tmp/wdtt_apk && cd /tmp/wdtt_apk
unzip -q /tmp/wdtt.apk
cp /tmp/wdtt_apk/assets/server /usr/local/bin/wdtt-server
chmod +x /usr/local/bin/wdtt-server

# 2. Создать директорию конфига и сгенерировать пароль
mkdir -p /etc/wdtt
PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
echo $PASS > /etc/wdtt/master.key && echo "Пароль: $PASS"

# 3. Настроить NAT
iptables -I FORWARD -i wdtt0 -j ACCEPT
iptables -I FORWARD -o wdtt0 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.66.66.0/24 -o eth0 -j MASQUERADE

# 4. Создать OpenRC сервис
PASS=$(cat /etc/wdtt/master.key)
cat > /etc/init.d/wdtt-server << INIT
#!/sbin/openrc-run
name="wdtt-server"
description="WDTT VPN Server"
command="/usr/local/bin/wdtt-server"
command_args="-listen 0.0.0.0:56000 -wg-port 56001 -config-dir /etc/wdtt -password $PASS -dns 1.1.1.1,8.8.8.8"
command_background=true
pidfile="/run/wdtt-server.pid"
output_log="/var/log/wdtt-server.log"
error_log="/var/log/wdtt-server.log"
depend() { need net; }
start_pre() {
    ip link show wdtt0 >/dev/null 2>&1 && ip link del wdtt0 2>/dev/null || true
}
INIT
chmod +x /etc/init.d/wdtt-server

# 5. Запустить и добавить в автозапуск
rc-update add wdtt-server default
rc-service wdtt-server start

# 6. Проверить
sleep 2 && tail -5 /var/log/wdtt-server.log
# Должно быть: [SERVER] Готов
```

### Обновление до новой версии (Alpine)

```bash
# Скачать новый APK, извлечь бинарник
curl -LA 'Mozilla/5.0' -o /tmp/wdtt_new.apk \
  'https://github.com/amurcanov/proxy-turn-vk-android/releases/latest/download/WDTT-x86_64.apk'
mkdir -p /tmp/wdtt_new && cd /tmp/wdtt_new
unzip -q /tmp/wdtt_new.apk

rc-service wdtt-server stop
cp /tmp/wdtt_new/assets/server /usr/local/bin/wdtt-server
chmod +x /usr/local/bin/wdtt-server
rc-service wdtt-server start
```

### Где хранится конфигурация

| Файл | Содержимое |
|---|---|
| `/etc/wdtt/master.key` | Мастер-пароль |
| `/etc/wdtt/wg-keys.dat` | WireGuard ключи сервера |
| `/etc/wdtt/passwords.json` | База пользовательских паролей |
| `/var/log/wdtt-server.log` | Лог сервера |
| `/etc/init.d/wdtt-server` | OpenRC сервис |


---

# Установка клиента PWDTT v1.2 на десктоп (Linux)

PWDTT — десктопный VPN-клиент, маскирующий трафик под звонки ВКонтакте через TURN/DTLS серверы VK.  
Репозиторий: https://github.com/luminescq/PWDTT  
Бинарник: https://github.com/luminescq/PWDTT/releases/download/v1.2/pwdtt-linux-amd64

---

## Вариант A — Debian 12 (Bookworm)

### Шаг 1 — Стандартные зависимости

```bash
sudo apt install -y wireguard-tools libayatana-appindicator3-1
```

### Шаг 2 — Скачать и обновить webkit2gtk до версии 2.50.x

На Bookworm по умолчанию стоит более старая версия webkit2gtk-4.0.  
Обновляем до актуальной (2.50.x), совместимой с бинарником:

```bash
curl -LO https://github.com/luminescq/PWDTT/releases/download/v1.2/pwdtt-linux-amd64

curl -L -o libjavascriptcoregtk.deb \
  "http://ftp.debian.org/debian/pool/main/w/webkit2gtk/libjavascriptcoregtk-4.0-18_2.50.6-1~deb12u1_amd64.deb"

curl -L -o libwebkit2gtk.deb \
  "http://ftp.debian.org/debian/pool/main/w/webkit2gtk/libwebkit2gtk-4.0-37_2.50.6-1~deb12u1_amd64.deb"

curl -L -o libavif15.deb \
  "http://ftp.debian.org/debian/pool/main/liba/libavif/libavif15_0.11.1-1+deb12u1_amd64.deb"

sudo dpkg --force-depends -i libjavascriptcoregtk.deb libavif15.deb libwebkit2gtk.deb
sudo ldconfig
```

> На Bookworm `libicu72`, `libdav1d6`, `librav1e0`, `libsvtav1enc1` уже есть нативно.
> Симлинки НЕ нужны. Не запускать команды `ln -sf` из инструкции для Trixie.

### Шаг 3 — Проверка зависимостей

```bash
ldd pwdtt-linux-amd64 | grep "not found"
# Должен быть пустой вывод
```

### Шаг 4 — Установка бинарника

```bash
chmod +x pwdtt-linux-amd64
sudo cp pwdtt-linux-amd64 /usr/local/bin/pwdtt
```

### Шаг 5 — Настройка sudo

```bash
echo 'USERNAME ALL=(ALL) NOPASSWD: /usr/bin/ip, /usr/bin/wg, /usr/bin/wg-quick, /usr/bin/true' | \
  sudo tee /etc/sudoers.d/pwdtt && sudo chmod 440 /etc/sudoers.d/pwdtt
```

> `/usr/bin/true` обязателен — PWDTT вызывает `sudo true` как предварительную проверку
> доступности sudo перед применением WireGuard конфига.

Проверка:
```bash
sudo -n /usr/bin/true && echo "OK"
sudo -n /usr/bin/wg-quick --version
sudo -n /usr/bin/wg --version
```

### Шаг 6 — Запуск

```bash
# GOMAXPROCS=1 обязателен — без него Go падает с "procresize: invalid arg"
# (cgroup на хосте возвращает 0 доступных CPU)
GOMAXPROCS=1 pwdtt
```

Чтобы не писать каждый раз:
```bash
echo 'export GOMAXPROCS=1' >> ~/.bashrc
source ~/.bashrc
pwdtt
```

---

## Вариант B — Debian 13 (Trixie)

### Шаг 1 — Стандартные зависимости

```bash
sudo apt install -y wireguard-tools libayatana-appindicator3-1
```

### Шаг 2 — WebKit2GTK 4.0 и ICU 72 из Bookworm

Trixie перешёл на webkit2gtk-4.1 и libicu76. Нужно вручную поставить Bookworm-пакеты:

```bash
curl -LO https://github.com/luminescq/PWDTT/releases/download/v1.2/pwdtt-linux-amd64

curl -L -o libicu72.deb \
  "http://ftp.debian.org/debian/pool/main/i/icu/libicu72_72.1-3+deb12u1_amd64.deb"

curl -L -o libjavascriptcoregtk.deb \
  "http://ftp.debian.org/debian/pool/main/w/webkit2gtk/libjavascriptcoregtk-4.0-18_2.50.6-1~deb12u1_amd64.deb"

curl -L -o libwebkit2gtk.deb \
  "http://ftp.debian.org/debian/pool/main/w/webkit2gtk/libwebkit2gtk-4.0-37_2.50.6-1~deb12u1_amd64.deb"

curl -L -o libavif15.deb \
  "http://ftp.debian.org/debian/pool/main/liba/libavif/libavif15_0.11.1-1+deb12u1_amd64.deb"

# libicu72 ставится чисто
sudo dpkg -i libicu72.deb

# Остальные через --force-depends (dpkg жалуется на версии, но .so-файлы найдутся через симлинки)
sudo dpkg --force-depends -i libjavascriptcoregtk.deb libavif15.deb libwebkit2gtk.deb
```

### Шаг 3 — Симлинки совместимости

```bash
# libavif: Trixie имеет libavif16, нужен libavif15
sudo ln -sf /usr/lib/x86_64-linux-gnu/libavif.so.16 \
            /usr/lib/x86_64-linux-gnu/libavif.so.15

# dav1d: Trixie имеет .so.7, нужен .so.6
sudo ln -sf /usr/lib/x86_64-linux-gnu/libdav1d.so.7 \
            /usr/lib/x86_64-linux-gnu/libdav1d.so.6

# rav1e: Trixie имеет librav1e0.7, нужен librav1e.so.0
sudo ln -sf /usr/lib/x86_64-linux-gnu/librav1e.so.0.7 \
            /usr/lib/x86_64-linux-gnu/librav1e.so.0

# SvtAv1Enc: Trixie имеет .so.2, нужен .so.1
sudo ln -sf /usr/lib/x86_64-linux-gnu/libSvtAv1Enc.so.2 \
            /usr/lib/x86_64-linux-gnu/libSvtAv1Enc.so.1
```

### Шаг 4 — Проверка зависимостей

```bash
ldd pwdtt-linux-amd64 | grep "not found"
# Должен быть пустой вывод
```

### Шаг 5 — Установка бинарника

```bash
chmod +x pwdtt-linux-amd64
sudo cp pwdtt-linux-amd64 /usr/local/bin/pwdtt
```

### Шаг 6 — Настройка sudo

```bash
echo 'USERNAME ALL=(ALL) NOPASSWD: /usr/bin/ip, /usr/bin/wg, /usr/bin/wg-quick, /usr/bin/true' | \
  sudo tee /etc/sudoers.d/pwdtt && sudo chmod 440 /etc/sudoers.d/pwdtt
```

> `/usr/bin/true` обязателен — PWDTT вызывает `sudo true` как предварительную проверку
> доступности sudo перед применением WireGuard конфига.

### Шаг 7 — Запуск

```bash
# При наличии графического окружения:
pwdtt

# Без GUI — через виртуальный буфер:
sudo apt install -y xvfb
Xvfb :99 -screen 0 1280x800x24 &
DISPLAY=:99 pwdtt
```

---

## Отключение IPv6 (получение IPv4 через туннель)

WireGuard маршрутизирует только IPv4 трафик. IPv6 идёт мимо туннеля напрямую через
мобильный интерфейс — поэтому `curl ifconfig.co` может возвращать IPv6 адрес провайдера.

### Применить сейчас

```bash
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
```

### Сделать постоянным (MX Linux / SysVinit — без systemd)

```bash
echo "net.ipv6.conf.all.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf
```

`net.ipv6.conf.default` применяется ко всем новым интерфейсам при создании,
включая `wg-turn` который PWDTT создаёт при подключении.

### Проверка

```bash
curl ifconfig.co
# Должен вернуть IPv4
```

---

## Известные проблемы PWDTT

| Симптом | Причина | Решение |
|---|---|---|
| `procresize: invalid arg` | cgroup возвращает 0 CPU (Bookworm хост или Trixie VM) | `GOMAXPROCS=1 pwdtt` |
| `libavif.so.15: cannot open shared object file` | Сломанный симлинк (применили Trixie-инструкцию на Bookworm) | `sudo rm /usr/lib/x86_64-linux-gnu/libavif.so.15 && sudo ldconfig` |
| `sudo требует пароль` в GUI | Не включён `/usr/bin/true` в sudoers | Добавить `true` в правило sudoers |
| `Join link is not valid` (error 9008) | VK join link просрочен или недействителен | Создать новую ссылку в VK, вставить хеш в настройки |
| Капча не проходит ни авто ни вручную | IP rate limit от VK после многих неудачных попыток | Остановить pwdtt, подождать 20–30 мин, повторить |
| `curl ifconfig.co` возвращает IPv6 | WireGuard туннелирует только IPv4, IPv6 идёт мимо | Отключить IPv6 через sysctl (раздел выше) |
