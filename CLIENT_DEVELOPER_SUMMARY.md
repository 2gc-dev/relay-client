# Краткое резюме для разработчика клиента

## 🚀 Что изменилось в CloudBridge Relay

### Новые возможности
- ✅ **P2P маршрутизация** через QUIC протокол
- ✅ **Мультитунельность** - изоляция между пользователями
- ✅ **Heartbeat система** - поддержание соединений
- ✅ **ICE/STUN/TURN** - NAT traversal

## 📡 Основные изменения API

### 1. Новый P2P API endpoint
```
https://edge.2gc.ru:8082  # Вместо 8080
```

### 2. Обязательные поля
- `relay_session_id` - теперь обязателен для heartbeat
- `tenant_id` - изоляция между пользователями
- `peer_id` - уникальный идентификатор пира

### 3. Heartbeat обязателен
```javascript
// Каждые 30 секунд
POST /api/v1/tenants/{tenant_id}/peers/{peer_id}/heartbeat
{
  "status": "active",
  "relay_session_id": "rs_abc123def456"
}
```

## 🔧 Что нужно обновить в клиенте

### 1. API URL
```javascript
// Было
const serverUrl = 'https://edge.2gc.ru:8080';

// Стало
const serverUrl = 'https://edge.2gc.ru:8082';
```

### 2. Heartbeat
```javascript
// Добавить heartbeat каждые 30 секунд
setInterval(async () => {
  await client.sendHeartbeat({
    status: 'active',
    relaySessionId: registration.relay_session_id
  });
}, 30000);
```

### 3. Tenant ID
```javascript
// Использовать tenant_id из JWT токена
const tenantId = jwtPayload.tenant_id;
```

## 🌐 Новые порты

### Добавить в конфигурацию
```
9090/UDP  - QUIC P2P Transport
9092/UDP  - Enhanced QUIC
19302/UDP - STUN Server
3478/UDP  - TURN Server (UDP)
3478/TCP  - TURN Server (TCP)
```

## 📋 Алгоритм подключения

1. **Регистрация пира** → получить `peer_id` и `relay_session_id`
2. **Обнаружение пиров** → найти других пиров в tenant
3. **Heartbeat** → отправлять каждые 30 секунд
4. **P2P соединение** → через QUIC на порту 9090

## ⚠️ Критически важно

- **Heartbeat обязателен** - без него пир будет offline
- **Tenant изоляция** - пиры видят только свой tenant
- **JWT токен** - должен содержать правильный tenant_id
- **STUN/TURN** - для NAT traversal

## 🎯 Минимальные изменения

```javascript
// 1. Обновить URL
const client = new CloudBridgeClient({
  serverUrl: 'https://edge.2gc.ru:8082', // ← Изменить
  jwtToken: 'your-jwt-token',
  tenantId: 'tenant-216420165' // ← Добавить
});

// 2. Добавить heartbeat
setInterval(() => {
  client.sendHeartbeat({
    status: 'active',
    relaySessionId: registration.relay_session_id // ← Добавить
  });
}, 30000);

// 3. Использовать peer_id
const peers = await client.discoverPeers();
peers.peers.forEach(peer => {
  console.log('Peer:', peer.peer_id); // ← Новое поле
});
```

## 📞 Поддержка

- **Полная документация**: `CLIENT_DEVELOPER_GUIDE.md`
- **Тестирование**: `test-p2p-with-token.sh`
- **Email**: support@2gc.ru

---

**Главное**: Обновите URL на 8082, добавьте heartbeat и используйте tenant_id!
