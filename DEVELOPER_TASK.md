# 🚀 Задание для разработчика CloudBridge Client

## 📋 Обзор задачи

Необходимо доработать CloudBridge Client для работы с реальными JWT токенами от Keycloak и обеспечить возможность работы в качестве Windows службы.

## 🎯 Основные задачи

### 1. 🔐 Настройка JWT аутентификации

#### 1.1 Получить fallback секрет от DevOps
- **Проблема**: Токены от Keycloak содержат `kid: "fallback-key"`, но fallback секрет неизвестен
- **Действие**: Связаться с DevOps и получить fallback секрет для валидации токенов
- **Формат**: Секрет должен быть в виде строки для HMAC-SHA256

#### 1.2 Обновить конфигурацию
```yaml
auth:
  type: "jwt"
  secret: "YOUR_JWT_SECRET"           # Основной секрет
  fallback_secret: "YOUR_FALLBACK_SECRET"  # Fallback секрет для kid: "fallback-key"
```

#### 1.3 Протестировать валидацию токена
- Использовать реальный токен: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImZhbGxiYWNrLWtleSJ9.eyJwcm90b2NvbF90eXBlIjoicDJwLW1lc2giLCJzY29wZSI6InAycC1tZXNoLWNsYWltcyIsIm9yZ19pZCI6ImIyZGJiMjkyLWQ4MzMtNGRlMi05MjFhLTJlMTJhZWFjZjg4MCIsInRlbmFudF9pZCI6ImIyZGJiMjkyLWQ4MzMtNGRlMi05MjFhLTJlMTJhZWFjZjg4MCIsInNlcnZlcl9pZCI6InNlcnZlci0xNzU3NzY5MjYwODI0IiwibWF4X3BlZXJzIjoiMTAiLCJwZXJtaXNzaW9ucyI6WyJtZXNoX2pvaW4iLCJtZXNoX21hbmFnZSJdLCJpYXQiOjE3NTc4NjQ3NTgsImlzcyI6Imh0dHBzOi8vYXV0aC4yZ2MucnUvcmVhbG1zL2Nsb3VkYnJpZGdlIiwiYXVkIjoiYWNjb3VudCIsInN1YiI6InNlcnZlci1jbGllbnQtc2VydmVyLTE3NTc3NjkyNjA4MjQiLCJqdGkiOiJqd3RfMTc1Nzg2NDc1ODQ1Ml9mM2FhZTRsOWwifQ.LMk61cPqnqx2-BubRhTwhfbV0JT5hPdMURiZi8yiGcc`

### 2. 🖥️ Windows служба

#### 2.1 Исследовать возможность работы как Windows служба
- **Вопрос**: Может ли клиент работать как Windows служба с предустановленным токеном?
- **Требования**: 
  - Автоматический запуск при старте системы
  - Работа в фоновом режиме
  - Логирование в Windows Event Log
  - Управление через Services.msc

#### 2.2 Реализовать Windows службу (если возможно)
- Добавить поддержку Windows Service API
- Создать installer для установки службы
- Настроить конфигурацию для службы

#### 2.3 Конфигурация для Windows службы
```yaml
# config-service.yaml
relay:
  host: "relay.2gc.ru"
  port: 9090
  tls:
    enabled: true

auth:
  type: "jwt"
  secret: "YOUR_JWT_SECRET"
  fallback_secret: "YOUR_FALLBACK_SECRET"

# P2P Mesh конфигурация для службы
p2p:
  peer_id: "server-001"
  endpoint: "192.168.1.100:51820"
  public_key: "WG_PUBLIC_KEY"
  private_key: "WG_PRIVATE_KEY"
  mesh_port: 51820
```

#### 2.4 Команды для Windows службы
```bash
# Установка службы
cloudbridge-client.exe install-service --config config-service.yaml --token "REAL_TOKEN"

# Запуск службы
net start CloudBridgeClient

# Остановка службы
net stop CloudBridgeClient

# Удаление службы
cloudbridge-client.exe uninstall-service
```

### 3. 🧪 Тестирование

#### 3.1 Локальное тестирование
```bash
# 1. Собрать клиент
make build

# 2. Создать тестовую конфигурацию
cp config.yaml config-test.yaml
# Отредактировать config-test.yaml с правильными секретами

