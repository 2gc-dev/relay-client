# Руководство для разработчика клиента CloudBridge Relay

## 🚀 Обновления P2P маршрутизации

### Что изменилось
- ✅ Добавлена полноценная P2P маршрутизация через QUIC
- ✅ Реализована мультитунельность с изоляцией между пользователями
- ✅ Добавлена heartbeat система для поддержания соединений
- ✅ Интегрированы ICE/STUN серверы для NAT traversal

## 📡 API Endpoints

### Базовый URL
```
https://edge.2gc.ru:8082  # P2P API
https://edge.2gc.ru:8080  # HTTP API (legacy)
```

### Аутентификация
Все запросы требуют JWT токен в заголовке:
```http
Authorization: Bearer <JWT_TOKEN>
```

## 🔧 Основные API методы

### 1. Регистрация пира
```http
POST /api/v1/tenants/{tenant_id}/peers/register
Content-Type: application/json
Authorization: Bearer <JWT_TOKEN>

{
  "public_key": "client-public-key",
  "allowed_ips": ["10.100.77.10/32"],
  "peer_info": {
    "name": "Client Name",
    "location": "Client Location"
  }
}
```

**Ответ:**
```json
{
  "success": true,
  "peer_id": "peer_server-client-123456789",
  "relay_session_id": "rs_abc123def456",
  "registered_at": "2025-09-18T23:33:09.182032254Z"
}
```

### 2. Обнаружение пиров
```http
GET /api/v1/tenants/{tenant_id}/peers/discover
Authorization: Bearer <JWT_TOKEN>
```

**Ответ:**
```json
{
  "success": true,
  "tenant_id": "tenant-216420165",
  "peers": [
    {
      "id": "peer_server-client-123456789",
      "peer_id": "peer_server-client-123456789",
      "tenant_id": "tenant-216420165",
      "connection_type": "relay-assisted",
      "relay_session_id": "rs_abc123def456",
      "wireguard_config": {
        "public_key": "client-public-key",
        "allowed_ips": ["10.100.77.10/32"]
      },
      "is_online": true,
      "last_seen": "2025-09-18T23:32:24.44412057Z",
      "mesh_status": "connected",
      "latency_ms": 0
    }
  ]
}
```

### 3. Heartbeat (обязательно каждые 30 секунд)
```http
POST /api/v1/tenants/{tenant_id}/peers/{peer_id}/heartbeat
Content-Type: application/json
Authorization: Bearer <JWT_TOKEN>

{
  "status": "active",
  "relay_session_id": "rs_abc123def456"
}
```

**Ответ:**
```json
{
  "success": true,
  "status": "active",
  "last_seen": "2025-09-18T23:33:09.182032254Z"
}
```

## 🌐 Сетевые порты и протоколы

### Доступные порты
```
8080/TCP  - HTTP API (legacy)
8082/TCP  - P2P API (новый)
9090/UDP  - QUIC P2P Transport
9092/UDP  - Enhanced QUIC
19302/UDP - STUN Server
8443/TCP  - HTTPS/MASQUE
3478/UDP  - TURN Server (UDP)
3478/TCP  - TURN Server (TCP)
```

### Рекомендуемый порядок подключения
1. **STUN** (19302/UDP) - для определения внешнего IP
2. **TURN** (3478/UDP, 3478/TCP) - для NAT traversal
3. **QUIC** (9090/UDP) - для P2P соединений
4. **Enhanced QUIC** (9092/UDP) - для продвинутых функций

## 🔐 JWT токен

### Структура токена
```json
{
  "protocol_type": "p2p-mesh",
  "scope": "p2p-mesh-claims",
  "org_id": "tenant-216420165",
  "tenant_id": "tenant-216420165",
  "server_id": "server-1758105689169",
  "connection_type": "wireguard",
  "max_peers": "10",
  "permissions": ["mesh_join", "mesh_manage"],
  "network_config": {
    "subnet": "10.0.0.0/24",
    "gateway": "10.0.0.1",
    "dns": ["8.8.8.8", "1.1.1.1"],
    "mtu": 1420,
    "firewall_rules": ["allow_ssh", "allow_http"],
    "enable_ipv6": false
  },
  "mesh_config": {
    "network_id": "mesh-network-001",
    "subnet": "10.0.0.0/16",
    "registry_url": "https://mesh-registry.2gc.ru",
    "heartbeat_interval": "30s",
    "max_peers": 10,
    "routing_strategy": "performance_optimal",
    "enable_auto_discovery": true,
    "trust_level": "basic"
  }
}
```

## 🚀 Алгоритм подключения клиента

### 1. Инициализация
```javascript
// Псевдокод
const client = new CloudBridgeClient({
  serverUrl: 'https://edge.2gc.ru:8082',
  jwtToken: 'your-jwt-token',
  tenantId: 'tenant-216420165'
});
```

### 2. Регистрация
```javascript
const registration = await client.register({
  publicKey: 'client-public-key',
  allowedIPs: ['10.100.77.10/32'],
  peerInfo: {
    name: 'My Client',
    location: 'Office'
  }
});

console.log('Peer ID:', registration.peer_id);
console.log('Relay Session:', registration.relay_session_id);
```

### 3. Обнаружение пиров
```javascript
const peers = await client.discoverPeers();
console.log('Available peers:', peers.peers.length);
```

### 4. Heartbeat (каждые 30 секунд)
```javascript
setInterval(async () => {
  await client.sendHeartbeat({
    status: 'active',
    relaySessionId: registration.relay_session_id
  });
}, 30000);
```

