# P2P Testing Guide - Правильные токены

## Обновления в клиенте

✅ **Исправлены проблемы:**
- Обновлены JWT токены на правильный P2P формат
- Исправлен tenant_id: `relay-test-tenant` (вместо `mesh-network-test`)
- Добавлены правильные поля: `protocol_type`, `connection_type`, `permissions`
- Исправлены API endpoints для регистрации peers

## Новые конфигурации

### Server A
```bash
./cloudbridge-client -config config-server-a-p2p.yaml
```

### Server B  
```bash
./cloudbridge-client -config config-server-b-p2p.yaml
```

## Что изменилось

### 1. JWT токены
- **Старый формат**: Keycloak-style с `user_id`, `permissions: ["relay_connect", "relay_tunnel"]`
- **Новый формат**: P2P-style с `server_id`, `protocol_type: "p2p-mesh"`, `connection_type: "quic"`, `permissions: ["p2p_connect", "p2p_relay"]`

### 2. API endpoints
- **Регистрация**: `http://192.168.49.2:32500/api/v1/tenants/relay-test-tenant/peers/register`
- **WebSocket**: `ws://192.168.49.2:32500/ws/peers`
- **Health**: `http://192.168.49.2:32500/health`

### 3. Tenant ID
- **Старый**: `mesh-network-test`
- **Новый**: `relay-test-tenant`

## Результаты регистрации

### Server A
- **peer_id**: `peer_server-a`
- **allocated_ip**: `10.100.77.10`
- **relay_session_id**: `rs_10eb156b35b99284de44455d7c18b84a`

### Server B
- **peer_id**: `peer_server-b`
- **allocated_ip**: `10.100.77.11`
- **relay_session_id**: `rs_369ec76775ba8365808c019c5b0997f9`

## Тестирование

1. **Запустить Server A**:
   ```bash
   cd test/relay-client
   ./cloudbridge-client -config config-server-a-p2p.yaml
   ```

2. **Запустить Server B** (на другом устройстве):
   ```bash
   cd test/relay-client
   ./cloudbridge-client -config config-server-b-p2p.yaml
   ```

3. **Проверить P2P соединение** между `10.100.77.10` и `10.100.77.11`

## Токены (14 дней)

### Server A Token:
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIyZ2MucnUiLCJzdWIiOiJzZXJ2ZXItYSIsImF1ZCI6WyJyZWxheS10ZXN0LXRlbmFudCJdLCJleHAiOjE3NjAzMDEwMzAsImlhdCI6MTc1OTA5MTQzMCwicHJvdG9jb2xfdHlwZSI6InAycC1tZXNoIiwidGVuYW50X2lkIjoicmVsYXktdGVzdC10ZW5hbnQiLCJzZXJ2ZXJfaWQiOiJzZXJ2ZXItYSIsImNvbm5lY3Rpb25fdHlwZSI6InF1aWMiLCJwZXJtaXNzaW9ucyI6WyJwMnBfY29ubmVjdCIsInAycF9yZWxheSJdfQ.Z-FxJBnk1kotUFrgYNridlb6jiS8Jr6Do8PMQJ9AHfs
```

### Server B Token:
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIyZ2MucnUiLCJzdWIiOiJzZXJ2ZXItYiIsImF1ZCI6WyJyZWxheS10ZXN0LXRlbmFudCJdLCJleHAiOjE3NjAzMDEwMzAsImlhdCI6MTc1OTA5MTQzMCwicHJvdG9jb2xfdHlwZSI6InAycC1tZXNoIiwidGVuYW50X2lkIjoicmVsYXktdGVzdC10ZW5hbnQiLCJzZXJ2ZXJfaWQiOiJzZXJ2ZXItYiIsImNvbm5lY3Rpb25fdHlwZSI6InF1aWMiLCJwZXJtaXNzaW9ucyI6WyJwMnBfY29ubmVjdCIsInAycF9yZWxheSJdfQ.ZUNG9phxBEKHtviBlxbgp84H4I1YFn24qhUaP6khnto
```
