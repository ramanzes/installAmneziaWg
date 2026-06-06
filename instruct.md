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