### 5. P2P соединение
```javascript
// Установка QUIC соединения
const quicConnection = await client.connectToPeer({
  peerId: 'target-peer-id',
  protocol: 'quic',
  port: 9090
});

// Отправка данных
await quicConnection.send('Hello from client!');
```

## 🔧 Конфигурация клиента

### Обязательные параметры
```javascript
const config = {
  // Сервер
  serverUrl: 'https://edge.2gc.ru:8082',
  jwtToken: 'your-jwt-token',
  tenantId: 'tenant-216420165',
  
  // Сеть
  allowedIPs: ['10.100.77.10/32'],
  publicKey: 'client-public-key',
  
  // Heartbeat
  heartbeatInterval: 30000, // 30 секунд
  
  // P2P
  p2pPort: 9090,
  stunServers: ['edge.2gc.ru:19302'],
  turnServers: [
    { url: 'turn:edge.2gc.ru:3478', username: 'user', credential: 'pass' }
  ]
};
```

### Опциональные параметры
```javascript
const advancedConfig = {
  // Enhanced QUIC
  enhancedQuicPort: 9092,
  enableEnhancedQuic: true,
  
  // MASQUE
  masqueUrl: 'https://edge.2gc.ru:8443',
  enableMasque: true,
  
  // Мониторинг
  enableMetrics: true,
  metricsPort: 9091,
  
  // Безопасность
  enableTLS: true,
  verifyCertificates: true
};
```

## 📊 Мониторинг и отладка

### Health Check
```http
GET /health
```

**Ответ:**
```json
{
  "status": "healthy",
  "timestamp": "2025-09-18T23:31:33.352871399Z",
  "services": {
    "database": "healthy",
    "redis": "healthy",
    "websocket": "healthy"
  },
  "metrics": {
    "active_connections": 0,
    "goroutines": 18,
    "memory_usage_mb": 3,
    "online_peers": 1,
    "total_peers": 1,
    "uptime_seconds": 96.581423874,
    "websocket_connections": 0
  },
  "version": "v1.0.0"
}
```

### Метрики Prometheus
```
GET http://edge.2gc.ru:9091/metrics
```

## ⚠️ Важные изменения

### 1. Новые обязательные поля
- `relay_session_id` - теперь обязателен для heartbeat
- `tenant_id` - изоляция между пользователями
- `peer_id` - уникальный идентификатор пира

### 2. Heartbeat обязателен
- Отправляйте heartbeat каждые 30 секунд
- Без heartbeat пир будет помечен как offline
- Используйте `relay_session_id` из регистрации

### 3. Мультитунельность
- Каждый tenant изолирован
- Пиры видят только других пиров в том же tenant
- JWT токен должен содержать правильный `tenant_id`

## 🐛 Отладка

### Частые ошибки
1. **401 Unauthorized** - проверьте JWT токен
2. **404 Not Found** - проверьте tenant_id в URL
3. **Peer offline** - проверьте heartbeat
4. **Connection failed** - проверьте STUN/TURN серверы

### Логи клиента
```javascript
client.on('error', (error) => {
  console.error('Client error:', error);
});

client.on('peerConnected', (peer) => {
  console.log('Peer connected:', peer.peer_id);
});

client.on('peerDisconnected', (peer) => {
  console.log('Peer disconnected:', peer.peer_id);
});
```

## 📚 Примеры кода

### JavaScript/Node.js
```javascript
const { CloudBridgeClient } = require('@2gc/cloudbridge-client');

const client = new CloudBridgeClient({
  serverUrl: 'https://edge.2gc.ru:8082',
  jwtToken: process.env.JWT_TOKEN,
  tenantId: 'tenant-216420165'
});

async function main() {
  // Регистрация
  const reg = await client.register({
    publicKey: 'client-public-key',
    allowedIPs: ['10.100.77.10/32']
  });
  
  // Heartbeat
  setInterval(() => {
    client.sendHeartbeat({
      status: 'active',
      relaySessionId: reg.relay_session_id
    });
  }, 30000);
  
  // Обнаружение пиров
  const peers = await client.discoverPeers();
  console.log('Peers:', peers.peers);
}

main().catch(console.error);
```

### Python
```python
import asyncio
from cloudbridge_client import CloudBridgeClient

async def main():
    client = CloudBridgeClient(
        server_url='https://edge.2gc.ru:8082',
        jwt_token='your-jwt-token',
        tenant_id='tenant-216420165'
    )
    
    # Регистрация
    reg = await client.register(
        public_key='client-public-key',
        allowed_ips=['10.100.77.10/32']
    )
    
    # Heartbeat
    asyncio.create_task(client.start_heartbeat(
        relay_session_id=reg['relay_session_id']
    ))
    
    # Обнаружение пиров
    peers = await client.discover_peers()
    print(f"Peers: {peers['peers']}")

if __name__ == '__main__':
    asyncio.run(main())
```

## 🎯 Следующие шаги

1. **Обновите клиент** для использования новых API endpoints
2. **Добавьте heartbeat** каждые 30 секунд
3. **Используйте tenant_id** для изоляции
4. **Настройте STUN/TURN** для NAT traversal
5. **Протестируйте P2P соединения** через QUIC

## 📞 Поддержка

- **Документация**: [ссылка на документацию]
- **GitHub**: [ссылка на репозиторий]
- **Telegram**: [ссылка на чат поддержки]
- **Email**: support@2gc.ru

---

**Версия документации**: 1.0.0  
**Дата обновления**: 2025-09-18  
**Совместимость**: CloudBridge Relay v1.0.0+
