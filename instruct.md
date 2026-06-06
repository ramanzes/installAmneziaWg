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

