# P2P Module

Модуль P2P (Peer-to-Peer) для CloudBridge Client обеспечивает поддержку WireGuard mesh сетей и peer discovery.

## Архитектура

```
p2p/
├── types.go          # Типы данных для P2P
├── manager.go        # Основной менеджер P2P
├── wireguard.go      # WireGuard клиент
├── discovery.go      # Peer discovery
├── mesh.go          # Mesh network management
├── logger.go        # Логирование
└── README.md        # Документация
```

## Основные компоненты

### 1. P2P Manager (`manager.go`)
Центральный компонент, управляющий всеми P2P соединениями:
- Инициализация WireGuard клиента
- Управление peer discovery
- Управление mesh сетью
- Определение типа соединения из JWT токена

### 2. WireGuard Client (`wireguard.go`)
Реализует WireGuard протокол для P2P соединений:
- UDP соединения на порту 51820
- Handshake с пирами
- Управление пирами
- Статистика трафика

### 3. Peer Discovery (`discovery.go`)
Автоматическое обнаружение пиров в mesh сети:
- Регистрация в peer registry
- Heartbeat с registry
- Обнаружение новых пиров
- Управление whitelist

### 4. Mesh Network (`mesh.go`)
Управление mesh сетью и маршрутизацией:
- Топология сети
- Маршрутизация (hybrid, direct, relay)
- Health checks
- Статистика mesh

## Типы соединений

### 1. Client-Server (`client-server`)
Стандартное соединение через relay сервер:
- TCP соединение
- TLS 1.3
- Стандартный протокол CloudBridge

### 2. Server-Server (`server-server`)
Сервер-сервер соединение:
- WireGuard P2P
- Прямое соединение между серверами
- Высокая производительность

### 3. P2P Mesh (`p2p-mesh`)
Полноценная mesh сеть:
- WireGuard P2P
- Peer discovery
- Автоматическая маршрутизация
- Fallback на relay

## Конфигурация JWT

P2P модуль извлекает конфигурацию из JWT токена:

```json
{
  "connection_type": "p2p-mesh",
  "wireguard_config": {
    "private_key": "base64-encoded-key",
    "public_key": "base64-encoded-key",
    "allowed_ips": ["10.0.0.0/8"],
    "endpoint": "edge.2gc.ru:51820"
  },
  "mesh_config": {
    "auto_discovery": true,
    "persistent": true,
    "routing": "hybrid",
    "encryption": "wireguard"
  },
  "peer_whitelist": {
    "allowed_peers": ["peer1-key", "peer2-key"],
    "auto_approve": false,
    "max_peers": 10
  },
  "network_config": {
    "subnet": "10.0.1.0/24",
    "dns": ["8.8.8.8", "1.1.1.1"],
    "mtu": 1420
  }
}
```

## Использование

### Создание P2P Manager

```go
import "github.com/2gc-dev/cloudbridge-client/pkg/p2p"

// Создание конфигурации
config := &p2p.P2PConfig{
    ConnectionType: p2p.ConnectionTypeP2PMesh,
    WireGuardConfig: &p2p.WireGuardConfig{
        PrivateKey: "private-key",
        PublicKey:  "public-key",
        ListenPort: 51820,
    },
    MeshConfig: &p2p.MeshConfig{
        AutoDiscovery: true,
        Routing:       "hybrid",
    },
}

// Создание логгера
logger := p2p.NewSimpleLogger("p2p")

// Создание менеджера
manager := p2p.NewManager(config, logger)

// Запуск
if err := manager.Start(); err != nil {
    log.Fatal(err)
}

// Получение статуса
status := manager.GetStatus()
fmt.Printf("P2P Status: %+v\n", status)

// Остановка
manager.Stop()
```

### Извлечение конфигурации из JWT

```go
import "github.com/2gc-dev/cloudbridge-client/pkg/auth"

// Валидация токена
token, err := authManager.ValidateToken(tokenString)
if err != nil {
    return err
}

// Извлечение P2P конфигурации
p2pConfig, err := p2p.ExtractP2PConfigFromToken(authManager, token)
if err != nil {
    return err
}

// Создание P2P менеджера
manager := p2p.NewManager(p2pConfig, logger)
```

## Безопасность

- Все WireGuard ключи валидируются
- Peer whitelist проверяется
- JWT токены валидируются
- Логирование всех операций
- Защита от path traversal
- Безопасные права доступа к файлам

## Мониторинг

P2P модуль предоставляет метрики:
- Количество активных пиров
- Статистика трафика
- Задержка соединений
- Статус mesh сети
- События peer discovery

## Fallback механизм

При недоступности P2P соединения:
1. Автоматический fallback на client-server режим
2. Уведомление клиента о недоступности P2P
3. Сохранение конфигурации для повторной попытки

## Тестирование

```bash
# Запуск тестов P2P модуля
go test ./pkg/p2p/...

# Тесты с покрытием
go test -cover ./pkg/p2p/...

# Бенчмарки
go test -bench=. ./pkg/p2p/...
```

## Интеграция с CloudBridge Client

P2P модуль интегрируется с основным CloudBridge Client:

1. **Аутентификация**: Извлечение P2P конфигурации из JWT
2. **Протокол**: Поддержка новых типов сообщений
3. **Метрики**: Интеграция с Prometheus
4. **Логирование**: Структурированное логирование
5. **Конфигурация**: YAML конфигурация

## Совместимость

- **Go**: 1.25+
- **WireGuard**: Стандартный протокол
- **JWT**: RS256/HS256 подписи
- **TLS**: 1.3 для fallback соединений
- **UDP**: Порт 51820 для WireGuard