# 3. Протестировать подключение
./cloudbridge-client --config config-test.yaml --token "REAL_TOKEN" --verbose
```

#### 3.2 Тестирование P2P Mesh команд
```bash
# P2P Mesh режим
./cloudbridge-client p2p \
  --config config.yaml \
  --token "REAL_TOKEN" \
  --peer-id "server-001" \
  --endpoint "192.168.1.100:51820" \
  --public-key "WG_PUBLIC_KEY" \
  --private-key "WG_PRIVATE_KEY" \
  --mesh-port 51820 \
  --verbose

# Tunnel режим (существующий)
./cloudbridge-client tunnel \
  --config config.yaml \
  --token "REAL_TOKEN" \
  --tunnel-id "tunnel_001" \
  --local-port 3389 \
  --remote-host "192.168.1.100" \
  --remote-port 3389 \
  --verbose
```

#### 3.2 Тестирование с реальным сервером
```bash
# 1. Обновить конфигурацию на реальные хосты
relay:
  host: "relay.2gc.ru"
  port: 9090
  tls:
    enabled: true

# 2. Протестировать подключение к реальному серверу
./cloudbridge-client --config config.yaml --token "REAL_TOKEN" --verbose
```

#### 3.3 Тестирование P2P функциональности
- Проверить регистрацию пира
- Протестировать создание туннеля
- Проверить работу WireGuard интеграции

## 📝 Структура токена

### Header:
```json
{
  "alg": "HS256",
  "kid": "fallback-key",
  "typ": "JWT"
}
```

### Payload:
```json
{
  "aud": "account",
  "iat": 1757864758,
  "iss": "https://auth.2gc.ru/realms/cloudbridge",
  "jti": "jwt_1757864758452_f3aae4l9l",
  "max_peers": "10",
  "org_id": "b2dbb292-d833-4de2-921a-2e12aeacf880",
  "permissions": ["mesh_join", "mesh_manage"],
  "protocol_type": "p2p-mesh",
  "scope": "p2p-mesh-claims",
  "server_id": "server-1757769260824",
  "sub": "server-client-server-1757769260824",
  "tenant_id": "b2dbb292-d833-4de2-921a-2e12aeacf880"
}
```

### ⚠️ ОТСУТСТВУЮЩИЕ ПОЛЯ ДЛЯ P2P MESH:
Токен не содержит информацию о подсети, которая необходима для P2P mesh:

```json
{
  "network_config": {
    "subnet": "10.0.0.0/24",
    "dns": ["8.8.8.8", "1.1.1.1"],
    "mtu": 1420
  },
  "wireguard_config": {
    "private_key": "WG_PRIVATE_KEY",
    "public_key": "WG_PUBLIC_KEY", 
    "allowed_ips": ["10.0.0.0/24"],
    "endpoint": "192.168.1.100:51820",
    "listen_port": 51820,
    "mtu": 1420
  },
  "mesh_config": {
    "network_id": "mesh-network-001",
    "subnet": "10.0.0.0/24",
    "max_peers": 10
  }
}
```

## 🔧 Технические детали

### Текущее состояние:
- ✅ Клиент собирается без ошибок
- ✅ TCP соединение работает
- ✅ JWT валидация реализована
- ✅ Поддержка fallback секрета добавлена
- ❌ Fallback секрет не настроен
- ❌ Windows служба не реализована

### Необходимые изменения:
1. Получить fallback секрет от DevOps
2. Обновить конфигурацию
3. Протестировать с реальным сервером
4. Реализовать Windows службу (если требуется)

## 📞 Контакты

- **DevOps**: Получить fallback секрет для `kid: "fallback-key"`
- **Keycloak**: Токены генерируются в `https://auth.2gc.ru/realms/cloudbridge`
- **Relay Server**: `relay.2gc.ru:9090`

## ✅ Критерии готовности

- [ ] Fallback секрет получен и настроен
- [ ] Клиент успешно подключается к реальному серверу
- [ ] JWT токен валидируется корректно
- [ ] P2P функциональность работает
- [ ] Windows служба реализована (если требуется)
- [ ] Документация обновлена

## 🚀 Следующие шаги

1. **Немедленно**: Связаться с DevOps для получения fallback секрета
2. **Краткосрочно**: Протестировать с реальным сервером
3. **Среднесрочно**: Реализовать Windows службу
4. **Долгосрочно**: Оптимизировать производительность и добавить мониторинг
